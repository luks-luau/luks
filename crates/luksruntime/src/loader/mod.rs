mod platform;
pub mod search;

pub use platform::clear_loaded_libs;
pub use platform::LuauExport;
pub use search::{executable_dir, find_library, system_library_paths};

use platform::load_export;
use std::path::PathBuf;

/// Loader de módulos dinâmicos (.dll, .so, .dylib)
pub struct ModuleLoader;

impl ModuleLoader {
    /// Cria um novo loader
    pub fn new() -> Self {
        Self
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
