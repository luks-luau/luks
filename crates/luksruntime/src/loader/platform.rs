use crate::path_resolution::canonicalize_or_absolute;
use libloading::{Library, Symbol};
use std::path::Path;
use std::sync::Mutex;

/// Type of the `luau_export` entrypoint from loaded libraries.
pub type LuauExport = unsafe extern "C-unwind" fn(*mut mlua::ffi::lua_State) -> i32;

// Keep libraries alive for the process lifetime.
// The `luau_export` symbol must remain valid after lookup.
use std::sync::LazyLock;
static LOADED_LIBS: LazyLock<Mutex<Vec<(std::path::PathBuf, Library)>>> =
    LazyLock::new(|| Mutex::new(Vec::new()));

/// Loads a library and returns its `luau_export` symbol.
pub fn load_export(path: &Path) -> Result<LuauExport, String> {
    let key = canonicalize_or_absolute(path);

    let libs = LOADED_LIBS
        .lock()
        .map_err(|_| "falha ao adquirir lock de LOADED_LIBS".to_string())?;

    if let Some((_, lib)) = libs.iter().find(|(p, _)| *p == key) {
        let symbol: Symbol<LuauExport> = unsafe {
            lib.get(b"luau_export\0")
                .map_err(|e| format!("símbolo 'luau_export' não encontrado: {}", e))?
        };
        return Ok(*symbol);
    }
    drop(libs);

    let library = unsafe {
        Library::new(&key)
            .map_err(|e| format!("falha ao carregar biblioteca '{}': {}", key.display(), e))?
    };

    let symbol: Symbol<LuauExport> = unsafe {
        library
            .get(b"luau_export\0")
            .map_err(|e| format!("símbolo 'luau_export' não encontrado: {}", e))?
    };

    let func: LuauExport = *symbol;

    let mut libs = LOADED_LIBS
        .lock()
        .map_err(|_| "falha ao adquirir lock de LOADED_LIBS".to_string())?;
    if let Some((_, lib)) = libs.iter().find(|(p, _)| *p == key) {
        let symbol: Symbol<LuauExport> = unsafe {
            lib.get(b"luau_export\0")
                .map_err(|e| format!("símbolo 'luau_export' não encontrado: {}", e))?
        };
        return Ok(*symbol);
    }

    libs.push((key, library));
    Ok(func)
}

pub fn clear_loaded_libs() -> Result<(), String> {
    let mut libs = LOADED_LIBS
        .lock()
        .map_err(|_| "falha ao adquirir lock de LOADED_LIBS".to_string())?;
    libs.clear();
    Ok(())
}
