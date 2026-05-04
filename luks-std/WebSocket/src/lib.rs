#![allow(unsafe_op_in_unsafe_fn)]

use mlua_sys::luau::*;
use std::collections::HashMap;
use std::ffi::{CStr, CString};
use std::net::TcpStream;
use std::ptr;
use std::sync::Mutex;
use std::sync::atomic::{AtomicI64, Ordering};
use std::time::Duration;
use tungstenite::stream::MaybeTlsStream;
use tungstenite::{Message, WebSocket};

// ---------------------------------------------------------------------------
// Global connection registry
// ---------------------------------------------------------------------------

struct WsConnection {
    socket: WebSocket<MaybeTlsStream<TcpStream>>,
    url: String,
}

static NEXT_ID: AtomicI64 = AtomicI64::new(1);

// SAFETY: WsConnection contains a TcpStream which is Send but not Sync.
// We wrap in Mutex which makes it Sync. Only accessed through the lock.
unsafe impl Send for WsConnection {}

static CONNECTIONS: Mutex<Option<HashMap<i64, WsConnection>>> = Mutex::new(None);

fn with_connections<F, R>(f: F) -> R
where
    F: FnOnce(&mut HashMap<i64, WsConnection>) -> R,
{
    let mut guard = CONNECTIONS.lock().unwrap_or_else(|e| e.into_inner());
    let map = guard.get_or_insert_with(HashMap::new);
    f(map)
}

// ---------------------------------------------------------------------------
// Lua helper utilities
// ---------------------------------------------------------------------------

/// Push a CString-safe Lua string.
unsafe fn lua_push_str(l: *mut lua_State, s: &str) {
    let sanitized = s.replace('\0', "\u{FFFD}");
    let cstr = CString::new(sanitized).unwrap_or_else(|_| CString::new("?").unwrap());
    lua_pushstring(l, cstr.as_ptr());
}

/// Raise a Lua runtime error with the given message. Never returns.
unsafe fn lua_raise(l: *mut lua_State, msg: &str) -> ! {
    lua_push_str(l, msg);
    lua_error(l);
}

/// Read a Lua string argument at `idx`. Returns None if not a string.
unsafe fn lua_get_string(l: *mut lua_State, idx: i32) -> Option<String> {
    if lua_isstring(l, idx) == 0 {
        return None;
    }
    let ptr = lua_tolstring(l, idx, ptr::null_mut());
    if ptr.is_null() {
        return None;
    }
    Some(CStr::from_ptr(ptr).to_string_lossy().into_owned())
}

/// Parse a table of string→string headers at `idx`. Returns empty Vec if not a table.
unsafe fn parse_headers(l: *mut lua_State, idx: i32) -> Vec<(String, String)> {
    let mut headers = Vec::new();
    let idx = lua_absindex(l, idx);
    if lua_istable(l, idx) == 0 {
        return headers;
    }
    lua_pushnil(l);
    while lua_next(l, idx) != 0 {
        let key = lua_tolstring(l, -2, ptr::null_mut());
        let val = lua_tolstring(l, -1, ptr::null_mut());
        if !key.is_null() && !val.is_null() {
            let k = CStr::from_ptr(key).to_string_lossy().into_owned();
            let v = CStr::from_ptr(val).to_string_lossy().into_owned();
            headers.push((k, v));
        }
        lua_pop(l, 1);
    }
    headers
}

