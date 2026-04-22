use libloading::{Library, Symbol};
use std::path::Path;
use std::sync::Mutex;

/// Tipo do export "luau_export" das bibliotecas carregadas
pub type LuauExport = unsafe extern "C-unwind" fn(*mut mlua::ffi::lua_State) -> i32;

// Mantém as libraries carregadas em memória para não descarregá-las
// (o símbolo luau_export precisa permanecer válido)
use std::sync::LazyLock;
static LOADED_LIBS: LazyLock<Mutex<Vec<(std::path::PathBuf, Library)>>> =
    LazyLock::new(|| Mutex::new(Vec::new()));

/// Carrega uma biblioteca e retorna o símbolo "luau_export"
pub fn load_export(path: &Path) -> Result<LuauExport, String> {
    let key = std::fs::canonicalize(path)
        .or_else(|_| std::path::absolute(path))
        .unwrap_or_else(|_| path.to_path_buf());

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
