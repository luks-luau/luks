use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::ffi::CStr;
use std::os::raw::c_char;
use std::path::{Path, PathBuf};

const CACHE_VERSION: u32 = 2;

#[derive(Serialize, Deserialize, Clone)]
struct CachedDiagnostic {
    severity: u8,
    line: u32,
    col: u32,
    end_line: u32,
    end_col: u32,
    message: String,
}

impl From<&luau_analyzer_sys::Diagnostic> for CachedDiagnostic {
    fn from(d: &luau_analyzer_sys::Diagnostic) -> Self {
        CachedDiagnostic {
            severity: d.severity,
            line: d.line,
            col: d.col,
            end_line: d.end_line,
            end_col: d.end_col,
            message: d.message.clone(),
        }
    }
}

impl From<&CachedDiagnostic> for luau_analyzer_sys::Diagnostic {
    fn from(d: &CachedDiagnostic) -> Self {
        luau_analyzer_sys::Diagnostic {
            severity: d.severity,
            line: d.line,
            col: d.col,
            end_line: d.end_line,
            end_col: d.end_col,
            message: d.message.clone(),
        }
    }
}

#[derive(Serialize, Deserialize)]
struct LocalCache {
    version: u32,
    files: HashMap<String, FileEntry>,
}

#[derive(Serialize, Deserialize)]
struct FileEntry {
    content_hash: String,
    mtime_secs: u64,
    mtime_nanos: u32,
    size: u64,
}

fn get_file_metadata(path: &Path) -> Option<(u64, u32, u64)> {
    let metadata = std::fs::metadata(path).ok()?;
    let mtime = metadata.modified().ok()?;
    let duration = mtime
        .duration_since(std::time::SystemTime::UNIX_EPOCH)
        .ok()?;
    Some((duration.as_secs(), duration.subsec_nanos(), metadata.len()))
}

fn resolve_local_cache_path(target_path: &Path) -> PathBuf {
    let mut current = target_path
        .canonicalize()
        .unwrap_or_else(|_| target_path.to_path_buf());
    while current.parent().is_some() {
        if current.join("Cargo.toml").is_file() {
            let luks_dir = current.join(".luks");
            std::fs::create_dir_all(&luks_dir).ok();
            return luks_dir.join("checker.cache.bin");
        }
        current.pop();
    }
    let fallback = PathBuf::from(".luks");
    std::fs::create_dir_all(&fallback).ok();
    fallback.join("checker.cache.bin")
}

fn global_cache_dir() -> PathBuf {
    let base = dirs::cache_dir()
        .unwrap_or_else(|| PathBuf::from(".luks"));
    let dir = base.join("luks").join("checker");
    std::fs::create_dir_all(&dir).ok();
    dir
}

fn global_cache_path(hash: &str) -> PathBuf {
    let dir = global_cache_dir();
    dir.join(&hash[..2]).join(format!("{}.bin", hash))
}

fn save_to_global_cache(hash: &str, diags: &[luau_analyzer_sys::Diagnostic]) {
    let path = global_cache_path(hash);
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent).ok();
    }
    let cached: Vec<CachedDiagnostic> = diags.iter().map(CachedDiagnostic::from).collect();
    if let Ok(data) = bincode::serialize(&cached) {
        let _ = std::fs::write(&path, &data);
    }
}

fn load_from_global_cache(hash: &str) -> Option<Vec<luau_analyzer_sys::Diagnostic>> {
    let path = global_cache_path(hash);
    let data = std::fs::read(&path).ok()?;
    let cached: Vec<CachedDiagnostic> = bincode::deserialize(&data).ok()?;
    Some(cached.iter().map(luau_analyzer_sys::Diagnostic::from).collect())
}

