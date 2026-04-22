use mlua::ffi;
use mlua::{Compiler, Lua, Result as LuaResult};
use std::ffi::{CStr, CString};
use std::path::PathBuf;
use std::ptr;

/// Normaliza um caminho removendo componentes . e ..
fn normalize_path(path: &std::path::Path) -> PathBuf {
    let mut result = PathBuf::new();
    for component in path.components() {
        match component {
            std::path::Component::Prefix(p) => result.push(p.as_os_str()),
            std::path::Component::RootDir => {
                result.push(component.as_os_str());
            }
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

pub mod loader;
pub mod luau_require;
pub mod utils;

#[repr(C)]
pub struct LuksRuntime {
    lua: Lua,
}

/// Obtém o diretório do script atual da global __script_dir__
unsafe fn get_script_dir(l: *mut ffi::lua_State) -> Option<std::path::PathBuf> {
    ffi::lua_getglobal(l, b"__script_dir__\0".as_ptr() as *const i8);
    let result = if ffi::lua_isstring(l, -1) != 0 {
        let ptr = ffi::lua_tostring(l, -1);
        if ptr.is_null() {
            None
        } else {
            let s = CStr::from_ptr(ptr).to_string_lossy();
            Some(std::path::PathBuf::from(s.as_ref()))
        }
    } else {
        None
    };
    ffi::lua_pop(l, 1);
    result
}

/// Função interna dlopen exposta ao Lua
/// Carrega uma biblioteca dinâmica e chama o luau_export
unsafe extern "C-unwind" fn lua_dlopen(l: *mut ffi::lua_State) -> i32 {
    if ffi::lua_isstring(l, 1) == 0 {
        ffi::lua_pushnil(l);
        let msg = CString::new("dlopen: argumento 1 deve ser string")
            .unwrap_or_else(|_| CString::new("dlopen: argumento inválido").unwrap());
        ffi::lua_pushstring(l, msg.as_ptr());
        return 2;
    }

    let arg_ptr = ffi::lua_tostring(l, 1);
    if arg_ptr.is_null() {
        ffi::lua_pushnil(l);
        let msg = CString::new("dlopen: argumento 1 inválido")
            .unwrap_or_else(|_| CString::new("dlopen: argumento inválido").unwrap());
        ffi::lua_pushstring(l, msg.as_ptr());
        return 2;
    }

    let arg = CStr::from_ptr(arg_ptr).to_string_lossy();

    // Obtém diretório do script atual (para @self/ e caminhos relativos)
    let script_dir = get_script_dir(l);

    // Determina o diretório base: @self/ ou caminho relativo usa diretório do script
    let raw_path = if let Some(rest) = arg
        .strip_prefix("@self/")
        .or_else(|| arg.strip_prefix("@self\\"))
    {
        // Resolve relativo ao diretório do script em execução
        let base = script_dir.unwrap_or_else(|| {
            std::env::current_dir().unwrap_or_else(|_| std::path::PathBuf::from("."))
        });
        base.join(rest)
    } else if arg.starts_with("./")
        || arg.starts_with("../")
        || arg.starts_with(".\\")
        || arg.starts_with("..\\")
    {
        // Caminho relativo explícito: resolve relativo ao diretório do script
        let base = script_dir.unwrap_or_else(|| {
            std::env::current_dir().unwrap_or_else(|_| std::path::PathBuf::from("."))
        });
        base.join(arg.as_ref())
    } else if !arg.contains('/') && !arg.contains('\\') {
        // Nome simples (sem separadores):
        // 1. Tenta diretório de script primeiro (com as mesmas variações de nome que serão carregadas)
        let script_base = script_dir.clone().unwrap_or_else(|| {
            std::env::current_dir().unwrap_or_else(|_| std::path::PathBuf::from("."))
        });

        let mut candidates: Vec<std::path::PathBuf> = Vec::new();
        let arg_path = std::path::Path::new(arg.as_ref());

        if arg_path.extension().is_some() {
            // Já tem extensão (ex: foo.dll) -> não adiciona DLL_EXTENSION
            candidates.push(script_base.join(arg.as_ref()));
        } else {
            // Candidato "direto" com extensão
            candidates.push(script_base.join(format!(
                "{}.{}",
                arg,
                std::env::consts::DLL_EXTENSION
            )));

            #[cfg(not(windows))]
            {
                // Em Unix, também tenta com prefixo lib quando apropriado
                if !arg.starts_with("lib") {
                    candidates.push(script_base.join(format!(
                        "lib{}.{}",
                        arg,
                        std::env::consts::DLL_EXTENSION
                    )));
                }
            }
        }

        if let Some(found) = candidates.into_iter().find(|p| p.exists()) {
            found
        } else if let Some(system_path) = loader::find_library(&arg) {
            // 2. Tenta nas pastas do sistema
            system_path
        } else {
            // 3. Fallback: caminho relativo ao script (a extensão será adicionada abaixo)
            script_base.join(arg.as_ref())
        }
    } else {
        // Caminho absoluto ou já qualificado
        let p = std::path::Path::new(arg.as_ref());
        if p.is_absolute() {
            p.to_path_buf()
        } else {
            // Se for um caminho relativo com separadores (ex: plugins/foo), resolve relativo ao script
            // para evitar depender do CWD do processo.
            let base = script_dir.unwrap_or_else(|| {
                std::env::current_dir().unwrap_or_else(|_| std::path::PathBuf::from("."))
            });
            base.join(p)
        }
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
            let sanitized = e.replace('\0', "\\0");
            let msg = CString::new(sanitized).unwrap_or_else(|_| CString::new("erro").unwrap());
            ffi::lua_pushstring(l, msg.as_ptr());
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

    // Configura o require nativo do Luau usando nosso trait Require
    let requirer = luau_require::LuksRequirer::new();
    let luau_require_fn = match lua.create_require_function(requirer) {
        Ok(f) => f,
        Err(e) => {
            eprintln!("create_require_function falhou: {}", e);
            return ptr::null_mut();
        }
    };

    // Cria wrapper que adiciona ./ a caminhos sem prefixo válido
    // Isso mantém compatibilidade com código que faz require("modulo") em vez de require("./modulo")
    let require_wrapper =
        lua.create_function(move |_lua, module: String| -> mlua::Result<mlua::Value> {
            let adjusted_path =
                if module.starts_with("./") || module.starts_with("../") || module.starts_with("@")
                {
                    module
                } else {
                    // Adiciona ./ para caminhos sem prefixo (relativo ao diretório do script)
                    format!("./{}", module)
                };
            luau_require_fn.call::<mlua::Value>(adjusted_path)
        });

    match require_wrapper {
        Ok(f) => {
            if let Err(e) = lua.globals().set("require", f) {
                eprintln!("falha ao registrar require: {}", e);
                return ptr::null_mut();
            }
        }
        Err(e) => {
            eprintln!("falha ao criar require wrapper: {}", e);
            return ptr::null_mut();
        }
    }

    // Registra dlopen
    if let Err(e) = register_dlopen(&lua) {
        eprintln!("falha ao registrar dlopen: {}", e);
        return ptr::null_mut();
    }

    let compiler = Compiler::new().set_optimization_level(1).set_debug_level(1);
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
    let src = match CStr::from_ptr(source).to_str() {
        Ok(s) => s,
        Err(e) => {
            return CString::new(format!("source inválido (utf-8): {}", e))
                .unwrap_or_else(|_| CString::new("source inválido").unwrap())
                .into_raw();
        }
    };
    let name_str = if chunk_name.is_null() {
        "luks_chunk"
    } else {
        match CStr::from_ptr(chunk_name).to_str() {
            Ok(s) => s,
            Err(e) => {
                return CString::new(format!("chunk_name inválido (utf-8): {}", e))
                    .unwrap_or_else(|_| CString::new("chunk_name inválido").unwrap())
                    .into_raw();
            }
        }
    };

    // Define __script_dir__ para @self/ funcionar corretamente
    let name_path = name_str.strip_prefix('@').unwrap_or(name_str);
    let script_dir = std::path::Path::new(name_path)
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
pub unsafe extern "C-unwind" fn luks_clear_loaded_libs() -> *mut i8 {
    match loader::clear_loaded_libs() {
        Ok(()) => ptr::null_mut(),
        Err(e) => CString::new(e)
            .unwrap_or_else(|_| CString::new("erro").unwrap())
            .into_raw(),
    }
}

#[no_mangle]
pub unsafe extern "C-unwind" fn luks_destroy(rt: *mut LuksRuntime) {
    if !rt.is_null() {
        drop(Box::from_raw(rt));
    }
}
