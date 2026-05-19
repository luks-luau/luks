use luks_module_sys::*;
use std::ffi::CString;
use std::os::raw::c_char;

/// Parse headers from a Lua table at given index
unsafe fn parse_headers(l: *mut lua_State, idx: i32) -> Vec<(String, String)> {
    let mut headers = Vec::new();
    let idx = unsafe { lua_absindex(l, idx) };
    let is_table = unsafe { lua_istable(l, idx) };
    if is_table == 0 {
        return headers;
    }

    unsafe {
        lua_pushnil(l);
        while lua_next(l, idx) != 0 {
            let mut key_len: usize = 0;
            let mut val_len: usize = 0;
            let key = lua_tolstring(l, -2, &mut key_len);
            let value = lua_tolstring(l, -1, &mut val_len);

            if !key.is_null() && !value.is_null() {
                let key_bytes = std::slice::from_raw_parts(key as *const u8, key_len);
                let val_bytes = std::slice::from_raw_parts(value as *const u8, val_len);
                let key_str = String::from_utf8_lossy(key_bytes).into_owned();
                let value_str = String::from_utf8_lossy(val_bytes).into_owned();
                headers.push((key_str, value_str));
            }

            lua_pop(l, 1);
        }
    }
    headers
}

/// Push response table to Lua stack
unsafe fn push_response(
    l: *mut lua_State,
    status: i32,
    status_text: &str,
    headers: &[(String, String)],
    body: Option<&str>,
    ok: bool,
) {
    unsafe {
        lua_createtable(l, 0, 5);

        lua_pushinteger(l, status as i64);
        lua_setfield(l, -2, c"status".as_ptr());

        let status_cstr = CString::new(status_text).unwrap();
        lua_pushstring(l, status_cstr.as_ptr());
        lua_setfield(l, -2, c"status_text".as_ptr());

        lua_createtable(l, 0, headers.len() as i32);
        for (key, value) in headers {
            let key_cstr = CString::new(key.as_str()).unwrap();
            lua_pushlstring(l, value.as_ptr() as *const c_char, value.len());
            lua_setfield(l, -2, key_cstr.as_ptr());
        }
        lua_setfield(l, -2, c"headers".as_ptr());

        if let Some(b) = body {
            lua_pushlstring(l, b.as_ptr() as *const c_char, b.len());
        } else {
            lua_pushnil(l);
        }
        lua_setfield(l, -2, c"body".as_ptr());

        lua_pushboolean(l, if ok { 1 } else { 0 });
        lua_setfield(l, -2, c"ok".as_ptr());
    }
}

/// Push error response
unsafe fn push_error(l: *mut lua_State, error_msg: &str, status: i32) {
    unsafe {
        lua_createtable(l, 0, 4);

        lua_pushinteger(l, status as i64);
        lua_setfield(l, -2, c"status".as_ptr());

        let status_text = if status == 0 {
            "Transport Error"
        } else {
            "HTTP Error"
        };
        let status_cstr = CString::new(status_text).unwrap();
        lua_pushstring(l, status_cstr.as_ptr());
        lua_setfield(l, -2, c"status_text".as_ptr());

        let error_cstr = CString::new(error_msg).unwrap();
        lua_pushstring(l, error_cstr.as_ptr());
        lua_setfield(l, -2, c"error".as_ptr());

        lua_pushboolean(l, 0);
        lua_setfield(l, -2, c"ok".as_ptr());

        lua_pushnil(l);
        lua_setfield(l, -2, c"headers".as_ptr());
        lua_pushnil(l);
        lua_setfield(l, -2, c"body".as_ptr());
    }
}

/// Parse timeout from options table at given index
unsafe fn parse_timeout(l: *mut lua_State, idx: i32) -> Option<std::time::Duration> {
    unsafe {
        lua_pushstring(l, c"timeout".as_ptr());
        lua_gettable(l, idx);
        let is_number = lua_isnumber(l, -1);
        if is_number != 0 {
            let timeout_secs = lua_tonumber(l, -1) as u64;
            lua_pop(l, 1);
            return Some(std::time::Duration::from_secs(timeout_secs));
        }
        lua_pop(l, 1);
        None
    }
}

