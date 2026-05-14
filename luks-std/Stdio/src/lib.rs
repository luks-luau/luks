#![allow(unsafe_op_in_unsafe_fn)]

use luks_module_sys::*;
use std::collections::HashMap;
use std::ffi::{CStr, CString};
use std::io::{BufRead, Read, Write};
use std::process::{Child, ChildStdin, Command, Stdio};
use std::sync::atomic::{AtomicBool, AtomicUsize, Ordering};
use std::sync::{Arc, LazyLock, Mutex};
use std::thread;

// ---------------------------------------------------------------------------
// Static State Management
// ---------------------------------------------------------------------------

static STDIN_READER_STARTED: AtomicBool = AtomicBool::new(false);
static STDIN_QUEUE: LazyLock<Mutex<Vec<String>>> = LazyLock::new(|| Mutex::new(Vec::new()));

struct StreamedChildState {
    child: Child,
    stdin: Option<ChildStdin>,
    stdout_queue: Arc<Mutex<Vec<String>>>,
    stderr_queue: Arc<Mutex<Vec<String>>>,
}

static NEXT_CHILD_ID: AtomicUsize = AtomicUsize::new(1);
static CHILDREN: LazyLock<Mutex<HashMap<usize, StreamedChildState>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));

// ---------------------------------------------------------------------------
// Stack Utilities
// ---------------------------------------------------------------------------

/// Push dynamic C string cleanly to stack
///
/// # Safety
/// Valid VM state pointer.
unsafe fn push_str(l: *mut lua_State, s: &str) {
    let cstr = CString::new(s).unwrap_or_default();
    unsafe {
        lua_pushstring(l, cstr.as_ptr());
    }
}

/// Read Lua string at absolute index safely
///
/// # Safety
/// Valid stack index bound.
unsafe fn read_str(l: *mut lua_State, idx: i32) -> String {
    unsafe {
        let ptr = lua_tolstring(l, idx, std::ptr::null_mut());
        if ptr.is_null() {
            String::new()
        } else {
            CStr::from_ptr(ptr).to_string_lossy().into_owned()
        }
    }
}

/// Read string array from stack table safely
///
/// # Safety
/// Valid stack state.
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
                let s = read_str(l, -1);
                if !s.is_empty() {
                    vec.push(s);
                }
            }
            lua_pop(l, 1);
        }
    }
    vec
}

// ---------------------------------------------------------------------------
// Synchronous Console Operations
// ---------------------------------------------------------------------------

/// Write text directly to console stdout
///
/// # Safety
/// Valid stack parameters.
unsafe extern "C-unwind" fn lua_write(l: *mut lua_State) -> i32 {
    let s = unsafe { read_str(l, 1) };
    let _ = std::io::stdout().lock().write_all(s.as_bytes());
    0
}

/// Write text + newline directly to console stdout
///
/// # Safety
/// Valid stack parameters.
unsafe extern "C-unwind" fn lua_write_line(l: *mut lua_State) -> i32 {
    let s = unsafe { read_str(l, 1) };
    let mut out = std::io::stdout().lock();
    let _ = out.write_all(s.as_bytes());
    let _ = out.write_all(b"\n");
    0
}

/// Write text directly to console stderr
///
/// # Safety
/// Valid stack parameters.
unsafe extern "C-unwind" fn lua_write_error(l: *mut lua_State) -> i32 {
    let s = unsafe { read_str(l, 1) };
    let _ = std::io::stderr().lock().write_all(s.as_bytes());
    0
}

/// Write text + newline directly to console stderr
///
/// # Safety
/// Valid stack parameters.
unsafe extern "C-unwind" fn lua_write_error_line(l: *mut lua_State) -> i32 {
    let s = unsafe { read_str(l, 1) };
    let mut err = std::io::stderr().lock();
    let _ = err.write_all(s.as_bytes());
    let _ = err.write_all(b"\n");
    0
}

