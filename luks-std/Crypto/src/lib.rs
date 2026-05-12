#![allow(unsafe_op_in_unsafe_fn)]

use aes_gcm::aead::{Aead, KeyInit, Payload};
use aes_gcm::{Aes128Gcm, Aes256Gcm, Nonce};
use base64::prelude::*;
use hmac::{Hmac, Mac};
use luks_module_sys::*;
use md5::Md5;
use rand::RngCore;
use rand::rngs::OsRng;
use sha1::Sha1;
use sha2::{Digest, Sha256, Sha384, Sha512};
use std::ffi::CString;

/// Helper to convert a Rust string to CString, replacing null bytes with U+FFFD
fn str_to_cstring(s: &str) -> CString {
    let sanitized = s.replace('\0', "\u{FFFD}");
    CString::new(sanitized).expect("Failed to create CString after sanitization")
}

/// Raise a Lua error with the given message. This function does not return.
///
/// # Safety
/// Assumes `l` is a valid `lua_State` pointer.
unsafe fn lua_error_msg(l: *mut lua_State, msg: &str) -> ! {
    unsafe {
        let cstr = str_to_cstring(msg);
        lua_pushstring(l, cstr.as_ptr());
        lua_error(l);
    }
}

/// Reads a string or raw binary payload from the given stack index.
///
/// # Safety
/// Assumes `l` is valid. Raises a Lua runtime error if the argument is missing or not a string.
unsafe fn get_string_arg<'a>(
    l: *mut lua_State,
    idx: i32,
    func_name: &str,
    arg_name: &str,
) -> &'a [u8] {
    unsafe {
        if lua_gettop(l) < idx {
            lua_error_msg(
                l,
                &format!(
                    "{} error: expected argument {} ({})",
                    func_name, idx, arg_name
                ),
            );
        }
        let mut len: usize = 0;
        let ptr = lua_tolstring(l, idx, &mut len);
        if ptr.is_null() {
            lua_error_msg(
                l,
                &format!(
                    "{} error: argument {} ({}) must be a string",
                    func_name, idx, arg_name
                ),
            );
        }
        std::slice::from_raw_parts(ptr as *const u8, len)
    }
}

/// Helper to compute standard hash digests.
///
/// # Safety
/// Invoked via VM bounds.
unsafe fn execute_hash<D: Digest>(l: *mut lua_State, func_name: &str) -> i32 {
    unsafe {
        let data = get_string_arg(l, 1, func_name, "data");
        let raw = if lua_gettop(l) >= 2 && lua_type(l, 2) == LUA_TBOOLEAN {
            lua_toboolean(l, 2) != 0
        } else {
            false
        };

        let mut hasher = D::new();
        hasher.update(data);
        let digest = hasher.finalize();

        if raw {
            lua_pushlstring(l, digest.as_ptr() as *const i8, digest.len());
        } else {
            let hex_str = hex::encode(digest);
            lua_pushlstring(l, hex_str.as_ptr() as *const i8, hex_str.len());
        }
        1
    }
}

/// Exported MD5 hashing wrapper.
///
/// # Safety
/// Must be invoked by the Luau VM with a valid state pointer.
unsafe extern "C-unwind" fn lua_md5(l: *mut lua_State) -> i32 {
    unsafe { execute_hash::<Md5>(l, "Crypto.md5") }
}

/// Exported SHA-1 hashing wrapper.
///
/// # Safety
/// Must be invoked by the Luau VM with a valid state pointer.
unsafe extern "C-unwind" fn lua_sha1(l: *mut lua_State) -> i32 {
    unsafe { execute_hash::<Sha1>(l, "Crypto.sha1") }
}

/// Exported SHA-256 hashing wrapper.
///
/// # Safety
/// Must be invoked by the Luau VM with a valid state pointer.
unsafe extern "C-unwind" fn lua_sha256(l: *mut lua_State) -> i32 {
    unsafe { execute_hash::<Sha256>(l, "Crypto.sha256") }
}

/// Exported SHA-384 hashing wrapper.
///
/// # Safety
/// Must be invoked by the Luau VM with a valid state pointer.
unsafe extern "C-unwind" fn lua_sha384(l: *mut lua_State) -> i32 {
    unsafe { execute_hash::<Sha384>(l, "Crypto.sha384") }
}