/// Generic request handler
unsafe fn handle_request(l: *mut lua_State, method: &str) -> i32 {
    let argc = unsafe { lua_gettop(l) };
    if argc < 1 {
        unsafe {
            push_error(l, "Missing URL argument", 0);
        }
        return 1;
    }

    // Get method string and indices
    let method_str: String;
    let url_idx: i32;
    let options_idx: i32;

    if method == "__generic__" {
        if argc < 2 {
            unsafe {
                push_error(l, "Missing URL argument for generic request", 0);
            }
            return 1;
        }
        let mut m_len: usize = 0;
        let m = unsafe { lua_tolstring(l, 1, &mut m_len) };
        if m.is_null() {
            unsafe {
                push_error(l, "Invalid method argument", 0);
            }
            return 1;
        }
        let m_bytes = unsafe { std::slice::from_raw_parts(m as *const u8, m_len) };
        method_str = String::from_utf8_lossy(m_bytes).into_owned();
        url_idx = 2;
        options_idx = 3;
    } else {
        method_str = method.to_string();
        url_idx = 1;
        options_idx = 2;
    }

    // Get URL
    let mut url_len: usize = 0;
    let url = unsafe { lua_tolstring(l, url_idx, &mut url_len) };
    if url.is_null() {
        unsafe {
            push_error(l, "Invalid or missing URL", 0);
        }
        return 1;
    }
    let url_bytes = unsafe { std::slice::from_raw_parts(url as *const u8, url_len) };
    let url = String::from_utf8_lossy(url_bytes).into_owned();

    // Parse options table
    let mut headers = Vec::new();
    let mut body: Option<String> = None;
    let mut timeout: Option<std::time::Duration> = None;

    if argc >= options_idx {
        let is_table = unsafe { lua_istable(l, options_idx) };
        if is_table != 0 {
            // Parse headers
            unsafe {
                lua_pushstring(l, c"headers".as_ptr());
                lua_gettable(l, options_idx);
                if lua_istable(l, -1) != 0 {
                    headers = parse_headers(l, -1);
                }
                lua_pop(l, 1);
            }

            // Parse body
            unsafe {
                lua_pushstring(l, c"body".as_ptr());
                lua_gettable(l, options_idx);
                if lua_isstring(l, -1) != 0 {
                    let mut body_len: usize = 0;
                    let body_str = lua_tolstring(l, -1, &mut body_len);
                    if !body_str.is_null() {
                        let bytes = std::slice::from_raw_parts(body_str as *const u8, body_len);
                        body = Some(String::from_utf8_lossy(bytes).into_owned());
                    }
                }
                lua_pop(l, 1);
            }

            // Parse timeout
            timeout = unsafe { parse_timeout(l, options_idx) };
        }
    }

    // Build request
    let method_upper = method_str.to_uppercase();
    let mut req = match method_upper.as_str() {
        "GET" => ureq::get(&url),
        "POST" => ureq::post(&url),
        "PUT" => ureq::put(&url),
        "DELETE" => ureq::delete(&url),
        "PATCH" => ureq::patch(&url),
        "HEAD" => ureq::head(&url),
        _ => {
            unsafe {
                push_error(l, &format!("Unsupported HTTP method: {}", method_str), 0);
            }
            return 1;
        }
    };

    // Apply timeout if specified
    if let Some(duration) = timeout {
        req = req.timeout(duration);
    }

    for (key, value) in headers {
        req = req.set(&key, &value);
    }

    let response = if let Some(b) = body {
        req.send_string(&b)
    } else {
        req.call()
    };

    match response {
        Ok(resp) => {
            let status = resp.status() as i32;
            let status_text = resp.status_text().to_string();
            let ok = (200..300).contains(&status);

            let resp_headers: Vec<(String, String)> = resp
                .headers_names()
                .iter()
                .filter_map(|name| resp.header(name).map(|v| (name.to_string(), v.to_string())))
                .collect();

            let body_str = resp.into_string().ok();
            unsafe {
                push_response(
                    l,
                    status,
                    &status_text,
                    &resp_headers,
                    body_str.as_deref(),
                    ok,
                );
            }
        }
        Err(ureq::Error::Status(status, resp)) => {
            let status = status as i32;
            let status_text = resp.status_text().to_string();
            let ok = false;

            let resp_headers: Vec<(String, String)> = resp
                .headers_names()
                .iter()
                .filter_map(|name| resp.header(name).map(|v| (name.to_string(), v.to_string())))
                .collect();

            let body_str = resp.into_string().ok();
            unsafe {
                push_response(
                    l,
                    status,
                    &status_text,
                    &resp_headers,
                    body_str.as_deref(),
                    ok,
                );
            }
        }
        Err(ureq::Error::Transport(e)) => unsafe {
            push_error(l, &e.to_string(), 0);
        },
    }

    1
}

// Lua bindings for HTTP methods
unsafe extern "C-unwind" fn lua_get(l: *mut lua_State) -> i32 {
    unsafe { handle_request(l, "GET") }
}

unsafe extern "C-unwind" fn lua_post(l: *mut lua_State) -> i32 {
    unsafe { handle_request(l, "POST") }
}

unsafe extern "C-unwind" fn lua_put(l: *mut lua_State) -> i32 {
    unsafe { handle_request(l, "PUT") }
}

unsafe extern "C-unwind" fn lua_delete(l: *mut lua_State) -> i32 {
    unsafe { handle_request(l, "DELETE") }
}

unsafe extern "C-unwind" fn lua_patch(l: *mut lua_State) -> i32 {
    unsafe { handle_request(l, "PATCH") }
}

unsafe extern "C-unwind" fn lua_head(l: *mut lua_State) -> i32 {
    unsafe { handle_request(l, "HEAD") }
}

unsafe extern "C-unwind" fn lua_request(l: *mut lua_State) -> i32 {
    unsafe { handle_request(l, "__generic__") }
}

/// Entrypoint
///
/// # Safety
///
/// This function is called from Lua and expects a valid lua_State pointer.
/// The caller must ensure that the lua_State pointer is valid and that
/// the Lua stack is in a proper state. This function creates and pushes
/// a table containing HTTP functions onto the Lua stack.
#[unsafe(no_mangle)]
pub unsafe extern "C-unwind" fn luau_export(l: *mut lua_State, api: *const LuauAPI) -> i32 {
    unsafe {
        init_api(api);
        lua_createtable(l, 0, 8);

        lua_pushstring(l, c"0.1.0".as_ptr());
        lua_setfield(l, -2, c"version".as_ptr());

        lua_pushcfunction(l, lua_get);
        lua_setfield(l, -2, c"get".as_ptr());

        lua_pushcfunction(l, lua_post);
        lua_setfield(l, -2, c"post".as_ptr());

        lua_pushcfunction(l, lua_put);
        lua_setfield(l, -2, c"put".as_ptr());

        lua_pushcfunction(l, lua_delete);
        lua_setfield(l, -2, c"delete".as_ptr());

        lua_pushcfunction(l, lua_patch);
        lua_setfield(l, -2, c"patch".as_ptr());

        lua_pushcfunction(l, lua_head);
        lua_setfield(l, -2, c"head".as_ptr());

        lua_pushcfunction(l, lua_request);
        lua_setfield(l, -2, c"request".as_ptr());

        1
    }
}