fn print_diagnostics(
    file: &Path,
    diags: &[luau_analyzer_sys::Diagnostic],
    total_errors: &mut i32,
    total_warnings: &mut i32,
    _cached: bool,
) {
    if diags.is_empty() {
        return;
    }

    let source_opt = std::fs::read_to_string(file).ok();
    let lines: Vec<&str> = source_opt
        .as_deref()
        .map(|s| s.lines().collect())
        .unwrap_or_default();

    for diag in diags {
        let severity_str = if diag.severity == 0 {
            *total_errors += 1;
            "\x1b[1;91merror\x1b[0m"
        } else {
            *total_warnings += 1;
            "\x1b[1;93mwarning\x1b[0m"
        };

        println!("{}: {}", severity_str, diag.message);
        println!(
            " \x1b[1;34m-->\x1b[0m {}:{}:{}",
            file.display(),
            diag.line + 1,
            diag.col + 1
        );

        let line_idx = diag.line as usize;
        if let Some(line_str) = lines.get(line_idx) {
            let line_num = diag.line + 1;
            let line_num_str = line_num.to_string();
            let margin_padding = " ".repeat(line_num_str.len());

            println!(" {} \x1b[1;34m|\x1b[0m", margin_padding);
            println!("{} \x1b[1;34m|\x1b[0m {}", line_num_str, line_str);

            let col = diag.col as usize;
            let end_col = diag.end_col as usize;
            let caret_len = if end_col > col { end_col - col } else { 1 };
            let prefix_spaces = " ".repeat(col);
            let carets = "^".repeat(caret_len);

            let carets_colored = if diag.severity == 0 {
                format!("\x1b[1;91m{}\x1b[0m", carets)
            } else {
                format!("\x1b[1;93m{}\x1b[0m", carets)
            };

            println!(
                " {} \x1b[1;34m|\x1b[0m {}{}",
                margin_padding, prefix_spaces, carets_colored
            );
        }
        println!();
    }
}

/// Entrypoint for checking scripts path via native static analysis.
///
/// # Safety
/// - `path_ptr` must be null or a valid pointer to a null-terminated UTF-8 string.
#[no_mangle]
pub unsafe extern "C-unwind" fn luks_checker_check_path(path_ptr: *const c_char) -> i32 {
    let result = std::panic::catch_unwind(|| {
        unsafe { luks_checker_check_path_inner(path_ptr) }
    });
    match result {
        Ok(code) => code,
        Err(e) => {
            let msg = if let Some(s) = e.downcast_ref::<&str>() {
                s
            } else if let Some(s) = e.downcast_ref::<String>() {
                s.as_str()
            } else {
                "unknown panic"
            };
            eprintln!(
                "\x1b[1;91merror\x1b[0m: lukschecker internal panic: {}",
                msg
            );
            -1
        }
    }
}

