#![allow(unsafe_op_in_unsafe_fn)]

use luks_module_sys::*;
use std::ffi::{CStr, CString};
use std::io::Write;
use std::process::{Command, Stdio};
use std::sync::LazyLock;
use std::time::Instant;

static START_TIME: LazyLock<Instant> = LazyLock::new(Instant::now);

struct ParsedOptions {
    cwd: Option<String>,
    env: Option<Vec<(String, String)>>,
    env_clear: bool,
    stdin: Option<String>,
}

/// Push dynamic ProcessOutput map to Lua stack
///
/// # Safety
/// Assumes `l` is a valid `lua_State` pointer.
unsafe fn push_process_output(
    l: *mut lua_State,
    ok: bool,
    status: i32,
    stdout: &str,
    stderr: &str,
    error: Option<&str>,
) {
    unsafe {
        lua_createtable(l, 0, 5);

        lua_pushboolean(l, if ok { 1 } else { 0 });
        lua_setfield(l, -2, c"ok".as_ptr());

        lua_pushinteger(l, status as i64);
        lua_setfield(l, -2, c"status".as_ptr());

        let stdout_cstr = CString::new(stdout).unwrap_or_default();
        lua_pushstring(l, stdout_cstr.as_ptr());
        lua_setfield(l, -2, c"stdout".as_ptr());

        let stderr_cstr = CString::new(stderr).unwrap_or_default();
        lua_pushstring(l, stderr_cstr.as_ptr());
        lua_setfield(l, -2, c"stderr".as_ptr());

        if let Some(err) = error {
            let err_cstr = CString::new(err).unwrap_or_default();
            lua_pushstring(l, err_cstr.as_ptr());
        } else {
            lua_pushnil(l);
        }
        lua_setfield(l, -2, c"error".as_ptr());
    }
}

/// Read a string list array from stack table at given index
///
/// # Safety
/// Assumes `l` is valid.
unsafe fn read_string_array(l: *mut lua_State, idx: i32) -> Vec<String> {
    let mut vec = Vec::new();
    let idx = unsafe { lua_absindex(l, idx) };
    if unsafe { lua_istable(l, idx) } == 0 {
        return vec;
    }
    unsafe {
        lua_pushnil(l);
        while lua_next(l, idx) != 0 {
            if lua_isstring(l, -1) != 0 {
                let s_ptr = lua_tolstring(l, -1, std::ptr::null_mut());
                if !s_ptr.is_null() {
                    let s = CStr::from_ptr(s_ptr).to_string_lossy().into_owned();
                    vec.push(s);
                }
            }
            lua_pop(l, 1);
        }
    }
    vec
}

/// Parse options configuration table from stack
///
/// # Safety
/// Assumes `l` is valid.
unsafe fn parse_process_options(l: *mut lua_State, idx: i32) -> ParsedOptions {
    let mut opts = ParsedOptions {
        cwd: None,
        env: None,
        env_clear: false,
        stdin: None,
    };
    let idx = unsafe { lua_absindex(l, idx) };
    if unsafe { lua_istable(l, idx) } == 0 {
        return opts;
    }

    unsafe {
        // Parse cwd
        lua_pushstring(l, c"cwd".as_ptr());
        lua_gettable(l, idx);
        if lua_isstring(l, -1) != 0 {
            let p = lua_tolstring(l, -1, std::ptr::null_mut());
            if !p.is_null() {
                opts.cwd = Some(CStr::from_ptr(p).to_string_lossy().into_owned());
            }
        }
        lua_pop(l, 1);

        // Parse env_clear
        lua_pushstring(l, c"env_clear".as_ptr());
        lua_gettable(l, idx);
        if lua_type(l, -1) == LUA_TBOOLEAN {
            opts.env_clear = lua_toboolean(l, -1) != 0;
        }
        lua_pop(l, 1);

        // Parse stdin
        lua_pushstring(l, c"stdin".as_ptr());
        lua_gettable(l, idx);
        if lua_isstring(l, -1) != 0 {
            let p = lua_tolstring(l, -1, std::ptr::null_mut());
            if !p.is_null() {
                opts.stdin = Some(CStr::from_ptr(p).to_string_lossy().into_owned());
            }
        }
        lua_pop(l, 1);

        // Parse env table
        lua_pushstring(l, c"env".as_ptr());
        lua_gettable(l, idx);
        if lua_istable(l, -1) != 0 {
            let mut env_pairs = Vec::new();
            lua_pushnil(l);
            while lua_next(l, -2) != 0 {
                // Duplicate key to top of stack to safely convert to string without breaking the iterator
                lua_pushvalue(l, -2);
                let k_ptr = lua_tolstring(l, -1, std::ptr::null_mut());
                let v_ptr = lua_tolstring(l, -2, std::ptr::null_mut());
                if !k_ptr.is_null() && !v_ptr.is_null() {
                    let k = CStr::from_ptr(k_ptr).to_string_lossy().into_owned();
                    let v = CStr::from_ptr(v_ptr).to_string_lossy().into_owned();
                    env_pairs.push((k, v));
                }
                lua_pop(l, 2); // Pop key copy and value, leaving original key at top for next iteration
            }
            opts.env = Some(env_pairs);
        }
        lua_pop(l, 1);
    }
    opts
}

