use std::env;
use std::path::PathBuf;

#[cfg(target_os = "linux")]
use std::sync::LazyLock;

/// Retorna as pastas de biblioteca do sistema para a plataforma atual
pub fn system_library_paths() -> Vec<PathBuf> {
    let mut paths = Vec::new();

    #[cfg(target_os = "windows")]
    {
        // Windows: System32 e SysWOW64
        if let Ok(system_root) = env::var("SystemRoot") {
            paths.push(PathBuf::from(&system_root).join("System32"));
            // Para 32-bit DLLs em sistema 64-bit
            if env::var("PROCESSOR_ARCHITEW6432").is_ok() {
                paths.push(PathBuf::from(&system_root).join("SysWOW64"));
            }
        }
        // PATH pode ser perigoso para resolução implícita de DLLs.
        // Só habilita se o usuário optar explicitamente.
        if env::var_os("LUKS_DLOPEN_SEARCH_PATH").is_some() {
            if let Ok(path_var) = env::var("PATH") {
                for dir in path_var.split(';') {
                    paths.push(PathBuf::from(dir));
                }
            }
        }
    }

    #[cfg(target_os = "linux")]
    {
        // Linux: LD_LIBRARY_PATH tem prioridade
        if let Ok(ld_path) = env::var("LD_LIBRARY_PATH") {
            for dir in ld_path.split(':') {
                paths.push(PathBuf::from(dir));
            }
        }
        // Pastas padrão
        paths.push(PathBuf::from("/usr/local/lib"));
        paths.push(PathBuf::from("/usr/lib"));
        paths.push(PathBuf::from("/lib"));

        // Multiarch support (x86_64-linux-gnu, etc)
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

    #[cfg(target_os = "macos")]
    {
        // macOS: DYLD_LIBRARY_PATH tem prioridade
        if let Ok(dyld_path) = env::var("DYLD_LIBRARY_PATH") {
            for dir in dyld_path.split(':') {
                paths.push(PathBuf::from(dir));
            }
        }
        // Frameworks e pastas padrão
        paths.push(PathBuf::from("/usr/local/lib"));
        paths.push(PathBuf::from("/usr/lib"));
        paths.push(PathBuf::from("/System/Library/Frameworks"));
        paths.push(PathBuf::from("/Library/Frameworks"));
    }

    #[cfg(target_os = "android")]
    {
        // Android
        paths.push(PathBuf::from("/system/lib"));
        paths.push(PathBuf::from("/system/lib64"));
        paths.push(PathBuf::from("/vendor/lib"));
        paths.push(PathBuf::from("/vendor/lib64"));
        // LD_LIBRARY_PATH no Android
        if let Ok(ld_path) = env::var("LD_LIBRARY_PATH") {
            for dir in ld_path.split(':') {
                paths.push(PathBuf::from(dir));
            }
        }
    }

    // Variável customizada LUKS_PATH (funciona em todas as plataformas)
    if let Ok(luks_path) = env::var("LUKS_PATH") {
        let separator = if cfg!(windows) { ';' } else { ':' };
        for dir in luks_path.split(separator) {
            paths.push(PathBuf::from(dir));
        }
    }

    paths
}

/// Tenta encontrar uma biblioteca pelo nome
///
/// Ordem de busca:
/// 1. Se tiver path separators (/ ou \), não resolve aqui (o caller decide)
/// 2. Tenta no diretório do executável
/// 3. Tenta nas pastas de sistema
///
/// Retorna None se não encontrar
pub fn find_library(name: &str) -> Option<PathBuf> {
    // Se tem separadores de path, é um caminho relativo ou absoluto
    if name.contains('/') || name.contains('\\') {
        return None; // Deixa o caller resolver
    }

    // Monta os possíveis nomes de arquivo
    let names = library_file_names(name);

    // Tenta no diretório do executável (útil p/ apps empacotados)
    if let Some(exe_dir) = executable_dir() {
        for lib_name in &names {
            let full_path = exe_dir.join(lib_name);
            if full_path.exists() {
                return Some(full_path);
            }
        }
    }

    // Busca em todas as pastas do sistema
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

/// Retorna os possíveis nomes de arquivo para a biblioteca
///
/// Exemplo: "testmodule" → ["testmodule.dll", "libtestmodule.so", "libtestmodule.dylib"]
fn library_file_names(name: &str) -> Vec<String> {
    let mut names = Vec::new();

    // Se já tem extensão, usa só ele
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
        // Também tenta sem prefixo (alguns sistemas)
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
        // Também tenta sem prefixo
        names.push(format!("{}.dylib", name));
    }

    names
}

/// Retorna o diretório do executável atual
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

        // Com extensão deve retornar só ela
        let names_ext = library_file_names("test.dll");
        assert_eq!(names_ext.len(), 1);
        assert_eq!(names_ext[0], "test.dll");
    }
}