unsafe fn luks_checker_check_path_inner(path_ptr: *const c_char) -> i32 {
    let target_path = if path_ptr.is_null() {
        PathBuf::from(".")
    } else {
        match CStr::from_ptr(path_ptr).to_str() {
            Ok(s) => PathBuf::from(s),
            Err(_) => {
                println!("\x1b[1;91merror\x1b[0m: Invalid UTF-8 path provided.");
                return -1;
            }
        }
    };

    let mut files = Vec::new();
    if target_path.is_file() {
        files.push(target_path.clone());
    } else {
        visit_files(&target_path, &mut files);
        files.sort();
    }

    if files.is_empty() {
        return 0;
    }

    let start_time = std::time::Instant::now();
    let local_cache_path = resolve_local_cache_path(&target_path);

    // Load local cache (versioned, bincode)
    let mut local_cache: LocalCache = std::fs::read(&local_cache_path)
        .ok()
        .and_then(|data| bincode::deserialize(&data).ok())
        .filter(|c: &LocalCache| c.version == CACHE_VERSION)
        .unwrap_or(LocalCache {
            version: CACHE_VERSION,
            files: HashMap::new(),
        });

    let mut analyzer: Option<luau_analyzer_sys::NativeAnalyzer> = None;

    let mut total_errors = 0i32;
    let mut total_warnings = 0i32;
    let mut local_changed = false;

    for file in &files {
        let canon = std::fs::canonicalize(file).unwrap_or_else(|_| file.clone());
        let key = canon.to_string_lossy().to_string();

        // Try cache hit
        if let Some(entry) = local_cache.files.get(&key) {
            if let Some(meta) = get_file_metadata(&canon) {
                if entry.mtime_secs == meta.0
                    && entry.mtime_nanos == meta.1
                    && entry.size == meta.2
                {
                    if let Some(cached_diags) = load_from_global_cache(&entry.content_hash) {
                        print_diagnostics(file, &cached_diags, &mut total_errors, &mut total_warnings, true);
                        continue;
                    }
                }
            }
        }

        // Cache miss — analyze
        let source = match std::fs::read_to_string(file) {
            Ok(s) => s,
            Err(_) => continue,
        };

        let current_hash = blake3::hash(source.as_bytes()).to_hex().to_string();
        let current_meta = get_file_metadata(&canon).unwrap_or((0, 0, 0));

        // Check global cache by content hash (shared across projects)
        if let Some(cached_diags) = load_from_global_cache(&current_hash) {
            local_cache.files.insert(key, FileEntry {
                content_hash: current_hash,
                mtime_secs: current_meta.0,
                mtime_nanos: current_meta.1,
                size: current_meta.2,
            });
            local_changed = true;
            print_diagnostics(file, &cached_diags, &mut total_errors, &mut total_warnings, true);
            continue;
        }

        // Fresh analysis
        if analyzer.is_none() {
            let mut a = luau_analyzer_sys::NativeAnalyzer::new();
            let defs = include_str!("../../../types/dlopen.d.luau");
            a.add_definitions(defs);
            let luau_defs = include_str!("../../../types/luauDefinitions.d.luau");
            a.add_definitions(luau_defs);
            let task_defs = include_str!("../../../types/task.d.luau");
            a.add_definitions(task_defs);
            let builtin_defs = r#"
declare table: {
    clone: (<T>(t: T) -> T),
    freeze: (<T>(t: T) -> T),
    clear: ((t: any) -> ()),
    concat: ((t: any, sep: string?, i: number?, j: number?) -> string),
    create: (<V>(count: number, value: V?) -> {V}),
    find: ((t: any, value: any, init: number?) -> number?),
    foreach: ((t: any, f: (any, any) -> ()) -> ()),
    foreachi: ((t: any, f: (number, any) -> ()) -> ()),
    getn: ((t: any) -> number),
    insert: ((t: any, pos_or_val: any, val: any?) -> ()),
    isfrozen: ((t: any) -> boolean),
    maxn: ((t: any) -> number),
    move: ((a1: any, f: number, e: number, t: number, a2: any?) -> any),
    pack: ((...any) -> { [number]: any, n: number }),
    remove: ((t: any, pos: number?) -> any),
    sort: ((t: any, comp: ((any, any) -> boolean)?) -> ()),
    unpack: ((t: any, i: number?, j: number?) -> ...any),
}
"#;
            a.add_definitions(builtin_defs);
            analyzer = Some(a);
        }
        let a = analyzer.as_mut().unwrap();

        let diags = a.check(
            &key,
            |req_name| {
                if req_name == key {
                    return Some(source.clone());
                }
                std::fs::read_to_string(req_name).ok()
            },
            |curr_mod_path, req_name| {
                let current_path = PathBuf::from(curr_mod_path);
                let target_dir = resolve_require_path(&current_path, req_name);

                for ext in ["luau", "lua"] {
                    let p = target_dir.with_extension(ext);
                    if p.is_file() {
                        if let Ok(tf_canon) = std::fs::canonicalize(&p) {
                            return Some(tf_canon.to_string_lossy().to_string());
                        }
                    }
                }

                for ext in ["luau", "lua"] {
                    let p = target_dir.join(format!("init.{}", ext));
                    if p.is_file() {
                        if let Ok(tf_canon) = std::fs::canonicalize(&p) {
                            return Some(tf_canon.to_string_lossy().to_string());
                        }
                    }
                }

                None
            },
        );

        // Save to global cache (content-addressed)
        save_to_global_cache(&current_hash, &diags);

        // Update local cache
        local_cache.files.insert(key, FileEntry {
            content_hash: current_hash,
            mtime_secs: current_meta.0,
            mtime_nanos: current_meta.1,
            size: current_meta.2,
        });
        local_changed = true;

        print_diagnostics(file, &diags, &mut total_errors, &mut total_warnings, false);
    }

    // Write local cache only if changed
    if local_changed {
        if let Ok(data) = bincode::serialize(&local_cache) {
            let _ = std::fs::write(&local_cache_path, &data);
        }
    }

    println!(
        "    \x1b[1;92mFinished\x1b[0m static analysis target(s) in {:.2}s",
        start_time.elapsed().as_secs_f64()
    );

    let target_disp = if target_path.to_string_lossy() == "." {
        "workspace"
    } else {
        target_path
            .file_name()
            .and_then(|s| s.to_str())
            .unwrap_or("workspace")
    };

    let err_word = if total_errors == 1 { "error" } else { "errors" };
    let warn_word = if total_warnings == 1 { "warning" } else { "warnings" };

    if total_errors > 0 {
        if total_warnings > 0 {
            println!(
                "\x1b[1;91merror\x1b[0m: could not compile `{}` due to {} previous {}; {} {} emitted",
                target_disp, total_errors, err_word, total_warnings, warn_word
            );
        } else {
            println!(
                "\x1b[1;91merror\x1b[0m: could not compile `{}` due to {} previous {}",
                target_disp, total_errors, err_word
            );
        }
        1
    } else if total_warnings > 0 {
        println!(
            "\x1b[1;93mwarning\x1b[0m: `{}` checked successfully; {} {} emitted",
            target_disp, total_warnings, warn_word
        );
        0
    } else {
        println!(
            "\x1b[1;92msuccess\x1b[0m: `{}` checked successfully",
            target_disp
        );
        0
    }
}

