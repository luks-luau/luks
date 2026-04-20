// crates/lukscli/src/main.rs
use std::env;
use std::ffi::{CStr, CString};
use std::fs;
use std::process;

#[link(name = "luksruntime")]
extern "C-unwind" {
    fn luks_new() -> *mut std::ffi::c_void;
    fn luks_execute(rt: *mut std::ffi::c_void, src: *const i8, name: *const i8) -> *mut i8;
    fn luks_destroy(rt: *mut std::ffi::c_void);
    fn luks_free_error(err: *mut i8);
}

fn main() {
    let script = env::args().nth(1).unwrap_or_else(|| {
        eprintln!("uso: lukscli <arquivo.luau>");
        process::exit(1);
    });

    let source = fs::read_to_string(&script).unwrap_or_else(|e| {
        eprintln!("falha ao ler '{}': {}", script, e);
        process::exit(1);
    });

    let c_source = CString::new(source).expect("script com null byte");
    let c_name = CString::new(script.clone()).expect("nome com null byte");

    unsafe {
        let rt = luks_new();
        if rt.is_null() {
            eprintln!("falha ao criar runtime");
            process::exit(1);
        }

        println!("Executing {}...", script);

        let err_ptr = luks_execute(rt, c_source.as_ptr(), c_name.as_ptr());

        if !err_ptr.is_null() {
            let msg = CStr::from_ptr(err_ptr).to_string_lossy();
            eprintln!("Error: {}", msg);
            luks_free_error(err_ptr);
            luks_destroy(rt);
            process::exit(1);
        }

        println!("Script executed successfully.");
        luks_destroy(rt);
    }
}