/// Exported SHA-512 hashing wrapper.
///
/// # Safety
/// Must be invoked by the Luau VM with a valid state pointer.
unsafe extern "C-unwind" fn lua_sha512(l: *mut lua_State) -> i32 {
    unsafe { execute_hash::<Sha512>(l, "Crypto.sha512") }
}

/// Exported HMAC-SHA256 wrapper.
///
/// # Safety
/// Must be invoked by the Luau VM with a valid state pointer.
unsafe extern "C-unwind" fn lua_hmac_sha256(l: *mut lua_State) -> i32 {
    unsafe {
        let key = get_string_arg(l, 1, "Crypto.hmacSha256", "key");
        let data = get_string_arg(l, 2, "Crypto.hmacSha256", "data");
        let raw = if lua_gettop(l) >= 3 && lua_type(l, 3) == LUA_TBOOLEAN {
            lua_toboolean(l, 3) != 0
        } else {
            false
        };

        type HmacSha256 = Hmac<Sha256>;
        let mut mac = match <HmacSha256 as Mac>::new_from_slice(key) {
            Ok(m) => m,
            Err(_) => lua_error_msg(l, "Crypto.hmacSha256 error: invalid key length"),
        };
        mac.update(data);
        let result = mac.finalize().into_bytes();

        if raw {
            lua_pushlstring(l, result.as_ptr() as *const i8, result.len());
        } else {
            let hex_str = hex::encode(result);
            lua_pushlstring(l, hex_str.as_ptr() as *const i8, hex_str.len());
        }
        1
    }
}

/// Exported HMAC-SHA512 wrapper.
///
/// # Safety
/// Must be invoked by the Luau VM with a valid state pointer.
unsafe extern "C-unwind" fn lua_hmac_sha512(l: *mut lua_State) -> i32 {
    unsafe {
        let key = get_string_arg(l, 1, "Crypto.hmacSha512", "key");
        let data = get_string_arg(l, 2, "Crypto.hmacSha512", "data");
        let raw = if lua_gettop(l) >= 3 && lua_type(l, 3) == LUA_TBOOLEAN {
            lua_toboolean(l, 3) != 0
        } else {
            false
        };

        type HmacSha512 = Hmac<Sha512>;
        let mut mac = match <HmacSha512 as Mac>::new_from_slice(key) {
            Ok(m) => m,
            Err(_) => lua_error_msg(l, "Crypto.hmacSha512 error: invalid key length"),
        };
        mac.update(data);
        let result = mac.finalize().into_bytes();

        if raw {
            lua_pushlstring(l, result.as_ptr() as *const i8, result.len());
        } else {
            let hex_str = hex::encode(result);
            lua_pushlstring(l, hex_str.as_ptr() as *const i8, hex_str.len());
        }
        1
    }
}

/// Authenticated AES-GCM encryption wrapper.
/// Supports both 128-bit (16 bytes key) and 256-bit (32 bytes key). Nonce must be 12 bytes.
///
/// # Safety
/// Must be invoked by the Luau VM with a valid state pointer.
unsafe extern "C-unwind" fn lua_encrypt_aes_gcm(l: *mut lua_State) -> i32 {
    unsafe {
        let key = get_string_arg(l, 1, "Crypto.encryptAesGcm", "key");
        let nonce_bytes = get_string_arg(l, 2, "Crypto.encryptAesGcm", "nonce");
        let data = get_string_arg(l, 3, "Crypto.encryptAesGcm", "data");

        let aad = if lua_gettop(l) >= 4 && lua_type(l, 4) == LUA_TSTRING {
            let mut len: usize = 0;
            let p = lua_tolstring(l, 4, &mut len);
            std::slice::from_raw_parts(p as *const u8, len)
        } else {
            &[]
        };

        if nonce_bytes.len() != 12 {
            lua_error_msg(
                l,
                "Crypto.encryptAesGcm error: nonce must be exactly 12 bytes",
            );
        }
        let nonce = Nonce::from_slice(nonce_bytes);
        let payload = Payload { msg: data, aad };

        let ciphertext = match key.len() {
            16 => {
                let cipher = Aes128Gcm::new_from_slice(key).unwrap();
                cipher.encrypt(nonce, payload)
            }
            32 => {
                let cipher = Aes256Gcm::new_from_slice(key).unwrap();
                cipher.encrypt(nonce, payload)
            }
            _ => lua_error_msg(
                l,
                "Crypto.encryptAesGcm error: key must be exactly 16 bytes (AES-128) or 32 bytes (AES-256)",
            ),
        };

        match ciphertext {
            Ok(res) => {
                lua_pushlstring(l, res.as_ptr() as *const i8, res.len());
                1
            }
            Err(e) => lua_error_msg(
                l,
                &format!("Crypto.encryptAesGcm error: encryption failed: {:?}", e),
            ),
        }
    }
}

