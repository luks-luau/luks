use std::collections::HashMap;
use std::ffi::CStr;
use std::os::raw::c_char;
use std::path::{Path, PathBuf};

/// Entrypoint for checking scripts path via native static analysis.
///
/// # Safety
/// - `path_ptr` must be null or a valid pointer to a null-terminated UTF-8 string.
#[no_mangle]
pub unsafe extern "C-unwind" fn luks_checker_check_path(path_ptr: *const c_char) -> i32 {
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

    struct CacheEntry {
        mtime_secs: u64,
        mtime_nanos: u32,
        size: u64,
        dependencies: HashMap<String, (u64, u32, u64)>,
        diagnostics: Vec<luau_analyzer_sys::Diagnostic>,
    }

    fn get_file_metadata(path: &Path) -> Option<(u64, u32, u64)> {
        let metadata = std::fs::metadata(path).ok()?;
        let mtime = metadata.modified().ok()?;
        let duration = mtime
            .duration_since(std::time::SystemTime::UNIX_EPOCH)
            .ok()?;
        Some((duration.as_secs(), duration.subsec_nanos(), metadata.len()))
    }

    fn resolve_cache_path(target_path: &Path) -> PathBuf {
        let mut current = target_path
            .canonicalize()
            .unwrap_or_else(|_| target_path.to_path_buf());
        while current.parent().is_some() {
            let cargo_toml = current.join("Cargo.toml");
            if cargo_toml.is_file() {
                let luks_dir = current.join(".luks");
                std::fs::create_dir_all(&luks_dir).ok();
                return luks_dir.join("checker.cache");
            }
            current.pop();
        }
        let fallback = PathBuf::from(".luks");
        std::fs::create_dir_all(&fallback).ok();
        fallback.join("checker.cache")
    }

    let cache_path = resolve_cache_path(&target_path);
    let mut cache: HashMap<String, CacheEntry> = HashMap::new();

    if let Ok(content) = std::fs::read_to_string(&cache_path) {
        let mut current_file: Option<String> = None;
        let mut current_entry: Option<CacheEntry> = None;

        for line in content.lines() {
            if let Some(stripped) = line.strip_prefix("FILE:") {
                if let (Some(f), Some(e)) = (current_file.take(), current_entry.take()) {
                    cache.insert(f, e);
                }
                let f_path = stripped.to_string();
                current_file = Some(f_path);
                current_entry = Some(CacheEntry {
                    mtime_secs: 0,
                    mtime_nanos: 0,
                    size: 0,
                    dependencies: HashMap::new(),
                    diagnostics: Vec::new(),
                });
            } else if let Some(stripped) = line.strip_prefix("MTIME:") {
                if let Some(ref mut entry) = current_entry {
                    let parts: Vec<&str> = stripped.split(':').collect();
                    if parts.len() == 3 {
                        entry.mtime_secs = parts[0].parse().unwrap_or(0);
                        entry.mtime_nanos = parts[1].parse().unwrap_or(0);
                        entry.size = parts[2].parse().unwrap_or(0);
                    }
                }
            } else if let Some(stripped) = line.strip_prefix("DEP:") {
                if let Some(ref mut entry) = current_entry {
                    let parts: Vec<&str> = stripped.split('|').collect();
                    if parts.len() == 2 {
                        let dep_path = parts[0].to_string();
                        let meta_parts: Vec<&str> = parts[1].split(':').collect();
                        if meta_parts.len() == 3 {
                            let secs = meta_parts[0].parse().unwrap_or(0);
                            let nanos = meta_parts[1].parse().unwrap_or(0);
                            let sz = meta_parts[2].parse().unwrap_or(0);
                            entry.dependencies.insert(dep_path, (secs, nanos, sz));
                        }
                    }
                }
            } else if let Some(stripped) = line.strip_prefix("DIAG:") {
                if let Some(ref mut entry) = current_entry {
                    let parts: Vec<&str> = stripped.split('|').collect();
                    if parts.len() == 6 {
                        let severity = parts[0].parse().unwrap_or(0);
                        let line_num = parts[1].parse().unwrap_or(0);
                        let col = parts[2].parse().unwrap_or(0);
                        let end_line = parts[3].parse().unwrap_or(0);
                        let end_col = parts[4].parse().unwrap_or(0);
                        let message = parts[5].replace("\\n", "\n").replace("\\pipe", "|");
                        entry.diagnostics.push(luau_analyzer_sys::Diagnostic {
                            severity,
                            line: line_num,
                            col,
                            end_line,
                            end_col,
                            message,
                        });
                    }
                }
            }
        }
        if let (Some(f), Some(e)) = (current_file, current_entry) {
            cache.insert(f, e);
        }
    }

    let mut analyzer = luau_analyzer_sys::NativeAnalyzer::new();

    // Load custom dlopen definitions
    let defs = include_str!("../../../types/dlopen.d.luau");
    analyzer.add_definitions(defs);

    // Load standard Luau global definitions
    let luau_defs = include_str!("../../../types/luauDefinitions.d.luau");
    analyzer.add_definitions(luau_defs);

    // Load global task scheduling definitions
    let task_defs = include_str!("../../../types/task.d.luau");
    analyzer.add_definitions(task_defs);

    // Register standard table overrides
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
    analyzer.add_definitions(builtin_defs);

    let mut total_errors = 0;
    let mut total_warnings = 0;

    for file in &files {
        let canon_file = std::fs::canonicalize(file).unwrap_or_else(|_| file.clone());
        let file_cache_key = canon_file.to_string_lossy().to_string();

        let mut is_cached_and_valid = false;
        if let Some(entry) = cache.get(&file_cache_key) {
            if let Some(current_meta) = get_file_metadata(&canon_file) {
                if entry.mtime_secs == current_meta.0
                    && entry.mtime_nanos == current_meta.1
                    && entry.size == current_meta.2
                {
                    let mut all_deps_valid = true;
                    for (dep_path, dep_cached_meta) in &entry.dependencies {
                        let dep_path_buf = PathBuf::from(dep_path);
                        if let Some(dep_current_meta) = get_file_metadata(&dep_path_buf) {
                            if dep_cached_meta.0 != dep_current_meta.0
                                || dep_cached_meta.1 != dep_current_meta.1
                                || dep_cached_meta.2 != dep_current_meta.2
                            {
                                all_deps_valid = false;
                                break;
                            }
                        } else {
                            all_deps_valid = false;
                            break;
                        }
                    }
                    if all_deps_valid {
                        is_cached_and_valid = true;
                    }
                }
            }
        }

        if is_cached_and_valid {
            let entry = cache.get(&file_cache_key).unwrap();
            let source_opt = std::fs::read_to_string(file);
            let lines: Vec<String> = if let Ok(ref src) = source_opt {
                src.lines().map(|s| s.to_string()).collect()
            } else {
                Vec::new()
            };

            if !entry.diagnostics.is_empty() {
                let filename = file.file_name().and_then(|s| s.to_str()).unwrap_or("");
                let module_name = if filename == "init.luau" || filename == "init.lua" {
                    file.parent()
                        .and_then(|p| p.file_name())
                        .and_then(|s| s.to_str())
                        .unwrap_or("workspace")
                } else {
                    file.file_stem()
                        .and_then(|s| s.to_str())
                        .unwrap_or(filename)
                };

                println!(
                    "    \x1b[1;92mChecking\x1b[0m {} ({}) [cached]",
                    module_name,
                    file.display()
                );

                for diag in &entry.diagnostics {
                    let severity_str = if diag.severity == 0 {
                        total_errors += 1;
                        "\x1b[1;91merror\x1b[0m"
                    } else {
                        total_warnings += 1;
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
                    let line_str = lines.get(line_idx).map(|s| s.as_str()).unwrap_or("");

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
                    println!();
                }
            }
            continue;
        }

        let filename = file.file_name().and_then(|s| s.to_str()).unwrap_or("");
        let module_name = if filename == "init.luau" || filename == "init.lua" {
            file.parent()
                .and_then(|p| p.file_name())
                .and_then(|s| s.to_str())
                .unwrap_or("workspace")
        } else {
            file.file_stem()
                .and_then(|s| s.to_str())
                .unwrap_or(filename)
        };

        println!(
            "    \x1b[1;92mChecking\x1b[0m {} ({})",
            module_name,
            file.display()
        );

        if let Ok(source) = std::fs::read_to_string(file) {
            let lines: Vec<&str> = source.lines().collect();
            let accessed_deps = std::cell::RefCell::new(Vec::new());

            let current_meta = get_file_metadata(&canon_file).unwrap_or((0, 0, 0));

            let diags = analyzer.check(
                &file_cache_key,
                |req_name| {
                    if req_name == file_cache_key {
                        return Some(source.clone());
                    }
                    if let Ok(content) = std::fs::read_to_string(req_name) {
                        return Some(content);
                    }
                    None
                },
                |curr_mod_path, req_name| {
                    let current_path = PathBuf::from(curr_mod_path);
                    let target_dir = resolve_require_path(&current_path, req_name);

                    let mut target_file = None;
                    for ext in ["luau", "lua"] {
                        let p = target_dir.with_extension(ext);
                        if p.is_file() {
                            target_file = Some(p);
                            break;
                        }
                    }

                    if target_file.is_none() {
                        for ext in ["luau", "lua"] {
                            let p = target_dir.join(format!("init.{}", ext));
                            if p.is_file() {
                                target_file = Some(p);
                                break;
                            }
                        }
                    }

                    if let Some(tf) = target_file {
                        if let Ok(tf_canon) = std::fs::canonicalize(&tf) {
                            let tf_str = tf_canon.to_string_lossy().to_string();
                            if let Some(meta) = get_file_metadata(&tf_canon) {
                                let mut borrow = accessed_deps.borrow_mut();
                                if !borrow.iter().any(|(p, _)| p == &tf_str) {
                                    borrow.push((tf_str.clone(), meta));
                                }
                            }
                            return Some(tf_str);
                        }
                    }
                    None
                },
            );

            for diag in &diags {
                let severity_str = if diag.severity == 0 {
                    total_errors += 1;
                    "\x1b[1;91merror\x1b[0m"
                } else {
                    total_warnings += 1;
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
                let line_str = lines.get(line_idx).unwrap_or(&"");

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
                println!();
            }

            cache.insert(
                file_cache_key,
                CacheEntry {
                    mtime_secs: current_meta.0,
                    mtime_nanos: current_meta.1,
                    size: current_meta.2,
                    dependencies: accessed_deps.into_inner().into_iter().collect(),
                    diagnostics: diags,
                },
            );
        }
    }

    let mut cache_out = String::new();
    for (file_path, entry) in &cache {
        cache_out.push_str(&format!("FILE:{}\n", file_path));
        cache_out.push_str(&format!(
            "MTIME:{}:{}:{}\n",
            entry.mtime_secs, entry.mtime_nanos, entry.size
        ));
        for (dep_path, dep_meta) in &entry.dependencies {
            cache_out.push_str(&format!(
                "DEP:{}|{}:{}:{}\n",
                dep_path, dep_meta.0, dep_meta.1, dep_meta.2
            ));
        }
        for diag in &entry.diagnostics {
            let escaped_msg = diag.message.replace('\n', "\\n").replace('|', "\\pipe");
            cache_out.push_str(&format!(
                "DIAG:{}|{}|{}|{}|{}|{}\n",
                diag.severity, diag.line, diag.col, diag.end_line, diag.end_col, escaped_msg
            ));
        }
    }
    std::fs::write(&cache_path, cache_out).ok();

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
    let warn_word = if total_warnings == 1 {
        "warning"
    } else {
        "warnings"
    };

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