/// Synchronize kernel standard output stream buffer
///
/// # Safety
/// Valid stack pointer context.
unsafe extern "C-unwind" fn lua_flush_stdout(_l: *mut lua_State) -> i32 {
    let _ = std::io::stdout().flush();
    0
}

/// Synchronize kernel standard error stream buffer
///
/// # Safety
/// Valid stack pointer context.
unsafe extern "C-unwind" fn lua_flush_stderr(_l: *mut lua_State) -> i32 {
    let _ = std::io::stderr().flush();
    0
}

// ---------------------------------------------------------------------------
// Input Readers
// ---------------------------------------------------------------------------

/// Read single line synchronously from standard input blocking host thread
///
/// # Safety
/// Valid stack context.
unsafe extern "C-unwind" fn lua_read_line(l: *mut lua_State) -> i32 {
    let mut s = String::new();
    match std::io::stdin().read_line(&mut s) {
        Ok(_) => {
            if s.ends_with('\n') {
                s.pop();
                if s.ends_with('\r') {
                    s.pop();
                }
            }
            unsafe { push_str(l, &s) };
            1
        }
        Err(_) => {
            unsafe { lua_pushnil(l) };
            1
        }
    }
}

/// Launch standard input background string queue reader exactly once
///
/// # Safety
/// Valid stack state.
unsafe extern "C-unwind" fn lua_start_reader_thread(_l: *mut lua_State) -> i32 {
    if !STDIN_READER_STARTED.swap(true, Ordering::SeqCst) {
        thread::spawn(move || {
            let stdin = std::io::stdin();
            let reader = stdin.lock();
            for line in reader.lines().map_while(Result::ok) {
                if let Ok(mut queue) = STDIN_QUEUE.lock() {
                    queue.push(line);
                }
            }
        });
    }
    0
}

/// Try extracting head item from standard input queue non-blockingly
///
/// # Safety
/// Valid stack parameter state.
unsafe extern "C-unwind" fn lua_try_read_line(l: *mut lua_State) -> i32 {
    unsafe {
        if let Ok(mut queue) = STDIN_QUEUE.lock()
            && !queue.is_empty()
        {
            let item = queue.remove(0);
            push_str(l, &item);
            return 1;
        }
        lua_pushnil(l);
        1
    }
}

// ---------------------------------------------------------------------------
// Piped Sub-Process Control Interface
// ---------------------------------------------------------------------------

/// Instantiates child command pipeline with active background queues
///
/// # Safety
/// Valid runtime input parameters.
unsafe extern "C-unwind" fn lua_spawn_stream_child(l: *mut lua_State) -> i32 {
    unsafe {
        let program = read_str(l, 1);
        let args = read_string_array(l, 2);

        let mut cmd = Command::new(&program);
        cmd.args(&args);

        // Parse optional target specifications map
        if lua_gettop(l) >= 3 && lua_istable(l, 3) != 0 {
            lua_pushstring(l, c"cwd".as_ptr());
            lua_gettable(l, 3);
            if lua_isstring(l, -1) != 0 {
                let cwd = read_str(l, -1);
                if !cwd.is_empty() {
                    cmd.current_dir(cwd);
                }
            }
            lua_pop(l, 1);

            lua_pushstring(l, c"env".as_ptr());
            lua_gettable(l, 3);
            if lua_istable(l, -1) != 0 {
                lua_pushnil(l);
                while lua_next(l, -2) != 0 {
                    lua_pushvalue(l, -2);
                    let k = read_str(l, -1);
                    let v = read_str(l, -2);
                    if !k.is_empty() {
                        cmd.env(k, v);
                    }
                    lua_pop(l, 2);
                }
            }
            lua_pop(l, 1);
        }

        cmd.stdin(Stdio::piped());
        cmd.stdout(Stdio::piped());
        cmd.stderr(Stdio::piped());

        match cmd.spawn() {
            Ok(mut child) => {
                let stdout_pipe = child.stdout.take();
                let stderr_pipe = child.stderr.take();
                let stdin_pipe = child.stdin.take();

                let stdout_queue = Arc::new(Mutex::new(Vec::new()));
                let stderr_queue = Arc::new(Mutex::new(Vec::new()));

                let out_arc = Arc::clone(&stdout_queue);
                if let Some(mut pipe) = stdout_pipe {
                    thread::spawn(move || {
                        let mut buf = [0u8; 4096];
                        while let Ok(n) = pipe.read(&mut buf) {
                            if n == 0 {
                                break;
                            }
                            let chunk = String::from_utf8_lossy(&buf[..n]).into_owned();
                            if let Ok(mut q) = out_arc.lock() {
                                q.push(chunk);
                            }
                        }
                    });
                }

                let err_arc = Arc::clone(&stderr_queue);
                if let Some(mut pipe) = stderr_pipe {
                    thread::spawn(move || {
                        let mut buf = [0u8; 4096];
                        while let Ok(n) = pipe.read(&mut buf) {
                            if n == 0 {
                                break;
                            }
                            let chunk = String::from_utf8_lossy(&buf[..n]).into_owned();
                            if let Ok(mut q) = err_arc.lock() {
                                q.push(chunk);
                            }
                        }
                    });
                }

                let id = NEXT_CHILD_ID.fetch_add(1, Ordering::SeqCst);
                if let Ok(mut map) = CHILDREN.lock() {
                    map.insert(
                        id,
                        StreamedChildState {
                            child,
                            stdin: stdin_pipe,
                            stdout_queue,
                            stderr_queue,
                        },
                    );
                }

                lua_pushinteger(l, id as i64);
                1
            }
            Err(_) => {
                lua_pushnil(l);
                1
            }
        }
    }
}

