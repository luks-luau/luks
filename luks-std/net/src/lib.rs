#![allow(unsafe_op_in_unsafe_fn)]

use luks_module_sys::*;
use std::ffi::CString;
use std::io::{Read, Write};
use std::net::{
    SocketAddr, TcpListener as StdTcpListener, TcpStream as StdTcpStream, UdpSocket as StdUdpSocket,
};
use std::sync::{LazyLock, Mutex};
use tokio::runtime::Runtime;

// --- GLOBAL RUNTIME (Only for connect) ---
static RUNTIME: LazyLock<Runtime> = LazyLock::new(|| {
    tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
        .expect("Failed to create Tokio runtime")
});

// --- HANDLES ---

struct LuauTcpListener {
    inner: StdTcpListener,
}

struct LuauTcpStream {
    inner: Mutex<StdTcpStream>,
}

struct LuauUdpSocket {
    inner: Mutex<StdUdpSocket>,
}

// --- HELPERS ---

fn str_to_cstring(s: &str) -> CString {
    let sanitized = s.replace('\0', "\u{FFFD}");
    CString::new(sanitized).expect("Failed to create CString")
}

unsafe fn lua_error_msg(l: *mut lua_State, msg: &str) -> ! {
    unsafe {
        let cstr = str_to_cstring(msg);
        lua_pushstring(l, cstr.as_ptr());
        lua_error(l);
    }
}

unsafe fn get_string_arg(l: *mut lua_State, idx: i32) -> String {
    unsafe {
        let mut len = 0;
        let ptr = lua_tolstring(l, idx, &mut len);
        if ptr.is_null() {
            lua_error_msg(l, "expected string");
        }
        let bytes = std::slice::from_raw_parts(ptr as *const u8, len);
        std::str::from_utf8(bytes).unwrap_or("").to_owned()
    }
}

unsafe fn parse_socket_addr(l: *mut lua_State, idx: i32) -> SocketAddr {
    let s = get_string_arg(l, idx);
    s.parse::<SocketAddr>().unwrap_or_else(|e| {
        lua_error_msg(l, &format!("invalid socket address '{}': {}", s, e));
    })
}

unsafe fn push_socket_addr(l: *mut lua_State, addr: SocketAddr) {
    let s = addr.to_string();
    lua_pushstring(l, str_to_cstring(&s).as_ptr());
}

unsafe fn get_buffer_mut(l: *mut lua_State, idx: i32) -> Option<&'static mut [u8]> {
    let mut len = 0;
    let ptr = lua_tobuffer(l, idx, &mut len);
    if ptr.is_null() {
        None
    } else {
        Some(std::slice::from_raw_parts_mut(ptr as *mut u8, len))
    }
}

unsafe fn get_tcp_listener(l: *mut lua_State, idx: i32) -> *mut LuauTcpListener {
    let ud_ptr = lua_touserdata(l, idx) as *mut *mut LuauTcpListener;
    if ud_ptr.is_null() {
        lua_error_msg(l, "expected TcpListener handle, got nil");
    }
    let ud = *ud_ptr;
    if ud.is_null() {
        lua_error_msg(l, "TcpListener is closed");
    }
    ud
}

unsafe fn get_tcp_stream(l: *mut lua_State, idx: i32) -> *mut LuauTcpStream {
    let ud_ptr = lua_touserdata(l, idx) as *mut *mut LuauTcpStream;
    if ud_ptr.is_null() {
        lua_error_msg(l, "expected TcpStream handle, got nil");
    }
    let ud = *ud_ptr;
    if ud.is_null() {
        lua_error_msg(l, "TcpStream is closed");
    }
    ud
}

unsafe fn get_udp_socket(l: *mut lua_State, idx: i32) -> *mut LuauUdpSocket {
    let ud_ptr = lua_touserdata(l, idx) as *mut *mut LuauUdpSocket;
    if ud_ptr.is_null() {
        lua_error_msg(l, "expected UdpSocket handle, got nil");
    }
    let ud = *ud_ptr;
    if ud.is_null() {
        lua_error_msg(l, "UdpSocket is closed");
    }
    ud
}

