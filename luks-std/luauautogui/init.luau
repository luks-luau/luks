--!strict

local types = require("@self/types")

export type MouseClick = types.MouseClick
export type Monitor = types.Monitor
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

-- Settings
local function change_debug_state(state: boolean)
    native.change_debug_state(state)
end

local function set_suppress_warnings(suppress: boolean)
    native.set_suppress_warnings(suppress)
end

-- Screen
local function get_screen_size(): (number, number)
    return native.get_screen_size()
end

local function capture_screenshot(): (buffer, number, number)
    local ok, buf, w, h = pcall(native.capture_screenshot)
    if not ok then
        error("capture_screenshot: " .. tostring(buf), 2)
    end
    return buf, w, h
end

local function save_screenshot(path: string, x: number?, y: number?, w: number?, h: number?)
    local sx, sy, sw, sh = x or 0, y or 0, w or 0, h or 0
    local ok = pcall(native.save_screenshot, path, sx, sy, sw, sh)
    if not ok then
        error("save_screenshot failed", 2)
    end
end

local function get_pixel(x: number, y: number): (number, number, number, number)
    local ok, r, g, b, a = pcall(native.get_pixel, x, y)
    if not ok then
        error("get_pixel: " .. tostring(r), 2)
    end
    return r, g, b, a
end

local function get_monitors(): { types.Monitor }
    return native.get_monitors()
end

-- Mouse
local function mouse_get_position(): (number, number)
    return native.get_mouse_position()
end

local function mouse_set_position(x: number, y: number)
    native.set_mouse_position(x, y)
end

local function mouse_click(button: types.MouseClick)
    local ok1 = pcall(native.mouse_click, button, true)
    if not ok1 then error("mouse_click down failed", 2) end
    task.wait(0.05)
    local ok2 = pcall(native.mouse_click, button, false)
    if not ok2 then error("mouse_click up failed", 2) end
end

local function mouse_down(button: types.MouseClick)
    local ok = pcall(native.mouse_click, button, true)
    if not ok then error("mouse_down failed", 2) end
end

local function mouse_up(button: types.MouseClick)
    local ok = pcall(native.mouse_click, button, false)
    if not ok then error("mouse_up failed", 2) end
end

local function mouse_scroll(intensity: number, direction: string)
    local ok = pcall(native.mouse_scroll, intensity, direction)
    if not ok then error("mouse_scroll failed", 2) end
end

-- Keyboard
local function keyboard_event(key: string, down: boolean)
    local ok = pcall(native.keyboard_event, key, down)
    if not ok then error("keyboard_event failed", 2) end
end

local function keyboard_type(text: string)
    local ok = pcall(native.keyboard_type, text)
    if not ok then error("keyboard_type failed", 2) end
end

local function keyboard_press(key: string)
    local ok1 = pcall(native.keyboard_event, key, true)
    if not ok1 then error("keyboard_press down failed", 2) end
    task.wait(0.05)
    local ok2 = pcall(native.keyboard_event, key, false)
    if not ok2 then error("keyboard_press up failed", 2) end
end

-- Clipboard
local function clipboard_get_text(): string
    return native.clipboard_get_text()
end

local function clipboard_set_text(text: string)
    local ok = pcall(native.clipboard_set_text, text)
    if not ok then error("clipboard_set_text failed", 2) end
end

-- Template matching
local function prepare_template_from_file(path: string)
    local ok = pcall(native.prepare_template_from_file, path)
    if not ok then error("prepare_template_from_file failed", 2) end
end

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

-- Window (by title)
local function focus_window(title: string): boolean
    local ok, result = pcall(native.focus_window, title)
    return if ok then result else false
end

local function window_exists(title: string): boolean
    local ok, result = pcall(native.window_exists, title)
    return if ok then result else false
end

local function get_active_window(): types.Window?
    local ok, handle = pcall(native.get_active_window)
    if ok and handle then
        return Window.new(handle)
    end
    return nil
end

local function get_all_windows(): { types.Window }
    local handles = native.get_all_windows()
    local windows: { types.Window } = {}
    for _, handle in ipairs(handles) do
        table.insert(windows, Window.new(handle))
    end
    return windows
end

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

-- Window (by handle) — raw operations returning lightuserdata
local function window_get_title(hwnd: any): string
    local ok, title = pcall(native.get_window_title, hwnd)
    return if ok then title else ""
end

local function window_get_geometry(hwnd: any): (number, number, number, number)
    local ok, x, y, w, h = pcall(native.get_window_geometry, hwnd)
    if ok then return x, y, w, h end
    return 0, 0, 0, 0
end

local function window_set_geometry(hwnd: any, x: number, y: number, w: number, h: number): boolean
    local ok, result = pcall(native.set_window_geometry, hwnd, x, y, w, h)
    return if ok then result else false
end

local function window_set_transparency(hwnd: any, alpha: number): boolean
    local ok, result = pcall(native.window_set_transparency, hwnd, alpha)
    return if ok then result else false
end

local function window_set_click_through(hwnd: any, enabled: boolean): boolean
    local ok, result = pcall(native.window_set_click_through, hwnd, enabled)
    return if ok then result else false
end

return {
    change_debug_state = change_debug_state,
    set_suppress_warnings = set_suppress_warnings,

    get_screen_size = get_screen_size,
    capture_screenshot = capture_screenshot,
    save_screenshot = save_screenshot,
    get_pixel = get_pixel,
    get_monitors = get_monitors,

    mouse_get_position = mouse_get_position,
    mouse_set_position = mouse_set_position,
    mouse_click = mouse_click,
    mouse_down = mouse_down,
    mouse_up = mouse_up,
    mouse_scroll = mouse_scroll,

    keyboard_event = keyboard_event,
    keyboard_type = keyboard_type,
    keyboard_press = keyboard_press,

    clipboard_get_text = clipboard_get_text,
    clipboard_set_text = clipboard_set_text,

    prepare_template_from_file = prepare_template_from_file,
    find_image_on_screen = find_image_on_screen,

    focus_window = focus_window,
    window_exists = window_exists,
    get_active_window = get_active_window,
    get_all_windows = get_all_windows,
    find_window = find_window,

    window_get_title = window_get_title,
    window_get_geometry = window_get_geometry,
    window_set_geometry = window_set_geometry,
    window_set_transparency = window_set_transparency,
    window_set_click_through = window_set_click_through,

    Window = Window,
}
