use mlua::ffi;
use mlua::{Compiler, Lua, Result as LuaResult};
use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::ptr;
use std::time::{Duration, Instant};

use async_io::Timer;
use futures_lite::future::yield_now;
use mlua_luau_scheduler::{Functions, Scheduler};

pub mod ffi_utils;
pub mod permissions;
pub use permissions::Permissions;

pub mod loader;
pub mod luau_require;
pub mod path_resolution;
pub mod utils;

#[repr(C)]
pub struct LuksRuntime {
    lua: Lua,
    scheduler: Scheduler,
}

/// Reads the current script directory from the `__script_dir__` global.
unsafe fn get_script_dir(l: *mut ffi::lua_State) -> Option<std::path::PathBuf> {
    ffi::lua_getglobal(l, c"__script_dir__".as_ptr());
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

fn extract_source_path(src: &str) -> Option<String> {
    if let Some(rest) = src.strip_prefix('@') {
        return Some(rest.to_string());
    }

    if let Some(inner) = src
        .strip_prefix("[string \"")
        .and_then(|s| s.strip_suffix("\"]"))
    {
        if let Some(rest) = inner.strip_prefix('@') {
            return Some(rest.to_string());
        }
        let p = std::path::Path::new(inner);
        if p.is_absolute() {
            return Some(inner.to_string());
        }
    }

    let p = std::path::Path::new(src);
    if p.is_absolute() {
        return Some(src.to_string());
    }

    None
}

/// Gets the caller script directory by inspecting the Luau stack.
unsafe fn get_caller_script_dir(l: *mut ffi::lua_State) -> Option<std::path::PathBuf> {
    const WHAT_SOURCE: &[u8] = b"s\0";

    for level in 1..=32 {
        let mut ar: ffi::lua_Debug = std::mem::zeroed();
        if ffi::lua_getinfo(
            l,
            level,
            WHAT_SOURCE.as_ptr() as *const i8,
            &mut ar as *mut ffi::lua_Debug,
        ) == 0
        {
            break;
        }

        for src_ptr in [ar.source, ar.short_src] {
            if src_ptr.is_null() {
                continue;
            }

            let src = CStr::from_ptr(src_ptr).to_string_lossy();
            let Some(path_str) = extract_source_path(src.as_ref()) else {
                continue;
            };

            let path = std::path::Path::new(&path_str);
            if let Some(parent) = path.parent() {
                return Some(parent.to_path_buf());
            }
        }
    }

    None
}

/// Internal `dlopen` function exposed to Lua.
/// Loads a dynamic library and invokes its `luau_export` entrypoint.
///
/// # Safety
/// This function is called by the Luau VM and may raise Lua errors via
/// `lua_error`. Its body must avoid Rust panics crossing the FFI boundary.
unsafe extern "C-unwind" fn lua_dlopen(l: *mut ffi::lua_State) -> i32 {
    lua_dlopen_impl(l)
}

/// Pushes an error message and raises a Lua error from C API.
unsafe fn lua_error(l: *mut ffi::lua_State, msg: impl AsRef<str>) -> i32 {
    let sanitized = msg.as_ref().replace('\0', "\\0");
    match CString::new(sanitized) {
        Ok(cmsg) => {
            ffi::lua_pushstring(l, cmsg.as_ptr());
        }
        Err(_) => {
            ffi::lua_pushliteral(l, c"internal error");
        }
    }
    ffi::lua_error(l)
}

/// Internal `dlopen` implementation, isolated for testability and safety.
unsafe fn lua_dlopen_impl(l: *mut ffi::lua_State) -> i32 {
    if ffi::lua_isstring(l, 1) == 0 {
        return lua_error(l, "dlopen: argumento 1 deve ser string");
    }

    let arg_ptr = ffi::lua_tostring(l, 1);
    if arg_ptr.is_null() {
        return lua_error(l, "dlopen: argumento 1 inválido");
    }

    let arg = CStr::from_ptr(arg_ptr).to_string_lossy();
    // Get caller script directory from stack with fallback to __script_dir__.
    let script_dir = get_caller_script_dir(l).or_else(|| get_script_dir(l));

    let base_dir = path_resolution::default_base_dir(script_dir);

    // Build the base path: @self/ and relative paths use script directory.
    let raw_path = if path_resolution::is_simple_name(arg.as_ref()) {
        // Simple name (no separators):
        // 1) Try script directory first with candidate filename variants.
        let script_base = base_dir.clone();

        let mut candidates: Vec<std::path::PathBuf> = Vec::new();
        let arg_path = std::path::Path::new(arg.as_ref());

        if arg_path.extension().is_some() {
            // Already has extension (e.g. foo.dll), do not append DLL_EXTENSION.
            candidates.push(script_base.join(arg.as_ref()));
        } else {
            // Direct candidate with platform extension.
            candidates.push(script_base.join(format!(
                "{}.{}",
                arg,
                std::env::consts::DLL_EXTENSION
            )));

            #[cfg(not(windows))]
            {
                // On Unix, also try `lib` prefix when applicable.
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
            // 2) Search system library directories.
            system_path
        } else {
            // 3) Fallback to script-relative path (extension applied below).
            script_base.join(arg.as_ref())
        }
    } else {
        path_resolution::resolve_from_base(&base_dir, arg.as_ref())
    };

    let path = path_resolution::normalize_path(&path_resolution::with_platform_library_extension(
        &raw_path,
    ));

    // Check NATIVE permission with panic-safe wrapper.
    match crate::permissions::check_native_safely() {
        Ok(true) => {}
        Ok(false) => {
            // Permission denied.
            return lua_error(l, "Native module loading denied");
        }
        Err(_) => {
            // Internal panic in permission check (fail-safe denial).
            return lua_error(l, "dlopen blocked: internal permission error");
        }
    }

    let loader = loader::ModuleLoader::new();
    let path_str = path.to_string_lossy().to_string();

    match loader.load(&path_str) {
        Ok(export) => export(l),
        Err(e) => lua_error(l, e),
    }
}

/// Registers the `dlopen` function into the Lua state.
fn register_dlopen(lua: &Lua) -> LuaResult<()> {
    // Use `exec_raw` for controlled access to the raw Lua C API state.
    unsafe {
        lua.exec_raw((), |state| {
            ffi::lua_pushcfunction(state, lua_dlopen);
            ffi::lua_setglobal(state, c"dlopen".as_ptr());
        })
    }
}

/// Registers the `task` module with scheduler functions.
fn register_task_module(lua: &Lua, fns: &Functions) -> LuaResult<()> {
    let task_wait = lua.create_async_function(task_wait)?;

    // Create delay function (similar to lune-std-task)
    let task_delay_env = lua.create_table()?;
    task_delay_env.set("select", lua.globals().get::<mlua::Function>("select")?)?;
    task_delay_env.set("spawn", fns.spawn.clone())?;
    task_delay_env.set("defer", fns.defer.clone())?;
    task_delay_env.set("wait", task_wait.clone())?;
    task_delay_env.set_readonly(true);
    let task_delay = lua
        .load(DELAY_IMPL_LUA)
        .set_name("task.delay")
        .set_environment(task_delay_env)
        .into_function()?;

    // Create task module table
    let task_module = lua.create_table()?;
    task_module.set("cancel", fns.cancel.clone())?;
    task_module.set("defer", fns.defer.clone())?;
    task_module.set("delay", task_delay)?;
    task_module.set("spawn", fns.spawn.clone())?;
    task_module.set("wait", task_wait)?;
    task_module.set_readonly(true);

    lua.globals().set("task", task_module)?;
    Ok(())
}

const DELAY_IMPL_LUA: &str = r"
return defer(function(...)
    wait(select(1, ...))
    spawn(select(2, ...))
end, ...)
";

async fn task_wait(lua: Lua, secs: Option<f64>) -> LuaResult<f64> {
    yield_now().await;
    task_wait_inner(lua, secs).await
}

async fn task_wait_inner(_: Lua, secs: Option<f64>) -> LuaResult<f64> {
    let duration = Duration::from_secs_f64(secs.unwrap_or_default());
    let duration = duration.max(Duration::from_millis(1));
    yield_now().await;
    let before = Instant::now();
    let after = Timer::after(duration).await;
    Ok((after - before).as_secs_f64())
}

/// Creates a new runtime instance.
///
/// # Safety
/// The returned pointer is owned by the caller and must be released with
/// [`luks_destroy`].
#[no_mangle]
pub unsafe extern "C-unwind" fn luks_new() -> *mut LuksRuntime {
    ffi_utils::ffi_catch_unwind(|| luks_new_impl()).unwrap_or(ptr::null_mut())
}

/// Safe implementation of `luks_new`, isolated for `catch_unwind`.
unsafe fn luks_new_impl() -> *mut LuksRuntime {
    let lua = unsafe { Lua::unsafe_new() };

    // Create scheduler for async task support
    let scheduler = Scheduler::new(lua.clone());

    // Create task functions from scheduler
    let fns = match Functions::new(lua.clone()) {
        Ok(f) => f,
        Err(e) => {
            crate::utils::runtime_warn(&format!("failed to create scheduler functions: {}", e));
            return ptr::null_mut();
        }
    };

    // Configure Luau's native require using our `Require` trait implementation.
    let requirer = luau_require::LuksRequirer::new();
    let luau_require_fn = match lua.create_require_function(requirer) {
        Ok(f) => f,
        Err(e) => {
            crate::utils::runtime_warn(&format!("create_require_function failed: {}", e));
            return ptr::null_mut();
        }
    };

    // Create a wrapper that adds `./` to paths without an explicit prefix.
    // This preserves compatibility with code calling `require("module")`.
    let require_wrapper =
        lua.create_function(move |_lua, module: String| -> mlua::Result<mlua::Value> {
            let adjusted_path =
                if module.starts_with("./") || module.starts_with("../") || module.starts_with("@")
                {
                    module
                } else {
                    // Add `./` for prefixless paths (relative to script directory).
                    format!("./{}", module)
                };
            luau_require_fn.call::<mlua::Value>(adjusted_path)
        });

    match require_wrapper {
        Ok(f) => {
            if let Err(e) = lua.globals().set("require", f) {
                crate::utils::runtime_warn(&format!("failed to register require: {}", e));
                return ptr::null_mut();
            }
        }
        Err(e) => {
            crate::utils::runtime_warn(&format!("failed to create require wrapper: {}", e));
            return ptr::null_mut();
        }
    }

    // Register `dlopen` global.
    if let Err(e) = register_dlopen(&lua) {
        crate::utils::runtime_warn(&format!("failed to register dlopen: {}", e));
        return ptr::null_mut();
    }

    // Register task module with scheduler functions
    if let Err(e) = register_task_module(&lua, &fns) {
        crate::utils::runtime_warn(&format!("failed to register task module: {}", e));
        return ptr::null_mut();
    }

    let compiler = Compiler::new().set_optimization_level(1).set_debug_level(1);
    lua.set_compiler(compiler);

    Box::into_raw(Box::new(LuksRuntime { lua, scheduler }))
}

/// Executes Luau source code inside an existing runtime.
///
/// Returns a null pointer on success. On failure, returns an allocated C string
/// describing the error; the caller must free it with [`luks_free_error`].
///
/// # Safety
/// - `rt` must be a valid pointer returned by [`luks_new`].
/// - `source` must be a valid, NUL-terminated UTF-8 string.
/// - `chunk_name` must be a valid, NUL-terminated UTF-8 string (or null).
#[no_mangle]
pub unsafe extern "C-unwind" fn luks_execute(
    rt: *mut LuksRuntime,
    source: *const i8,
    chunk_name: *const i8,
) -> *mut i8 {
    ffi_utils::ffi_catch_unwind(|| luks_execute_impl(rt, source, chunk_name))
        .unwrap_or(ptr::null_mut())
}

/// Internal `luks_execute` implementation with safe error handling.
unsafe fn luks_execute_impl(
    rt: *mut LuksRuntime,
    source: *const i8,
    chunk_name: *const i8,
) -> *mut c_char {
    if rt.is_null() || source.is_null() {
        return ffi_utils::ffi_error_msg("runtime ou source nulo");
    }
    let rt = &mut *rt;
    let src = match CStr::from_ptr(source).to_str() {
        Ok(s) => s,
        Err(e) => {
            return ffi_utils::ffi_error_msg(format!("source inválido (utf-8): {}", e));
        }
    };
    let name_str = if chunk_name.is_null() {
        "luks_chunk"
    } else {
        match CStr::from_ptr(chunk_name).to_str() {
            Ok(s) => s,
            Err(e) => {
                return ffi_utils::ffi_error_msg(format!("chunk_name inválido (utf-8): {}", e));
            }
        }
    };

    // Set `__script_dir__` so `@self/` path resolution works correctly.
    let name_path = name_str.strip_prefix('@').unwrap_or(name_str);
    let script_dir = std::path::Path::new(name_path)
        .parent()
        .map(|p| p.to_string_lossy().to_string())
        .unwrap_or_else(|| ".".to_string());
    let _ = rt.lua.globals().set("__script_dir__", script_dir.clone());

    // Load the chunk and create a thread so it runs inside the scheduler
    let chunk = match rt.lua.load(src).set_name(name_str).into_function() {
        Ok(f) => f,
        Err(e) => {
            return ffi_utils::ffi_error_msg(format!("compile error: {}", e));
        }
    };
    let thread = match rt.lua.create_thread(chunk) {
        Ok(t) => t,
        Err(e) => {
            return ffi_utils::ffi_error_msg(format!("thread create error: {}", e));
        }
    };

    // Push the main thread to the scheduler, track it, and get the ThreadId
    let thread_id = match rt.scheduler.push_thread_front(thread, ()) {
        Ok(id) => id,
        Err(e) => {
            return ffi_utils::ffi_error_msg(format!("scheduler push error: {}", e));
        }
    };

    // Block on the scheduler until all tasks complete
    async_io::block_on(rt.scheduler.run());

    // Check if the main thread had an error
    if let Some(Err(e)) = rt.scheduler.get_thread_result(thread_id) {
        return ffi_utils::ffi_error_msg(format!("runtime error: {}", e));
    }

    ptr::null_mut()
}

/// Frees an error string allocated by the runtime.
///
/// # Safety
/// `err` must be a pointer previously returned by this runtime (for example by
/// [`luks_execute`] or [`luks_clear_loaded_libs`]), and must be freed at most once.
#[no_mangle]
pub unsafe extern "C-unwind" fn luks_free_error(err: *mut i8) {
    // No catch_unwind needed: dropping CString should not panic in normal conditions.
    if !err.is_null() {
        drop(CString::from_raw(err));
    }
}

/// Clears the internal native-library cache.
///
/// Returns null on success. On failure, returns an allocated error string that
/// must be freed with [`luks_free_error`].
///
/// # Safety
/// This function may be called from foreign code. The returned pointer, when
/// non-null, is owned by the caller.
#[no_mangle]
pub unsafe extern "C-unwind" fn luks_clear_loaded_libs() -> *mut i8 {
    ffi_utils::ffi_catch_unwind(|| match loader::clear_loaded_libs() {
        Ok(()) => ptr::null_mut(),
        Err(e) => ffi_utils::ffi_error_msg(e),
    })
    .unwrap_or(ffi_utils::ffi_error_msg("panic during clear_loaded_libs"))
}

/// Destroys a runtime instance created by [`luks_new`].
///
/// # Safety
/// - `rt` must be a pointer returned by [`luks_new`].
/// - It must not be used after this call.
#[no_mangle]
pub unsafe extern "C-unwind" fn luks_destroy(rt: *mut LuksRuntime) {
    // No catch_unwind needed: dropping Box should not panic.
    if !rt.is_null() {
        drop(Box::from_raw(rt));
    }
}

/// Returns runtime version from `Cargo.toml` at compile time.
///
/// # Safety
/// The returned pointer is valid for the lifetime of the process.
#[no_mangle]
pub unsafe extern "C-unwind" fn luks_version() -> *const c_char {
    const VER: &[u8] = concat!(env!("CARGO_PKG_VERSION"), "\0").as_bytes();
    VER.as_ptr() as *const c_char
}

/// Returns the linked Luau VM version (dynamic, no hardcoded value).
///
/// # Safety
/// The returned pointer is valid for the lifetime of the process.
#[no_mangle]
pub unsafe extern "C-unwind" fn luks_luau_version() -> *const c_char {
    use std::ffi::CString;
    use std::sync::OnceLock;

    static LUAU_VER: OnceLock<CString> = OnceLock::new();
    LUAU_VER
        .get_or_init(|| {
            // `mlua_sys::luau_version` returns `Option<&'static str>`.
            let ver = mlua_sys::luau_version().unwrap_or("unknown");
            CString::new(ver).expect("Luau version string contained null byte")
        })
        .as_ptr()
}

/// Runs the async scheduler until all tasks complete.
///
/// Returns a null pointer on success. On failure, returns an allocated C string
/// describing the error; the caller must free it with [`luks_free_error`].
///
/// # Safety
/// `rt` must be a valid pointer returned by [`luks_new`].
#[no_mangle]
pub unsafe extern "C-unwind" fn luks_run_scheduler(rt: *mut LuksRuntime) -> *mut i8 {
    ffi_utils::ffi_catch_unwind(|| luks_run_scheduler_impl(rt)).unwrap_or(ptr::null_mut())
}

/// Internal `luks_run_scheduler` implementation.
unsafe fn luks_run_scheduler_impl(rt: *mut LuksRuntime) -> *mut c_char {
    if rt.is_null() {
        return ffi_utils::ffi_error_msg("runtime nulo");
    }
    let rt = &mut *rt;
    // Block on the scheduler until all tasks complete
    async_io::block_on(rt.scheduler.run());
    ptr::null_mut()
}
