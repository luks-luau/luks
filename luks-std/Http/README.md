# Http Module

Native HTTP client module for Luau with sync/async support, HTTP/HTTPS compatibility, and integration with Luau's `task` scheduler and `Signal` module.

## Features

- **HTTP/HTTPS Support**: Full support for HTTP and HTTPS requests via `ureq` Rust crate with TLS
- **Sync & Async Operations**: Synchronous requests via native bindings, asynchronous requests using `task.spawn` and `Signal`
- **Standard HTTP Methods**: GET, POST, PUT, DELETE, PATCH, HEAD
- **Type Safety**: Full Luau type annotations with generic `Signal<T>` integration for async responses
- **Intellisense Support**: JSDoc-style documentation compatible with Luau LSP tools
- **Helper Functions**: Built-in JSON encoding and URL encoding utilities

## API Reference

### Types

```lua
export type HttpHeaders = {[string]: string}

export type HttpResponse = {
    status: number,
    status_text: string,
    headers: HttpHeaders,
    body: string?,
    ok: boolean,
    error: string?,
}

export type HttpRequestOptions = {
    headers: HttpHeaders?,
    body: string?,
    timeout: number?,
}

export type AsyncHttpResponse = Signal<HttpResponse>
```

### Sync Methods

#### `Http.request(method: string, url: string, options?: HttpRequestOptions): HttpResponse`
Generic HTTP request with custom method.

#### `Http.get(url: string, headers?: HttpHeaders): HttpResponse`
GET request.

#### `Http.post(url: string, options?: HttpRequestOptions): HttpResponse`
POST request.

#### `Http.put(url: string, options?: HttpRequestOptions): HttpResponse`
PUT request.

#### `Http.delete(url: string, headers?: HttpHeaders): HttpResponse`
DELETE request.

#### `Http.patch(url: string, options?: HttpRequestOptions): HttpResponse`
PATCH request.

#### `Http.head(url: string, headers?: HttpHeaders): HttpResponse`
HEAD request.

### Async Methods (Return `Signal<HttpResponse>`)

All async methods wrap sync calls with `task.spawn` and return a public `Signal` that fires with the `HttpResponse` when complete:

- `Http.requestAsync(...)`
- `Http.getAsync(...)`
- `Http.postAsync(...)`
- `Http.putAsync(...)`
- `Http.deleteAsync(...)`
- `Http.patchAsync(...)`
- `Http.headAsync(...)`

### Helpers

#### `Http.json(data: any): string`
Encodes Lua data to JSON string using Luau's built-in `json.encode`.

#### `Http.urlencode(data: {[string]: string}): string`
URL-encodes a key-value table into a query string format.

## Usage

### Synchronous Requests

```lua
local Http = require("@std/Http")

-- GET request
local response = Http.get("https://api.example.com/users")
if response.ok then
    print("Users:", response.body)
else
    print("Error:", response.error or response.status_text)
end

-- POST with JSON body
local postResponse = Http.post("https://api.example.com/users", {
    headers = {["Content-Type"] = "application/json"},
    body = Http.json({name = "John", age = 30})
})
```

### Asynchronous Requests (Using Signal)

```lua
local Http = require("@std/Http")

-- Async GET
local responseSignal = Http.getAsync("https://api.example.com/data")

-- Wait for response (blocks current thread)
task.spawn(function()
    local response = responseSignal:Wait()
    if response.ok then
        print("Async GET success:", response.body)
    end
end)

-- Or connect a callback
responseSignal:Connect(function(response)
    if response.ok then
        print("Received data:", response.body)
    end
end)
```

## Building the Native Library

1. Navigate to the `Http` directory:
   ```bash
   cd luks-std/Http
   ```

2. Build the release version:
   ```bash
   cargo build --release
   ```

3. The native library will be generated at:
   - Windows: `target/release/http.dll`
   - Linux: `target/release/libhttp.so`
   - macOS: `target/release/libhttp.dylib`

4. Copy the library to the `lib/` directory for deployment:
   ```bash
   # Windows
   copy target\release\http.dll lib\
   ```

## Dependencies

- **Rust Crate**: `ureq` (HTTP client with TLS support)
- **Luau Modules**: `Signal` (for async operations)
- **Luau VM**: Built-in `task` scheduler, `json` library, `dlopen` function

## License

MIT License - see [LICENSE](LICENSE) file for details.
