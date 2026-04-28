use std::env;
use std::path::PathBuf;

#[cfg(target_os = "linux")]
use std::sync::LazyLock;

/// Returns system library directories for the current platform.
pub fn system_library_paths() -> Vec<PathBuf> {
    let mut paths = Vec::new();

    #[cfg(target_os = "windows")]
    {
        // Windows: System32 and SysWOW64.
        if let Ok(system_root) = env::var("SystemRoot") {
            paths.push(PathBuf::from(&system_root).join("System32"));
            // Include 32-bit DLL directory on 64-bit hosts.
            if env::var("PROCESSOR_ARCHITEW6432").is_ok() {
                paths.push(PathBuf::from(&system_root).join("SysWOW64"));
            }
        }
        // PATH can be unsafe for implicit DLL resolution.
        // Only enable when explicitly opted in.
        if env::var_os("LUKS_DLOPEN_SEARCH_PATH").is_some() {
            if let Ok(path_var) = env::var("PATH") {
                for dir in path_var.split(';') {
                    let dir = dir.trim();
                    if dir.is_empty() {
                        continue;
                    }
                    let p = PathBuf::from(dir);
                    if !p.is_absolute() {
                        continue;
                    }
                    paths.push(p);
                }
            }
        }
    }

    #[cfg(target_os = "linux")]
    {
        // Linux: LD_LIBRARY_PATH has priority.
        if let Ok(ld_path) = env::var("LD_LIBRARY_PATH") {
            for dir in ld_path.split(':') {
                paths.push(PathBuf::from(dir));
            }
        }
        // Default library directories.
        paths.push(PathBuf::from("/usr/local/lib"));
        paths.push(PathBuf::from("/usr/lib"));
        paths.push(PathBuf::from("/lib"));

        // Multiarch support (x86_64-linux-gnu, etc).
        if env::var_os("LUKS_DLOPEN_LINUX_MULTIARCH").is_some() {
            static MULTIARCH: LazyLock<Option<String>> = LazyLock::new(|| {
                std::process::Command::new("dpkg-architecture")
                    .arg("-qDEB_HOST_MULTIARCH")
                    .output()
                    .ok()
                    .and_then(|out| {
                        let s = String::from_utf8_lossy(&out.stdout).trim().to_string();
                        if s.is_empty() {
                            None
                        } else {
                            Some(s)
                        }
                    })
            });
            if let Some(arch_str) = MULTIARCH.as_deref() {
                paths.push(PathBuf::from(format!("/usr/local/lib/{}", arch_str)));
                paths.push(PathBuf::from(format!("/usr/lib/{}", arch_str)));
                paths.push(PathBuf::from(format!("/lib/{}", arch_str)));
            }
        }
    }

    #[cfg(target_os = "macos")]
    {
        // macOS: DYLD_LIBRARY_PATH has priority.
        if let Ok(dyld_path) = env::var("DYLD_LIBRARY_PATH") {
            for dir in dyld_path.split(':') {
                paths.push(PathBuf::from(dir));
            }
        }
        // Framework and default directories.
        paths.push(PathBuf::from("/usr/local/lib"));
        paths.push(PathBuf::from("/usr/lib"));
        paths.push(PathBuf::from("/System/Library/Frameworks"));
        paths.push(PathBuf::from("/Library/Frameworks"));
    }

    #[cfg(target_os = "android")]
    {
        // Android.
        paths.push(PathBuf::from("/system/lib"));
        paths.push(PathBuf::from("/system/lib64"));
        paths.push(PathBuf::from("/vendor/lib"));
        paths.push(PathBuf::from("/vendor/lib64"));
        // LD_LIBRARY_PATH on Android.
        if let Ok(ld_path) = env::var("LD_LIBRARY_PATH") {
            for dir in ld_path.split(':') {
                paths.push(PathBuf::from(dir));
            }
        }
    }

    // Custom LUKS_PATH variable (works on all platforms).
    if let Ok(luks_path) = env::var("LUKS_PATH") {
        let separator = if cfg!(windows) { ';' } else { ':' };
        for dir in luks_path.split(separator) {
            paths.push(PathBuf::from(dir));
        }
    }

    paths
}

/// Tries to find a library by name.
///
/// Search order:
/// 1. If path separators exist (`/` or `\`), skip resolution here (caller decides)
/// 2. Try executable directory
/// 3. Try system library directories
///
/// Returns `None` when not found.
pub fn find_library(name: &str) -> Option<PathBuf> {
    // If it has path separators, it is relative/absolute and handled by caller.
    if name.contains('/') || name.contains('\\') {
        return None; // Leave resolution to caller.
    }

    // Build possible file names.
    let names = library_file_names(name);

    // Try executable directory first (useful for bundled apps).
    if let Some(exe_dir) = executable_dir() {
        for lib_name in &names {
            let full_path = exe_dir.join(lib_name);
            if full_path.exists() {
                return Some(full_path);
            }
        }
    }

    // Search all system directories.
    for dir in system_library_paths() {
        for lib_name in &names {
            let full_path = dir.join(lib_name);
            if full_path.exists() {
                return Some(full_path);
            }
        }
    }

    None
}

/// Returns possible file names for a given library name.
///
/// Example: `testmodule` -> `testmodule.dll`, `libtestmodule.so`, `libtestmodule.dylib`.
fn library_file_names(name: &str) -> Vec<String> {
    let mut names = Vec::new();

    // If extension already exists, keep as-is.
    if std::path::Path::new(name).extension().is_some() {
        names.push(name.to_string());
        return names;
    }

    #[cfg(windows)]
    {
        names.push(format!("{}.dll", name));
    }

    #[cfg(target_os = "linux")]
    {
        // Linux: .so
        if name.starts_with("lib") {
            names.push(format!("{}.so", name));
        } else {
            names.push(format!("lib{}.so", name));
        }
        // Also try without `lib` prefix (some systems).
        names.push(format!("{}.so", name));
    }

    #[cfg(target_os = "macos")]
    {
        // macOS: .dylib
        if name.starts_with("lib") {
            names.push(format!("{}.dylib", name));
        } else {
            names.push(format!("lib{}.dylib", name));
        }
        // Also try without `lib` prefix.
        names.push(format!("{}.dylib", name));
    }

    names
}

/// Returns the current executable directory.
pub fn executable_dir() -> Option<PathBuf> {
    env::current_exe()
        .ok()
        .and_then(|p| p.parent().map(|p| p.to_path_buf()))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_library_file_names() {
        let names = library_file_names("test");
        assert!(names.iter().any(|n| n.contains("test")));

        // With extension it should return only that candidate.
        let names_ext = library_file_names("test.dll");
        assert_eq!(names_ext.len(), 1);
        assert_eq!(names_ext[0], "test.dll");
    }
}