/// Core terminal engine boundary executing child operations
fn execute_command(
    program: &str,
    args: &[String],
    options: ParsedOptions,
) -> (bool, i32, String, String, Option<String>) {
    let mut cmd = Command::new(program);
    cmd.args(args);

    if let Some(cwd) = options.cwd {
        cmd.current_dir(cwd);
    }

    if options.env_clear {
        cmd.env_clear();
    }

    if let Some(env_pairs) = options.env {
        for (k, v) in env_pairs {
            cmd.env(k, v);
        }
    }

    cmd.stdout(Stdio::piped());
    cmd.stderr(Stdio::piped());
    if options.stdin.is_some() {
        cmd.stdin(Stdio::piped());
    } else {
        cmd.stdin(Stdio::null());
    }

    let mut child = match cmd.spawn() {
        Ok(c) => c,
        Err(e) => return (false, -1, String::new(), String::new(), Some(e.to_string())),
    };

    if let Some(stdin_data) = options.stdin
        && let Some(mut stdin_pipe) = child.stdin.take()
    {
        let _ = stdin_pipe.write_all(stdin_data.as_bytes());
    }

    let output = match child.wait_with_output() {
        Ok(o) => o,
        Err(e) => return (false, -1, String::new(), String::new(), Some(e.to_string())),
    };

    let status = output
        .status
        .code()
        .unwrap_or(if output.status.success() { 0 } else { 1 });
    let stdout = String::from_utf8_lossy(&output.stdout).into_owned();
    let stderr = String::from_utf8_lossy(&output.stderr).into_owned();

    (output.status.success(), status, stdout, stderr, None)
}

/// Direct Spawning Native Wrapper
///
/// # Safety
/// Invoked by the VM with valid stack state.
unsafe extern "C-unwind" fn lua_spawn(l: *mut lua_State) -> i32 {
    unsafe {
        let argc = lua_gettop(l);
        if argc < 1 {
            push_process_output(
                l,
                false,
                -1,
                "",
                "",
                Some("Process.spawn error: missing program argument"),
            );
            return 1;
        }

        let prog_ptr = lua_tolstring(l, 1, std::ptr::null_mut());
        if prog_ptr.is_null() {
            push_process_output(
                l,
                false,
                -1,
                "",
                "",
                Some("Process.spawn error: program must be a string"),
            );
            return 1;
        }
        let program = CStr::from_ptr(prog_ptr).to_string_lossy().into_owned();

        let args = if argc >= 2 {
            read_string_array(l, 2)
        } else {
            Vec::new()
        };

        let options = if argc >= 3 {
            parse_process_options(l, 3)
        } else {
            ParsedOptions {
                cwd: None,
                env: None,
                env_clear: false,
                stdin: None,
            }
        };

        let (ok, status, stdout, stderr, err) = execute_command(&program, &args, options);
        push_process_output(l, ok, status, &stdout, &stderr, err.as_deref());
        1
    }
}