// ---------------------------------------------------------------------------
// ws_connect(url: string, options?: {headers?: {[string]:string}, timeout?: number}) -> id: number
// Raises a Lua error on failure (catchable with pcall).
// ---------------------------------------------------------------------------
unsafe extern "C-unwind" fn lua_ws_connect(l: *mut lua_State) -> i32 {
    let url = match lua_get_string(l, 1) {
        Some(u) => u,
        None => lua_raise(l, "ws_connect: argument #1 must be a string URL"),
    };

    // Parse options table (arg 2)
    let mut extra_headers: Vec<(String, String)> = Vec::new();
    let mut timeout_secs: u64 = 30;

    let argc = lua_gettop(l);
    if argc >= 2 && lua_istable(l, 2) != 0 {
        lua_pushstring(l, c"headers".as_ptr());
        lua_gettable(l, 2);
        if lua_istable(l, -1) != 0 {
            extra_headers = parse_headers(l, -1);
        }
        lua_pop(l, 1);

        lua_pushstring(l, c"timeout".as_ptr());
        lua_gettable(l, 2);
        if lua_isnumber(l, -1) != 0 {
            let t = lua_tonumber(l, -1);
            if t > 0.0 {
                timeout_secs = t as u64;
            }
        }
        lua_pop(l, 1);
    }

    // CORRECT approach per tungstenite docs:
    // Build the request by converting the URL via IntoClientRequest, which lets tungstenite
    // populate ALL mandatory WebSocket handshake headers automatically
    // (Sec-WebSocket-Key, Sec-WebSocket-Version, Upgrade, Connection, Host).
    // Then inject any caller-supplied custom headers via headers_mut().
    // Building from scratch with Request::builder() skips these required headers → handshake fails.
    use tungstenite::client::IntoClientRequest;
    let mut request = match url.as_str().into_client_request() {
        Ok(r) => r,
        Err(e) => lua_raise(l, &format!("ws_connect: invalid URL: {}", e)),
    };
    for (k, v) in &extra_headers {
        if let (Ok(name), Ok(value)) = (
            tungstenite::http::header::HeaderName::from_bytes(k.as_bytes()),
            tungstenite::http::header::HeaderValue::from_str(v),
        ) {
            request.headers_mut().insert(name, value);
        }
        // Skip malformed header names/values silently
    }

    // tungstenite::connect handles DNS, TCP, and TLS correctly for both ws:// and wss://.
    let (mut socket, _response) = match tungstenite::connect(request) {
        Ok(pair) => pair,
        Err(e) => lua_raise(l, &format!("ws_connect: {}", e)),
    };

    // Apply read/write timeouts on the underlying TCP socket.
    // This affects blocking receive calls (not the initial TCP connect).
    let timeout = Some(Duration::from_secs(timeout_secs));
    match socket.get_mut() {
        tungstenite::stream::MaybeTlsStream::Plain(tcp) => {
            let _ = tcp.set_read_timeout(timeout);
            let _ = tcp.set_write_timeout(timeout);
        }
        tungstenite::stream::MaybeTlsStream::NativeTls(tls) => {
            let _ = tls.get_ref().set_read_timeout(timeout);
            let _ = tls.get_ref().set_write_timeout(timeout);
        }
        _ => {}
    }

    let id = NEXT_ID.fetch_add(1, Ordering::Relaxed);
    with_connections(|map| {
        map.insert(id, WsConnection { socket, url });
    });
    lua_pushinteger(l, id);
    1
}

// ---------------------------------------------------------------------------
// ws_send(handle_id: number, message: string) -> true
// Raises a Lua error on failure (catchable with pcall).
// ---------------------------------------------------------------------------
unsafe extern "C-unwind" fn lua_ws_send(l: *mut lua_State) -> i32 {
    if lua_isnumber(l, 1) == 0 {
        lua_raise(l, "ws_send: argument #1 must be a handle id (number)");
    }
    let id = lua_tointeger(l, 1);

    let message = match lua_get_string(l, 2) {
        Some(m) => m,
        None => lua_raise(l, "ws_send: argument #2 must be a string message"),
    };

    let result = with_connections(|map| {
        let conn = map.get_mut(&id)?;
        Some(conn.socket.send(Message::Text(message)))
    });

    match result {
        None => lua_raise(l, "ws_send: invalid or closed handle"),
        Some(Ok(())) => {
            lua_pushboolean(l, 1);
            1
        }
        Some(Err(e)) => lua_raise(l, &format!("ws_send: {}", e)),
    }
}

