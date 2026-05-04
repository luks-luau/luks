# Http Module

Native HTTP client module for Luau. Supports HTTP and HTTPS, all standard methods, synchronous and `Signal`-based asynchronous requests, and URL encoding helpers.

## Features

- **HTTP/HTTPS** — Full TLS support via `ureq` + `native-tls`
- **Standard Methods** — GET, POST, PUT, DELETE, PATCH, HEAD
- **Sync & Async** — Sync methods return `HttpResponse` directly; `*Async` variants return a `Signal<HttpResponse>` fired from `task.spawn`
- **URL Helpers** — `urlencode` and `urlencodePart` for building query strings
- **Type Safety** — Full Luau type annotations with LSP/intellisense support

## API Reference

### Types

```lua
-- A map of HTTP header names to values
export type HttpHeaders = { [string]: string }

-- The response returned by all synchronous HTTP methods
export type HttpResponse = {
    status:      number,    -- HTTP status code (e.g. 200, 404)
    status_text: string,    -- HTTP status text (e.g. "OK", "Not Found")
    headers:     HttpHeaders,
    body:        string?,   -- Response body; nil for no-body responses
    ok:          boolean,   -- true when status is 2xx
    error:       string?,   -- Transport-level error description
}

-- Options for request, post, put, patch
export type HttpRequestOptions = {
    headers: HttpHeaders?,  -- Request headers
    body:    string?,       -- Raw request body
    timeout: number?,       -- Timeout in seconds (default: 30)
}

-- Signal fired by *Async methods when the response arrives
export type AsyncHttpResponse = Signal<HttpResponse>
```

### Sync Methods

#### `Http.request(method, url, options?) → HttpResponse`
Generic request with a custom HTTP method.

#### `Http.get(url, headers?) → HttpResponse`
GET request.

#### `Http.post(url, options?) → HttpResponse`
POST request.

#### `Http.put(url, options?) → HttpResponse`
PUT request.

#### `Http.delete(url, headers?) → HttpResponse`
DELETE request.

#### `Http.patch(url, options?) → HttpResponse`
PATCH request.

#### `Http.head(url, headers?) → HttpResponse`
HEAD request (response has no body).

### Async Methods

Each sync method has an `*Async` variant that runs the request in a background thread via `task.spawn` and returns a `Signal<HttpResponse>`. Connect a callback before the request completes:

- `Http.requestAsync(method, url, options?)`
- `Http.getAsync(url, headers?)`
- `Http.postAsync(url, options?)`
- `Http.putAsync(url, options?)`
- `Http.deleteAsync(url, headers?)`
- `Http.patchAsync(url, options?)`
- `Http.headAsync(url, headers?)`

### URL Helpers

#### `Http.urlencodePart(s: string) → string`
Percent-encodes a single string component. Encodes everything except `A-Z a-z 0-9 - . _ ~`.

#### `Http.urlencode(data: { [string]: string }) → string`
Encodes a key→value table as a URL query string (without the leading `?`).

### `Http.version: string`
Native library version string.

---

## Usage

### GET request

```lua
local Http = require("@std/Http")

local response = Http.get("https://httpbin.org/get", {
    ["Accept"] = "application/json",
})

if response.ok then
    print("Status:", response.status)
    print("Body:",   response.body)
else
    print("Error:", response.error or response.status_text)
end
```

### POST with JSON body

```lua
local Http = require("@std/Http")
local Json = require("@std/Json")

local response = Http.post("https://httpbin.org/post", {
    headers = { ["Content-Type"] = "application/json" },
    body    = Json.encode({ name = "luks", level = 5 }),
    timeout = 10,
})

if response.ok then
    local data = Json.decode(response.body)
    print("Echoed name:", data.json.name)
end
```

### Generic request

```lua
local response = Http.request("DELETE", "https://api.example.com/items/42", {
    headers = { ["Authorization"] = "Bearer TOKEN" },
})
print(response.status) -- 204
```

### Async request (Signal-based)

```lua
local Http = require("@std/Http")

-- Connect a callback before the response arrives
local sig = Http.getAsync("https://httpbin.org/delay/1")
sig:Connect(function(response)
    print("Async response:", response.status, response.body)
end)

-- Or block-wait in a spawned thread
task.spawn(function()
    local response = Http.getAsync("https://httpbin.org/get"):Wait()
    print("Waited:", response.status)
end)
```

### URL encoding

```lua
local Http = require("@std/Http")

-- Encode individual components
print(Http.urlencodePart("hello world")) -- "hello%20world"
print(Http.urlencodePart("a=1&b=2"))    -- "a%3D1%26b%3D2"

-- Build a full query string
local qs = Http.urlencode({ q = "luau lang", page = "1" })
local url = "https://search.example.com/?" .. qs
print(url) -- https://search.example.com/?q=luau%20lang&page=1
```

---

## Building

```bash
cd luks-std/Http
cargo build --release
```

Output locations:
- **Windows**: `target/release/http.dll`
- **Linux**: `target/release/libhttp.so`
- **macOS**: `target/release/libhttp.dylib`

Copy to `lib/` for deployment:
```bash
# Windows
copy target\release\http.dll lib\
```

---

## Dependencies

- **Rust**: `ureq` (HTTP client with TLS support via `native-tls`)
- **Luau Modules**: `Signal` (for async operations)
- **Luau VM**: Built-in `task` scheduler and `dlopen` function

## License

MIT License — see [LICENSE](LICENSE) file for details.