// --- TCP LISTENER ---

unsafe extern "C-unwind" fn net_tcp_bind(l: *mut lua_State) -> i32 {
    let addr = parse_socket_addr(l, 1);
    match StdTcpListener::bind(addr) {
        Ok(inner) => {
            inner.set_nonblocking(true).unwrap_or_default();
            let ud = lua_newuserdata(l, std::mem::size_of::<*mut LuauTcpListener>());
            let boxed = Box::into_raw(Box::new(LuauTcpListener { inner }));
            *(ud as *mut *mut LuauTcpListener) = boxed;

            lua_createtable(l, 0, 1);
            lua_pushcfunction(l, net_tcp_listener_gc);
            lua_setfield(l, -2, c"__gc".as_ptr());
            lua_setmetatable(l, -2);
            1
        }
        Err(e) => {
            lua_error_msg(l, &e.to_string());
        }
    }
}

unsafe extern "C-unwind" fn net_tcp_listener_close(l: *mut lua_State) -> i32 {
    let ud_ptr = lua_touserdata(l, 1) as *mut *mut LuauTcpListener;
    if !ud_ptr.is_null() && !(*ud_ptr).is_null() {
        let _ = Box::from_raw(*ud_ptr);
        *ud_ptr = std::ptr::null_mut();
    }
    0
}

unsafe extern "C-unwind" fn net_tcp_listener_gc(l: *mut lua_State) -> i32 {
    let ud_ptr = lua_touserdata(l, 1) as *mut *mut LuauTcpListener;
    if !ud_ptr.is_null() && !(*ud_ptr).is_null() {
        let _ = Box::from_raw(*ud_ptr);
        *ud_ptr = std::ptr::null_mut();
    }
    0
}

unsafe extern "C-unwind" fn net_tcp_listener_local_addr(l: *mut lua_State) -> i32 {
    let listener = &mut *get_tcp_listener(l, 1);
    match listener.inner.local_addr() {
        Ok(addr) => {
            push_socket_addr(l, addr);
            1
        }
        Err(e) => {
            lua_error_msg(l, &e.to_string());
        }
    }
}

unsafe extern "C-unwind" fn net_tcp_listener_set_ttl(l: *mut lua_State) -> i32 {
    let listener = &mut *get_tcp_listener(l, 1);
    let ttl = lua_tointeger(l, 2) as u32;
    match listener.inner.set_ttl(ttl) {
        Ok(_) => {
            lua_pushboolean(l, 1);
            1
        }
        Err(e) => {
            lua_error_msg(l, &e.to_string());
        }
    }
}

unsafe extern "C-unwind" fn net_tcp_listener_ttl(l: *mut lua_State) -> i32 {
    let listener = &mut *get_tcp_listener(l, 1);
    match listener.inner.ttl() {
        Ok(t) => {
            lua_pushnumber(l, t as f64);
            1
        }
        Err(e) => {
            lua_error_msg(l, &e.to_string());
        }
    }
}

unsafe extern "C-unwind" fn net_tcp_accept(l: *mut lua_State) -> i32 {
    let listener = &mut *get_tcp_listener(l, 1);
    match listener.inner.accept() {
        Ok((stream, addr)) => {
            stream.set_nonblocking(true).unwrap_or_default();
            let stream_ud = lua_newuserdata(l, std::mem::size_of::<*mut LuauTcpStream>());
            let boxed = Box::into_raw(Box::new(LuauTcpStream {
                inner: Mutex::new(stream),
            }));
            *(stream_ud as *mut *mut LuauTcpStream) = boxed;

            lua_createtable(l, 0, 1);
            lua_pushcfunction(l, net_tcp_stream_gc);
            lua_setfield(l, -2, c"__gc".as_ptr());
            lua_setmetatable(l, -2);
            push_socket_addr(l, addr);
            2
        }
        Err(ref e) if e.kind() == std::io::ErrorKind::WouldBlock => {
            lua_pushnil(l);
            lua_pushstring(l, c"WouldBlock".as_ptr());
            2
        }
        Err(e) => {
            lua_error_msg(l, &e.to_string());
        }
    }
}

