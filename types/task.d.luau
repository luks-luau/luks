--[=[
 * Global scheduling library for asynchronous task execution and thread management.
 ---
 ```lua
 task.spawn(function()
     print("Running immediately")
 end)

 task.delay(1.5, function(msg)
     print("Delayed message:", msg)
 end, "Hello Task!")

 local elapsed = task.wait(0.5)
 print("Waited for", elapsed, "seconds")
 ```
]=]
export type TaskLibrary = {
    --[=[
     * Immediately resumes a thread or function using the engine scheduler.
     ---
     * **param** `...` The function or thread followed by any arguments
     * **return** The scheduled thread handle
    ]=]
    spawn: (...any) -> thread,

    --[=[
     * Defers execution of a thread or function until the next scheduling cycle.
     ---
     * **param** `...` The function or thread followed by any arguments
     * **return** The deferred thread handle
    ]=]
    defer: (...any) -> thread,

    --[=[
     * Delays execution of a thread or function by a specified duration in seconds.
     ---
     * **param** `duration` Time to wait in seconds
     * **param** `...` The function or thread followed by any arguments
     * **return** The scheduled thread handle
    ]=]
    delay: (duration: number, ...any) -> thread,

    --[=[
     * Yields the current executing thread for a specified duration in seconds.
     ---
     * **param** `duration` Optional time to wait in seconds
     * **return** The actual elapsed duration in seconds
    ]=]
    wait: (duration: number?) -> number,

    --[=[
     * Cancels a previously scheduled thread to prevent its resumption.
     ---
     * **param** `thread` The target thread to cancel
    ]=]
    cancel: (thread: thread) -> (),
}

declare task: TaskLibrary
