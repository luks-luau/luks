use std::path::{Component, Path, PathBuf};

/// Returns the provided base directory or falls back to current directory.
pub fn default_base_dir(base: Option<PathBuf>) -> PathBuf {
    base.or_else(|| std::env::current_dir().ok())
        .unwrap_or_else(|| PathBuf::from("."))
}

/// Resolves a runtime path from a base directory.
/// Supports `@self`, explicit relative paths, and absolute paths.
pub fn resolve_from_base(base: &Path, input: &str) -> PathBuf {
    if let Some(rest) = input
        .strip_prefix("@self/")
        .or_else(|| input.strip_prefix("@self\\"))
    {
        return base.join(rest);
    }

    if input == "@self" {
        return base.to_path_buf();
    }

    let p = Path::new(input);
    if is_explicit_relative(input) {
        base.join(p)
    } else if p.is_absolute() {
        p.to_path_buf()
    } else {
        base.join(p)
    }
}

/// Checks whether a path is a simple name (no directory separators).
pub fn is_simple_name(input: &str) -> bool {
    !input.contains('/') && !input.contains('\\')
}

/// Normalizes a path by removing `.` and folding `..` segments.
pub fn normalize_path(path: &Path) -> PathBuf {
    let mut result = PathBuf::new();
    for component in path.components() {
        match component {
            Component::Prefix(p) => result.push(p.as_os_str()),
            Component::RootDir => result.push(component.as_os_str()),
            Component::CurDir => {}
            Component::ParentDir => {
                if result.file_name().is_some() {
                    result.pop();
                }
            }
            Component::Normal(c) => result.push(c),
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
    std::fs::canonicalize(path)
        .or_else(|_| std::path::absolute(path))
        .unwrap_or_else(|_| path.to_path_buf())
}

fn is_explicit_relative(input: &str) -> bool {
    input.starts_with("./")
        || input.starts_with("../")
        || input.starts_with(".\\")
        || input.starts_with("..\\")
}
