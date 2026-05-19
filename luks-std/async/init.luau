--!strict
-- luks-std/Async/init.luau
-- Innovative API inspired by the 'futures' and 'tokio' Rust ecosystem using Signals

local Signal = require("@self/deps/signal")

--[[
    Represents a filesystem, network, or execution error.
    Designed to mimic Rust's structured error patterns.
]]
export type FsError = { 
    --[[ The category or type of error (e.g., "NotFound", "PermissionDenied"). ]]
    kind: string, 
    --[[ A human-readable description of what went wrong. ]]
    message: string 
}

--[[
    Status of a TaskFuture.
]]
export type FutureState = "Pending" | "Resolved" | "Rejected" | "Cancelled"

--[[
    Holds the data signals and state for a TaskFuture.
    This is the internal state container that manages event dispatching.
]]
export type TaskFutureData<T> = {
    --[[ 
        Signal fired when data is successfully resolved. 
        @param self The future data instance
    ]]
    OnData: Signal.Signal<T>,
    --[[ 
        Signal fired when an error occurs during future execution. 
        @param self The future data instance
    ]]
    OnError: Signal.Signal<FsError>,
    --[[ 
        Signal fired when the task completes, regardless of success or failure. 
        @param self The future data instance
    ]]
    OnComplete: Signal.Signal<()>,

    --[[ The current state of the future. ]]
    _state: FutureState,
    --[[ The resolved value (if Resolved). ]]
    _value: any,
    --[[ The error object (if Rejected). ]]
    _error: FsError?,
    --[[ Internal raw signal for data (used by cancel). ]]
    _data_sig: Signal.SignalInternal<any>,
    --[[ Internal raw signal for error (used by cancel). ]]
    _err_sig: Signal.SignalInternal<FsError>,
    --[[ Internal raw signal for completion (used by cancel). ]]
    _comp_sig: Signal.SignalInternal<()>,
}

--[[
    Contains combinator methods for TaskFuture.
    Using expanded intersection types to bypass Luau's recursive generic limitations
    while providing full Intellisense for chained operations.
]]
type TaskFutureMethods = {
    --[[
        Chains another future or value after this one succeeds.
        If this future fails, the callback is skipped and the error propagates.
        
        @param self The future instance
        @param callback Function that takes the result and returns a new TaskFuture or a direct value.
        @return A new TaskFuture that resolves after the entire chain completes.
    ]]
    and_then: <T, U>(self: TaskFutureData<T> & TaskFutureMethods, callback: (T) -> (TaskFutureData<U> & TaskFutureMethods) | U) -> TaskFutureData<U> & TaskFutureMethods,
    
    --[[
        Transforms the successful result of this future into a new value.
        
        @param self The future instance
        @param callback Function that transforms the data (T -> U).
        @return A new TaskFuture containing the transformed result.
    ]]
    map: <T, U>(self: TaskFutureData<T> & TaskFutureMethods, callback: (T) -> U) -> TaskFutureData<U> & TaskFutureMethods,

    --[[
        Recovers from an error by returning a fallback future or value.
        If this future succeeds, the callback is skipped.
        
        @param self The future instance
        @param callback Function that handles the error and returns a recovery value or TaskFuture.
        @return A TaskFuture that resolves with either the original data or the recovery result.
    ]]
    or_else: <T>(self: TaskFutureData<T> & TaskFutureMethods, callback: (FsError) -> (TaskFutureData<T> & TaskFutureMethods) | T) -> TaskFutureData<T> & TaskFutureMethods,

    --[[
        Transforms the error object of this future if it fails.
        
        @param self The future instance
        @param callback Function that takes the original FsError and returns a new one.
        @return A new TaskFuture containing the transformed error.
    ]]
    map_err: <T>(self: TaskFutureData<T> & TaskFutureMethods, callback: (FsError) -> FsError) -> TaskFutureData<T> & TaskFutureMethods,

    --[[
        Executes a side-effect if the future succeeds, without consuming or modifying the value.
        Perfect for logging or non-blocking telemetry.
        
        @param self The future instance
        @param callback Function to execute with the successful data.
        @return The same TaskFuture instance for further chaining.
    ]]
    inspect: <T>(self: TaskFutureData<T> & TaskFutureMethods, callback: (T) -> ()) -> TaskFutureData<T> & TaskFutureMethods,

    --[[
        Executes a side-effect if the future fails, without consuming or modifying the error.
        
        @param self The future instance
        @param callback Function to execute with the error object.
        @return The same TaskFuture instance for further chaining.
    ]]
    inspect_err: <T>(self: TaskFutureData<T> & TaskFutureMethods, callback: (FsError) -> ()) -> TaskFutureData<T> & TaskFutureMethods,
    
    --[[
        Yields the current Luau thread until the future resolves (Success or Error).
        
        @param self The future instance
        @return The resolved data (or error object) and a success boolean.
    ]]
    Wait: <T>(self: TaskFutureData<T> & TaskFutureMethods) -> (T, boolean),

    --[[
        Yields the thread and returns the value. 
        If the future failed, it triggers a Luau error (Panic) with the failure details.
        
        @param self The future instance
        @return The resolved successful data.
    ]]
    unwrap: <T>(self: TaskFutureData<T> & TaskFutureMethods) -> T,

    --[[
        Yields the thread and returns the value. 
        If the future failed, it triggers a panic with a custom message.
        
        @param self The future instance
        @param message The custom panic message prefix.
        @return The resolved successful data.
    ]]
    expect: <T>(self: TaskFutureData<T> & TaskFutureMethods, message: string) -> T,
}

