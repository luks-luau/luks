#![allow(unsafe_op_in_unsafe_fn)]

use luks_module_sys::*;
use std::ffi::CString;
use std::io::{ErrorKind, Read, Write};
use std::process::{Child, ChildStderr, ChildStdin, ChildStdout, Command, Stdio};
use std::sync::{Arc, Mutex};

#[cfg(unix)]
use std::os::unix::io::AsRawFd;
#[cfg(windows)]
use std::os::windows::io::AsRawHandle;

// --- Handle Management ---

struct ProcessChild {
    inner: Arc<Mutex<Child>>,
    stdin: Option<Arc<Mutex<ChildStdin>>>,
    stdout: Option<Arc<Mutex<ChildStdout>>>,
    stderr: Option<Arc<Mutex<ChildStderr>>>,
}

unsafe fn get_child(l: *mut lua_State, idx: i32) -> *mut ProcessChild {
    let ud = lua_touserdata(l, idx);
    if ud.is_null() {
        luaL_error(l, c"expected ProcessChild handle".as_ptr());
    }
    *(ud as *mut *mut ProcessChild)
}

// --- Pipe Helpers ---

#[cfg(windows)]
fn set_nonblocking(handle: &impl AsRawHandle) {
    unsafe {
        use windows_sys::Win32::System::Pipes::{SetNamedPipeHandleState, PIPE_NOWAIT};
        let mode = PIPE_NOWAIT;
        SetNamedPipeHandleState(
            handle.as_raw_handle() as _,
            &mode,
            std::ptr::null_mut(),
            std::ptr::null_mut(),
        );
    }
}

#[cfg(unix)]
fn set_nonblocking(handle: &impl AsRawFd) {
    unsafe {
        use libc::{fcntl, F_GETFL, F_SETFL, O_NONBLOCK};
        let fd = handle.as_raw_fd();
        let flags = fcntl(fd, F_GETFL, 0);
        fcntl(fd, F_SETFL, flags | O_NONBLOCK);
    }
}

// --- Helpers ---

fn str_to_cstring(s: &str) -> CString {
    CString::new(s).unwrap_or_else(|_| CString::new("").unwrap())
}

unsafe fn get_string_arg(l: *mut lua_State, idx: i32) -> String {
    let mut len = 0;
    let ptr = lua_tolstring(l, idx, &mut len);
    if ptr.is_null() {
        "".to_string()
    } else {
        let bytes = std::slice::from_raw_parts(ptr as *const u8, len);
        String::from_utf8_lossy(bytes).into_owned()
    }
}

// --- FFI Methods ---

unsafe extern "C-unwind" fn process_spawn(l: *mut lua_State) -> i32 {
    let program = get_string_arg(l, 1);
    let mut cmd = Command::new(program);

    if lua_istable(l, 2) != 0 {
        let mut i = 1;
        loop {
            lua_rawgeti(l, 2, i);
            if lua_isnil(l, -1) != 0 {
                lua_pop(l, 1);
                break;
            }
            cmd.arg(get_string_arg(l, -1));
            lua_pop(l, 1);
            i += 1;
        }
    }

    if lua_istable(l, 3) != 0 {
        lua_getfield(l, 3, c"cwd".as_ptr());
        if lua_isstring(l, -1) != 0 {
            cmd.current_dir(get_string_arg(l, -1));
        }
        lua_pop(l, 1);

        lua_getfield(l, 3, c"env_clear".as_ptr());
        if lua_toboolean(l, -1) != 0 {
            cmd.env_clear();
        }
        lua_pop(l, 1);

        lua_getfield(l, 3, c"env".as_ptr());
        if lua_istable(l, -1) != 0 {
            lua_pushnil(l);
            while lua_next(l, -2) != 0 {
                cmd.env(get_string_arg(l, -2), get_string_arg(l, -1));
                lua_pop(l, 1);
            }
        }
        lua_pop(l, 1);

        let setup_stdio = |l: *mut lua_State, field: *const i8| -> Stdio {
            lua_getfield(l, 3, field);
            let s = match get_string_arg(l, -1).as_str() {
                "piped" => Stdio::piped(),
                "null" => Stdio::null(),
                "inherit" => Stdio::inherit(),
                _ => Stdio::inherit(),
            };
            lua_pop(l, 1);
            s
        };

        cmd.stdin(setup_stdio(l, c"stdin".as_ptr()));
        cmd.stdout(setup_stdio(l, c"stdout".as_ptr()));
        cmd.stderr(setup_stdio(l, c"stderr".as_ptr()));
    }

    match cmd.spawn() {
        Ok(mut child) => {
            let stdin = child.stdin.take().map(|s| {
                set_nonblocking(&s);
                Arc::new(Mutex::new(s))
            });
            let stdout = child.stdout.take().map(|s| {
                set_nonblocking(&s);
                Arc::new(Mutex::new(s))
            });
            let stderr = child.stderr.take().map(|s| {
                set_nonblocking(&s);
                Arc::new(Mutex::new(s))
            });

            let boxed = Box::new(ProcessChild {
                inner: Arc::new(Mutex::new(child)),
                stdin,
                stdout,
                stderr,
            });
            let ud = lua_newuserdata(l, std::mem::size_of::<*mut ProcessChild>())
                as *mut *mut ProcessChild;
            *ud = Box::into_raw(boxed);
            1
        }
        Err(e) => {
            lua_pushnil(l);
            let err = e.to_string();
            lua_pushstring(l, str_to_cstring(&err).as_ptr());
            2
        }
    }
}

