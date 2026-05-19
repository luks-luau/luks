--!strict

local types = require("types")

type Self = {
    _handle: any,
    _title: string,
    _valid: boolean,
}

local native: {
    get_window_title: (hwnd: any) -> string,
    focus_window_by_handle: (hwnd: any) -> boolean,
    close_window: (hwnd: any) -> boolean,
    minimize_window: (hwnd: any) -> boolean,
    maximize_window: (hwnd: any) -> boolean,
    restore_window: (hwnd: any) -> boolean,
    get_window_geometry: (hwnd: any) -> (number, number, number, number),
    set_window_geometry: (hwnd: any, x: number, y: number, w: number, h: number) -> boolean,
    is_window_minimized: (hwnd: any) -> boolean,
    is_window_maximized: (hwnd: any) -> boolean,
    is_window_visible: (hwnd: any) -> boolean,
    get_active_window: () -> any?,
    window_set_transparency: (hwnd: any, alpha: number) -> boolean,
    window_set_click_through: (hwnd: any, enabled: boolean) -> boolean,
}

local WindowMT = {}
WindowMT.__index = WindowMT

--[[
    Gets the window title.
    @param self The window instance
    @return The window title string
]]
function WindowMT:get_title(): string
    return self._title
end

--[[
    Brings the window into focus.
    @param self The window instance
    @return Whether the focus operation succeeded
]]
function WindowMT:focus(): boolean
    if not self._valid then return false end
    local ok, result = pcall(native.focus_window_by_handle, self._handle)
    return if ok then result else false
end

--[[
    Closes the window.
    @param self The window instance
    @return Whether the close operation succeeded
]]
function WindowMT:close(): boolean
    if not self._valid then return false end
    local ok, result = pcall(native.close_window, self._handle)
    return if ok then result else false
end

--[[
    Minimizes the window to the taskbar.
    @param self The window instance
    @return Whether the minimize operation succeeded
]]
function WindowMT:minimize(): boolean
    if not self._valid then return false end
    local ok, result = pcall(native.minimize_window, self._handle)
    return if ok then result else false
end

--[[
    Maximizes the window to fill the screen.
    @param self The window instance
    @return Whether the maximize operation succeeded
]]
function WindowMT:maximize(): boolean
    if not self._valid then return false end
    local ok, result = pcall(native.maximize_window, self._handle)
    return if ok then result else false
end

--[[
    Restores the window from minimized or maximized state.
    @param self The window instance
    @return Whether the restore operation succeeded
]]
function WindowMT:restore(): boolean
    if not self._valid then return false end
    local ok, result = pcall(native.restore_window, self._handle)
    return if ok then result else false
end

--[[
    Gets the position and size of the window.
    @param self The window instance
    @return A table containing x, y, w, h of the window
]]
function WindowMT:get_position(): { x: number, y: number, w: number, h: number }
    if not self._valid then return { x = 0, y = 0, w = 0, h = 0 } end
    local ok, gx, gy, gw, gh = pcall(native.get_window_geometry, self._handle)
    if ok then
        return { x = gx, y = gy, w = gw, h = gh }
    end
    return { x = 0, y = 0, w = 0, h = 0 }
end

--[[
    Moves the window to the specified screen coordinates.
    @param self The window instance
    @param x The new x-coordinate
    @param y The new y-coordinate
    @return Whether the repositioning succeeded
]]
function WindowMT:set_position(x: number, y: number): boolean
    if not self._valid then return false end
    local ok, _gx, _gy, gw, gh = pcall(native.get_window_geometry, self._handle)
    if not ok then return false end
    local ok2, result = pcall(native.set_window_geometry, self._handle, x, y, gw, gh)
    return if ok2 then result else false
end

--[[
    Resizes the window to the specified dimensions.
    @param self The window instance
    @param w The new width
    @param h The new height
    @return Whether the resize succeeded
]]
function WindowMT:set_size(w: number, h: number): boolean
    if not self._valid then return false end
    local ok, gx, gy, _gw, _gh = pcall(native.get_window_geometry, self._handle)
    if not ok then return false end
    local ok2, result = pcall(native.set_window_geometry, self._handle, gx, gy, w, h)
    return if ok2 then result else false
end

--[[
    Checks whether the window is visible.
    @param self The window instance
    @return Whether the window is visible
]]
function WindowMT:is_visible(): boolean
    if not self._valid then return false end
    local ok, result = pcall(native.is_window_visible, self._handle)
    return if ok then result else false
end

--[[
    Checks whether the window is minimized.
    @param self The window instance
    @return Whether the window is minimized
]]
function WindowMT:is_minimized(): boolean
    if not self._valid then return false end
    local ok, result = pcall(native.is_window_minimized, self._handle)
    return if ok then result else false
end

--[[
    Checks whether the window is maximized.
    @param self The window instance
    @return Whether the window is maximized
]]
function WindowMT:is_maximized(): boolean
    if not self._valid then return false end
    local ok, result = pcall(native.is_window_maximized, self._handle)
    return if ok then result else false
end

--[[
    Checks whether the window is the active (foreground) window.
    @param self The window instance
    @return Whether the window is active
]]
function WindowMT:is_active(): boolean
    if not self._valid then return false end
    local ok, active = pcall(native.get_active_window)
    if ok and active then
        return active == self._handle
    end
    return false
end

--[[
    Sets the window transparency level.
    @param self The window instance
    @param alpha Transparency value from 0 (fully transparent) to 255 (fully opaque)
    @return Whether the transparency change succeeded
]]
function WindowMT:set_transparency(alpha: number): boolean
    if not self._valid then return false end
    local ok, result = pcall(native.window_set_transparency, self._handle, alpha)
    return if ok then result else false
end

--[[
    Enables or disables click-through on the window.
    @param self The window instance
    @param enabled Whether click-through should be enabled
    @return Whether the change succeeded
]]
function WindowMT:set_click_through(enabled: boolean): boolean
    if not self._valid then return false end
    local ok, result = pcall(native.window_set_click_through, self._handle, enabled)
    return if ok then result else false
end

--[[
    Cleans up the window handle when the object is garbage collected.
    @param self The window instance
]]
function WindowMT:__gc()
    self._valid = false
    self._handle = nil
end

--[[
    Initializes the Window module with the native API table.
    @param n The native API table
]]
local function init(n: any)
    native = n
end

--[[
    Creates a new Window instance wrapping a native window handle.
    @param handle The native window handle
    @return A new Window instance
]]
local function new(handle: any): types.Window
    local ok, title = pcall(native.get_window_title, handle)
    local self: Self = {
        _handle = handle,
        _title = if ok then title else "",
        _valid = true,
    }
    return (setmetatable(self, WindowMT) :: any) :: types.Window
end

return {
    init = init,
    new = new,
}