// --- TCP STREAM ---

unsafe extern "C-unwind" fn net_tcp_connect(l: *mut lua_State) -> i32 {
    let addr = parse_socket_addr(l, 1);
    match RUNTIME.block_on(tokio::net::TcpStream::connect(addr)) {
        Ok(tokio_stream) => match tokio_stream.into_std() {
            Ok(stream) => {
                stream.set_nonblocking(true).unwrap_or_default();
                let ud = lua_newuserdata(l, std::mem::size_of::<*mut LuauTcpStream>());
                let boxed = Box::into_raw(Box::new(LuauTcpStream {
                    inner: Mutex::new(stream),
                }));
                *(ud as *mut *mut LuauTcpStream) = boxed;

                lua_createtable(l, 0, 1);
                lua_pushcfunction(l, net_tcp_stream_gc);
                lua_setfield(l, -2, c"__gc".as_ptr());
                lua_setmetatable(l, -2);
                1
            }
            Err(e) => {
                lua_error_msg(l, &e.to_string());
            }
        },
        Err(e) => {
            lua_error_msg(l, &e.to_string());
        }
    }
}

unsafe extern "C-unwind" fn net_tcp_stream_close(l: *mut lua_State) -> i32 {
    let ud_ptr = lua_touserdata(l, 1) as *mut *mut LuauTcpStream;
    if !ud_ptr.is_null() && !(*ud_ptr).is_null() {
        let _ = Box::from_raw(*ud_ptr);
        *ud_ptr = std::ptr::null_mut();
    }
    0
}

unsafe extern "C-unwind" fn net_tcp_stream_gc(l: *mut lua_State) -> i32 {
    let ud_ptr = lua_touserdata(l, 1) as *mut *mut LuauTcpStream;
    if !ud_ptr.is_null() && !(*ud_ptr).is_null() {
        let _ = Box::from_raw(*ud_ptr);
        *ud_ptr = std::ptr::null_mut();
    }
    0
}

unsafe extern "C-unwind" fn net_tcp_stream_peer_addr(l: *mut lua_State) -> i32 {
    let stream_ud = &mut *get_tcp_stream(l, 1);
    let stream = stream_ud.inner.lock().unwrap();
    match stream.peer_addr() {
        Ok(addr) => {
            push_socket_addr(l, addr);
            1
        }
        Err(e) => {
            lua_error_msg(l, &e.to_string());
        }
    }
}

unsafe extern "C-unwind" fn net_tcp_stream_local_addr(l: *mut lua_State) -> i32 {
    let stream_ud = &mut *get_tcp_stream(l, 1);
    let stream = stream_ud.inner.lock().unwrap();
    match stream.local_addr() {
        Ok(addr) => {
            push_socket_addr(l, addr);
            1
        }
        Err(e) => {
            lua_error_msg(l, &e.to_string());
        }
    }
}

unsafe extern "C-unwind" fn net_tcp_stream_set_ttl(l: *mut lua_State) -> i32 {
    let stream_ud = &mut *get_tcp_stream(l, 1);
    let ttl = lua_tointeger(l, 2) as u32;
    let stream = stream_ud.inner.lock().unwrap();
    match stream.set_ttl(ttl) {
        Ok(_) => {
            lua_pushboolean(l, 1);
            1
        }
        Err(e) => {
            lua_error_msg(l, &e.to_string());
        }
    }
}

unsafe extern "C-unwind" fn net_tcp_stream_ttl(l: *mut lua_State) -> i32 {
    let stream_ud = &mut *get_tcp_stream(l, 1);
    let stream = stream_ud.inner.lock().unwrap();
    match stream.ttl() {
        Ok(t) => {
            lua_pushnumber(l, t as f64);
            1
        }
        Err(e) => {
            lua_error_msg(l, &e.to_string());
        }
    }
}

