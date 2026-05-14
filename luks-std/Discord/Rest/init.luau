--!strict
--!native
--!optimize 2

--[[
    Rest Layer — Internal HTTP API Dispatcher for luks-std/Discord.
    Abstracts authentication headers, JSON payload serialization, and robust routing.
]]

local Http = require("../Http")
local Json = require("../Json")
local Data = require("Data")

export type RestClient = {
    -- Weak application client host reference
    _client: any,
    
    --[[
        Executes a signed customized HTTP request against target API destinations.
        @param self The rest client instance
        @param method The uppercase HTTP method (GET, POST, PATCH, DELETE, PUT)
        @param path The absolute URL or relative Discord API path route
        @param options Optional parameter block holding request body payloads and header mappings
        @return Success status boolean alongside decoded response tables or failure descriptions
    ]]
    request: (self: RestClient, method: string, path: string, options: { body: any?, headers: { [string]: string }? }?) -> (boolean, any),
    
    --[[
        Executes a standard HTTP GET request against the destination endpoint.
        @param self The rest client instance
        @param path Relative or absolute endpoint routing path
        @param headers Optional explicit table of additional request headers
        @return Success condition boolean alongside decoded payload contents
    ]]
    get: (self: RestClient, path: string, headers: { [string]: string }?) -> (boolean, any),
    
    --[[
        Executes a standard HTTP POST request submitting data payloads.
        @param self The rest client instance
        @param path Relative or absolute endpoint routing path
        @param body Data content string or table structure to encode
        @param headers Optional explicit table of additional request headers
        @return Success condition boolean alongside decoded payload contents
    ]]
    post: (self: RestClient, path: string, body: any?, headers: { [string]: string }?) -> (boolean, any),
    
    --[[
        Executes a standard HTTP PATCH request updating remote resources.
        @param self The rest client instance
        @param path Relative or absolute endpoint routing path
        @param body Data content string or table structure to encode
        @param headers Optional explicit table of additional request headers
        @return Success condition boolean alongside decoded payload contents
    ]]
    patch: (self: RestClient, path: string, body: any?, headers: { [string]: string }?) -> (boolean, any),
    
    --[[
        Executes a standard HTTP DELETE request targeting a remote resource.
        @param self The rest client instance
        @param path Relative or absolute endpoint routing path
        @param headers Optional explicit table of additional request headers
        @return Success condition boolean alongside decoded payload contents
    ]]
    delete: (self: RestClient, path: string, headers: { [string]: string }?) -> (boolean, any),
    
    --[[
        Executes a standard HTTP PUT request overwriting destination configurations.
        @param self The rest client instance
        @param path Relative or absolute endpoint routing path
        @param body Data content string or table structure to encode
        @param headers Optional explicit table of additional request headers
        @return Success condition boolean alongside decoded payload contents
    ]]
    put: (self: RestClient, path: string, body: any?, headers: { [string]: string }?) -> (boolean, any),
}

local Rest = {}
local RestMT = {}
RestMT.__index = RestMT

--[[
    Initializes a new Rest interface layer tied to the primary Client scope.
    @param client Base client framework object containing authorized credentials
    @return A new RestClient interface instance
]]
function Rest.new(client: any): RestClient
    local self = {
        _client = client,
    }
    setmetatable(self, RestMT)
    return (self :: any) :: RestClient
end

