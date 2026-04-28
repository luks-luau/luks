use libloading::Library;
use std::ffi::CStr;
use anyhow::{Context, Result};

/// Dynamic handle to the runtime shared library and FFI entrypoints.
pub struct RuntimeHandle {
    _lib: Library,
    new: unsafe extern "C-unwind" fn() -> *mut std::ffi::c_void,
    exec: unsafe extern "C-unwind" fn(*mut std::ffi::c_void, *const i8, *const i8) -> *mut i8,
    free: unsafe extern "C-unwind" fn(*mut i8),
    destroy: unsafe extern "C-unwind" fn(*mut std::ffi::c_void),
    version: unsafe extern "C-unwind" fn() -> *const i8,
    luau_version: unsafe extern "C-unwind" fn() -> *const i8,
}

impl RuntimeHandle {
    /// Loads the runtime shared library located next to the CLI executable.
    pub fn load() -> Result<Self> {
        // Find the runtime library in the CLI executable directory.
        let exe_path = std::env::current_exe().context("Failed to get exe path")?;
        let exe_dir = exe_path.parent().context("Failed to get exe dir")?;

        let lib_name = if cfg!(target_os = "windows") {
            "luksruntime.dll"
        } else if cfg!(target_os = "macos") {
            "libluksruntime.dylib"
        } else {
            "libluksruntime.so"
        };

        let lib_path = exe_dir.join(lib_name);
        if !lib_path.exists() {
            anyhow::bail!("Runtime library not found at: {}", lib_path.display());
        }

        let lib = unsafe { Library::new(&lib_path)? };

        // Resolve symbols while `lib` is still borrowed (before moving into struct).
        let new = unsafe { get_symbol(&lib, "luks_new")? };
        let exec = unsafe { get_symbol(&lib, "luks_execute")? };
        let free = unsafe { get_symbol(&lib, "luks_free_error")? };
        let destroy = unsafe { get_symbol(&lib, "luks_destroy")? };
        let version = unsafe { get_symbol(&lib, "luks_version")? };
        let luau_version = unsafe { get_symbol(&lib, "luks_luau_version")? };

        Ok(Self {
            _lib: lib,
            new,
            exec,
            free,
            destroy,
            version,
            luau_version,
        })
    }

    /// Returns `(runtime_version, luau_version)` from the shared library.
    pub fn get_versions(&self) -> Result<(String, String)> {
        unsafe {
            let rt_fn: extern "C-unwind" fn() -> *const i8 = std::mem::transmute(self.version);
            let luau_fn: extern "C-unwind" fn() -> *const i8 = std::mem::transmute(self.luau_version);
            Ok((
                CStr::from_ptr(rt_fn()).to_string_lossy().into_owned(),
                CStr::from_ptr(luau_fn()).to_string_lossy().into_owned(),
            ))
        }
    }

    /// Executes source code with a provided chunk name.
    pub fn execute(&self, source: &str, chunk_name: &str) -> Result<()> {
        let c_src = std::ffi::CString::new(source)?;
        let c_chunk = std::ffi::CString::new(chunk_name)?;

        unsafe {
            let new_fn: extern "C-unwind" fn() -> *mut std::ffi::c_void = std::mem::transmute(self.new);
            let exec_fn: extern "C-unwind" fn(*mut std::ffi::c_void, *const i8, *const i8) -> *mut i8 = std::mem::transmute(self.exec);
            let free_fn: extern "C-unwind" fn(*mut i8) = std::mem::transmute(self.free);
            let destroy_fn: extern "C-unwind" fn(*mut std::ffi::c_void) = std::mem::transmute(self.destroy);

            let rt = new_fn();
            if rt.is_null() { anyhow::bail!("Failed to initialize runtime"); }

            let err = exec_fn(rt, c_src.as_ptr(), c_chunk.as_ptr());
            destroy_fn(rt);

            if !err.is_null() {
                let msg = CStr::from_ptr(err).to_string_lossy().into_owned();
                free_fn(err);
                anyhow::bail!("[RUNTIME] {}", msg);
            }
        }
        Ok(())
    }
}

unsafe fn get_symbol<T: Copy>(lib: &Library, name: &str) -> Result<T> {
    let sym = lib.get::<T>(name.as_bytes())?;
    // `Symbol<T>` dereferences to `T`, so `*sym` yields the function pointer value.
    Ok(*sym)
}