unsafe extern "C-unwind" fn net_tcp_stream_shutdown(l: *mut lua_State) -> i32 {
    let stream_ud = &mut *get_tcp_stream(l, 1);
    let how_str = get_string_arg(l, 2);
    let how = match how_str.as_str() {
        "Read" => std::net::Shutdown::Read,
        "Write" => std::net::Shutdown::Write,
        "Both" => std::net::Shutdown::Both,
        _ => lua_error_msg(l, "invalid shutdown mode"),
    };
    let stream = stream_ud.inner.lock().unwrap();
    match stream.shutdown(how) {
        Ok(_) => {
            lua_pushboolean(l, 1);
            1
        }
        Err(e) => {
            lua_error_msg(l, &e.to_string());
        }
    }
}

unsafe extern "C-unwind" fn net_tcp_stream_set_nodelay(l: *mut lua_State) -> i32 {
    let stream_ud = &mut *get_tcp_stream(l, 1);
    let nodelay = lua_toboolean(l, 2) != 0;
    let stream = stream_ud.inner.lock().unwrap();
    match stream.set_nodelay(nodelay) {
        Ok(_) => {
            lua_pushboolean(l, 1);
            1
        }
        Err(e) => {
            lua_error_msg(l, &e.to_string());
        }
    }
}

unsafe extern "C-unwind" fn net_tcp_stream_nodelay(l: *mut lua_State) -> i32 {
    let stream_ud = &mut *get_tcp_stream(l, 1);
    let stream = stream_ud.inner.lock().unwrap();
    match stream.nodelay() {
        Ok(n) => {
            lua_pushboolean(l, if n { 1 } else { 0 });
            1
        }
        Err(e) => {
            lua_error_msg(l, &e.to_string());
        }
    }
}

unsafe extern "C-unwind" fn net_tcp_peek(l: *mut lua_State) -> i32 {
    let stream_ud = &mut *get_tcp_stream(l, 1);
    let offset = lua_tointeger(l, 3) as usize;
    let len = lua_tointeger(l, 4) as usize;
    if let Some(buf) = get_buffer_mut(l, 2) {
        if offset + len > buf.len() {
            lua_error_msg(l, "buffer overflow");
        }
        let stream = stream_ud.inner.lock().unwrap();
        match stream.peek(&mut buf[offset..offset + len]) {
            Ok(n) => {
                lua_pushnumber(l, n as f64);
                1
            }
            Err(ref e) if e.kind() == std::io::ErrorKind::WouldBlock => {
                lua_pushnil(l);
                lua_pushstring(l, c"WouldBlock".as_ptr());
                2
            }
            Err(e) => {
                lua_pushnil(l);
                let err_msg = e.to_string();
                lua_pushstring(l, str_to_cstring(&err_msg).as_ptr());
                2
            }
        }
    } else {
        lua_error_msg(l, "expected buffer");
    }
}

unsafe extern "C-unwind" fn net_tcp_read(l: *mut lua_State) -> i32 {
    let stream_ud = &mut *get_tcp_stream(l, 1);
    let offset = lua_tointeger(l, 3) as usize;
    let len = lua_tointeger(l, 4) as usize;
    if let Some(buf) = get_buffer_mut(l, 2) {
        if offset + len > buf.len() {
            lua_error_msg(l, "buffer overflow");
        }
        let mut stream = stream_ud.inner.lock().unwrap();
        match stream.read(&mut buf[offset..offset + len]) {
            Ok(n) => {
                lua_pushnumber(l, n as f64);
                1
            }
            Err(ref e) if e.kind() == std::io::ErrorKind::WouldBlock => {
                lua_pushnil(l);
                lua_pushstring(l, c"WouldBlock".as_ptr());
                2
            }
            Err(e) => {
                lua_pushnil(l);
                let err_msg = e.to_string();
                lua_pushstring(l, str_to_cstring(&err_msg).as_ptr());
                2
            }
        }
    } else {
        lua_error_msg(l, "expected buffer");
    }
}

