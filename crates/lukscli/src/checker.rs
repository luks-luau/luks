use anyhow::{Context, Result};
use libloading::Library;
use std::ffi::CString;
use std::path::Path;

/// Dynamic handle to the lukschecker shared library.
pub struct CheckerHandle {
    _lib: Library,
    check_path: unsafe extern "C-unwind" fn(*const std::ffi::c_char) -> i32,
}

impl CheckerHandle {
    /// Loads the checker shared library located next to the CLI executable.
    pub fn load() -> Result<Self> {
        let exe_path = std::env::current_exe().context("Failed to get exe path")?;
        let exe_dir = exe_path.parent().context("Failed to get exe dir")?;

        let lib_name = if cfg!(target_os = "windows") {
            "lukschecker.dll"
        } else if cfg!(target_os = "macos") {
            "liblukschecker.dylib"
        } else {
            "liblukschecker.so"
        };

        let lib_path = exe_dir.join(lib_name);
        if !lib_path.exists() {
            anyhow::bail!(
                "Checker library not found at: {}\nDid you compile lukschecker?",
                lib_path.display()
            );
        }

        let lib = unsafe { Library::new(&lib_path)? };
        let check_path = unsafe {
            let sym = lib.get::<unsafe extern "C-unwind" fn(*const std::ffi::c_char) -> i32>(
                b"luks_checker_check_path",
            )?;
            *sym
        };

        Ok(Self {
            _lib: lib,
            check_path,
        })
    }

    /// Checks the given path (or current directory if None).
    pub fn check(&self, path: Option<&Path>) -> Result<i32> {
        let c_path = match path {
            Some(p) => Some(CString::new(p.to_string_lossy().as_ref())?),
            None => None,
        };

        let ptr = match &c_path {
            Some(cp) => cp.as_ptr(),
            None => std::ptr::null(),
        };

        unsafe {
            let func: extern "C-unwind" fn(*const std::ffi::c_char) -> i32 =
                std::mem::transmute(self.check_path);
            Ok(func(ptr))
        }
    }
}