/// Native Shell Target Wrapper
///
/// # Safety
/// Invoked by the VM with valid stack state.
unsafe extern "C-unwind" fn lua_exec(l: *mut lua_State) -> i32 {
    unsafe {
        let argc = lua_gettop(l);
        if argc < 1 {
            push_process_output(
                l,
                false,
                -1,
                "",
                "",
                Some("Process.exec error: missing command argument"),
            );
            return 1;
        }

        let cmd_ptr = lua_tolstring(l, 1, std::ptr::null_mut());
        if cmd_ptr.is_null() {
            push_process_output(
                l,
                false,
                -1,
                "",
                "",
                Some("Process.exec error: command must be a string"),
            );
            return 1;
        }
        let command_str = CStr::from_ptr(cmd_ptr).to_string_lossy().into_owned();

        let options = if argc >= 2 {
            parse_process_options(l, 2)
        } else {
            ParsedOptions {
                cwd: None,
                env: None,
                env_clear: false,
                stdin: None,
            }
        };

        let (program, args) = if cfg!(target_os = "windows") {
            ("cmd.exe", vec!["/C".to_string(), command_str])
        } else {
            ("/bin/sh", vec!["-c".to_string(), command_str])
        };

        let (ok, status, stdout, stderr, err) = execute_command(program, &args, options);
        push_process_output(l, ok, status, &stdout, &stderr, err.as_deref());
        1
    }
}

/// Return host PID
///
/// # Safety
/// Valid stack pointer context.
unsafe extern "C-unwind" fn lua_id(l: *mut lua_State) -> i32 {
    unsafe {
        lua_pushinteger(l, std::process::id() as i64);
        1
    }
}

/// Return hardware CPU target architecture
///
/// # Safety
/// Valid stack pointer context.
unsafe extern "C-unwind" fn lua_arch(l: *mut lua_State) -> i32 {
    unsafe {
        let cstr = CString::new(std::env::consts::ARCH).unwrap();
        lua_pushstring(l, cstr.as_ptr());
        1
    }
}

/// Return kernel operating system target string
///
/// # Safety
/// Valid stack pointer context.
unsafe extern "C-unwind" fn lua_os(l: *mut lua_State) -> i32 {
    unsafe {
        let cstr = CString::new(std::env::consts::OS).unwrap();
        lua_pushstring(l, cstr.as_ptr());
        1
    }
}

/// Intercept floating runtime allocation interval
///
/// # Safety
/// Valid stack pointer context.
unsafe extern "C-unwind" fn lua_uptime(l: *mut lua_State) -> i32 {
    unsafe {
        let elapsed = START_TIME.elapsed().as_secs_f64();
        lua_pushnumber(l, elapsed);
        1
    }
}

/// Retrieve environmental configuration targets
///
/// # Safety
/// Valid stack pointer context.
unsafe extern "C-unwind" fn lua_get_env(l: *mut lua_State) -> i32 {
    unsafe {
        if lua_gettop(l) < 1 {
            lua_pushnil(l);
            return 1;
        }
        let ptr = lua_tolstring(l, 1, std::ptr::null_mut());
        if ptr.is_null() {
            lua_pushnil(l);
            return 1;
        }
        let key = CStr::from_ptr(ptr).to_string_lossy();
        match std::env::var(key.as_ref()) {
            Ok(val) => {
                let cstr = CString::new(val).unwrap_or_default();
                lua_pushstring(l, cstr.as_ptr());
            }
            Err(_) => lua_pushnil(l),
        }
        1
    }
}

