--!strict

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
local native = SafeLoadNative("@self/lib/".. nativeName) 
    or SafeLoadNative("@self/../../target/release/".. nativeName) 
    or SafeLoadNative("@self/../../target/debug/".. nativeName) 
    or error("Could not load HTTP native library")

-- Types
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

export type AsyncHttpResponse = Signal.Signal<HttpResponse>

export type Http = {
    -- Sync methods
    request: (method: string, url: string, options: HttpRequestOptions?) -> HttpResponse,
    get: (url: string, headers: HttpHeaders?) -> HttpResponse,
    post: (url: string, options: HttpRequestOptions?) -> HttpResponse,
    put: (url: string, options: HttpRequestOptions?) -> HttpResponse,
    delete: (url: string, headers: HttpHeaders?) -> HttpResponse,
    patch: (url: string, options: HttpRequestOptions?) -> HttpResponse,
    head: (url: string, headers: HttpHeaders?) -> HttpResponse,
    
    -- Async methods
    requestAsync: (method: string, url: string, options: HttpRequestOptions?) -> AsyncHttpResponse,
    getAsync: (url: string, headers: HttpHeaders?) -> AsyncHttpResponse,
    postAsync: (url: string, options: HttpRequestOptions?) -> AsyncHttpResponse,
    putAsync: (url: string, options: HttpRequestOptions?) -> AsyncHttpResponse,
    deleteAsync: (url: string, headers: HttpHeaders?) -> AsyncHttpResponse,
     patchAsync: (url: string, options: HttpRequestOptions?) -> AsyncHttpResponse,
     headAsync: (url: string, headers: HttpHeaders?) -> AsyncHttpResponse,
     
     -- Helpers
     urlencodePart: (s: string) -> string,
     urlencode: (data: {[string]: string}) -> string,
     version: string,
}

local Module = {} :: Http

-- Sync methods
function Module.request(method: string, url: string, options: HttpRequestOptions?): HttpResponse
    return native.request(method, url, options)
end

function Module.get(url: string, headers: HttpHeaders?): HttpResponse
    return native.get(url, {headers = headers})
end

function Module.post(url: string, options: HttpRequestOptions?): HttpResponse
    return native.post(url, options)
end

function Module.put(url: string, options: HttpRequestOptions?): HttpResponse
    return native.put(url, options)
end

function Module.delete(url: string, headers: HttpHeaders?): HttpResponse
    return native.delete(url, {headers = headers})
end

function Module.patch(url: string, options: HttpRequestOptions?): HttpResponse
    return native.patch(url, options)
end

function Module.head(url: string, headers: HttpHeaders?): HttpResponse
    return native.head(url, {headers = headers})
end

-- Async methods (using Signal + task.spawn)
local function createAsyncWrapper(syncFn: (...any) -> HttpResponse): (...any) -> AsyncHttpResponse
    return function(...: any): AsyncHttpResponse
        local args = {...}
        local signal = Signal.new() :: Signal.SignalInternal<HttpResponse>
        task.spawn(function()
            local response = syncFn(table.unpack(args))
            signal:Fire(response)
        end)
        return signal:Public()
    end
end

Module.requestAsync = createAsyncWrapper(Module.request)
Module.getAsync = createAsyncWrapper(Module.get)
Module.postAsync = createAsyncWrapper(Module.post)
Module.putAsync = createAsyncWrapper(Module.put)
Module.deleteAsync = createAsyncWrapper(Module.delete)
Module.patchAsync = createAsyncWrapper(Module.patch)
Module.headAsync = createAsyncWrapper(Module.head)

-- Helpers
function Module.urlencodePart(s: string): string
    local encodedString = s:gsub("[^%w%-._~]", function(c)
        return string.format("%%%02X", c:byte())
    end)
    
    return encodedString
end

function Module.urlencode(data: {[string]: string}): string
    local parts = {}
    for key, value in pairs(data) do
        table.insert(parts, Module.urlencodePart(key) .. "=" .. Module.urlencodePart(value))
    end
    return table.concat(parts, "&")
end

Module.version = native.version :: string

return Module