// ---------------------------------------------------------------------------
// ws_send_binary(handle_id: number, data: string) -> true
// Raises a Lua error on failure (catchable with pcall).
// ---------------------------------------------------------------------------
unsafe extern "C-unwind" fn lua_ws_send_binary(l: *mut lua_State) -> i32 {
    if lua_isnumber(l, 1) == 0 {
        lua_raise(
            l,
            "ws_send_binary: argument #1 must be a handle id (number)",
        );
    }
    let id = lua_tointeger(l, 1);

    let message = match lua_get_string(l, 2) {
        Some(m) => m,
        None => lua_raise(l, "ws_send_binary: argument #2 must be a string"),
    };

    let result = with_connections(|map| {
        let conn = map.get_mut(&id)?;
        Some(conn.socket.send(Message::Binary(message.into_bytes())))
    });

    match result {
        None => lua_raise(l, "ws_send_binary: invalid or closed handle"),
        Some(Ok(())) => {
            lua_pushboolean(l, 1);
            1
        }
        Some(Err(e)) => lua_raise(l, &format!("ws_send_binary: {}", e)),
    }
}

// ---------------------------------------------------------------------------
// ws_receive(handle_id: number) -> {type, data, code?, reason?} | nil, "timeout"
//
// Returns nil + "timeout" on WouldBlock/TimedOut (expected in poll loops).
// Raises a Lua error for unexpected protocol/IO errors.
// Designed to be called inside task.spawn in Luau.
// ---------------------------------------------------------------------------
unsafe extern "C-unwind" fn lua_ws_receive(l: *mut lua_State) -> i32 {
    if lua_isnumber(l, 1) == 0 {
        lua_raise(l, "ws_receive: argument #1 must be a handle id (number)");
    }
    let id = lua_tointeger(l, 1);

    let result = with_connections(|map| {
        let conn = map.get_mut(&id)?;
        Some(conn.socket.read())
    });

    match result {
        None => lua_raise(l, "ws_receive: invalid or closed handle"),
        Some(Ok(msg)) => {
            // Push result table: { type, data, code?, reason? }
            lua_createtable(l, 0, 4);

            match msg {
                Message::Text(text) => {
                    lua_push_str(l, "text");
                    lua_setfield(l, -2, c"type".as_ptr());
                    lua_push_str(l, &text);
                    lua_setfield(l, -2, c"data".as_ptr());
                }
                Message::Binary(bytes) => {
                    lua_push_str(l, "binary");
                    lua_setfield(l, -2, c"type".as_ptr());
                    lua_pushlstring(l, bytes.as_ptr() as *const i8, bytes.len());
                    lua_setfield(l, -2, c"data".as_ptr());
                }
                Message::Ping(data) => {
                    lua_push_str(l, "ping");
                    lua_setfield(l, -2, c"type".as_ptr());
                    lua_pushlstring(l, data.as_ptr() as *const i8, data.len());
                    lua_setfield(l, -2, c"data".as_ptr());
                }
                Message::Pong(data) => {
                    lua_push_str(l, "pong");
                    lua_setfield(l, -2, c"type".as_ptr());
                    lua_pushlstring(l, data.as_ptr() as *const i8, data.len());
                    lua_setfield(l, -2, c"data".as_ptr());
                }
                Message::Close(frame) => {
                    lua_push_str(l, "close");
                    lua_setfield(l, -2, c"type".as_ptr());
                    if let Some(f) = frame {
                        lua_pushinteger(l, u16::from(f.code) as i64);
                        lua_setfield(l, -2, c"code".as_ptr());
                        lua_push_str(l, &f.reason);
                        lua_setfield(l, -2, c"reason".as_ptr());
                    } else {
                        lua_pushinteger(l, 1000);
                        lua_setfield(l, -2, c"code".as_ptr());
                        lua_push_str(l, "");
                        lua_setfield(l, -2, c"reason".as_ptr());
                    }
                }
                Message::Frame(_) => {
                    lua_push_str(l, "frame");
                    lua_setfield(l, -2, c"type".as_ptr());
                    lua_pushnil(l);
                    lua_setfield(l, -2, c"data".as_ptr());
                }
            }

            1
        }
        Some(Err(tungstenite::Error::ConnectionClosed)) => {
            // Connection was cleanly closed — return a synthetic close message
            lua_createtable(l, 0, 3);
            lua_push_str(l, "close");
            lua_setfield(l, -2, c"type".as_ptr());
            lua_pushinteger(l, 1000);
            lua_setfield(l, -2, c"code".as_ptr());
            lua_push_str(l, "connection closed");
            lua_setfield(l, -2, c"reason".as_ptr());
            1
        }
        Some(Err(tungstenite::Error::Io(e)))
            if e.kind() == std::io::ErrorKind::WouldBlock
                || e.kind() == std::io::ErrorKind::TimedOut =>
        {
            // Expected: no message yet (non-blocking / timeout). Return nil, "timeout".
            lua_pushnil(l);
            lua_push_str(l, "timeout");
            2
        }
        Some(Err(e)) => lua_raise(l, &format!("ws_receive: {}", e)),
    }
}