unsafe extern "C-unwind" fn process_child_id(l: *mut lua_State) -> i32 {
    let child = &*get_child(l, 1);
    lua_pushnumber(l, child.inner.lock().unwrap().id() as f64);
    1
}

unsafe extern "C-unwind" fn process_child_kill(l: *mut lua_State) -> i32 {
    let child = &*get_child(l, 1);
    match child.inner.lock().unwrap().kill() {
        Ok(_) => {
            lua_pushboolean(l, 1);
            1
        }
        Err(e) => {
            lua_pushnil(l);
            lua_pushstring(l, str_to_cstring(&e.to_string()).as_ptr());
            2
        }
    }
}

unsafe extern "C-unwind" fn process_child_try_wait(l: *mut lua_State) -> i32 {
    let child = &*get_child(l, 1);
    match child.inner.lock().unwrap().try_wait() {
        Ok(Some(status)) => {
            lua_pushinteger(l, status.code().unwrap_or(0) as i64);
            1
        }
        Ok(None) => {
            lua_pushnil(l);
            1
        }
        Err(e) => {
            lua_pushnil(l);
            lua_pushstring(l, str_to_cstring(&e.to_string()).as_ptr());
            2
        }
    }
}

// --- Pipe I/O ---

unsafe extern "C-unwind" fn process_child_stdout_read(l: *mut lua_State) -> i32 {
    let child = &*get_child(l, 1);
    let mut blen = 0;
    let bptr = lua_tobuffer(l, 2, &mut blen);
    if bptr.is_null() {
        return 0;
    }

    let offset = luaL_optinteger(l, 3, 0) as usize;
    let len = luaL_optinteger(l, 4, (blen - offset) as i64) as usize;

    let slice = std::slice::from_raw_parts_mut(bptr.add(offset) as *mut u8, len);

    if let Some(stdout) = &child.stdout {
        let mut pipe = stdout.lock().unwrap();

        #[cfg(windows)]
        {
            use windows_sys::Win32::System::Pipes::PeekNamedPipe;
            let mut avail = 0;
            let handle = pipe.as_raw_handle() as _;
            unsafe {
                if PeekNamedPipe(
                    handle,
                    std::ptr::null_mut(),
                    0,
                    std::ptr::null_mut(),
                    &mut avail,
                    std::ptr::null_mut(),
                ) != 0
                    && avail == 0
                {
                    let mut inner = child.inner.lock().unwrap();
                    match inner.try_wait() {
                        Ok(Some(_)) => {
                            // Child has exited, let actual read call run to get EOF (Ok(0))
                        }
                        _ => {
                            // Child is still running, return WouldBlock immediately to prevent blocking the OS thread
                            lua_pushnil(l);
                            lua_pushstring(l, c"WouldBlock".as_ptr());
                            return 2;
                        }
                    }
                }
            }
        }

        match pipe.read(slice) {
            Ok(n) => {
                lua_pushinteger(l, n as i64);
                1
            }
            Err(e) if e.kind() == ErrorKind::WouldBlock => {
                lua_pushnil(l);
                lua_pushstring(l, c"WouldBlock".as_ptr());
                2
            }
            Err(e) => {
                lua_pushnil(l);
                lua_pushstring(l, str_to_cstring(&e.to_string()).as_ptr());
                2
            }
        }
    } else {
        luaL_error(l, c"stdout not piped".as_ptr());
    }
}