/// Polls child process standard output chunks non-blockingly
///
/// # Safety
/// Valid stack integer mappings.
unsafe extern "C-unwind" fn lua_poll_child_stdout(l: *mut lua_State) -> i32 {
    unsafe {
        let id = lua_tointeger(l, 1) as usize;
        if let Ok(map) = CHILDREN.lock()
            && let Some(state) = map.get(&id)
            && let Ok(mut q) = state.stdout_queue.lock()
            && !q.is_empty()
        {
            let combined = q.drain(..).collect::<Vec<String>>().join("");
            push_str(l, &combined);
            return 1;
        }
        lua_pushnil(l);
        1
    }
}

/// Polls child process standard error chunks non-blockingly
///
/// # Safety
/// Valid stack integer mappings.
unsafe extern "C-unwind" fn lua_poll_child_stderr(l: *mut lua_State) -> i32 {
    unsafe {
        let id = lua_tointeger(l, 1) as usize;
        if let Ok(map) = CHILDREN.lock()
            && let Some(state) = map.get(&id)
            && let Ok(mut q) = state.stderr_queue.lock()
            && !q.is_empty()
        {
            let combined = q.drain(..).collect::<Vec<String>>().join("");
            push_str(l, &combined);
            return 1;
        }
        lua_pushnil(l);
        1
    }
}

/// Verifies child process termination status code
///
/// # Safety
/// Valid stack parameters.
unsafe extern "C-unwind" fn lua_poll_child_exit(l: *mut lua_State) -> i32 {
    unsafe {
        let id = lua_tointeger(l, 1) as usize;
        let mut exited = false;
        let mut exit_code = 0;

        if let Ok(mut map) = CHILDREN.lock() {
            if let Some(state) = map.get_mut(&id)
                && let Ok(Some(status)) = state.child.try_wait()
            {
                exited = true;
                exit_code = status
                    .code()
                    .unwrap_or(if status.success() { 0 } else { 1 });
            }
            if exited {
                map.remove(&id);
                lua_pushinteger(l, exit_code as i64);
                return 1;
            }
        }
        lua_pushnil(l);
        1
    }
}

