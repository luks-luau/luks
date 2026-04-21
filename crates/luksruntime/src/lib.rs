use mlua::{Lua, Compiler, Result as LuaResult};
use mlua::ffi as ffi;
use std::ffi::{CStr, CString};
use std::path::PathBuf;
use std::ptr;

/// Normaliza um caminho removendo componentes . e ..
fn normalize_path(path: &std::path::Path) -> PathBuf {
    let mut result = PathBuf::new();
    for component in path.components() {
        match component {
            std::path::Component::Prefix(p) => result.push(p.as_os_str()),
            std::path::Component::RootDir => result.push("/"),
            std::path::Component::CurDir => { /* ignora . */ }
            std::path::Component::ParentDir => {
                // Remove o último componente se houver
                if result.file_name().is_some() {
                    result.pop();
                }
            }
            std::path::Component::Normal(c) => result.push(c),
        }
    }
    result
}

pub mod require;
pub mod utils;
pub mod loader;

#[repr(C)]
pub struct LuksRuntime {
    lua: Lua,
}

/// Obtém o diretório do script atual da global __script_dir__
unsafe fn get_script_dir(l: *mut ffi::lua_State) -> Option<std::path::PathBuf> {
    ffi::lua_getglobal(l, b"__script_dir__\0".as_ptr() as *const i8);
    let result = if ffi::lua_isstring(l, -1) != 0 {
        let s = CStr::from_ptr(ffi::lua_tostring(l, -1)).to_string_lossy();
        Some(std::path::PathBuf::from(s.as_ref()))
    } else {
        None
    };
    ffi::lua_pop(l, 1);
    result
}

/// Função interna dlopen exposta ao Lua
/// Carrega uma biblioteca dinâmica e chama o luau_export
unsafe extern "C-unwind" fn lua_dlopen(l: *mut ffi::lua_State) -> i32 {
    let arg = CStr::from_ptr(ffi::luaL_checkstring(l, 1)).to_string_lossy();

    // Obtém diretório do script atual (para @self/ e caminhos relativos)
    let script_dir = get_script_dir(l);

    // Determina o diretório base: @self/ ou caminho relativo usa diretório do script
    let raw_path = if let Some(rest) = arg.strip_prefix("@self/") {
        // Resolve relativo ao diretório do script em execução
        let base = script_dir
            .unwrap_or_else(|| std::env::current_dir().unwrap_or_else(|_| std::path::PathBuf::from(".")));
        base.join(rest)
    } else if arg.starts_with("./") || arg.starts_with("../") {
        // Caminho relativo explícito: resolve relativo ao diretório do script
        let base = script_dir
            .unwrap_or_else(|| std::env::current_dir().unwrap_or_else(|_| std::path::PathBuf::from(".")));
        base.join(arg.as_ref())
    } else if !arg.contains('/') && !arg.contains('\\') {
        // Nome simples (sem separadores): 
        // 1. Tenta diretório do script primeiro
        let script_base = script_dir.clone()
            .unwrap_or_else(|| std::env::current_dir().unwrap_or_else(|_| std::path::PathBuf::from(".")));
        let script_path = script_base.join(arg.as_ref());
        if script_path.exists() {
            script_path
        } else {
            // 2. Tenta nas pastas do sistema
            if let Some(system_path) = loader::find_library(&arg) {
                system_path
            } else {
                // 3. Fallback: caminho relativo ao script
                script_path
            }
        }
    } else {
        // Caminho absoluto ou já qualificado
        std::path::PathBuf::from(arg.as_ref())
    };

    // Adiciona prefixo 'lib' no Linux/macOS se não tiver extensão e não começar com 'lib'
    let mut path = raw_path.clone();
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

    // Normaliza o caminho removendo . e ..
    let path = normalize_path(&path);

    let loader = loader::ModuleLoader::new();
    let path_str = path.to_string_lossy().to_string();
    
    match loader.load(&path_str) {
        Ok(export) => export(l),
        Err(e) => {
            ffi::lua_pushnil(l);
            ffi::lua_pushstring(l, CString::new(e).unwrap_or_default().as_ptr());
            2
        }
    }
}

/// Registra a função dlopen no estado Lua
fn register_dlopen(lua: &Lua) -> LuaResult<()> {
    // Usa exec_raw para acessar a FFI bruta de forma controlada
    unsafe {
        lua.exec_raw((), |state| {
            ffi::lua_pushcfunction(state, lua_dlopen);
            ffi::lua_setglobal(state, b"dlopen\0".as_ptr() as *const i8);
        })
    }
}

#[no_mangle]
pub unsafe extern "C-unwind" fn luks_new() -> *mut LuksRuntime {
    let lua = unsafe { Lua::unsafe_new() };

    if let Err(e) = require::init_require(&lua) {
        eprintln!("init_require falhou: {}", e);
        return ptr::null_mut();
    }

    // Registra dlopen
    if let Err(e) = register_dlopen(&lua) {
        eprintln!("falha ao registrar dlopen: {}", e);
        return ptr::null_mut();
    }

    let compiler = Compiler::new()
        .set_optimization_level(1)
        .set_debug_level(1);
    let _ = lua.set_compiler(compiler);

    Box::into_raw(Box::new(LuksRuntime { lua }))
}

#[no_mangle]
pub unsafe extern "C-unwind" fn luks_execute(
    rt: *mut LuksRuntime,
    source: *const i8,
    chunk_name: *const i8,
) -> *mut i8 {
    if rt.is_null() || source.is_null() {
        return CString::new("runtime ou source nulo").unwrap().into_raw();
    }
    let rt = &mut *rt;
    let src = CStr::from_ptr(source).to_str().unwrap_or("");
    let name_str = if chunk_name.is_null() {
        "luks_chunk"
    } else {
        CStr::from_ptr(chunk_name).to_str().unwrap_or("luks_chunk")
    };

    // Define __script_dir__ para @self/ funcionar corretamente
    let script_dir = std::path::Path::new(name_str)
        .parent()
        .map(|p| p.to_string_lossy().to_string())
        .unwrap_or_else(|| ".".to_string());
    let _ = rt.lua.globals().set("__script_dir__", script_dir.clone());

    match rt.lua.load(src).set_name(name_str).exec() {
        Ok(_) => ptr::null_mut(),
        Err(e) => CString::new(format!("runtime error: {}", e))
            .unwrap_or_else(|_| CString::new("erro").unwrap())
            .into_raw(),
    }
}

#[no_mangle]
pub unsafe extern "C-unwind" fn luks_free_error(err: *mut i8) {
    if !err.is_null() {
        drop(CString::from_raw(err));
    }
}

#[no_mangle]
pub unsafe extern "C-unwind" fn luks_destroy(rt: *mut LuksRuntime) {
    if !rt.is_null() {
        drop(Box::from_raw(rt));
    }
}