unsafe extern "C-unwind" fn net_tcp_write(l: *mut lua_State) -> i32 {
    let stream_ud = &mut *get_tcp_stream(l, 1);
    let offset = lua_tointeger(l, 3) as usize;
    let write_len = lua_tointeger(l, 4) as usize;
    let data = if lua_isstring(l, 2) != 0 {
        let mut slen = 0;
        let ptr = lua_tolstring(l, 2, &mut slen);
        std::slice::from_raw_parts(ptr as *const u8, slen)
    } else if let Some(buf) = get_buffer_mut(l, 2) {
        buf
    } else {
        lua_error_msg(l, "expected buffer or string");
    };
    if offset + write_len > data.len() {
        lua_error_msg(l, "source overflow");
    }
    let mut stream = stream_ud.inner.lock().unwrap();
    match stream.write(&data[offset..offset + write_len]) {
        Ok(n) => {
            lua_pushnumber(l, n as f64);
            1
        }
        Err(ref e) if e.kind() == std::io::ErrorKind::WouldBlock => {
            lua_pushnil(l);
            lua_pushstring(l, c"WouldBlock".as_ptr());
            2
        }
        Err(e) => {
            lua_error_msg(l, &e.to_string());
        }
    }
}

// --- UDP SOCKET ---

unsafe extern "C-unwind" fn net_udp_bind(l: *mut lua_State) -> i32 {
    let addr = parse_socket_addr(l, 1);
    match StdUdpSocket::bind(addr) {
        Ok(inner) => {
            inner.set_nonblocking(true).unwrap_or_default();
            let ud = lua_newuserdata(l, std::mem::size_of::<*mut LuauUdpSocket>());
            let boxed = Box::into_raw(Box::new(LuauUdpSocket {
                inner: Mutex::new(inner),
            }));
            *(ud as *mut *mut LuauUdpSocket) = boxed;

            lua_createtable(l, 0, 1);
            lua_pushcfunction(l, net_udp_socket_gc);
            lua_setfield(l, -2, c"__gc".as_ptr());
            lua_setmetatable(l, -2);
            1
        }
        Err(e) => {
            lua_error_msg(l, &e.to_string());
        }
    }
}

unsafe extern "C-unwind" fn net_udp_socket_gc(l: *mut lua_State) -> i32 {
    let ud_ptr = lua_touserdata(l, 1) as *mut *mut LuauUdpSocket;
    if !ud_ptr.is_null() && !(*ud_ptr).is_null() {
        let _ = Box::from_raw(*ud_ptr);
        *ud_ptr = std::ptr::null_mut();
    }
    0
}

unsafe extern "C-unwind" fn net_udp_socket_local_addr(l: *mut lua_State) -> i32 {
    let socket_ud = &mut *get_udp_socket(l, 1);
    let socket = socket_ud.inner.lock().unwrap();
    match socket.local_addr() {
        Ok(addr) => {
            push_socket_addr(l, addr);
            1
        }
        Err(e) => {
            lua_error_msg(l, &e.to_string());
        }
    }
}

unsafe extern "C-unwind" fn net_udp_socket_peer_addr(l: *mut lua_State) -> i32 {
    let socket_ud = &mut *get_udp_socket(l, 1);
    let socket = socket_ud.inner.lock().unwrap();
    match socket.peer_addr() {
        Ok(addr) => {
            push_socket_addr(l, addr);
            1
        }
        Err(e) => {
            lua_error_msg(l, &e.to_string());
        }
    }
}

unsafe extern "C-unwind" fn net_udp_socket_set_ttl(l: *mut lua_State) -> i32 {
    let socket_ud = &mut *get_udp_socket(l, 1);
    let ttl = lua_tointeger(l, 2) as u32;
    let socket = socket_ud.inner.lock().unwrap();
    match socket.set_ttl(ttl) {
        Ok(_) => {
            lua_pushboolean(l, 1);
            1
        }
        Err(e) => {
            lua_error_msg(l, &e.to_string());
        }
    }
}

