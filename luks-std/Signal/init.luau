--!strict

--[[
    Signal Module - A type-safe implementation of the observer pattern.
    Provides a robust event system for decoupled communication between components.
]]

-- Public interface types
export type Connection = {
    --[[
        Disconnects this connection, preventing the callback from being fired.
        @param self The connection instance
    ]]
    Disconnect: (self: Connection) -> (),
}

export type Signal<T...> = {
    --[[
        Connects a callback to be fired when the signal fires.
        @param self The signal instance
        @param callback The function to call when the signal fires
        @return A connection object that can be disconnected
    ]]
    Connect: (self: Signal<T...>, callback: (T...) -> ()) -> Connection,
    --[[
        Connects a callback that will only fire once, then disconnects.
        @param self The signal instance
        @param callback The function to call when the signal fires
        @return A connection object that can be disconnected
    ]]
    Once: (self: Signal<T...>, callback: (T...) -> ()) -> Connection,
    --[[
        Yields the current thread until the signal fires.
        @param self The signal instance
        @return The arguments passed to the signal
    ]]
    Wait: (self: Signal<T...>) -> T...,
}

-- Forward declarations for circular type references
type ConnectionInternal<T...> = {
    --[[
        Whether this connection is still active.
        @param self The connection instance
    ]]
    Connected: boolean,
    --[[
        Disconnects this connection, preventing the callback from being fired.
        @param self The connection instance
    ]]
    Disconnect: (self: ConnectionInternal<T...>) -> (),
    _signal: SignalInternal<T...>,
    _next: ConnectionInternal<T...>?,
    _callback: (T...) -> (),
}

export type SignalInternal<T...> = {
    _head: ConnectionInternal<T...>?,
    --[[
        Connects a callback to be fired when the signal fires.
        @param self The signal instance
        @param callback The function to call when the signal fires
        @return A connection object that can be disconnected
    ]]
    Connect: (self: SignalInternal<T...>, callback: (T...) -> ()) -> ConnectionInternal<T...>,
    --[[
        Connects a callback that will only fire once, then disconnects.
        @param self The signal instance
        @param callback The function to call when the signal fires
        @return A connection object that can be disconnected
    ]]
    Once: (self: SignalInternal<T...>, callback: (T...) -> ()) -> ConnectionInternal<T...>,
    --[[
        Yields the current thread until the signal fires.
        @param self The signal instance
        @return The arguments passed to the signal
    ]]
    Wait: (self: SignalInternal<T...>) -> T...,
    --[[
        Fires the signal with the given arguments.
        @param self The signal instance
        @param args The arguments to pass to the callbacks
    ]]
    Fire: (self: SignalInternal<T...>, T...) -> (),
    --[[
        Disconnects all connections from this signal.
        @param self The signal instance
    ]]
    DisconnectAll: (self: SignalInternal<T...>) -> (),
    --[[
        Destroys the signal and all its connections.
        @param self The signal instance
    ]]
    Destroy: (self: SignalInternal<T...>) -> (),
    --[[
        Returns a read-only proxy to the signal.
        @param self The signal instance
        @return A read-only proxy to the signal
    ]]
    Public: (self: SignalInternal<T...>) -> Signal<T...>,
}

-- Connection metatable
local ConnectionMT = {}
ConnectionMT.__index = ConnectionMT

-- Signal metatable
local SignalMT = {}
SignalMT.__index = SignalMT

--[[
    Creates a new connection object.
    @param signal The signal this connection belongs to
    @param callback The function to call when the signal fires
    @return A new ConnectionInternal instance
]]
local function createConnection<T...>(
    signal: SignalInternal<T...>,
    callback: (T...) -> ()
): ConnectionInternal<T...>
    local connection = {
        Connected = true,
        _signal = signal,
        _callback = callback,
        _next = nil :: ConnectionInternal<T...>?,
    }
    setmetatable(connection, ConnectionMT)
    return (connection :: any) :: ConnectionInternal<T...>
end

--[[
    Connects a callback to the signal.
    @param self The signal instance
    @param callback The function to call when the signal fires
    @return A connection object that can be disconnected
]]
function SignalMT:Connect<T...>(callback: (T...) -> ()): ConnectionInternal<T...>
    local signal = self :: SignalInternal<T...>
    local connection = createConnection(signal, callback)
    connection._next = signal._head
    signal._head = connection
    return connection
end

--[[
    Creates a connection that will only fire once.
    @param self The signal instance
    @param callback The function to call when the signal fires
    @return A connection object that can be disconnected
]]
function SignalMT:Once<T...>(callback: (T...) -> ()): ConnectionInternal<T...>
    local connection: ConnectionInternal<T...>
    connection = self:Connect(function(...: T...)
        connection:Disconnect()
        callback(...)
    end)
    return connection
end

--[[
    Yields the current thread until the signal fires.
    @param self The signal instance
    @return The arguments passed to Fire
]]
function SignalMT:Wait<T...>(): T...
    local thread = coroutine.running()
    local connection: ConnectionInternal<T...>
    connection = self:Connect(function(...: T...)
        connection:Disconnect()
        task.spawn(thread, ...)
    end)
    return coroutine.yield()
end

--[[
    Fires the signal, calling all connected callbacks.
    @param self The signal instance
    @param ... The arguments to pass to callbacks
]]
function SignalMT:Fire<T...>(...: T...)
    local current = self._head
    while current do
        if current.Connected then
            task.spawn(current._callback, ...)
        end
        current = current._next
    end
end

--[[
    Disconnects all connections from this signal.
    @param self The signal instance
]]
function SignalMT:DisconnectAll()
    local current = self._head
    while current do
        current.Connected = false
        current = current._next
    end
    self._head = (nil :: any)
end

--[[
    Destroys the signal and disconnects all connections.
    @param self The signal instance
]]
function SignalMT:Destroy()
    self:DisconnectAll()
end

--[[
    Disconnects this connection from its signal.
    @param self The connection instance
]]
function ConnectionMT:Disconnect()
    if not self.Connected then
        return
    end
    self.Connected = false

    local signal = self._signal
    if signal._head == self then
        signal._head = nil
    else
        local current = signal._head
        while current and current._next ~= self do
            current = current._next
        end
        if current then
            current._next = self._next
        end
    end
end

--[[
    Creates a public interface for the signal.
    @param self The signal instance
    @return A frozen table with Connect, Once, and Wait methods
]]
function SignalMT:Public<T...>(): Signal<T...>
    local internal = self :: SignalInternal<T...>
    local proxy = {} :: Signal<T...>
    
    --[[ Connects a callback to the signal. ]]
    function proxy:Connect(callback: (T...) -> ()): Connection
        return internal:Connect(callback)
    end
    
    --[[ Creates a connection that will only fire once. ]]
    function proxy:Once(callback: (T...) -> ()): Connection
        return internal:Once(callback)
    end
    
    --[[ Waits for the signal to fire and returns the arguments. ]]
    function proxy:Wait(): T...
        return internal:Wait()
    end
    
    table.freeze(proxy)
    return proxy
end

-- Module table
local Signal = {}

--[[
    Creates a new signal instance.
    @return A new SignalInternal instance
]]
function Signal.new<T...>(): SignalInternal<T...>
    local signal = {
        _head = nil :: ConnectionInternal<T...>?,
    }
    setmetatable(signal, SignalMT)
    return (signal :: any) :: SignalInternal<T...>
end

return Signal