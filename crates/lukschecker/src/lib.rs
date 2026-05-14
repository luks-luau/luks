use std::collections::HashMap;
use std::ffi::CStr;
use std::hash::{Hash, Hasher};
use std::os::raw::c_char;
use std::path::{Path, PathBuf};

fn hash_str(s: &str) -> u64 {
    use std::collections::hash_map::DefaultHasher;
    let mut hasher = DefaultHasher::new();
    s.hash(&mut hasher);
    hasher.finish()
}

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

    let cache_path = std::env::temp_dir().join("luks_luau_checker.cache");
    let mut cache: HashMap<String, (u64, Vec<(String, u64)>)> = HashMap::new();
    if let Ok(content) = std::fs::read_to_string(&cache_path) {
        for line in content.lines() {
            let parts: Vec<&str> = line.split("::").collect();
            if parts.len() >= 2 {
                let target = parts[0].to_string();
                if let Ok(target_hash) = parts[1].parse::<u64>() {
                    let mut deps = Vec::new();
                    let mut i = 2;
                    while i + 1 < parts.len() {
                        if let Ok(h) = parts[i + 1].parse::<u64>() {
                            deps.push((parts[i].to_string(), h));
                        }
                        i += 2;
                    }
                    cache.insert(target, (target_hash, deps));
                }
            }
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

        let file_str = file.to_string_lossy().to_string();
        if let Ok(source) = std::fs::read_to_string(file) {
            let current_hash = hash_str(&source);

            let mut is_cached_and_valid = false;
            if let Some((cached_target_hash, deps)) = cache.get(&file_cache_key) {
                if cached_target_hash == &current_hash {
                    let mut all_deps_valid = true;
                    for (d_path, d_cached_hash) in deps {
                        if let Ok(d_content) = std::fs::read_to_string(d_path) {
                            if hash_str(&d_content) != *d_cached_hash {
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

            if is_cached_and_valid {
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

            let lines: Vec<&str> = source.lines().collect();
            let accessed_deps = std::cell::RefCell::new(Vec::new());

            // Native checking closure resolving required file dependencies recursively from disk
            let diags = analyzer.check(&file_str, |req_name| {
                if req_name == file_str {
                    return Some(source.clone());
                }

                let target_dir = resolve_require_path(file, req_name);
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
                    if let Ok(content) = std::fs::read_to_string(&tf) {
                        let tf_canon = std::fs::canonicalize(&tf).unwrap_or(tf);
                        let tf_str = tf_canon.to_string_lossy().to_string();
                        let mut borrow = accessed_deps.borrow_mut();
                        if !borrow.iter().any(|(p, _)| p == &tf_str) {
                            borrow.push((tf_str, hash_str(&content)));
                        }
                        return Some(content);
                    }
                }
                None
            });

            let had_diags = !diags.is_empty();

            for diag in diags {
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

            if !had_diags {
                cache.insert(file_cache_key, (current_hash, accessed_deps.into_inner()));
            } else {
                cache.remove(&file_cache_key);
            }
        }
    }

    let mut cache_out = String::new();
    for (target, (target_hash, deps)) in &cache {
        cache_out.push_str(target);
        cache_out.push_str("::");
        cache_out.push_str(&target_hash.to_string());
        for (d_path, d_hash) in deps {
            cache_out.push_str("::");
            cache_out.push_str(d_path);
            cache_out.push_str("::");
            cache_out.push_str(&d_hash.to_string());
        }
        cache_out.push('\n');
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