unsafe extern "C-unwind" fn net_udp_socket_ttl(l: *mut lua_State) -> i32 {
    let socket_ud = &mut *get_udp_socket(l, 1);
    let socket = socket_ud.inner.lock().unwrap();
    match socket.ttl() {
        Ok(t) => {
            lua_pushnumber(l, t as f64);
            1
        }
        Err(e) => {
            lua_error_msg(l, &e.to_string());
        }
    }
}

unsafe extern "C-unwind" fn net_udp_socket_set_broadcast(l: *mut lua_State) -> i32 {
    let socket_ud = &mut *get_udp_socket(l, 1);
    let broadcast = lua_toboolean(l, 2) != 0;
    let socket = socket_ud.inner.lock().unwrap();
    match socket.set_broadcast(broadcast) {
        Ok(_) => {
            lua_pushboolean(l, 1);
            1
        }
        Err(e) => {
            lua_error_msg(l, &e.to_string());
        }
    }
}

unsafe extern "C-unwind" fn net_udp_socket_broadcast(l: *mut lua_State) -> i32 {
    let socket_ud = &mut *get_udp_socket(l, 1);
    let socket = socket_ud.inner.lock().unwrap();
    match socket.broadcast() {
        Ok(b) => {
            lua_pushboolean(l, if b { 1 } else { 0 });
            1
        }
        Err(e) => {
            lua_error_msg(l, &e.to_string());
        }
    }
}

unsafe extern "C-unwind" fn net_udp_send_to(l: *mut lua_State) -> i32 {
    let socket_ud = &mut *get_udp_socket(l, 1);
    let addr = parse_socket_addr(l, 3);
    let data = if lua_isstring(l, 2) != 0 {
        let mut slen = 0;
        let ptr = lua_tolstring(l, 2, &mut slen);
        std::slice::from_raw_parts(ptr as *const u8, slen)
    } else if let Some(buf) = get_buffer_mut(l, 2) {
        buf
    } else {
        lua_error_msg(l, "expected buffer or string");
    };
    let socket = socket_ud.inner.lock().unwrap();
    match socket.send_to(data, addr) {
        Ok(n) => {
            lua_pushnumber(l, n as f64);
            1
        }
        Err(ref e) if e.kind() == std::io::ErrorKind::WouldBlock => {
            lua_pushnil(l);
            lua_pushstring(l, c"WouldBlock".as_ptr());
            2
        }
        Err(e) => {
            lua_error_msg(l, &e.to_string());
        }
    }
}

unsafe extern "C-unwind" fn net_udp_recv_from(l: *mut lua_State) -> i32 {
    let socket_ud = &mut *get_udp_socket(l, 1);
    if let Some(buf) = get_buffer_mut(l, 2) {
        let socket = socket_ud.inner.lock().unwrap();
        match socket.recv_from(buf) {
            Ok((n, addr)) => {
                lua_pushnumber(l, n as f64);
                push_socket_addr(l, addr);
                2
            }
            Err(ref e) if e.kind() == std::io::ErrorKind::WouldBlock => {
                lua_pushnil(l);
                lua_pushstring(l, c"WouldBlock".as_ptr());
                2
            }
            Err(e) => {
                lua_pushnil(l);
                let err_msg = e.to_string();
                lua_pushstring(l, str_to_cstring(&err_msg).as_ptr());
                2
            }
        }
    } else {
        lua_error_msg(l, "expected buffer");
    }
}

