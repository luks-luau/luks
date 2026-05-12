--!strict

--[[
    Rest Layer — Internal HTTP API Dispatcher for luks-std/Discord.
    Abstracts authentication headers, JSON payload serialization, and robust routing.
]]

local Http = require("../Http")
local Json = require("../Json")
local Data = require("Data")

export type RestClient = {
    _client: any, -- Referência fraca/abstrata à instância de Client principal
    
    --[[ Executa uma requisição HTTP customizada. ]]
    request: (self: RestClient, method: string, path: string, options: { body: any?, headers: { [string]: string }? }?) -> (boolean, any),
    
    --[[ Helpers de atalho para métodos HTTP padronizados ]]
    get: (self: RestClient, path: string, headers: { [string]: string }?) -> (boolean, any),
    post: (self: RestClient, path: string, body: any?, headers: { [string]: string }?) -> (boolean, any),
    patch: (self: RestClient, path: string, body: any?, headers: { [string]: string }?) -> (boolean, any),
    delete: (self: RestClient, path: string, headers: { [string]: string }?) -> (boolean, any),
    put: (self: RestClient, path: string, body: any?, headers: { [string]: string }?) -> (boolean, any),
}

local Rest = {}
local RestMT = {}
RestMT.__index = RestMT

--[[
    Inicializa uma nova interface Rest vinculada ao token do Client.
    @param client Instância base de Client contendo a propriedade `.token`.
]]
function Rest.new(client: any): RestClient
    local self = {
        _client = client,
    }
    setmetatable(self, RestMT)
    return (self :: any) :: RestClient
end

--[[
    Dispara uma requisição HTTP assinada contra a API do Discord.
    @param method Método HTTP (GET, POST, PATCH, DELETE, PUT).
    @param path Caminho do endpoint relativo (ex: "/channels/123/messages") ou absoluto.
    @param options Opções opcionais contendo corpo (tabela ou string) e headers extras.
    @return (sucesso, dadosDecodificadosOuErro)
]]
function RestMT:request(method: string, path: string, options: { body: any?, headers: { [string]: string }? }?): (boolean, any)
    local token = self._client and self._client.token
    if not token then
        return false, "Nenhum token configurado no Client para autorização HTTP."
    end

    -- Resolução inteligente do URL base
    local url = path
    if not string.find(url, "^https?://") then
        url = Data.Constants.BaseUrl .. (string.sub(path, 1, 1) == "/" and "" or "/") .. path
    end

    local opts = options or {}
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
            -- Serialização automática de tabelas para JSON
            local ok, encoded = pcall(Json.encode, opts.body)
            if not ok then
                return false, "Falha ao serializar corpo da requisição para JSON: " .. tostring(encoded)
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

    -- Execução assíncrona robusta na thread do runtime com pcall
    local ok, res = pcall(function()
        local httpMethod = string.upper(method)
        if httpMethod == "GET" then
            return Http.get(url, reqHeaders)
        elseif httpMethod == "POST" then
            return Http.post(url, { headers = reqHeaders, body = reqBody or "" })
        elseif httpMethod == "DELETE" then
            -- O Http nativo aceita o mapa de headers diretamente no delete
            return Http.delete(url, reqHeaders)
        elseif httpMethod == "PATCH" then
            -- Caso o método nativo patch não exista separadamente, podemos mapear ou usar post/custom
            -- O módulo Http padrão possui get, post, delete. Vamos checar se possui patch/put:
            if (Http :: any).patch then
                return (Http :: any).patch(url, { headers = reqHeaders, body = reqBody or "" })
            else
                -- Mapeia via POST customizado caso a engine nativa restrinja verbos extras
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
        return false, "Falha de socket I/O HTTP ao comunicar com a API REST: " .. tostring(res)
    end

    -- Se o status for de sucesso (2xx)
    if res.status and res.status >= 200 and res.status < 300 then
        if not res.body or res.body == "" then
            return true, {}
        end
        
        -- Tenta decodificar o JSON automaticamente
        local decOk, decoded = pcall(Json.decode, res.body)
        if decOk and decoded then
            return true, decoded
        else
            -- Retorna a string pura caso o endpoint devolva texto puro em vez de JSON
            return true, res.body
        end
    else
        -- Tenta extrair a mensagem de erro da API do Discord
        local errMsg = "Erro HTTP " .. tostring(res.status)
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

function RestMT:get(path: string, headers: { [string]: string }?): (boolean, any)
    return self:request("GET", path, { headers = headers })
end

function RestMT:post(path: string, body: any?, headers: { [string]: string }?): (boolean, any)
    return self:request("POST", path, { body = body, headers = headers })
end

function RestMT:patch(path: string, body: any?, headers: { [string]: string }?): (boolean, any)
    return self:request("PATCH", path, { body = body, headers = headers })
end

function RestMT:delete(path: string, headers: { [string]: string }?): (boolean, any)
    return self:request("DELETE", path, { headers = headers })
end

function RestMT:put(path: string, body: any?, headers: { [string]: string }?): (boolean, any)
    return self:request("PUT", path, { body = body, headers = headers })
end

table.freeze(RestMT)
table.freeze(Rest)
return Rest