unsafe extern "C-unwind" fn process_child_stderr_read(l: *mut lua_State) -> i32 {
    let child = &*get_child(l, 1);
    let mut blen = 0;
    let bptr = lua_tobuffer(l, 2, &mut blen);
    if bptr.is_null() {
        return 0;
    }

    let offset = luaL_optinteger(l, 3, 0) as usize;
    let len = luaL_optinteger(l, 4, (blen - offset) as i64) as usize;

    let slice = std::slice::from_raw_parts_mut(bptr.add(offset) as *mut u8, len);

    if let Some(stderr) = &child.stderr {
        let mut pipe = stderr.lock().unwrap();

        #[cfg(windows)]
        {
            use windows_sys::Win32::System::Pipes::PeekNamedPipe;
            let mut avail = 0;
            let handle = pipe.as_raw_handle() as _;
            unsafe {
                if PeekNamedPipe(
                    handle,
                    std::ptr::null_mut(),
                    0,
                    std::ptr::null_mut(),
                    &mut avail,
                    std::ptr::null_mut(),
                ) != 0
                    && avail == 0
                {
                    let mut inner = child.inner.lock().unwrap();
                    match inner.try_wait() {
                        Ok(Some(_)) => {
                            // Child has exited, let actual read call run to get EOF (Ok(0))
                        }
                        _ => {
                            // Child is still running, return WouldBlock immediately to prevent blocking the OS thread
                            lua_pushnil(l);
                            lua_pushstring(l, c"WouldBlock".as_ptr());
                            return 2;
                        }
                    }
                }
            }
        }

        match pipe.read(slice) {
            Ok(n) => {
                lua_pushinteger(l, n as i64);
                1
            }
            Err(e) if e.kind() == ErrorKind::WouldBlock => {
                lua_pushnil(l);
                lua_pushstring(l, c"WouldBlock".as_ptr());
                2
            }
            Err(e) => {
                lua_pushnil(l);
                lua_pushstring(l, str_to_cstring(&e.to_string()).as_ptr());
                2
            }
        }
    } else {
        luaL_error(l, c"stderr not piped".as_ptr());
    }
}

unsafe extern "C-unwind" fn process_child_stdin_write(l: *mut lua_State) -> i32 {
    let child = &*get_child(l, 1);
    let mut data_len = 0;
    let data_ptr = if lua_isstring(l, 2) != 0 {
        lua_tolstring(l, 2, &mut data_len) as *const u8
    } else {
        let ptr = lua_tobuffer(l, 2, &mut data_len);
        if ptr.is_null() {
            return 0;
        }
        ptr as *const u8
    };

    let offset = luaL_optinteger(l, 3, 0) as usize;
    let len = luaL_optinteger(l, 4, (data_len - offset) as i64) as usize;

    let slice = std::slice::from_raw_parts(data_ptr.add(offset), len);

    if let Some(stdin) = &child.stdin {
        let mut pipe = stdin.lock().unwrap();
        match pipe.write(slice) {
            Ok(n) => {
                lua_pushinteger(l, n as i64);
                1
            }
            Err(e) if e.kind() == ErrorKind::WouldBlock => {
                lua_pushnil(l);
                lua_pushstring(l, c"WouldBlock".as_ptr());
                2
            }
            Err(e) => {
                lua_pushnil(l);
                lua_pushstring(l, str_to_cstring(&e.to_string()).as_ptr());
                2
            }
        }
    } else {
        luaL_error(l, c"stdin not piped".as_ptr());
    }
}

