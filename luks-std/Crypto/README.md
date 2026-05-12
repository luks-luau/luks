# Crypto Module

Native Cryptographic client module for Luau. Delivers high-performance binary string operations including message digests, hash authentication codes, authenticated symmetric envelope stream cryptography, pseudorandom byte generation, and string translation namespaces utilizing the **RustCrypto** runtime engine.

## Features

- **Message Digests** — High-speed implementations of MD5, SHA-1, SHA-256, SHA-384, and SHA-512 standard algorithms
- **Message Authentication** — Secure generation of Hash-based Message Authentication Codes (HMAC-SHA256, HMAC-SHA512)
- **Authenticated Encryption** — Advanced **AES-GCM** (Galois/Counter Mode) streams delivering validated data confidentiality and payload integrity checks without padding manipulation
- **Secure Randomness** — Operating system kernel source cryptographic sequence allocations (`OsRng`) via the CSPRNG interface
- **Translation Namespaces** — Dedicated submodules (`Crypto.hex`, `Crypto.base64`) exposing uniform string transformation methods
- **Type Safety** — Comprehensive Luau static definitions complete with LSP hover intellisense documentation

## API Reference

### Hashing Methods

#### `Crypto.md5(data: string, raw: boolean?) → string`
#### `Crypto.sha1(data: string, raw: boolean?) → string`
#### `Crypto.sha256(data: string, raw: boolean?) → string`
#### `Crypto.sha384(data: string, raw: boolean?) → string`
#### `Crypto.sha512(data: string, raw: boolean?) → string`
Computes the specified standard message digest. Returns a lowercase hexadecimal string by default, or raw binary streams when `raw` is passed as `true`.

### Authentication Methods

#### `Crypto.hmacSha256(key: string, data: string, raw: boolean?) → string`
#### `Crypto.hmacSha512(key: string, data: string, raw: boolean?) → string`
Generates a secret-key authenticated message string. Raises runtime validation faults if the parameter array is malformed.

### Symmetric Encryption

#### `Crypto.encryptAesGcm(key: string, nonce: string, data: string, aad: string?) → string`
Wraps the raw plaintext string buffer inside an authenticated envelope ciphertext containing trailing authentication validation tags.
- `key`: Exactly 16 bytes (AES-128) or 32 bytes (AES-256).
- `nonce`: Exactly 12 bytes.

#### `Crypto.decryptAesGcm(key: string, nonce: string, encrypted_data: string, aad: string?) → string`
Expands the target ciphertext payload string, verifying transport authentication tags before plaintext evaluation. Dispara uma falha nativa if the data stream has been manipulated or if the key signature fails.

### Secure Pseudorandomness

#### `Crypto.randomBytes(size: number) → string`
Allocates a byte array buffer populated with cryptographically secure random values bounded to kernel allocation pools.

### Translation Namespaces

#### `Crypto.hex.encode(data: string) → string`
#### `Crypto.hex.decode(hex_str: string) → string`
Translates strings or byte sequences into and out of lowercase hexadecimal text formats.

#### `Crypto.base64.encode(data: string) → string`
#### `Crypto.base64.decode(base64_str: string) → string`
Translates strings or byte sequences into and out of standard RFC 4648 Base64 text formats.

### Properties

#### `Crypto.version: string`
The runtime dynamic module compilation version string.

---

## Usage

### Password Hashing

```lua
local Crypto = require("path/to/Crypto")

local password = "SuperSecretPassword123!"
local salt = Crypto.randomBytes(16)

-- Mix the salt and password buffers to compute a SHA-256 secure digest
local digest = Crypto.sha256(salt .. password)
print("Hexadecimal Digest Output:", digest)
```

### Symmetric Authenticated Envelope

```lua
local Crypto = require("path/to/Crypto")

-- Generate secure symmetric keys and unique nonces
local key = Crypto.randomBytes(32)   -- AES-256 requires 32 bytes
local nonce = Crypto.randomBytes(12) -- AES-GCM requires 12 bytes
local secretMessage = "Confidential business payload stream data."

-- Encrypt payload stream
local ciphertext = Crypto.encryptAesGcm(key, nonce, secretMessage)
print("Encrypted stream length:", #ciphertext)

-- Safely restore stream payload wrapping operations in pcall blocks
local success, plaintext = pcall(Crypto.decryptAesGcm, key, nonce, ciphertext)
if success then
    print("Decrypted plaintext perfectly restored:", plaintext)
else
    print("Decryption authentication fault intercepted.")
end
```

### Namespace Translation conversions

```lua
local Crypto = require("path/to/Crypto")

local buffer = "Luau runtime binary translations."

local b64 = Crypto.base64.encode(buffer)
local hex = Crypto.hex.encode(buffer)

print("Base64 text format:", b64)
print("Hexadecimal text format:", hex)

assert(Crypto.base64.decode(b64) == buffer)
assert(Crypto.hex.decode(hex) == buffer)
```

---

## Building

```bash
cd luks-std/Crypto
cargo build --release
```

Output execution binary paths:
- **Windows**: `target/release/crypto.dll`
- **Linux**: `target/release/libcrypto.so`
- **macOS**: `target/release/libcrypto.dylib`

---

## Dependencies

- **Rust**: `sha2`, `md-5`, `sha1`, `hmac`, `aes-gcm`, `hex`, `base64`, `rand`
- **Luau Interface**: Pure dynamic library VTable bindings via `luks-module-sys`

## License

MIT License — see [LICENSE](LICENSE) file for details.
