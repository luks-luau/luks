--!strict

local types = require("@self/types")

--[[ Mouse button identifiers for click/down/up operations. ]]
export type MouseClick = types.MouseClick
--[[ Represents a physical display monitor with its position and dimensions. ]]
export type Monitor = types.Monitor
--[[ Represents a native window with methods for manipulation and inspection. ]]
export type Window = types.Window

type NativeAPI = {
    change_debug_state: (state: boolean) -> (),
    set_suppress_warnings: (suppress: boolean) -> (),
    get_screen_size: () -> (number, number),
    get_mouse_position: () -> (number, number),
    set_mouse_position: (x: number, y: number) -> (),
    mouse_click: (button: string, down: boolean) -> (),
    mouse_scroll: (intensity: number, dir: string) -> (),
    keyboard_event: (key: string, down: boolean) -> (),
    keyboard_type: (text: string) -> (),
    save_screenshot: (path: string, x: number, y: number, w: number, h: number) -> (),
    capture_screenshot: () -> (buffer, number, number),
    get_pixel: (x: number, y: number) -> (number, number, number, number),
    get_monitors: () -> { types.Monitor },
    clipboard_get_text: () -> string,
    clipboard_set_text: (text: string) -> (),
    prepare_template_from_file: (path: string) -> (),
    find_image_on_screen: (threshold: number, x: number, y: number, w: number, h: number) -> (number?, number?),
    focus_window: (title: string) -> boolean,
    window_exists: (title: string) -> boolean,
    get_active_window: () -> any?,
    get_all_windows: () -> { any },
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
    window_create: (hwnd: any) -> any?,
    window_set_transparency: (hwnd: any, alpha: number) -> boolean,
    window_set_click_through: (hwnd: any, enabled: boolean) -> boolean,
}

local native: NativeAPI = (function()
    local function try_load(p) local s, n = pcall(dlopen, p); return if s then n else nil end
    local lib = try_load("@self/lib/luauautogui")
        or try_load("@self/../../target/release/luauautogui")
        or try_load("@self/../../target/debug/luauautogui")
        or error("Could not load luauautogui native library")
    return lib :: any
end)()

local Window = require("@self/Window")
Window.init(native)

--[[
    Enables or disables debug state for the automation engine.
    @param state Whether debug state should be enabled
]]
local function change_debug_state(state: boolean)
    native.change_debug_state(state)
end

--[[
    Suppresses or re-enables warning messages from the native library.
    @param suppress Whether warnings should be suppressed
]]
local function set_suppress_warnings(suppress: boolean)
    native.set_suppress_warnings(suppress)
end

--[[
    Gets the total screen size across all monitors.
    @return The width and height of the virtual screen
]]
local function get_screen_size(): (number, number)
    return native.get_screen_size()
end

--[[
    Captures a screenshot of the entire screen.
    @return A buffer containing the image data, the width, and the height
]]
local function capture_screenshot(): (buffer, number, number)
    local ok, buf, w, h = pcall(native.capture_screenshot)
    if not ok then
        error("capture_screenshot: " .. tostring(buf), 2)
    end
    return buf, w, h
end

--[[
    Saves a screenshot of the specified screen region to a file.
    @param path The file path to save the screenshot to
    @param x The left edge of the region (default 0)
    @param y The top edge of the region (default 0)
    @param w The width of the region (default 0 = full width)
    @param h The height of the region (default 0 = full height)
]]
local function save_screenshot(path: string, x: number?, y: number?, w: number?, h: number?)
    local sx, sy, sw, sh = x or 0, y or 0, w or 0, h or 0
    local ok = pcall(native.save_screenshot, path, sx, sy, sw, sh)
    if not ok then
        error("save_screenshot failed", 2)
    end
end

--[[
    Gets the RGBA color values of a single pixel on the screen.
    @param x The x-coordinate of the pixel
    @param y The y-coordinate of the pixel
    @return The red, green, blue, and alpha values (0-255 each)
]]
local function get_pixel(x: number, y: number): (number, number, number, number)
    local ok, r, g, b, a = pcall(native.get_pixel, x, y)
    if not ok then
        error("get_pixel: " .. tostring(r), 2)
    end
    return r, g, b, a
end

--[[
    Gets information about all connected monitors.
    @return A list of Monitor objects
]]
local function get_monitors(): { types.Monitor }
    return native.get_monitors()
end

--[[
    Gets the current mouse cursor position in screen coordinates.
    @return The x and y coordinates of the cursor
]]
local function mouse_get_position(): (number, number)
    return native.get_mouse_position()
end

--[[
    Moves the mouse cursor to the specified screen coordinates.
    @param x The target x-coordinate
    @param y The target y-coordinate
]]
local function mouse_set_position(x: number, y: number)
    native.set_mouse_position(x, y)
end

--[[
    Performs a full mouse click (press and release) at the current position.
    @param button The mouse button to click
]]
local function mouse_click(button: types.MouseClick)
    local ok1 = pcall(native.mouse_click, button, true)
    if not ok1 then error("mouse_click down failed", 2) end
    task.wait(0.05)
    local ok2 = pcall(native.mouse_click, button, false)
    if not ok2 then error("mouse_click up failed", 2) end
