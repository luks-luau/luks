--!strict
-- luks-std/IO/types.luau
-- Central type definitions for the IO module to avoid circularity

local Async = require("@self/../async")

--[[ Standard IO Error type. ]]
export type IoError = {
    --[[ The category of error (e.g., "NotFound", "PermissionDenied"). ]]
    kind: string,
    --[[ A human-readable description of the error. ]]
    message: string,
}

--[[ Enumeration for seeking positions in a stream. ]]
export type SeekFrom = 
    --[[ Seek from the start of the stream. ]]
    { kind: "Start", pos: number } | 
    --[[ Seek from the end of the stream. ]]
    { kind: "End", pos: number } | 
    --[[ Seek from the current position in the stream. ]]
    { kind: "Current", pos: number }

--[[ Interface for a byte-oriented reader. ]]
export type Reader = {
    --[[
        Attempts to read bytes from the source into the provided buffer.
        @param self The reader instance
        @param buf The buffer to read into
        @param offset Optional offset in the buffer to start writing
        @param len Optional number of bytes to read
        @return A future resolving to the number of bytes read
    ]]
    read: (self: Reader, buf: buffer, offset: number?, len: number?) -> Async.TaskFuture<number>,
    
    --[[
        Reads all bytes from the source until EOF and returns them in a buffer.
        @param self The reader instance
        @return A future resolving to the full buffer of bytes
    ]]
    read_to_end: (self: Reader) -> Async.TaskFuture<buffer>,
    
    --[[
        Reads all bytes from the source until EOF and returns them as a string.
        @param self The reader instance
        @return A future resolving to the full string
    ]]
    read_to_string: (self: Reader) -> Async.TaskFuture<string>,
    
    --[[
        Attempts to read the exact number of bytes needed to fill the buffer.
        @param self The reader instance
        @param buf The buffer to fill
        @param len The number of bytes to read
        @return A future resolving when the buffer is filled
    ]]
    read_exact: (self: Reader, buf: buffer, len: number) -> Async.TaskFuture<any>,
    
    --[[
        Creates a new reader that is limited to a certain number of bytes.
        @param self The reader instance
        @param limit The maximum number of bytes to read
        @return A new Reader instance
    ]]
    take: (self: Reader, limit: number) -> Reader,
    
    --[[
        Chains two readers together, reading from the second once the first reaches EOF.
        @param self The first reader
        @param other The second reader
        @return A new Reader instance
    ]]
    chain: (self: Reader, other: Reader) -> Reader,
}

--[[ Interface for a byte-oriented writer. ]]
export type Writer = {
    --[[
        Attempts to write bytes from the provided buffer or string into the destination.
        @param self The writer instance
        @param buf The buffer or string containing data to write
        @param offset Optional offset in the data to start reading
        @param len Optional number of bytes to write
        @return A future resolving to the number of bytes written
    ]]
    write: (self: Writer, buf: buffer | string, offset: number?, len: number?) -> Async.TaskFuture<number>,
    
    --[[
        Attempts to write all bytes from the provided buffer or string.
        @param self The writer instance
        @param buf The data to write
        @return A future resolving when all data is written
    ]]
    write_all: (self: Writer, buf: buffer | string) -> Async.TaskFuture<any>,
    
    --[[
        Flushes any intermediate buffered data to the destination.
        @param self The writer instance
        @return A future resolving when the flush is complete
    ]]
    flush: (self: Writer) -> Async.TaskFuture<any>,
}

--[[ Interface for a stream that can change its current position. ]]
export type Seeker = {
    --[[
        Changes the current position in the stream.
        @param self The seeker instance
        @param pos The position to seek to
        @return A future resolving to the new position
    ]]
    seek: (self: Seeker, pos: SeekFrom) -> Async.TaskFuture<number>,
    
    --[[
        Returns the current position in the stream.
        @param self The seeker instance
        @return The current position in bytes from the start
    ]]
    position: (self: Seeker) -> number,
}

--[[ Interface for buffered reading operations. ]]
export type BufRead = Reader & {
    --[[
        Ensures the internal buffer is filled, potentially reading from the underlying source.
        @param self The buffered reader instance
        @return A future resolving to the internal buffer
    ]]
    fill_buf: (self: BufRead) -> Async.TaskFuture<buffer>,
    
    --[[
        Marks a certain amount of bytes as consumed from the internal buffer.
        @param self The buffered reader instance
        @param amt The number of bytes to consume
    ]]
    consume: (self: BufRead, amt: number) -> (),
    
    --[[
        Reads from the source until the specified byte is found.
        @param self The buffered reader instance
        @param byte The byte to search for
        @return A future resolving to a buffer containing the data up to and including the byte
    ]]
    read_until: (self: BufRead, byte: number) -> Async.TaskFuture<buffer?>,
    
    --[[
        Reads from the source until a newline character (LF) is found.
        @param self The buffered reader instance
        @return A future resolving to the line as a string
    ]]
    read_line: (self: BufRead) -> Async.TaskFuture<string?>,
    
    --[[
        Returns an iterator over the lines of the reader.
        @param self The buffered reader instance
        @return An iterator function returning strings
    ]]
    lines: (self: BufRead) -> () -> string?,
}

return {}
