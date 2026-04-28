mod platform;
pub mod search;

pub use platform::clear_loaded_libs;
pub use platform::LuauExport;
pub use search::{executable_dir, find_library, system_library_paths};

use platform::load_export;
use std::path::PathBuf;

/// Dynamic module loader (`.dll`, `.so`, `.dylib`).
pub struct ModuleLoader;

impl ModuleLoader {
    /// Creates a new loader instance.
    pub fn new() -> Self {
        Self
    }

    /// Loads a module from the provided path.
    ///
    /// NOTE: `@self/`, `lib` prefix, and extension processing happen in `lib.rs`.
    /// This function expects a fully resolved path.
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
