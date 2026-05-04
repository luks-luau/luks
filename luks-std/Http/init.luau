--!strict

--[[
    Http Module — Native HTTP client for Luau.
    Supports GET, POST, PUT, DELETE, PATCH, HEAD via both synchronous and
    Signal-based asynchronous variants. Built on top of `ureq` under the hood.

    Sync methods block the current thread and return an `HttpResponse` directly.
    Async methods (`*Async`) return a `Signal<HttpResponse>` that fires once the
    response arrives, running the request inside `task.spawn`.
]]

local Signal = require("@self/../Signal")

local SafeLoadNative = function(path: string)
    local success, native = pcall(dlopen, path)
    if success then
        return native
    else
        return nil
    end
end

local nativeName = "http"
local native = SafeLoadNative("@self/lib/" .. nativeName)
    or SafeLoadNative("@self/../../target/release/" .. nativeName)
    or SafeLoadNative("@self/../../target/debug/" .. nativeName)
    or error("Could not load HTTP native library")

-- ---------------------------------------------------------------------------
-- Public Types
-- ---------------------------------------------------------------------------

--[[
    A map of HTTP header names to header values.
    Example: `{ ["Content-Type"] = "application/json", ["Accept"] = "*/*" }`
]]
export type HttpHeaders = { [string]: string }

--[[
    The response returned by all synchronous HTTP methods.
]]
export type HttpResponse = {
    --[[ HTTP status code (e.g. 200, 404, 500). ]]
    status: number,
    --[[ HTTP status text (e.g. "OK", "Not Found"). ]]
    status_text: string,
    --[[ Response headers as a key→value map. ]]
    headers: HttpHeaders,
    --[[ Response body as a raw string. `nil` for responses with no body. ]]
    body: string?,
    --[[ `true` when status is in the 2xx range. ]]
    ok: boolean,
    --[[ Human-readable error description when the request fails at the transport level. ]]
    error: string?,
}

--[[
    Options accepted by `request`, `post`, `put`, and `patch`.
]]
export type HttpRequestOptions = {
    --[[ HTTP headers to include in the request. ]]
    headers: HttpHeaders?,
    --[[ Raw request body string. ]]
    body: string?,
    --[[ Request timeout in seconds. Default: 30. ]]
    timeout: number?,
}

--[[
    A `Signal<HttpResponse>` returned by the `*Async` methods.
    Connect a callback before the signal fires to receive the response:
        local sig = Http.getAsync("https://...")
        sig:Connect(function(response) print(response.body) end)
]]
export type AsyncHttpResponse = Signal.Signal<HttpResponse>

-- ---------------------------------------------------------------------------
-- Module
-- ---------------------------------------------------------------------------

--[[
    Http Module — provides HTTP client functionality with sync and async variants.
]]
local Http = {}

-- ---------------------------------------------------------------------------
-- Synchronous methods
-- ---------------------------------------------------------------------------

--[[
    Sends an HTTP request with a custom method.

    @param method   HTTP method string (e.g. `"GET"`, `"POST"`, `"DELETE"`).
    @param url      Full URL to request.
    @param options  Optional request options (headers, body, timeout).
    @return         `HttpResponse` with status, headers, and body.

    @example
        local res = Http.request("GET", "https://httpbin.org/get")
        print(res.status, res.body)
]]
function Http.request(method: string, url: string, options: HttpRequestOptions?): HttpResponse
    return native.request(method, url, options)
end

--[[
    Sends an HTTP GET request.

    @param url      Full URL to request.
    @param headers  Optional headers map.
    @return         `HttpResponse`.

    @example
        local res = Http.get("https://httpbin.org/get", { ["Accept"] = "application/json" })
        print(res.ok, res.status)
]]
function Http.get(url: string, headers: HttpHeaders?): HttpResponse
    return native.get(url, { headers = headers })
end

--[[
    Sends an HTTP POST request.

    @param url      Full URL to request.
    @param options  Optional request options (headers, body, timeout).
    @return         `HttpResponse`.

    @example
        local res = Http.post("https://httpbin.org/post", {
            headers = { ["Content-Type"] = "application/json" },
            body    = Json.encode({ key = "value" }),
        })
]]
function Http.post(url: string, options: HttpRequestOptions?): HttpResponse
    return native.post(url, options)
end

--[[
    Sends an HTTP PUT request.

    @param url      Full URL to request.
    @param options  Optional request options (headers, body, timeout).
    @return         `HttpResponse`.
]]
function Http.put(url: string, options: HttpRequestOptions?): HttpResponse
    return native.put(url, options)