/// Authenticated AES-GCM decryption wrapper.
///
/// # Safety
/// Must be invoked by the Luau VM with a valid state pointer.
unsafe extern "C-unwind" fn lua_decrypt_aes_gcm(l: *mut lua_State) -> i32 {
    unsafe {
        let key = get_string_arg(l, 1, "Crypto.decryptAesGcm", "key");
        let nonce_bytes = get_string_arg(l, 2, "Crypto.decryptAesGcm", "nonce");
        let encrypted_data = get_string_arg(l, 3, "Crypto.decryptAesGcm", "encrypted_data");

        let aad = if lua_gettop(l) >= 4 && lua_type(l, 4) == LUA_TSTRING {
            let mut len: usize = 0;
            let p = lua_tolstring(l, 4, &mut len);
            std::slice::from_raw_parts(p as *const u8, len)
        } else {
            &[]
        };

        if nonce_bytes.len() != 12 {
            lua_error_msg(
                l,
                "Crypto.decryptAesGcm error: nonce must be exactly 12 bytes",
            );
        }
        let nonce = Nonce::from_slice(nonce_bytes);
        let payload = Payload {
            msg: encrypted_data,
            aad,
        };

        let plaintext = match key.len() {
            16 => {
                let cipher = Aes128Gcm::new_from_slice(key).unwrap();
                cipher.decrypt(nonce, payload)
            }
            32 => {
                let cipher = Aes256Gcm::new_from_slice(key).unwrap();
                cipher.decrypt(nonce, payload)
            }
            _ => lua_error_msg(
                l,
                "Crypto.decryptAesGcm error: key must be exactly 16 bytes (AES-128) or 32 bytes (AES-256)",
            ),
        };

        match plaintext {
            Ok(res) => {
                lua_pushlstring(l, res.as_ptr() as *const i8, res.len());
                1
            }
            Err(_) => lua_error_msg(
                l,
                "Crypto.decryptAesGcm error: authentication failed (invalid key, tampered ciphertext, or wrong nonce)",
            ),
        }
    }
}

/// CSPRNG secure randomness wrapper.
///
/// # Safety
/// Must be invoked by the Luau VM with a valid state pointer.
unsafe extern "C-unwind" fn lua_random_bytes(l: *mut lua_State) -> i32 {
    unsafe {
        if lua_gettop(l) < 1 {
            lua_error_msg(l, "Crypto.randomBytes error: expected 1 argument (size)");
        }
        if lua_type(l, 1) != LUA_TNUMBER {
            lua_error_msg(
                l,
                "Crypto.randomBytes error: argument 1 (size) must be a number",
            );
        }
        let n = lua_tonumber(l, 1);
        if !(0.0..=1048576.0).contains(&n) {
            lua_error_msg(
                l,
                "Crypto.randomBytes error: size must be between 0 and 1048576 bytes",
            );
        }
        let size = n as usize;
        let mut buf = vec![0u8; size];
        OsRng.fill_bytes(&mut buf);

        lua_pushlstring(l, buf.as_ptr() as *const i8, buf.len());
        1
    }
}

/// Hexadecimal string encode wrapper.
///
/// # Safety
/// Must be invoked by the Luau VM with a valid state pointer.
unsafe extern "C-unwind" fn lua_hex_encode(l: *mut lua_State) -> i32 {
    unsafe {
        let data = get_string_arg(l, 1, "Crypto.hex.encode", "data");
        let encoded = hex::encode(data);
        lua_pushlstring(l, encoded.as_ptr() as *const i8, encoded.len());
        1
    }
}