unsafe extern "C-unwind" fn process_child_stdin_close(l: *mut lua_State) -> i32 {
    let child = &mut *get_child(l, 1);
    child.stdin = None;
    0
}

unsafe extern "C-unwind" fn process_child_has_stdin(l: *mut lua_State) -> i32 {
    let child = &*get_child(l, 1);
    lua_pushboolean(l, if child.stdin.is_some() { 1 } else { 0 });
    1
}

unsafe extern "C-unwind" fn process_child_has_stdout(l: *mut lua_State) -> i32 {
    let child = &*get_child(l, 1);
    lua_pushboolean(l, if child.stdout.is_some() { 1 } else { 0 });
    1
}

unsafe extern "C-unwind" fn process_child_has_stderr(l: *mut lua_State) -> i32 {
    let child = &*get_child(l, 1);
    lua_pushboolean(l, if child.stderr.is_some() { 1 } else { 0 });
    1
}

unsafe extern "C-unwind" fn process_child_free(l: *mut lua_State) -> i32 {
    let ud = lua_touserdata(l, 1);
    if !ud.is_null() {
        let ptr_ptr = ud as *mut *mut ProcessChild;
        if !(*ptr_ptr).is_null() {
            let _ = Box::from_raw(*ptr_ptr);
            *ptr_ptr = std::ptr::null_mut();
        }
    }
    0
}

// --- Static Methods ---

unsafe extern "C-unwind" fn process_id(l: *mut lua_State) -> i32 {
    lua_pushnumber(l, std::process::id() as f64);
    1
}

unsafe extern "C-unwind" fn process_exit(l: *mut lua_State) -> i32 {
    let code = luaL_optinteger(l, 1, 0) as i32;
    std::process::exit(code);
}

unsafe extern "C-unwind" fn process_abort(_l: *mut lua_State) -> i32 {
    std::process::abort();
}

// --- Initialization ---

/// # Safety
/// - `l` must be a valid pointer to a `lua_State`.
/// - `api` must be a valid pointer to a `LuauAPI` struct.
#[unsafe(no_mangle)]
pub unsafe extern "C-unwind" fn luau_export(l: *mut lua_State, api: *const LuauAPI) -> i32 {
    unsafe {
        init_api(api);
        lua_createtable(l, 0, 15);

        lua_pushcfunction(l, process_spawn);
        lua_setfield(l, -2, c"spawn".as_ptr());
        lua_pushcfunction(l, process_child_id);
        lua_setfield(l, -2, c"child_id".as_ptr());
        lua_pushcfunction(l, process_child_kill);
        lua_setfield(l, -2, c"child_kill".as_ptr());
        lua_pushcfunction(l, process_child_try_wait);
        lua_setfield(l, -2, c"child_try_wait".as_ptr());
        lua_pushcfunction(l, process_child_free);
        lua_setfield(l, -2, c"child_free".as_ptr());

        lua_pushcfunction(l, process_child_stdout_read);
        lua_setfield(l, -2, c"child_stdout_read".as_ptr());
        lua_pushcfunction(l, process_child_stderr_read);
        lua_setfield(l, -2, c"child_stderr_read".as_ptr());
        lua_pushcfunction(l, process_child_stdin_write);
        lua_setfield(l, -2, c"child_stdin_write".as_ptr());
        lua_pushcfunction(l, process_child_stdin_close);
        lua_setfield(l, -2, c"child_stdin_close".as_ptr());

        lua_pushcfunction(l, process_child_has_stdin);
        lua_setfield(l, -2, c"child_has_stdin".as_ptr());
        lua_pushcfunction(l, process_child_has_stdout);
        lua_setfield(l, -2, c"child_has_stdout".as_ptr());
        lua_pushcfunction(l, process_child_has_stderr);
        lua_setfield(l, -2, c"child_has_stderr".as_ptr());

        lua_pushcfunction(l, process_id);
        lua_setfield(l, -2, c"id".as_ptr());
        lua_pushcfunction(l, process_exit);
        lua_setfield(l, -2, c"exit".as_ptr());
        lua_pushcfunction(l, process_abort);
        lua_setfield(l, -2, c"abort".as_ptr());

        1
    }
}