end

--[[
    Presses and holds a mouse button at the current position.
    @param button The mouse button to press
]]
local function mouse_down(button: types.MouseClick)
    local ok = pcall(native.mouse_click, button, true)
    if not ok then error("mouse_down failed", 2) end
end

--[[
    Releases a previously pressed mouse button.
    @param button The mouse button to release
]]
local function mouse_up(button: types.MouseClick)
    local ok = pcall(native.mouse_click, button, false)
    if not ok then error("mouse_up failed", 2) end
end

--[[
    Scrolls the mouse wheel by the specified intensity.
    @param intensity The scroll amount (positive = down, negative = up)
    @param direction The scroll direction ("vertical" or "horizontal")
]]
local function mouse_scroll(intensity: number, direction: string)
    local ok = pcall(native.mouse_scroll, intensity, direction)
    if not ok then error("mouse_scroll failed", 2) end
end

--[[
    Simulates a keyboard key press or release event.
    @param key The key identifier string
    @param down Whether the key is pressed (true) or released (false)
]]
local function keyboard_event(key: string, down: boolean)
    local ok = pcall(native.keyboard_event, key, down)
    if not ok then error("keyboard_event failed", 2) end
end

--[[
    Types a string of text by simulating each key press.
    @param text The text to type
]]
local function keyboard_type(text: string)
    local ok = pcall(native.keyboard_type, text)
    if not ok then error("keyboard_type failed", 2) end
end

--[[
    Presses and releases a single key.
    @param key The key identifier string
]]
local function keyboard_press(key: string)
    local ok1 = pcall(native.keyboard_event, key, true)
    if not ok1 then error("keyboard_press down failed", 2) end
    task.wait(0.05)
    local ok2 = pcall(native.keyboard_event, key, false)
    if not ok2 then error("keyboard_press up failed", 2) end
end

--[[
    Gets the current text content of the system clipboard.
    @return The clipboard text
]]
local function clipboard_get_text(): string
    return native.clipboard_get_text()
end

--[[
    Sets the system clipboard text content.
    @param text The text to set in the clipboard
]]
local function clipboard_set_text(text: string)
    local ok = pcall(native.clipboard_set_text, text)
    if not ok then error("clipboard_set_text failed", 2) end
end

--[[
    Prepares an image template file for later use with find_image_on_screen.
    @param path The file path to the template image
]]
local function prepare_template_from_file(path: string)
    local ok = pcall(native.prepare_template_from_file, path)
    if not ok then error("prepare_template_from_file failed", 2) end
end

--[[
    Finds a prepared template image on the screen within the specified region.
    @param threshold The matching confidence threshold (0.0 to 1.0)
    @param region_x The left edge of the search region (default 0)
    @param region_y The top edge of the search region (default 0)
    @param region_w The width of the search region (default 0 = full width)
    @param region_h The height of the search region (default 0 = full height)
    @return A table with x and y coordinates of the match, or nil if not found
]]
local function find_image_on_screen(threshold: number, region_x: number?, region_y: number?, region_w: number?, region_h: number?): { x: number, y: number }?
    local rx, ry, rw, rh = region_x or 0, region_y or 0, region_w or 0, region_h or 0
    local ok, cx, cy = pcall(native.find_image_on_screen, threshold, rx, ry, rw, rh)
    if not ok then
        error("find_image_on_screen: " .. tostring(cx), 2)
    end
    if cx and cy then
        return { x = cx, y = cy }
    end
    return nil
end

--[[
    Brings the window with the specified title into focus.
    @param title The title of the window to focus
    @return Whether the window was found and focused
]]
local function focus_window(title: string): boolean
    local ok, result = pcall(native.focus_window, title)
    return if ok then result else false
end

--[[
    Checks whether a window with the specified title exists.
    @param title The title to search for
    @return Whether a matching window exists
]]
local function window_exists(title: string): boolean
    local ok, result = pcall(native.window_exists, title)
    return if ok then result else false
end

--[[
    Gets the currently active (foreground) window.
    @return A Window instance, or nil if no active window
]]
local function get_active_window(): types.Window?
    local ok, handle = pcall(native.get_active_window)
    if ok and handle then
        return Window.new(handle)
    end
    return nil
end

--[[
    Gets a list of all top-level windows on the desktop.
    @return A list of Window instances
]]
local function get_all_windows(): { types.Window }
    local handles = native.get_all_windows()
    local windows: { types.Window } = {}
    for _, handle in ipairs(handles) do
        table.insert(windows, Window.new(handle))
    end
    return windows
end

--[[
    Finds the first window whose title contains the given substring (case-insensitive).
    @param title_substring The substring to search for in window titles
    @return A Window instance, or nil if no match was found
]]
local function find_window(title_substring: string): types.Window?
    local handles = native.get_all_windows()
    for _, handle in ipairs(handles) do
        local ok, title = pcall(native.get_window_title, handle)
        if ok and string.find(string.lower(title), string.lower(title_substring), 1, true) then
            return Window.new(handle)
        end
    end
    return nil
