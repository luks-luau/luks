--!strict

export type MouseClick = "LEFT" | "RIGHT" | "MIDDLE"

export type Monitor = {
    --[[ The x-coordinate of the monitor's top-left corner in screen space. ]]
    x: number,
    --[[ The y-coordinate of the monitor's top-left corner in screen space. ]]
    y: number,
    --[[ The width of the monitor in pixels. ]]
    width: number,
    --[[ The height of the monitor in pixels. ]]
    height: number,
    --[[ Whether this monitor is the primary display. ]]
    primary: boolean,
}

export type Window = {
    --[[ Internal platform handle for the window. ]]
    _handle: any,
    --[[ Cached window title string. ]]
    _title: string,
    --[[ Whether this Window instance still refers to a valid window. ]]
    _valid: boolean,
    --[[
        Gets the window title.
        @param self The window instance
        @return The window title string
    ]]
    get_title: (self: Window) -> string,
    --[[
        Brings the window into focus.
        @param self The window instance
        @return Whether the focus operation succeeded
    ]]
    focus: (self: Window) -> boolean,
    --[[
        Closes the window.
        @param self The window instance
        @return Whether the close operation succeeded
    ]]
    close: (self: Window) -> boolean,
    --[[
        Minimizes the window to the taskbar.
        @param self The window instance
        @return Whether the minimize operation succeeded
    ]]
    minimize: (self: Window) -> boolean,
    --[[
        Maximizes the window to fill the screen.
        @param self The window instance
        @return Whether the maximize operation succeeded
    ]]
    maximize: (self: Window) -> boolean,
    --[[
        Restores the window from minimized or maximized state.
        @param self The window instance
        @return Whether the restore operation succeeded
    ]]
    restore: (self: Window) -> boolean,
    --[[
        Gets the position and size of the window.
        @param self The window instance
        @return A table containing x, y, w, h of the window
    ]]
    get_position: (self: Window) -> { x: number, y: number, w: number, h: number },
    --[[
        Moves the window to the specified screen coordinates.
        @param self The window instance
        @param x The new x-coordinate
        @param y The new y-coordinate
        @return Whether the repositioning succeeded
    ]]
    set_position: (self: Window, x: number, y: number) -> boolean,
    --[[
        Resizes the window to the specified dimensions.
        @param self The window instance
        @param w The new width
        @param h The new height
        @return Whether the resize succeeded
    ]]
    set_size: (self: Window, w: number, h: number) -> boolean,
    --[[
        Checks whether the window is visible.
        @param self The window instance
        @return Whether the window is visible
    ]]
    is_visible: (self: Window) -> boolean,
    --[[
        Checks whether the window is minimized.
        @param self The window instance
        @return Whether the window is minimized
    ]]
    is_minimized: (self: Window) -> boolean,
    --[[
        Checks whether the window is maximized.
        @param self The window instance
        @return Whether the window is maximized
    ]]
    is_maximized: (self: Window) -> boolean,
    --[[
        Checks whether the window is the active window.
        @param self The window instance
        @return Whether the window is active
    ]]
    is_active: (self: Window) -> boolean,
    --[[
        Sets the window transparency level.
        @param self The window instance
        @param alpha Transparency value from 0 (fully transparent) to 255 (fully opaque)
        @return Whether the transparency change succeeded
    ]]
    set_transparency: (self: Window, alpha: number) -> boolean,
    --[[
        Enables or disables click-through on the window.
        @param self The window instance
        @param enabled Whether click-through should be enabled
        @return Whether the change succeeded
    ]]
    set_click_through: (self: Window, enabled: boolean) -> boolean,
}

return {}