unsafe extern "C-unwind" fn net_udp_peek_from(l: *mut lua_State) -> i32 {
    let socket_ud = &mut *get_udp_socket(l, 1);
    if let Some(buf) = get_buffer_mut(l, 2) {
        let socket = socket_ud.inner.lock().unwrap();
        match socket.peek_from(buf) {
            Ok((n, addr)) => {
                lua_pushnumber(l, n as f64);
                push_socket_addr(l, addr);
                2
            }
            Err(ref e) if e.kind() == std::io::ErrorKind::WouldBlock => {
                lua_pushnil(l);
                lua_pushstring(l, c"WouldBlock".as_ptr());
                2
            }
            Err(e) => {
                lua_pushnil(l);
                let err_msg = e.to_string();
                lua_pushstring(l, str_to_cstring(&err_msg).as_ptr());
                2
            }
        }
    } else {
        lua_error_msg(l, "expected buffer");
    }
}

unsafe extern "C-unwind" fn net_udp_connect(l: *mut lua_State) -> i32 {
    let socket_ud = &mut *get_udp_socket(l, 1);
    let addr = parse_socket_addr(l, 2);
    let socket = socket_ud.inner.lock().unwrap();
    match socket.connect(addr) {
        Ok(_) => {
            lua_pushboolean(l, 1);
            1
        }
        Err(e) => {
            lua_error_msg(l, &e.to_string());
        }
    }
}

unsafe extern "C-unwind" fn net_udp_send(l: *mut lua_State) -> i32 {
    let socket_ud = &mut *get_udp_socket(l, 1);
    let data = if lua_isstring(l, 2) != 0 {
        let mut slen = 0;
        let ptr = lua_tolstring(l, 2, &mut slen);
        std::slice::from_raw_parts(ptr as *const u8, slen)
    } else if let Some(buf) = get_buffer_mut(l, 2) {
        buf
    } else {
        lua_error_msg(l, "expected buffer or string");
    };
    let socket = socket_ud.inner.lock().unwrap();
    match socket.send(data) {
        Ok(n) => {
            lua_pushnumber(l, n as f64);
            1
        }
        Err(ref e) if e.kind() == std::io::ErrorKind::WouldBlock => {
            lua_pushnil(l);
            lua_pushstring(l, c"WouldBlock".as_ptr());
            2
        }
        Err(e) => {
            lua_error_msg(l, &e.to_string());
        }
    }
}

unsafe extern "C-unwind" fn net_udp_recv(l: *mut lua_State) -> i32 {
    let socket_ud = &mut *get_udp_socket(l, 1);
    if let Some(buf) = get_buffer_mut(l, 2) {
        let socket = socket_ud.inner.lock().unwrap();
        match socket.recv(buf) {
            Ok(n) => {
                lua_pushnumber(l, n as f64);
                1
            }
            Err(ref e) if e.kind() == std::io::ErrorKind::WouldBlock => {
                lua_pushnil(l);
                lua_pushstring(l, c"WouldBlock".as_ptr());
                2
            }
            Err(e) => {
                lua_pushnil(l);
                let err_msg = e.to_string();
                lua_pushstring(l, str_to_cstring(&err_msg).as_ptr());
                2
            }
        }
    } else {
        lua_error_msg(l, "expected buffer");
    }
}

// --- EXPORT ---

