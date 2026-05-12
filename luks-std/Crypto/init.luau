--!strict

--[[
    Crypto Module — High-performance native Cryptographic functions for Luau.
    Delivers standard hashing digests, HMAC authentication, secure AES-GCM 
    authenticated encryption, CSPRNG randomness, and custom hex/base64 namespaces.

    Errors are raised as Lua runtime errors and can be caught with pcall:
        local ok, ciphertext = pcall(Crypto.encryptAesGcm, key, nonce, data)
        local ok, plaintext = pcall(Crypto.decryptAesGcm, key, nonce, encryptedData)
]]

local SafeLoadNative = function(path: string)
    local success, native = pcall(dlopen, path)
    if success then
        return native
    else
        return nil
    end
end

local nativeName = "crypto"
local native = SafeLoadNative("@self/lib/" .. nativeName)
    or SafeLoadNative("@self/../../target/release/" .. nativeName)
    or SafeLoadNative("@self/../../target/debug/" .. nativeName)
    or error("Could not load Crypto native library")

-- ---------------------------------------------------------------------------
-- Module
-- ---------------------------------------------------------------------------

local Crypto = {}

--[[
    Computes an MD5 hash digest.

    @param data The payload string to digest.
    @param raw  Optional flag to return raw bytes instead of a hex string.
    @return     The digested hash string.
]]
function Crypto.md5(data: string, raw: boolean?): string
    return native.md5(data, raw)
end

--[[
    Computes a SHA-1 hash digest.

    @param data The payload string to digest.
    @param raw  Optional flag to return raw bytes instead of a hex string.
    @return     The digested hash string.
]]
function Crypto.sha1(data: string, raw: boolean?): string
    return native.sha1(data, raw)
end

--[[
    Computes a SHA-256 hash digest.

    @param data The payload string to digest.
    @param raw  Optional flag to return raw bytes instead of a hex string.
    @return     The digested hash string.
]]
function Crypto.sha256(data: string, raw: boolean?): string
    return native.sha256(data, raw)
end

--[[
    Computes a SHA-384 hash digest.

    @param data The payload string to digest.
    @param raw  Optional flag to return raw bytes instead of a hex string.
    @return     The digested hash string.
]]
function Crypto.sha384(data: string, raw: boolean?): string
    return native.sha384(data, raw)
end

--[[
    Computes a SHA-512 hash digest.

    @param data The payload string to digest.
    @param raw  Optional flag to return raw bytes instead of a hex string.
    @return     The digested hash string.
]]
function Crypto.sha512(data: string, raw: boolean?): string
    return native.sha512(data, raw)
end

--[[
    Computes an HMAC-SHA256 message authentication code.

    @param key  The secret signature key.
    @param data The raw message data to authenticate.
    @param raw  Optional flag to return raw bytes instead of a hex string.
    @return     The computed HMAC signature.
]]
function Crypto.hmacSha256(key: string, data: string, raw: boolean?): string
    return native.hmacSha256(key, data, raw)
end

--[[
    Computes an HMAC-SHA512 message authentication code.

    @param key  The secret signature key.
    @param data The raw message data to authenticate.
    @param raw  Optional flag to return raw bytes instead of a hex string.
    @return     The computed HMAC signature.
]]
function Crypto.hmacSha512(key: string, data: string, raw: boolean?): string
    return native.hmacSha512(key, data, raw)
end

--[[
    Performs authenticated symmetric encryption using AES-GCM.
    Accepts keys of precisely 16 bytes (AES-128) or 32 bytes (AES-256).
    The nonce/IV string must be precisely 12 bytes.

    @param key   The symmetric cryptographic key.
    @param nonce The unique initialization vector (12 bytes).
    @param data  The raw plaintext payload to encrypt.
    @param aad   Optional Additional Authenticated Data string.
    @return      The encrypted ciphertext envelope containing embedded auth tags.
]]
function Crypto.encryptAesGcm(key: string, nonce: string, data: string, aad: string?): string
    return native.encryptAesGcm(key, nonce, data, aad)
end

--[[
    Decrypts an authenticated AES-GCM ciphertext stream back to plaintext.
    Verifies authentication tags before returning the output. Raises a Lua error 
    if the payload has been tampered with or if the key/nonce is invalid.

    @param key            The symmetric cryptographic key.
    @param nonce          The unique initialization vector (12 bytes).
    @param encrypted_data The ciphertext buffer to restore.
    @param aad            Optional Additional Authenticated Data string.
    @return               The uncompressed, fully authenticated original plaintext.
]]
function Crypto.decryptAesGcm(key: string, nonce: string, encrypted_data: string, aad: string?): string
    return native.decryptAesGcm(key, nonce, encrypted_data, aad)
end

--[[
    Generates a string populated with cryptographically secure pseudorandom numbers.

    @param size The byte length array size requested.
    @return     A secure random byte string buffer.
]]
function Crypto.randomBytes(size: number): string
    return native.randomBytes(size)
end

--[[
    Hexadecimal String Namespace.
]]
Crypto.hex = {
    --[[
        Encodes a string or byte sequence into a lowercase hexadecimal string.

        @param data The raw payload buffer.
        @return     The encoded hexadecimal string.
    ]]
    encode = function(data: string): string
        return native.hex.encode(data)
    end,

    --[[
        Decodes a hexadecimal string back to raw bytes. Raises an error on malformed inputs.

        @param hex_str The hexadecimal string.
        @return        The decoded raw byte string.
    ]]
    decode = function(hex_str: string): string
        return native.hex.decode(hex_str)
    end,
}

--[[
    Base64 String Namespace.
]]
Crypto.base64 = {
    --[[
        Encodes a string or byte sequence into standard Base64 format.

        @param data The raw payload buffer.
        @return     The encoded Base64 string.
    ]]
    encode = function(data: string): string
        return native.base64.encode(data)
    end,

    --[[
        Decodes a standard Base64 string back to raw bytes. Raises an error on invalid strings.

        @param base64_str The Base64 string.
        @return           The decoded raw byte string.
    ]]
    decode = function(base64_str: string): string
        return native.base64.decode(base64_str)
    end,
}

--[[ Native library version string. ]]
Crypto.version = native.version :: string

return Crypto
