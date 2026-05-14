use std::path::{Component, Path, PathBuf};

/// Returns the provided base directory or falls back to current directory.
pub fn default_base_dir(base: Option<PathBuf>) -> PathBuf {
    base.or_else(|| std::env::current_dir().ok())
        .unwrap_or_else(|| PathBuf::from("."))
}

/// Resolves a runtime path from a base directory.
/// Supports `@self`, explicit relative paths, and absolute paths.
pub fn resolve_from_base(base: &Path, input: &str) -> PathBuf {
    // Make base absolute to correctly normalize relative paths like "foo/../bar"
    let base_abs = if base.is_absolute() {
        base.to_path_buf()
    } else {
        std::path::absolute(base).unwrap_or_else(|_| base.to_path_buf())
    };
    let base_abs = strip_verbatim(&base_abs);

    if let Some(rest) = input
        .strip_prefix("@self/")
        .or_else(|| input.strip_prefix("@self\\"))
    {
        return normalize_path(&base_abs.join(rest));
    }

    if input == "@self" {
        return base_abs;
    }

    let clean_input = input.strip_prefix('@').unwrap_or(input);
    let p = Path::new(clean_input);
    if is_explicit_relative(clean_input) {
        normalize_path(&base_abs.join(p))
    } else if p.is_absolute() {
        p.to_path_buf()
    } else {
        normalize_path(&base_abs.join(p))
    }
}

/// Checks whether a path is a simple name (no directory separators).
pub fn is_simple_name(input: &str) -> bool {
    !input.contains('/') && !input.contains('\\')
}

pub fn strip_verbatim(path: &Path) -> PathBuf {
    let s = path.to_string_lossy();
    if let Some(stripped) = s
        .strip_prefix("\\\\?\\")
        .or_else(|| s.strip_prefix("\\?\\"))
    {
        PathBuf::from(stripped)
    } else {
        path.to_path_buf()
    }
}

/// Normalizes a path by removing `.` and folding `..` segments.
pub fn normalize_path(path: &Path) -> PathBuf {
    let clean = strip_verbatim(path);
    let mut result = PathBuf::new();
    for component in clean.components() {
        match component {
            Component::Prefix(p) => result.push(p.as_os_str()),
            Component::RootDir => result.push(component.as_os_str()),
            Component::CurDir => {}
            Component::ParentDir => {
                if result.file_name().is_some() {
                    result.pop();
                }
            }
            Component::Normal(c) => {
                if c == ".." {
                    if result.file_name().is_some() {
                        result.pop();
                    }
                } else if c == "." {
                    // Ignora o diretório atual
                } else {
                    result.push(c);
                }
            }
        }
    }
    result
}

/// Applies platform library naming when extension is missing.
/// On Unix, also adds `lib` prefix when absent.
pub fn with_platform_library_extension(input: &Path) -> PathBuf {
    let mut path = input.to_path_buf();
    if path.extension().is_none() {
        #[cfg(not(windows))]
        {
            if let Some(filename) = path.file_name() {
                let name = filename.to_string_lossy();
                if !name.starts_with("lib") {
                    path.set_file_name(format!("lib{}", name));
                }
            }
        }
        path.set_extension(std::env::consts::DLL_EXTENSION);
    }
    path
}

/// Returns a canonical path when possible, otherwise absolute path fallback.
pub fn canonicalize_or_absolute(path: &Path) -> PathBuf {
    let res = std::fs::canonicalize(path)
        .or_else(|_| std::path::absolute(path))
        .unwrap_or_else(|_| path.to_path_buf());
    strip_verbatim(&res)
}

fn is_explicit_relative(input: &str) -> bool {
    input.starts_with("./")
        || input.starts_with("../")
        || input.starts_with(".\\")
        || input.starts_with("..\\")
}

/// Computes a standard relative require string (`./...` or `../...`) from a base directory to a target absolute path.
pub fn make_relative_path(base: &Path, target: &Path) -> String {
    let base_clean = strip_verbatim(base);
    let target_clean = strip_verbatim(target);

    let base_comps: Vec<_> = base_clean.components().collect();
    let target_comps: Vec<_> = target_clean.components().collect();

    let mut common_count = 0;
    for (b, t) in base_comps.iter().zip(target_comps.iter()) {
        if b == t {
            common_count += 1;
        } else {
            break;
        }
    }

    let up_count = base_comps.len().saturating_sub(common_count);
    let mut parts = Vec::new();

    if up_count == 0 {
        parts.push(".".to_string());
    } else {
        for _ in 0..up_count {
            parts.push("..".to_string());
        }
    }

    for comp in &target_comps[common_count..] {
        parts.push(comp.as_os_str().to_string_lossy().to_string());
    }

    parts.join("/")
}

/// Standardizes and cleans raw source identifiers from the Lua VM by stripping `@`, `[string "..."]`, and Windows verbatim prefixes.
pub fn clean_source_name(src: &str) -> &str {
    let s = src.strip_prefix('@').unwrap_or(src);
    let s = if let Some(inner) = s
        .strip_prefix("[string \"")
        .and_then(|str| str.strip_suffix("\"]"))
    {
        inner.strip_prefix('@').unwrap_or(inner)
    } else {
        s
    };
    s.strip_prefix("\\\\?\\")
        .or_else(|| s.strip_prefix("\\?\\"))
        .unwrap_or(s)
}

/// Probes for an existing Luau file or package folder candidate matching the path.
pub fn find_candidate_file(base: &Path) -> Option<PathBuf> {
    for ext in ["luau", "lua"] {
        let f = base.with_extension(ext);
        if f.is_file() {
            return Some(f);
        }
    }
    for ext in ["luau", "lua"] {
        let init = base.join(format!("init.{}", ext));
        if init.is_file() {
            return Some(init);
        }
    }
    None
}
