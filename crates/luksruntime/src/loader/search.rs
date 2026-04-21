use std::env;
use std::path::PathBuf;

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
        // Também procura no PATH
        if let Ok(path_var) = env::var("PATH") {
            for dir in path_var.split(';') {
                paths.push(PathBuf::from(dir));
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
        if let Ok(arch) = std::process::Command::new("dpkg-architecture")
            .arg("-qDEB_HOST_MULTIARCH")
            .output()
        {
            let arch_str = String::from_utf8_lossy(&arch.stdout).trim().to_string();
            if !arch_str.is_empty() {
                paths.push(PathBuf::from(format!("/usr/local/lib/{}", arch_str)));
                paths.push(PathBuf::from(format!("/usr/lib/{}", arch_str)));
                paths.push(PathBuf::from(format!("/lib/{}", arch_str)));
            }
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
/// 1. Se tiver path separators (/ ou \), usa como caminho relativo
/// 2. Tenta no diretório do script
/// 3. Tenta no diretório do executável
/// 4. Tenta nas pastas de sistema
/// 
/// Retorna None se não encontrar
pub fn find_library(name: &str) -> Option<PathBuf> {
    // Se tem separadores de path, é um caminho relativo ou absoluto
    if name.contains('/') || name.contains('\\') {
        return None; // Deixa o caller resolver
    }

    // Monta os possíveis nomes de arquivo
    let names = library_file_names(name);
    
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
    if name.contains('.') {
        names.push(name.to_string());
        return names;
    }

    #[cfg(windows)]
    {
        names.push(format!("{}.dll", name));
    }

    #[cfg(not(windows))]
    {
        // No Unix, tenta com prefixo 'lib'
        if name.starts_with("lib") {
            names.push(format!("{}.so", name));
            names.push(format!("{}.dylib", name));
        } else {
            names.push(format!("lib{}.so", name));
            names.push(format!("lib{}.dylib", name));
        }
        // Também tenta sem prefixo (alguns sistemas)
        names.push(format!("{}.so", name));
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