/// Hexadecimal string decode wrapper.
///
/// # Safety
/// Must be invoked by the Luau VM with a valid state pointer.
unsafe extern "C-unwind" fn lua_hex_decode(l: *mut lua_State) -> i32 {
    unsafe {
        let hex_str = get_string_arg(l, 1, "Crypto.hex.decode", "data");
        match hex::decode(hex_str) {
            Ok(decoded) => {
                lua_pushlstring(l, decoded.as_ptr() as *const i8, decoded.len());
                1
            }
            Err(e) => lua_error_msg(
                l,
                &format!("Crypto.hex.decode error: invalid hex string: {}", e),
            ),
        }
    }
}

/// Base64 string encode wrapper.
///
/// # Safety
/// Must be invoked by the Luau VM with a valid state pointer.
unsafe extern "C-unwind" fn lua_base64_encode(l: *mut lua_State) -> i32 {
    unsafe {
        let data = get_string_arg(l, 1, "Crypto.base64.encode", "data");
        let encoded = BASE64_STANDARD.encode(data);
        lua_pushlstring(l, encoded.as_ptr() as *const i8, encoded.len());
        1
    }
}

/// Base64 string decode wrapper.
///
/// # Safety
/// Must be invoked by the Luau VM with a valid state pointer.
unsafe extern "C-unwind" fn lua_base64_decode(l: *mut lua_State) -> i32 {
    unsafe {
        let base64_str = get_string_arg(l, 1, "Crypto.base64.decode", "data");
        match BASE64_STANDARD.decode(base64_str) {
            Ok(decoded) => {
                lua_pushlstring(l, decoded.as_ptr() as *const i8, decoded.len());
                1
            }
            Err(e) => lua_error_msg(
                l,
                &format!("Crypto.base64.decode error: invalid base64 string: {}", e),
            ),
        }
    }
}

/// Native API Initialization Entrypoint.
///
/// # Safety
/// Must be executed within VM dynamic library linking bounds.
#[unsafe(no_mangle)]
pub unsafe extern "C-unwind" fn luau_export(l: *mut lua_State, api: *const LuauAPI) -> i32 {
    unsafe {
        init_api(api);

        // Primary Crypto module table
        lua_createtable(l, 0, 13);

        // Bind standard hashing algorithms
        lua_pushcfunction(l, lua_md5);
        lua_setfield(l, -2, c"md5".as_ptr());

        lua_pushcfunction(l, lua_sha1);
        lua_setfield(l, -2, c"sha1".as_ptr());

        lua_pushcfunction(l, lua_sha256);
        lua_setfield(l, -2, c"sha256".as_ptr());

        lua_pushcfunction(l, lua_sha384);
        lua_setfield(l, -2, c"sha384".as_ptr());

        lua_pushcfunction(l, lua_sha512);
        lua_setfield(l, -2, c"sha512".as_ptr());

        // Bind HMAC algorithms
        lua_pushcfunction(l, lua_hmac_sha256);
        lua_setfield(l, -2, c"hmacSha256".as_ptr());

        lua_pushcfunction(l, lua_hmac_sha512);
        lua_setfield(l, -2, c"hmacSha512".as_ptr());

        // Bind AES-GCM boundary routines
        lua_pushcfunction(l, lua_encrypt_aes_gcm);
        lua_setfield(l, -2, c"encryptAesGcm".as_ptr());

        lua_pushcfunction(l, lua_decrypt_aes_gcm);
        lua_setfield(l, -2, c"decryptAesGcm".as_ptr());

        // Bind CSPRNG helper
        lua_pushcfunction(l, lua_random_bytes);
        lua_setfield(l, -2, c"randomBytes".as_ptr());

        // Construct nested namespace table: Crypto.hex
        lua_createtable(l, 0, 2);
        lua_pushcfunction(l, lua_hex_encode);
        lua_setfield(l, -2, c"encode".as_ptr());
        lua_pushcfunction(l, lua_hex_decode);
        lua_setfield(l, -2, c"decode".as_ptr());
        lua_setfield(l, -2, c"hex".as_ptr());

        // Construct nested namespace table: Crypto.base64
        lua_createtable(l, 0, 2);
        lua_pushcfunction(l, lua_base64_encode);
        lua_setfield(l, -2, c"encode".as_ptr());
        lua_pushcfunction(l, lua_base64_decode);
        lua_setfield(l, -2, c"decode".as_ptr());
        lua_setfield(l, -2, c"base64".as_ptr());

        // Attach static version signature
        lua_pushstring(l, c"0.1.0".as_ptr());
        lua_setfield(l, -2, c"version".as_ptr());

        1
    }
}