--[[
    A Signal-based Future interface similar to Rust's Future trait.
    Enables powerful asynchronous composition and synchronization.
]]
export type TaskFuture<T> = TaskFutureData<T> & TaskFutureMethods

local Async = {}

-- [[ TaskFuture Metatable ]]
local TaskFutureMT = {}
TaskFutureMT.__index = TaskFutureMT

--[[ Internal helper to connect to a future, handling immediate resolution. ]]
local function connect<T>(future: any, onData: (T) -> (), onError: (FsError) -> ())
    local f = future :: TaskFuture<T>
    if f._state == "Resolved" then
        task.spawn(onData, f._value :: T)
    elseif f._state == "Rejected" then
        task.spawn(onError, f._error :: FsError)
    else
        f.OnData:Connect(onData)
        f.OnError:Connect(onError)
    end
end

--[[
    Internal implementation of .and_then().
]]
function TaskFutureMT:and_then<T, U>(callback: (T) -> (TaskFuture<U> | U)): TaskFuture<U>
    local next_future, next_success, next_error = Async.new_future()
    local self_typed = (self :: any) :: TaskFuture<T>
    
    connect(self_typed, function(data)
        local success, chained = pcall(callback, data)
        if not success then
            next_error({ kind = "CallbackError", message = tostring(chained) })
            return
        end

        if type(chained) == "table" and (chained :: any).OnData then
            local chained_future = (chained :: any) :: TaskFuture<U>
            connect(chained_future, next_success, next_error)
        else
            next_success(chained :: U)
        end
    end, next_error)
    
    return next_future
end

--[[
    Internal implementation of .map().
]]
function TaskFutureMT:map<T, U>(callback: (T) -> U): TaskFuture<U>
    local next_future, next_success, next_error = Async.new_future()
    local self_typed = (self :: any) :: TaskFuture<T>
    
    connect(self_typed, function(data)
        local success, result = pcall(callback, data)
        if success then
            next_success(result)
        else
            next_error({ kind = "MapError", message = tostring(result) })
        end
    end, next_error)
    
    return next_future
end

--[[
    Internal implementation of .or_else().
]]
function TaskFutureMT:or_else<T>(callback: (FsError) -> (TaskFuture<T> | T)): TaskFuture<T>
    local next_future, next_success, next_error = Async.new_future()
    local self_typed = (self :: any) :: TaskFuture<T>

    connect(self_typed, next_success, function(err)
        local success, chained = pcall(callback, err)
        if not success then
            next_error({ kind = "OrElseError", message = tostring(chained) })
            return
        end

        if type(chained) == "table" and (chained :: any).OnData then
            local chained_future = (chained :: any) :: TaskFuture<T>
            connect(chained_future, next_success, next_error)
        else
            next_success(chained :: T)
        end
    end)

    return next_future
end

--[[
    Internal implementation of .map_err().
]]
function TaskFutureMT:map_err<T>(callback: (FsError) -> FsError): TaskFuture<T>
    local next_future, next_success, next_error = Async.new_future()
    local self_typed = (self :: any) :: TaskFuture<T>

    connect(self_typed, next_success, function(err)
        local success, result = pcall(callback, err)
        if success then
            next_error(result)
        else
            next_error({ kind = "MapErrError", message = tostring(result) })
        end
    end)

    return next_future
end

--[[
    Internal implementation of .inspect().
]]
function TaskFutureMT:inspect<T>(callback: (T) -> ()): TaskFuture<T>
    local self_typed = (self :: any) :: TaskFuture<T>
    connect(self_typed, function(data)
        pcall(callback, data)
    end, function() end)
    return self_typed
end

--[[
    Internal implementation of .inspect_err().
]]
function TaskFutureMT:inspect_err<T>(callback: (FsError) -> ()): TaskFuture<T>
    local self_typed = (self :: any) :: TaskFuture<T>
    connect(self_typed, function() end, function(err)
        pcall(callback, err)
    end)
    return self_typed
end

--[[
    Cancels the future, preventing any pending callbacks from firing.
    Disconnects all internal signals to free captured closures.
]]
function TaskFutureMT:cancel()
    local self_typed = self :: TaskFuture<any>
    if self_typed._state ~= "Pending" then return end
    self_typed._state = "Cancelled"
    self_typed._data_sig:DisconnectAll()
    self_typed._err_sig:DisconnectAll()
    self_typed._comp_sig:DisconnectAll()
end