/// Appends octet stream payload securely to running child standard input pipe
///
/// # Safety
/// Valid runtime ID parameter flags.
unsafe extern "C-unwind" fn lua_write_child_stdin(l: *mut lua_State) -> i32 {
    unsafe {
        let id = lua_tointeger(l, 1) as usize;
        let data = read_str(l, 2);

        if let Ok(mut map) = CHILDREN.lock()
            && let Some(state) = map.get_mut(&id)
            && let Some(stdin) = state.stdin.as_mut()
        {
            let _ = stdin.write_all(data.as_bytes());
            let _ = stdin.flush();
        }
        0
    }
}

/// Takes input buffer handle closing channel pipeline
///
/// # Safety
/// Valid runtime ID parameters.
unsafe extern "C-unwind" fn lua_close_child_stdin(l: *mut lua_State) -> i32 {
    unsafe {
        let id = lua_tointeger(l, 1) as usize;
        if let Ok(mut map) = CHILDREN.lock()
            && let Some(state) = map.get_mut(&id)
        {
            let _ = state.stdin.take(); // Automatically flushes and drops closing handle
        }
        0
    }
}

/// Executes OS abort command on active child struct
///
/// # Safety
/// Valid runtime parameters.
unsafe extern "C-unwind" fn lua_terminate_child(l: *mut lua_State) -> i32 {
    unsafe {
        let id = lua_tointeger(l, 1) as usize;
        if let Ok(mut map) = CHILDREN.lock()
            && let Some(state) = map.get_mut(&id)
        {
            let _ = state.child.kill();
        }
        0
    }
}

// ---------------------------------------------------------------------------
// Library Export Registration
// ---------------------------------------------------------------------------

/// Submodule native API initialization hook
///
/// # Safety
/// Valid execution parameters provided by VM runtime wrapper.
#[unsafe(no_mangle)]
pub unsafe extern "C-unwind" fn luau_export(l: *mut lua_State, api: *const LuauAPI) -> i32 {
    unsafe {
        init_api(api);

        lua_createtable(l, 0, 16);

        push_str(l, "0.1.0");
        lua_setfield(l, -2, c"version".as_ptr());

        lua_pushcfunction(l, lua_write);
        lua_setfield(l, -2, c"write".as_ptr());

        lua_pushcfunction(l, lua_write_line);
        lua_setfield(l, -2, c"writeLine".as_ptr());

        lua_pushcfunction(l, lua_write_error);
        lua_setfield(l, -2, c"writeError".as_ptr());

        lua_pushcfunction(l, lua_write_error_line);
        lua_setfield(l, -2, c"writeErrorLine".as_ptr());

        lua_pushcfunction(l, lua_flush_stdout);
        lua_setfield(l, -2, c"flushStdout".as_ptr());

        lua_pushcfunction(l, lua_flush_stderr);
        lua_setfield(l, -2, c"flushStderr".as_ptr());

        lua_pushcfunction(l, lua_read_line);
        lua_setfield(l, -2, c"readLine".as_ptr());

        lua_pushcfunction(l, lua_start_reader_thread);
        lua_setfield(l, -2, c"startReaderThread".as_ptr());

        lua_pushcfunction(l, lua_try_read_line);
        lua_setfield(l, -2, c"tryReadLine".as_ptr());

        lua_pushcfunction(l, lua_spawn_stream_child);
        lua_setfield(l, -2, c"spawnStreamChild".as_ptr());

        lua_pushcfunction(l, lua_poll_child_stdout);
        lua_setfield(l, -2, c"pollChildStdout".as_ptr());

        lua_pushcfunction(l, lua_poll_child_stderr);
        lua_setfield(l, -2, c"pollChildStderr".as_ptr());

        lua_pushcfunction(l, lua_poll_child_exit);
        lua_setfield(l, -2, c"pollChildExit".as_ptr());

        lua_pushcfunction(l, lua_write_child_stdin);
        lua_setfield(l, -2, c"writeChildStdin".as_ptr());

        lua_pushcfunction(l, lua_close_child_stdin);
        lua_setfield(l, -2, c"closeChildStdin".as_ptr());

        lua_pushcfunction(l, lua_terminate_child);
        lua_setfield(l, -2, c"terminateChild".as_ptr());

        1
    }
}