// ---------------------------------------------------------------------------
// ws_close(handle_id: number, code?: number, reason?: string) -> ()
// Raises a Lua error if handle is invalid.
// ---------------------------------------------------------------------------
unsafe extern "C-unwind" fn lua_ws_close(l: *mut lua_State) -> i32 {
    if lua_isnumber(l, 1) == 0 {
        lua_raise(l, "ws_close: argument #1 must be a handle id (number)");
    }
    let id = lua_tointeger(l, 1);

    let code: u16 = if lua_isnumber(l, 2) != 0 {
        lua_tointeger(l, 2) as u16
    } else {
        1000
    };
    let reason = lua_get_string(l, 3).unwrap_or_default();

    with_connections(|map| {
        if let Some(conn) = map.get_mut(&id) {
            let close_frame = tungstenite::protocol::CloseFrame {
                code: tungstenite::protocol::frame::coding::CloseCode::from(code),
                reason: reason.into(),
            };
            let _ = conn.socket.close(Some(close_frame));
        }
        map.remove(&id);
    });

    0
}

// ---------------------------------------------------------------------------
// ws_is_open(handle_id: number) -> boolean
// ---------------------------------------------------------------------------
unsafe extern "C-unwind" fn lua_ws_is_open(l: *mut lua_State) -> i32 {
    if lua_isnumber(l, 1) == 0 {
        lua_raise(l, "ws_is_open: argument #1 must be a handle id (number)");
    }
    let id = lua_tointeger(l, 1);

    let open = with_connections(|map| {
        map.get(&id)
            .map(|conn| conn.socket.can_write())
            .unwrap_or(false)
    });

    lua_pushboolean(l, if open { 1 } else { 0 });
    1
}

// ---------------------------------------------------------------------------
// ws_url(handle_id: number) -> string
// Raises a Lua error if handle is invalid.
// ---------------------------------------------------------------------------
unsafe extern "C-unwind" fn lua_ws_url(l: *mut lua_State) -> i32 {
    if lua_isnumber(l, 1) == 0 {
        lua_raise(l, "ws_url: argument #1 must be a handle id (number)");
    }
    let id = lua_tointeger(l, 1);

    let url = with_connections(|map| map.get(&id).map(|c| c.url.clone()));

    match url {
        Some(u) => {
            lua_push_str(l, &u);
            1
        }
        None => lua_raise(l, "ws_url: invalid or closed handle"),
    }
}

// ---------------------------------------------------------------------------
// Entrypoint
// ---------------------------------------------------------------------------

/// # Safety
/// Called from Luau VM with a valid lua_State.
#[unsafe(no_mangle)]
pub unsafe extern "C-unwind" fn luau_export(l: *mut lua_State) -> i32 {
    lua_createtable(l, 0, 8);

    lua_pushstring(l, c"0.1.0".as_ptr());
    lua_setfield(l, -2, c"version".as_ptr());

    lua_pushcfunction(l, lua_ws_connect);
    lua_setfield(l, -2, c"connect".as_ptr());

    lua_pushcfunction(l, lua_ws_send);
    lua_setfield(l, -2, c"send".as_ptr());

    lua_pushcfunction(l, lua_ws_send_binary);
    lua_setfield(l, -2, c"send_binary".as_ptr());

    lua_pushcfunction(l, lua_ws_receive);
    lua_setfield(l, -2, c"receive".as_ptr());

    lua_pushcfunction(l, lua_ws_close);
    lua_setfield(l, -2, c"close".as_ptr());

    lua_pushcfunction(l, lua_ws_is_open);
    lua_setfield(l, -2, c"is_open".as_ptr());

    lua_pushcfunction(l, lua_ws_url);
    lua_setfield(l, -2, c"url".as_ptr());

    1
}