fn visit_files(path: &Path, files: &mut Vec<PathBuf>) {
    if path.is_file() {
        let filename = path.file_name().and_then(|s| s.to_str()).unwrap_or("");
        if !filename.ends_with(".d.luau") {
            let ext = path.extension().and_then(|s| s.to_str()).unwrap_or("");
            if ext == "luau" || ext == "lua" {
                files.push(path.to_path_buf());
            }
        }
    } else if path.is_dir() {
        let name = path.file_name().and_then(|s| s.to_str()).unwrap_or("");
        if name == "target" || name.starts_with('.') && name != "." {
            return;
        }
        if let Ok(entries) = std::fs::read_dir(path) {
            for entry in entries.flatten() {
                visit_files(&entry.path(), files);
            }
        }
    }
}

fn resolve_require_path(script_path: &Path, req_str: &str) -> PathBuf {
    let filename = script_path
        .file_name()
        .and_then(|s| s.to_str())
        .unwrap_or("");
    let file_dir = script_path.parent().unwrap_or_else(|| Path::new("."));

    if let Some(rest) = req_str.strip_prefix("@self/") {
        let mut base = file_dir.to_path_buf();
        for segment in rest.split('/') {
            if segment == ".." {
                base.pop();
            } else if segment != "." && !segment.is_empty() {
                base.push(segment);
            }
        }
        return base;
    }

    if req_str == "@self" {
        return file_dir.to_path_buf();
    }

    let mut base = if filename == "init.luau" || filename == "init.lua" {
        file_dir
            .parent()
            .unwrap_or_else(|| Path::new("."))
            .to_path_buf()
    } else {
        file_dir.to_path_buf()
    };

    let cleaned_req = req_str.strip_prefix("./").unwrap_or(req_str);
    for segment in cleaned_req.split('/') {
        if segment == ".." {
            base.pop();
        } else if segment != "." && !segment.is_empty() {
            base.push(segment);
        }
    }
    base
}
