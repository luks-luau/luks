use libloading::{Library, Symbol};
use std::path::Path;
use std::sync::Mutex;

/// Tipo do export "luau_export" das bibliotecas carregadas
pub type LuauExport = unsafe extern "C-unwind" fn(*mut mlua::ffi::lua_State) -> i32;

// Mantém as libraries carregadas em memória para não descarregá-las
// (o símbolo luau_export precisa permanecer válido)
use std::sync::LazyLock;
static LOADED_LIBS: LazyLock<Mutex<Vec<Library>>> = LazyLock::new(|| Mutex::new(Vec::new()));

/// Carrega uma biblioteca e retorna o símbolo "luau_export"
pub fn load_export(path: &Path) -> Result<LuauExport, String> {
    let library = unsafe {
        Library::new(path)
            .map_err(|e| format!("falha ao carregar biblioteca '{}': {}", path.display(), e))?
    };

    // Obtém o símbolo primeiro
    let symbol: Symbol<LuauExport> = unsafe {
        library
            .get(b"luau_export\0")
            .map_err(|e| format!("símbolo 'luau_export' não encontrado: {}", e))?
    };

    // Copia o endereço da função
    let func: LuauExport = *symbol;

    // Mantém a library carregada em memória
    if let Ok(mut libs) = LOADED_LIBS.lock() {
        libs.push(library);
    }

    Ok(func)
}