end

--[[
    Gets the title of a window identified by its native handle.
    @param hwnd The native window handle
    @return The window title string
]]
local function window_get_title(hwnd: any): string
    local ok, title = pcall(native.get_window_title, hwnd)
    return if ok then title else ""
end

--[[
    Gets the position and size of a window identified by its native handle.
    @param hwnd The native window handle
    @return The x, y, width, and height of the window
]]
local function window_get_geometry(hwnd: any): (number, number, number, number)
    local ok, x, y, w, h = pcall(native.get_window_geometry, hwnd)
    if ok then return x, y, w, h end
    return 0, 0, 0, 0
end

--[[
    Sets the position and size of a window identified by its native handle.
    @param hwnd The native window handle
    @param x The new x-coordinate
    @param y The new y-coordinate
    @param w The new width
    @param h The new height
    @return Whether the operation succeeded
]]
local function window_set_geometry(hwnd: any, x: number, y: number, w: number, h: number): boolean
    local ok, result = pcall(native.set_window_geometry, hwnd, x, y, w, h)
    return if ok then result else false
end

--[[
    Sets the transparency level of a window identified by its native handle.
    @param hwnd The native window handle
    @param alpha Transparency value from 0 (fully transparent) to 255 (fully opaque)
    @return Whether the operation succeeded
]]
local function window_set_transparency(hwnd: any, alpha: number): boolean
    local ok, result = pcall(native.window_set_transparency, hwnd, alpha)
    return if ok then result else false
end

--[[
    Enables or disables click-through on a window identified by its native handle.
    @param hwnd The native window handle
    @param enabled Whether click-through should be enabled
    @return Whether the operation succeeded
]]
local function window_set_click_through(hwnd: any, enabled: boolean): boolean
    local ok, result = pcall(native.window_set_click_through, hwnd, enabled)
    return if ok then result else false
end

return {
    --[[ Enables or disables debug state. ]]
    change_debug_state = change_debug_state,
    --[[ Suppresses or re-enables native warning messages. ]]
    set_suppress_warnings = set_suppress_warnings,

    --[[ Gets the virtual screen size. ]]
    get_screen_size = get_screen_size,
    --[[ Captures a screenshot of the entire screen. ]]
    capture_screenshot = capture_screenshot,
    --[[ Saves a screenshot of a screen region to a file. ]]
    save_screenshot = save_screenshot,
    --[[ Gets the RGBA color of a single pixel. ]]
    get_pixel = get_pixel,
    --[[ Gets information about all connected monitors. ]]
    get_monitors = get_monitors,

    --[[ Gets the current mouse position. ]]
    mouse_get_position = mouse_get_position,
    --[[ Moves the mouse to the specified coordinates. ]]
    mouse_set_position = mouse_set_position,
    --[[ Performs a full mouse click (press + release). ]]
    mouse_click = mouse_click,
    --[[ Presses and holds a mouse button. ]]
    mouse_down = mouse_down,
    --[[ Releases a pressed mouse button. ]]
    mouse_up = mouse_up,
    --[[ Scrolls the mouse wheel. ]]
    mouse_scroll = mouse_scroll,

    --[[ Simulates a keyboard key event (press or release). ]]
    keyboard_event = keyboard_event,
    --[[ Types a string of text via simulated key presses. ]]
    keyboard_type = keyboard_type,
    --[[ Presses and releases a single key. ]]
    keyboard_press = keyboard_press,

    --[[ Gets text from the system clipboard. ]]
    clipboard_get_text = clipboard_get_text,
    --[[ Sets text in the system clipboard. ]]
    clipboard_set_text = clipboard_set_text,

    --[[ Prepares an image template for screen matching. ]]
    prepare_template_from_file = prepare_template_from_file,
    --[[ Finds a prepared template on screen within a region. ]]
    find_image_on_screen = find_image_on_screen,

    --[[ Brings a window by title into focus. ]]
    focus_window = focus_window,
    --[[ Checks whether a window by title exists. ]]
    window_exists = window_exists,
    --[[ Gets the currently active window. ]]
    get_active_window = get_active_window,
    --[[ Gets all top-level windows. ]]
    get_all_windows = get_all_windows,
    --[[ Finds the first window whose title contains the given substring. ]]
    find_window = find_window,

    --[[ Gets the title of a window by native handle. ]]
    window_get_title = window_get_title,
    --[[ Gets the geometry of a window by native handle. ]]
    window_get_geometry = window_get_geometry,
    --[[ Sets the geometry of a window by native handle. ]]
    window_set_geometry = window_set_geometry,
    --[[ Sets the transparency of a window by native handle. ]]
    window_set_transparency = window_set_transparency,
    --[[ Enables or disables click-through on a window by native handle. ]]
    window_set_click_through = window_set_click_through,

    --[[ Window module for creating and manipulating window objects. ]]
    Window = Window,
}