end

--[[
    Sends an HTTP DELETE request.

    @param url      Full URL to request.
    @param headers  Optional headers map.
    @return         `HttpResponse`.
]]
function Http.delete(url: string, headers: HttpHeaders?): HttpResponse
    return native.delete(url, { headers = headers })
end

--[[
    Sends an HTTP PATCH request.

    @param url      Full URL to request.
    @param options  Optional request options (headers, body, timeout).
    @return         `HttpResponse`.
]]
function Http.patch(url: string, options: HttpRequestOptions?): HttpResponse
    return native.patch(url, options)
end

--[[
    Sends an HTTP HEAD request (response has no body).

    @param url      Full URL to request.
    @param headers  Optional headers map.
    @return         `HttpResponse` (body will be `nil`).
]]
function Http.head(url: string, headers: HttpHeaders?): HttpResponse
    return native.head(url, { headers = headers })
end

-- ---------------------------------------------------------------------------
-- Asynchronous methods (Signal-based, run inside task.spawn)
-- ---------------------------------------------------------------------------

--[[
    Internal helper: wraps a sync HTTP function so it runs in a background thread
    and fires a Signal once the response is ready.
]]
local function createAsyncWrapper(syncFn: (...any) -> HttpResponse): (...any) -> AsyncHttpResponse
    return function(...: any): AsyncHttpResponse
        local args = { ... }
        local signal = Signal.new() :: Signal.SignalInternal<HttpResponse>
        task.spawn(function()
            local response = syncFn(table.unpack(args))
            signal:Fire(response)
        end)
        return signal:Public()
    end
end

--[[
    Async variant of `Http.request`. Returns a `Signal<HttpResponse>` that fires
    when the response arrives. Connect before the request completes:
        local sig = Http.requestAsync("GET", "https://...")
        sig:Connect(function(res) print(res.status) end)
]]
Http.requestAsync = createAsyncWrapper(Http.request)

--[[
    Async variant of `Http.get`. Returns `Signal<HttpResponse>`.
    @see Http.get
]]
Http.getAsync = createAsyncWrapper(Http.get)

--[[
    Async variant of `Http.post`. Returns `Signal<HttpResponse>`.
    @see Http.post
]]
Http.postAsync = createAsyncWrapper(Http.post)

--[[
    Async variant of `Http.put`. Returns `Signal<HttpResponse>`.
    @see Http.put
]]
Http.putAsync = createAsyncWrapper(Http.put)

--[[
    Async variant of `Http.delete`. Returns `Signal<HttpResponse>`.
    @see Http.delete
]]
Http.deleteAsync = createAsyncWrapper(Http.delete)

--[[
    Async variant of `Http.patch`. Returns `Signal<HttpResponse>`.
    @see Http.patch
]]
Http.patchAsync = createAsyncWrapper(Http.patch)

--[[
    Async variant of `Http.head`. Returns `Signal<HttpResponse>`.
    @see Http.head
]]
Http.headAsync = createAsyncWrapper(Http.head)

-- ---------------------------------------------------------------------------
-- Utility helpers
-- ---------------------------------------------------------------------------

--[[
    Percent-encodes a single string component for use in a URL query string.
    Encodes all characters except unreserved ones (`A-Z a-z 0-9 - . _ ~`).

    @param s  The string to encode.
    @return   The percent-encoded string.

    @example
        Http.urlencodePart("hello world") -- "hello%20world"
        Http.urlencodePart("a=b&c=d")     -- "a%3Db%26c%3Dd"
]]
function Http.urlencodePart(s: string): string
    return s:gsub("[^%w%-._~]", function(c)
        return string.format("%%%02X", c:byte())
    end)
end

--[[
    Encodes a key→value table as a URL query string.
    Keys and values are each percent-encoded and joined with `&`.

    @param data  A `{ [string]: string }` table of query parameters.
    @return      A URL-encoded query string (without the leading `?`).

    @example
        Http.urlencode({ name = "luks", level = "5" })
        -- "name=luks&level=5"
]]
function Http.urlencode(data: { [string]: string }): string
    local parts = {}
    for key, value in pairs(data) do
        table.insert(parts, Http.urlencodePart(key) .. "=" .. Http.urlencodePart(value))
    end
    return table.concat(parts, "&")
end

--[[ Native library version. ]]
Http.version = native.version :: string

return Http
