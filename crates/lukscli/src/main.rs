// crates/lukscli/src/main.rs
use libloading::{Library, Symbol};
use std::env;
use std::ffi::{CStr, CString};
use std::fs;
use std::path::PathBuf;
use std::process;

/// Estrutura que encapsula o runtime carregado dinamicamente
struct RuntimeHandle {
    #[allow(dead_code)]
    library: Library,
    luks_new: unsafe extern "C-unwind" fn() -> *mut std::ffi::c_void,
    luks_execute: unsafe extern "C-unwind" fn(*mut std::ffi::c_void, *const i8, *const i8) -> *mut i8,
    luks_destroy: unsafe extern "C-unwind" fn(*mut std::ffi::c_void),
    luks_free_error: unsafe extern "C-unwind" fn(*mut i8),
}

impl RuntimeHandle {
    /// Carrega o runtime da biblioteca dinâmica
    fn load() -> Result<Self, String> {
        // Encontra o caminho da biblioteca
        let lib_path = Self::find_runtime_library()?;

        let library = unsafe {
            Library::new(&lib_path)
                .map_err(|e| format!("falha ao carregar '{}': {}", lib_path.display(), e))?
        };

        // Carrega os símbolos e copia os ponteiros de função imediatamente
        let luks_new = unsafe {
            let sym: Symbol<unsafe extern "C-unwind" fn() -> *mut std::ffi::c_void> = library
                .get(b"luks_new\0")
                .map_err(|e| format!("símbolo 'luks_new' não encontrado: {}", e))?;
            *sym
        };

        let luks_execute = unsafe {
            let sym: Symbol<unsafe extern "C-unwind" fn(*mut std::ffi::c_void, *const i8, *const i8) -> *mut i8> = library
                .get(b"luks_execute\0")
                .map_err(|e| format!("símbolo 'luks_execute' não encontrado: {}", e))?;
            *sym
        };

        let luks_destroy = unsafe {
            let sym: Symbol<unsafe extern "C-unwind" fn(*mut std::ffi::c_void)> = library
                .get(b"luks_destroy\0")
                .map_err(|e| format!("símbolo 'luks_destroy' não encontrado: {}", e))?;
            *sym
        };

        let luks_free_error = unsafe {
            let sym: Symbol<unsafe extern "C-unwind" fn(*mut i8)> = library
                .get(b"luks_free_error\0")
                .map_err(|e| format!("símbolo 'luks_free_error' não encontrado: {}", e))?;
            *sym
        };

        Ok(RuntimeHandle {
            library,
            luks_new,
            luks_execute,
            luks_destroy,
            luks_free_error,
        })
    }

    /// Encontra o caminho do runtime baseado na plataforma
    fn find_runtime_library() -> Result<PathBuf, String> {
        let exe_path = env::current_exe()
            .map_err(|e| format!("falha ao obter caminho do executável: {}", e))?;

        let exe_dir = exe_path
            .parent()
            .ok_or("não foi possível determinar diretório do executável")?;

        // Nome da biblioteca varia por plataforma
        // Windows: luksruntime.dll
        // Linux: libluksruntime.so
        // macOS: libluksruntime.dylib
        let lib_name = if cfg!(windows) {
            "luksruntime.dll".to_string()
        } else if cfg!(target_os = "macos") {
            "libluksruntime.dylib".to_string()
        } else {
            "libluksruntime.so".to_string()
        };

        // Procura no diretório do executável
        let lib_path = exe_dir.join(&lib_name);
        if lib_path.exists() {
            return Ok(lib_path);
        }

        // Procura no subdiretório lib/
        let lib_path = exe_dir.join("lib").join(&lib_name);
        if lib_path.exists() {
            return Ok(lib_path);
        }

        // Procura no diretório target/release (modo desenvolvimento)
        let dev_path = exe_dir
            .parent()
            .and_then(|p| p.parent())
            .map(|p| p.join("target").join("release").join(&lib_name));

        if let Some(ref path) = dev_path {
            if path.exists() {
                return Ok(path.clone());
            }
        }

        Err(format!(
            "não encontrou '{}' em: {:?}, {:?}, ou {:?}",
            lib_name,
            exe_dir.join(&lib_name),
            exe_dir.join("lib").join(&lib_name),
            dev_path
        ))
    }
}

fn main() {
    let script = env::args().nth(1).unwrap_or_else(|| {
        eprintln!("uso: lukscli <arquivo.luau>");
        process::exit(1);
    });

    // Carrega o runtime
    let runtime = RuntimeHandle::load().unwrap_or_else(|e| {
        eprintln!("falha ao carregar runtime: {}", e);
        process::exit(1);
    });

    let source = fs::read_to_string(&script).unwrap_or_else(|e| {
        eprintln!("falha ao ler '{}': {}", script, e);
        process::exit(1);
    });

    let c_source = CString::new(source).expect("script com null byte");
    let c_name = CString::new(script.clone()).expect("nome com null byte");

    unsafe {
        let rt = (runtime.luks_new)();
        if rt.is_null() {
            eprintln!("falha ao criar runtime");
            process::exit(1);
        }

        println!("Executing {}...", script);

        let err_ptr = (runtime.luks_execute)(rt, c_source.as_ptr(), c_name.as_ptr());

        if !err_ptr.is_null() {
            let msg = CStr::from_ptr(err_ptr).to_string_lossy();
            eprintln!("Error: {}", msg);
            (runtime.luks_free_error)(err_ptr);
            (runtime.luks_destroy)(rt);
            process::exit(1);
        }

        println!("Script executed successfully.");
        (runtime.luks_destroy)(rt);
    }
}