/// # Safety
/// - `l` must be a valid pointer to a `lua_State`.
/// - `api` must be a valid pointer to a `LuauAPI` struct.
#[unsafe(no_mangle)]
pub unsafe extern "C-unwind" fn luau_export(l: *mut lua_State, api: *const LuauAPI) -> i32 {
    unsafe {
        init_api(api);
        lua_createtable(l, 0, 20);

        lua_pushcfunction(l, net_tcp_bind);
        lua_setfield(l, -2, c"tcp_bind".as_ptr());
        lua_pushcfunction(l, net_tcp_accept);
        lua_setfield(l, -2, c"tcp_accept".as_ptr());
        lua_pushcfunction(l, net_tcp_listener_close);
        lua_setfield(l, -2, c"tcp_listener_close".as_ptr());
        lua_pushcfunction(l, net_tcp_listener_local_addr);
        lua_setfield(l, -2, c"tcp_listener_local_addr".as_ptr());
        lua_pushcfunction(l, net_tcp_listener_set_ttl);
        lua_setfield(l, -2, c"tcp_listener_set_ttl".as_ptr());
        lua_pushcfunction(l, net_tcp_listener_ttl);
        lua_setfield(l, -2, c"tcp_listener_ttl".as_ptr());

        lua_pushcfunction(l, net_tcp_connect);
        lua_setfield(l, -2, c"tcp_connect".as_ptr());
        lua_pushcfunction(l, net_tcp_stream_close);
        lua_setfield(l, -2, c"tcp_stream_close".as_ptr());
        lua_pushcfunction(l, net_tcp_read);
        lua_setfield(l, -2, c"tcp_read".as_ptr());
        lua_pushcfunction(l, net_tcp_write);
        lua_setfield(l, -2, c"tcp_write".as_ptr());
        lua_pushcfunction(l, net_tcp_stream_peer_addr);
        lua_setfield(l, -2, c"tcp_stream_peer_addr".as_ptr());
        lua_pushcfunction(l, net_tcp_stream_local_addr);
        lua_setfield(l, -2, c"tcp_stream_local_addr".as_ptr());
        lua_pushcfunction(l, net_tcp_stream_shutdown);
        lua_setfield(l, -2, c"tcp_stream_shutdown".as_ptr());
        lua_pushcfunction(l, net_tcp_stream_set_nodelay);
        lua_setfield(l, -2, c"tcp_stream_set_nodelay".as_ptr());
        lua_pushcfunction(l, net_tcp_stream_nodelay);
        lua_setfield(l, -2, c"tcp_stream_nodelay".as_ptr());
        lua_pushcfunction(l, net_tcp_stream_set_ttl);
        lua_setfield(l, -2, c"tcp_stream_set_ttl".as_ptr());
        lua_pushcfunction(l, net_tcp_stream_ttl);
        lua_setfield(l, -2, c"tcp_stream_ttl".as_ptr());
        lua_pushcfunction(l, net_tcp_peek);
        lua_setfield(l, -2, c"tcp_peek".as_ptr());

        lua_pushcfunction(l, net_udp_bind);
        lua_setfield(l, -2, c"udp_bind".as_ptr());
        lua_pushcfunction(l, net_udp_send_to);
        lua_setfield(l, -2, c"udp_send_to".as_ptr());
        lua_pushcfunction(l, net_udp_recv_from);
        lua_setfield(l, -2, c"udp_recv_from".as_ptr());
        lua_pushcfunction(l, net_udp_peek_from);
        lua_setfield(l, -2, c"udp_peek_from".as_ptr());
        lua_pushcfunction(l, net_udp_socket_local_addr);
        lua_setfield(l, -2, c"udp_socket_local_addr".as_ptr());
        lua_pushcfunction(l, net_udp_socket_peer_addr);
        lua_setfield(l, -2, c"udp_socket_peer_addr".as_ptr());
        lua_pushcfunction(l, net_udp_socket_set_ttl);
        lua_setfield(l, -2, c"udp_socket_set_ttl".as_ptr());
        lua_pushcfunction(l, net_udp_socket_ttl);
        lua_setfield(l, -2, c"udp_socket_ttl".as_ptr());
        lua_pushcfunction(l, net_udp_socket_set_broadcast);
        lua_setfield(l, -2, c"udp_socket_set_broadcast".as_ptr());
        lua_pushcfunction(l, net_udp_socket_broadcast);
        lua_setfield(l, -2, c"udp_socket_broadcast".as_ptr());
        lua_pushcfunction(l, net_udp_connect);
        lua_setfield(l, -2, c"udp_connect".as_ptr());
        lua_pushcfunction(l, net_udp_send);
        lua_setfield(l, -2, c"udp_send".as_ptr());
        lua_pushcfunction(l, net_udp_recv);
        lua_setfield(l, -2, c"udp_recv".as_ptr());

        1
    }
}