--[[
    Executes a signed customized HTTP request against target API destinations.
    @param self The rest client instance
    @param method The uppercase HTTP method (GET, POST, PATCH, DELETE, PUT)
    @param path The absolute URL or relative Discord API path route
    @param options Optional parameter block holding request body payloads and header mappings
    @return Success status boolean alongside decoded response tables or failure descriptions
]]
function RestMT:request(method: string, path: string, options: { body: any?, headers: { [string]: string }? }?): (boolean, any)
    local token = self._client and self._client.token
    if not token then
        return false, "No authentication token configured on Client for HTTP authorization."
    end

    -- Intelligent base URL resolution
    local url = path
    if not string.find(url, "^https?://") then
        url = Data.Constants.BaseUrl .. (string.sub(path, 1, 1) == "/" and "" or "/") .. path
    end

    local opts = (options or {}) :: { body: any?, headers: { [string]: string }? }
    local reqHeaders = {
        ["Authorization"] = "Bot " .. token,
        ["User-Agent"] = "DiscordBot (https://github.com/luks-luau/luks, 1.0.0)",
    }

    if opts.headers then
        for k, v in pairs(opts.headers) do
            reqHeaders[k] = v
        end
    end

    local reqBody: string? = nil
    if opts.body ~= nil then
        if type(opts.body) == "table" then
            -- Automatic serialization of tables to JSON
            local ok, encoded = pcall(Json.encode, opts.body)
            if not ok then
                return false, "Failed to serialize request body to JSON: " .. tostring(encoded)
            end
            reqBody = encoded
            reqHeaders["Content-Type"] = "application/json"
        elseif type(opts.body) == "string" then
            reqBody = opts.body
            if not reqHeaders["Content-Type"] then
                reqHeaders["Content-Type"] = "application/json"
            end
        else
            reqBody = tostring(opts.body)
        end
    end

    -- Robust execution on the runtime thread via pcall
    local ok, res = pcall(function()
        local httpMethod = string.upper(method)
        if httpMethod == "GET" then
            return Http.get(url, reqHeaders)
        elseif httpMethod == "POST" then
            return Http.post(url, { headers = reqHeaders, body = reqBody or "" })
        elseif httpMethod == "DELETE" then
            -- Native Http accepts the headers map directly on delete
            return Http.delete(url, reqHeaders)
        elseif httpMethod == "PATCH" then
            -- Fallback mapping if native patch method is unavailable
            if (Http :: any).patch then
                return (Http :: any).patch(url, { headers = reqHeaders, body = reqBody or "" })
            else
                -- Override method via POST if native engine restricts additional verbs
                reqHeaders["X-HTTP-Method-Override"] = "PATCH"
                return Http.post(url, { headers = reqHeaders, body = reqBody or "" })
            end
        elseif httpMethod == "PUT" then
            if (Http :: any).put then
                return (Http :: any).put(url, { headers = reqHeaders, body = reqBody or "" })
            else
                reqHeaders["X-HTTP-Method-Override"] = "PUT"
                return Http.post(url, { headers = reqHeaders, body = reqBody or "" })
            end
        else
            return Http.get(url, reqHeaders)
        end
    end)

    if not ok or not res then
        return false, "HTTP socket I/O failure while communicating with REST API: " .. tostring(res)
    end

    -- Successful status response (2xx)
    if res.status and res.status >= 200 and res.status < 300 then
        if not res.body or res.body == "" then
            return true, {}
        end
        
        -- Attempt automatic JSON decoding
        local decOk, decoded = pcall(Json.decode, res.body)
        if decOk and decoded then
            return true, decoded
        else
            -- Return raw text body if endpoint serves plaintext instead of JSON
            return true, res.body
        end
    else
        -- Attempt extracting error message payload from Discord API
        local errMsg = "HTTP Error " .. tostring(res.status)
        if res.body and res.body ~= "" then
            local decOk, decoded = pcall(Json.decode, res.body)
            if decOk and decoded and decoded.message then
                errMsg = errMsg .. ": " .. tostring(decoded.message)
            else
                errMsg = errMsg .. " (" .. tostring(res.body) .. ")"
            end
        end
        return false, errMsg
    end
end

--[[
    Executes a standard HTTP GET request against the destination endpoint.
    @param path Relative or absolute endpoint routing path
    @param headers Optional explicit table of additional request headers
    @return Success condition boolean alongside decoded payload contents
]]
function RestMT:get(path: string, headers: { [string]: string }?): (boolean, any)
    return self:request("GET", path, { headers = headers })
end

--[[
    Executes a standard HTTP POST request submitting data payloads.
    @param path Relative or absolute endpoint routing path
    @param body Data content string or table structure to encode
    @param headers Optional explicit table of additional request headers
    @return Success condition boolean alongside decoded payload contents
]]
function RestMT:post(path: string, body: any?, headers: { [string]: string }?): (boolean, any)
    return self:request("POST", path, { body = body, headers = headers })
end

--[[
    Executes a standard HTTP PATCH request updating remote resources.
    @param path Relative or absolute endpoint routing path
    @param body Data content string or table structure to encode
    @param headers Optional explicit table of additional request headers
    @return Success condition boolean alongside decoded payload contents
]]
function RestMT:patch(path: string, body: any?, headers: { [string]: string }?): (boolean, any)
    return self:request("PATCH", path, { body = body, headers = headers })
end

--[[
    Executes a standard HTTP DELETE request targeting a remote resource.
    @param path Relative or absolute endpoint routing path
    @param headers Optional explicit table of additional request headers
    @return Success condition boolean alongside decoded payload contents
]]
function RestMT:delete(path: string, headers: { [string]: string }?): (boolean, any)
    return self:request("DELETE", path, { headers = headers })
end

--[[
    Executes a standard HTTP PUT request overwriting destination configurations.
    @param path Relative or absolute endpoint routing path
    @param body Data content string or table structure to encode
    @param headers Optional explicit table of additional request headers
    @return Success condition boolean alongside decoded payload contents
]]
function RestMT:put(path: string, body: any?, headers: { [string]: string }?): (boolean, any)
    return self:request("PUT", path, { body = body, headers = headers })
end

table.freeze(RestMT)
table.freeze(Rest)
return Rest