/// Set or assign environmental map values
///
/// # Safety
/// Valid stack pointer context.
unsafe extern "C-unwind" fn lua_set_env(l: *mut lua_State) -> i32 {
    unsafe {
        if lua_gettop(l) < 2 {
            return 0;
        }
        let k_ptr = lua_tolstring(l, 1, std::ptr::null_mut());
        let v_ptr = lua_tolstring(l, 2, std::ptr::null_mut());
        if !k_ptr.is_null() && !v_ptr.is_null() {
            let k = CStr::from_ptr(k_ptr).to_string_lossy();
            let v = CStr::from_ptr(v_ptr).to_string_lossy();
            std::env::set_var(k.as_ref(), v.as_ref());
        }
        0
    }
}

/// Unlink target environmental framework mapping
///
/// # Safety
/// Valid stack pointer context.
unsafe extern "C-unwind" fn lua_remove_env(l: *mut lua_State) -> i32 {
    unsafe {
        if lua_gettop(l) >= 1 {
            let k_ptr = lua_tolstring(l, 1, std::ptr::null_mut());
            if !k_ptr.is_null() {
                let k = CStr::from_ptr(k_ptr).to_string_lossy();
                std::env::remove_var(k.as_ref());
            }
        }
        0
    }
}

/// Construct dictionary containing all standard process environment mappings
///
/// # Safety
/// Valid stack pointer context.
unsafe extern "C-unwind" fn lua_get_all_env(l: *mut lua_State) -> i32 {
    unsafe {
        lua_createtable(l, 0, 16);
        for (k, v) in std::env::vars() {
            let k_cstr = CString::new(k).unwrap_or_default();
            let v_cstr = CString::new(v).unwrap_or_default();
            lua_pushstring(l, v_cstr.as_ptr());
            lua_setfield(l, -2, k_cstr.as_ptr());
        }
        1
    }
}

/// Explicit shutdown procedure
///
/// # Safety
/// Invoked by the VM engine. Does not return upon evaluation.
unsafe extern "C-unwind" fn lua_exit(l: *mut lua_State) -> i32 {
    unsafe {
        let code = if lua_gettop(l) >= 1 && lua_isnumber(l, 1) != 0 {
            lua_tointeger(l, 1) as i32
        } else {
            0
        };
        std::process::exit(code);
    }
}

/// Submodule initialization function
///
/// # Safety
/// Requires valid execution VTable parameters.
#[unsafe(no_mangle)]
pub unsafe extern "C-unwind" fn luau_export(l: *mut lua_State, api: *const LuauAPI) -> i32 {
    unsafe {
        init_api(api);

        // Force deref initialization of static tracking frame
        let _ = LazyLock::force(&START_TIME);

        lua_createtable(l, 0, 13);

        lua_pushstring(l, c"0.1.0".as_ptr());
        lua_setfield(l, -2, c"version".as_ptr());

        lua_pushcfunction(l, lua_spawn);
        lua_setfield(l, -2, c"spawn".as_ptr());

        lua_pushcfunction(l, lua_exec);
        lua_setfield(l, -2, c"exec".as_ptr());

        lua_pushcfunction(l, lua_id);
        lua_setfield(l, -2, c"id".as_ptr());

        lua_pushcfunction(l, lua_arch);
        lua_setfield(l, -2, c"arch".as_ptr());

        lua_pushcfunction(l, lua_os);
        lua_setfield(l, -2, c"os".as_ptr());

        lua_pushcfunction(l, lua_uptime);
        lua_setfield(l, -2, c"uptime".as_ptr());

        lua_pushcfunction(l, lua_get_env);
        lua_setfield(l, -2, c"getEnv".as_ptr());

        lua_pushcfunction(l, lua_set_env);
        lua_setfield(l, -2, c"setEnv".as_ptr());

        lua_pushcfunction(l, lua_remove_env);
        lua_setfield(l, -2, c"removeEnv".as_ptr());

        lua_pushcfunction(l, lua_get_all_env);
        lua_setfield(l, -2, c"getAllEnv".as_ptr());

        lua_pushcfunction(l, lua_exit);
        lua_setfield(l, -2, c"exit".as_ptr());

        1
    }
}
