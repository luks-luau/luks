--!strict
-- luks-std/env/consts/init.luau
-- Native OS and Architecture constants exported from std::env::consts

local SafeLoadNative = function(path: string)
    local success, native = pcall(dlopen, path)
    if success then
        return native
    else
        return nil
    end
end

--[[ 
    Loading from @self/../lib/env because this is in a subfolder.
    The native library provides a 'consts' table populated from Rust's std::env::consts.
]]
local native = SafeLoadNative("@self/../lib/env")
    or SafeLoadNative("@self/../../../target/release/env")
    or SafeLoadNative("@self/../../../target/debug/env")
    or error("Could not load Env native library for consts")

--[[
    Native system constants derived from the compilation target.
]]
export type EnvConsts = {
    --[[ The target CPU architecture (e.g., "x86_64", "aarch64"). ]]
    ARCH: string,
    --[[ The target operating system (e.g., "windows", "linux"). ]]
    OS: string,
    --[[ The target OS family ("windows" or "unix"). ]]
    FAMILY: string,
    --[[ The standard extension for executables on this platform ("exe" or ""). ]]
    EXE_EXTENSION: string,
    --[[ The standard extension for dynamic libraries ("dll", "so", or "dylib"). ]]
    DLL_EXTENSION: string,
    --[[ The standard prefix for dynamic libraries (usually empty on Windows, "lib" on Unix). ]]
    DLL_PREFIX: string,
    --[[ The standard suffix for executables (e.g., ".exe" on Windows). ]]
    EXE_SUFFIX: string,
}

return (native.consts :: any) :: EnvConsts