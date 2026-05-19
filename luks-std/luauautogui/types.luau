--!strict

export type MouseClick = "LEFT" | "RIGHT" | "MIDDLE"

export type Monitor = {
    x: number,
    y: number,
    width: number,
    height: number,
    primary: boolean,
}

export type Window = {
    _handle: any,
    _title: string,
    _valid: boolean,
    get_title: (self: Window) -> string,
    focus: (self: Window) -> boolean,
    close: (self: Window) -> boolean,
    minimize: (self: Window) -> boolean,
    maximize: (self: Window) -> boolean,
    restore: (self: Window) -> boolean,
    get_position: (self: Window) -> { x: number, y: number, w: number, h: number },
    set_position: (self: Window, x: number, y: number) -> boolean,
    set_size: (self: Window, w: number, h: number) -> boolean,
    is_visible: (self: Window) -> boolean,
    is_minimized: (self: Window) -> boolean,
    is_maximized: (self: Window) -> boolean,
    is_active: (self: Window) -> boolean,
    set_transparency: (self: Window, alpha: number) -> boolean,
    set_click_through: (self: Window, enabled: boolean) -> boolean,
}

return {}