--[[
    Internal implementation of .Wait().
]]
function TaskFutureMT:Wait(): any
    local self_typed = (self :: any) :: TaskFuture<any>
    
    if self_typed._state == "Resolved" then
        return self_typed._value, true
    elseif self_typed._state == "Rejected" then
        return self_typed._error, false
    elseif self_typed._state == "Cancelled" then
        return ({ kind = "Cancelled", message = "future was cancelled" } :: FsError), false
    end

    local thread = coroutine.running()
    
    local d_conn, e_conn
    d_conn = self_typed.OnData:Once(function(data)
        if e_conn then e_conn:Disconnect() end
        task.spawn(thread, true, data)
    end)
    e_conn = self_typed.OnError:Once(function(err)
        if d_conn then d_conn:Disconnect() end
        task.spawn(thread, false, err)
    end)
    
    local success, result = coroutine.yield()
    return result, success
end

--[[
    Internal implementation of .unwrap().
]]
function TaskFutureMT:unwrap(): any
    local result, success = self:Wait()
    if not success then
        local err = result :: FsError
        error(string.format("Called `TaskFuture:unwrap()` on an `Err` value: %s (%s)", err.message, err.kind))
    end
    return result
end

--[[
    Internal implementation of .expect().
]]
function TaskFutureMT:expect(message: string): any
    local result, success = self:Wait()
    if not success then
        local err = result :: FsError
        error(string.format("%s: %s (%s)", message, err.message, err.kind))
    end
    return result
end

--[[
    Creates a new internal future based on signals.
    This is the primary way to integrate native asynchronous operations into the TaskFuture system.
    
    @return A TaskFuture instance, a resolve function, and a reject function.
]]
function Async.new_future<T>(): (TaskFuture<T>, (T) -> (), (FsError) -> ())
    local data_sig = Signal.new() :: Signal.SignalInternal<T>
    local err_sig = Signal.new() :: Signal.SignalInternal<FsError>
    local comp_sig = Signal.new() :: Signal.SignalInternal<()>

    local future = {
        OnData = data_sig:Public(),
        OnError = err_sig:Public(),
        OnComplete = comp_sig:Public(),
        _state = "Pending" :: FutureState,
        _value = nil :: any,
        _error = nil :: FsError?,
        _data_sig = data_sig,
        _err_sig = err_sig,
        _comp_sig = comp_sig,
    }
    setmetatable(future, TaskFutureMT)

    local function resolve(data: T) 
        if future._state ~= "Pending" then return end
        future._state = "Resolved"
        future._value = data
        data_sig:Fire(data)
        comp_sig:Fire() 
    end
    
    local function reject(err: FsError) 
        if future._state ~= "Pending" then return end
        future._state = "Rejected"
        future._error = err
        err_sig:Fire(err)
        comp_sig:Fire() 
    end

    return (future :: any) :: TaskFuture<T>, resolve, reject
end

--[[ 
    Creates a future that is already resolved with the given value. 
    @param value The value to resolve the future with.
    @return A TaskFuture already in the Resolved state.
]]
function Async.resolved<T>(value: T): TaskFuture<T>
    local fut, resolve = Async.new_future()
    resolve(value)
    return fut
end

--[[ 
    Creates a future that is already rejected with the given error. 
    @param err The error object to reject the future with.
    @return A TaskFuture already in the Rejected state.
]]
function Async.rejected<T>(err: FsError): TaskFuture<T>
    local fut, _, reject = Async.new_future()
    reject(err)
    return fut
end

--------------------------------------------------------------------------------
-- GLOBAL COMBINATORS (Rust-style Macros)
--------------------------------------------------------------------------------

--[[
    Waits for a list of parallel futures to finish.
    Inspired by Rust's `tokio::join!` macro.
    
    @param futures A table array of TaskFutures to wait for.
    @return A TaskFuture that resolves with an array containing all successful results in order.
]]
function Async.join(futures: {TaskFuture<any>}): TaskFuture<{any}>
    local joint_future, resolve, reject = Async.new_future()
    local total = #futures
    local completed = 0
    local results = table.create(total)

    if total == 0 then
        resolve({})
        return joint_future
    end

    for i, fut in futures do
        connect(fut, function(data)
            results[i] = data
            completed += 1
            if completed == total then
                resolve(results)
            end
        end, function(err)
            reject(err) -- Standard Join behavior: First error fails the entire set.
        end)
    end

    return joint_future
end

--[[
    Races multiple futures. The first one to fire (resolve or error) wins the race.
    Inspired by Rust's `tokio::select!` macro.
    
    @param futures A table array of TaskFutures to race.
    @return A TaskFuture that resolves with the result of the fastest future.
]]
function Async.select(futures: {TaskFuture<any>}): TaskFuture<any>
    local select_future, resolve, reject = Async.new_future()
    local done = false

    for _, fut in futures do
        connect(fut, function(data)
            if not done then
                done = true
                resolve(data)
            end
        end, function(err)
            if not done then
                done = true
                reject(err)
            end
        end)
    end

    return select_future
end

--[[ Re-export the Signal module for consistent access. ]]
Async.Signal = Signal

return Async
