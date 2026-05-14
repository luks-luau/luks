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
                println!("\x1b[1;31merror\x1b[0m: Invalid UTF-8 path provided.");
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
        let file_str = file.to_string_lossy().to_string();
        if let Ok(source) = std::fs::read_to_string(file) {
            let lines: Vec<&str> = source.lines().collect();

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
                    std::fs::read_to_string(tf).ok()
                } else {
                    None
                }
            });

            for diag in diags {
                let severity_str = if diag.severity == 0 {
                    total_errors += 1;
                    "\x1b[1;31merror\x1b[0m"
                } else {
                    total_warnings += 1;
                    "\x1b[1;33mwarning\x1b[0m"
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
                    format!("\x1b[1;31m{}\x1b[0m", carets)
                } else {
                    format!("\x1b[1;33m{}\x1b[0m", carets)
                };

                println!(
                    " {} \x1b[1;34m|\x1b[0m {}{}",
                    margin_padding, prefix_spaces, carets_colored
                );
                println!();
            }
        }
    }

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
                "\x1b[1;31merror\x1b[0m: could not compile `{}` due to {} previous {}; {} {} emitted",
                target_disp, total_errors, err_word, total_warnings, warn_word
            );
        } else {
            println!(
                "\x1b[1;31merror\x1b[0m: could not compile `{}` due to {} previous {}",
                target_disp, total_errors, err_word
            );
        }
        1
    } else if total_warnings > 0 {
        println!(
            "\x1b[1;33mwarning\x1b[0m: `{}` checked successfully; {} {} emitted",
            target_disp, total_warnings, warn_word
        );
        0
    } else {
        println!(
            "\x1b[1;32msuccess\x1b[0m: `{}` checked successfully",
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
