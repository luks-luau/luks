mod cache;
mod platform;
pub mod search;

pub use platform::LuauExport;
pub use search::{find_library, system_library_paths, executable_dir};

use cache::ModuleCache;
use platform::load_export;
use std::path::PathBuf;

/// Loader de módulos dinâmicos (.dll, .so, .dylib)
pub struct ModuleLoader {
    #[allow(dead_code)]
    cache: ModuleCache, // TODO: Implementar cache real de handles
}

impl ModuleLoader {
    /// Cria um novo loader com cache vazio
    pub fn new() -> Self {
        Self {
            cache: ModuleCache::new(),
        }
    }

    /// Carrega um módulo do caminho especificado
    /// 
    /// NOTA: O processamento de "@self/", prefixo 'lib' e extensão é feito em lib.rs
    /// Esta função recebe o caminho já completo e pronto.
    pub fn load(&self, path: &str) -> Result<LuauExport, String> {
        let pathbuf = PathBuf::from(path);
        load_export(&pathbuf)
    }
}

impl Default for ModuleLoader {
    fn default() -> Self {
        Self::new()
    }
}
