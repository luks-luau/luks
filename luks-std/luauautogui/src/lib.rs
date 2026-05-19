#![allow(unsafe_op_in_unsafe_fn)]
#![allow(non_snake_case)]
#![allow(clippy::upper_case_acronyms)]

use luks_module_sys::*;
use std::fs::File;
use std::io::Write;
use std::sync::Mutex;

static DEBUG_STATE: Mutex<bool> = Mutex::new(false);
static SUPPRESS_WARNINGS: Mutex<bool> = Mutex::new(false);

struct Template {
    width: u32,
    height: u32,
    pixels: Vec<u32>,
}
static TEMPLATE: Mutex<Option<Template>> = Mutex::new(None);

fn log_debug(msg: &str) {
    if let Ok(debug) = DEBUG_STATE.lock()
        && *debug
    {
        println!("[luauautogui] {}", msg);
    }
}

fn log_warning(msg: &str) {
    if let Ok(suppress) = SUPPRESS_WARNINGS.lock()
        && !*suppress
    {
        eprintln!("[luauautogui Warning] {}", msg);
    }
}

unsafe fn lua_error_msg(l: *mut lua_State, msg: &str) -> ! {
    let c_msg = std::ffi::CString::new(msg).unwrap_or_default();
    lua_pushstring(l, c_msg.as_ptr());
    lua_error(l);
}

#[cfg(target_os = "windows")]
mod win32 {
    #![allow(clippy::upper_case_acronyms)]
    #![allow(dead_code)]
    use std::ffi::c_void;

    #[repr(C)]
    #[derive(Clone, Copy)]
    pub struct POINT {
        pub x: i32,
        pub y: i32,
    }

    #[repr(C)]
    #[allow(dead_code)]
    pub struct BITMAPFILEHEADER {
        pub bfType: u16,
        pub bfSize: u32,
        pub bfReserved1: u16,
        pub bfReserved2: u16,
        pub bfOffBits: u32,
    }

    #[repr(C)]
    pub struct BITMAPINFOHEADER {
        pub biSize: u32,
        pub biWidth: i32,
        pub biHeight: i32,
        pub biPlanes: u16,
        pub biBitCount: u16,
        pub biCompression: u32,
        pub biSizeImage: u32,
        pub biXPelsPerMeter: i32,
        pub biYPelsPerMeter: i32,
        pub biClrUsed: u32,
        pub biClrImportant: u32,
    }

    #[repr(C)]
    pub struct BITMAPINFO {
        pub bmiHeader: BITMAPINFOHEADER,
        pub bmiColors: [u32; 1],
    }

    #[repr(C)]
    #[derive(Clone, Copy)]
    pub struct MOUSEINPUT {
        pub dx: i32,
        pub dy: i32,
        pub mouseData: u32,
        pub dwFlags: u32,
        pub time: u32,
        pub dwExtraInfo: usize,
    }

    #[repr(C)]
    #[derive(Clone, Copy)]
    pub struct KEYBDINPUT {
        pub wVk: u16,
        pub wScan: u16,
        pub dwFlags: u32,
        pub time: u32,
        pub dwExtraInfo: usize,
    }

    #[repr(C)]
    #[derive(Clone, Copy)]
    pub struct HARDWAREINPUT {
        pub uMsg: u32,
        pub wParamL: u16,
        pub wParamH: u16,
    }

    #[repr(C)]
    pub union INPUT_UNION {
        pub mi: MOUSEINPUT,
        pub ki: KEYBDINPUT,
        pub hi: HARDWAREINPUT,
    }

    #[repr(C)]
    pub struct INPUT {
        pub r#type: u32,
        pub Anonymous: INPUT_UNION,
    }

    pub const INPUT_KEYBOARD: u32 = 1;
    pub const KEYEVENTF_UNICODE: u32 = 0x0004;

    #[link(name = "user32")]
    unsafe extern "system" {
        pub fn GetCursorPos(lpPoint: *mut POINT) -> i32;
        pub fn SetCursorPos(X: i32, Y: i32) -> i32;
        pub fn mouse_event(dwFlags: u32, dx: i32, dy: i32, dwData: u32, dwExtraInfo: usize);
        pub fn keybd_event(bVk: u8, bScan: u8, dwFlags: u32, dwExtraInfo: usize);
        pub fn SendInput(cInputs: u32, pInputs: *mut INPUT, cbSize: i32) -> u32;
        pub fn GetSystemMetrics(nIndex: i32) -> i32;
        pub fn GetDC(hWnd: *mut c_void) -> *mut c_void;
        pub fn ReleaseDC(hWnd: *mut c_void, hDC: *mut c_void) -> i32;
        pub fn EnumWindows(
            lpEnumFunc: unsafe extern "system" fn(*mut c_void, isize) -> i32,
            lParam: isize,
        ) -> i32;
        pub fn GetWindowTextW(hWnd: *mut c_void, lpString: *mut u16, nMaxCount: i32) -> i32;
        pub fn IsWindowVisible(hWnd: *mut c_void) -> i32;
        pub fn SetForegroundWindow(hWnd: *mut c_void) -> i32;
        pub fn ShowWindow(hWnd: *mut c_void, nCmdShow: i32) -> i32;
        pub fn IsIconic(hWnd: *mut c_void) -> i32;
        pub fn SetFocus(hWnd: *mut c_void) -> *mut c_void;
        pub fn AttachThreadInput(idAttach: u32, idAttachTo: u32, fAttach: i32) -> i32;
        pub fn GetWindowThreadProcessId(hWnd: *mut c_void, lpdwProcessId: *mut u32) -> u32;
        pub fn GetForegroundWindow() -> *mut c_void;
        pub fn GetWindowRect(hWnd: *mut c_void, lpRect: *mut RECT) -> i32;
        pub fn MoveWindow(
            hWnd: *mut c_void,
            X: i32,
            Y: i32,
            nWidth: i32,
            nHeight: i32,
            bRepaint: i32,
        ) -> i32;
        pub fn PostMessageW(hWnd: *mut c_void, Msg: u32, wParam: usize, lParam: isize) -> i32;
        pub fn IsZoomed(hWnd: *mut c_void) -> i32;
        pub fn GetPixel(hdc: *mut c_void, x: i32, y: i32) -> u32;
        pub fn GetDesktopWindow() -> *mut c_void;
        pub fn OpenClipboard(hWndNewOwner: *mut c_void) -> i32;
        pub fn CloseClipboard() -> i32;
        pub fn GetClipboardData(uFormat: u32) -> *mut c_void;
        pub fn SetClipboardData(uFormat: u32, hMem: *mut c_void) -> *mut c_void;
        pub fn EmptyClipboard() -> i32;
        pub fn GlobalAlloc(uFlags: u32, dwBytes: usize) -> *mut c_void;
        pub fn GlobalLock(hMem: *mut c_void) -> *mut c_void;
        pub fn GlobalUnlock(hMem: *mut c_void) -> i32;
        pub fn GlobalSize(hMem: *mut c_void) -> usize;
        pub fn EnumDisplayMonitors(
            hdc: *mut c_void,
            lprcClip: *mut c_void,
            lpEnumFunc: unsafe extern "system" fn(*mut c_void, *mut c_void, *mut RECT, isize) -> i32,
            dwData: isize,
        ) -> i32;
        pub fn GetWindowLongA(hWnd: *mut c_void, nIndex: i32) -> i32;
        pub fn SetWindowLongA(hWnd: *mut c_void, nIndex: i32, dwNewLong: i32) -> i32;
        pub fn SetLayeredWindowAttributes(
            hWnd: *mut c_void,
            crKey: u32,
            bAlpha: u8,
            dwFlags: u32,
        ) -> i32;
    }

    #[link(name = "kernel32")]
    unsafe extern "system" {
        pub fn GetCurrentThreadId() -> u32;
        pub fn GetLastError() -> u32;
        pub fn FormatMessageW(
            dwFlags: u32,
            lpSource: *mut c_void,
            dwMessageId: u32,
            dwLanguageId: u32,
            lpBuffer: *mut u16,
            nSize: u32,
            Arguments: *mut c_void,
        ) -> u32;
    }

    #[link(name = "gdi32")]
    unsafe extern "system" {
        pub fn CreateCompatibleDC(hDC: *mut c_void) -> *mut c_void;
        pub fn CreateCompatibleBitmap(hDC: *mut c_void, cx: i32, cy: i32) -> *mut c_void;
        pub fn SelectObject(hDC: *mut c_void, h: *mut c_void) -> *mut c_void;
        pub fn BitBlt(
            hdcDest: *mut c_void,
            xDest: i32,
            yDest: i32,
            w: i32,
            h: i32,
            hdcSrc: *mut c_void,
            xSrc: i32,
            ySrc: i32,
            rop: u32,
        ) -> i32;
        pub fn DeleteDC(hDC: *mut c_void) -> i32;
        pub fn DeleteObject(ho: *mut c_void) -> i32;
        pub fn GetDIBits(
            hdc: *mut c_void,
            hbm: *mut c_void,
            start: u32,
            cLines: u32,
            lpvBits: *mut c_void,
            lpbmi: *mut BITMAPINFO,
            usage: u32,
        ) -> i32;
    }

    pub const FORMAT_MESSAGE_FROM_SYSTEM: u32 = 0x00001000;
    pub const FORMAT_MESSAGE_ALLOCATE_BUFFER: u32 = 0x00000100;
    pub const FORMAT_MESSAGE_IGNORE_INSERTS: u32 = 0x00000200;
    pub const LANG_NEUTRAL: u32 = 0x0000;
    pub const MAKELANGID: fn(u32, u32) -> u32 = |p, s| (p << 10) | s;

    pub fn get_last_error_string() -> String {
        unsafe {
            let err = GetLastError();
            let mut buf_ptr: *mut u16 = std::ptr::null_mut();
            let flags = FORMAT_MESSAGE_FROM_SYSTEM
                | FORMAT_MESSAGE_ALLOCATE_BUFFER
                | FORMAT_MESSAGE_IGNORE_INSERTS;
            let len = FormatMessageW(
                flags,
                std::ptr::null_mut(),
                err,
                MAKELANGID(LANG_NEUTRAL, 0),
                &mut buf_ptr as *mut *mut u16 as *mut u16,
                0,
                std::ptr::null_mut(),
            );
            if len > 0 && !buf_ptr.is_null() {
                let msg = String::from_utf16_lossy(std::slice::from_raw_parts(buf_ptr, len as usize));
                let _ = GlobalFree(buf_ptr as *mut c_void);
                msg.trim().to_string()
            } else {
                format!("Error code {}", err)
            }
        }
    }

    #[link(name = "kernel32")]
    unsafe extern "system" {
        pub fn GlobalFree(hMem: *mut c_void) -> *mut c_void;
    }

    #[repr(C)]
    #[derive(Clone, Copy)]
    pub struct RECT {
        pub left: i32,
        pub top: i32,
        pub right: i32,
        pub bottom: i32,
    }

    pub const WM_CLOSE: u32 = 0x0010;

    pub const MOUSEEVENTF_MOVE: u32 = 0x0001;
    pub const MOUSEEVENTF_LEFTDOWN: u32 = 0x0002;
    pub const MOUSEEVENTF_LEFTUP: u32 = 0x0004;
    pub const MOUSEEVENTF_RIGHTDOWN: u32 = 0x0008;
    pub const MOUSEEVENTF_RIGHTUP: u32 = 0x0010;
    pub const MOUSEEVENTF_MIDDLEDOWN: u32 = 0x0020;
    pub const MOUSEEVENTF_MIDDLEUP: u32 = 0x0040;
    pub const MOUSEEVENTF_WHEEL: u32 = 0x0800;
    pub const MOUSEEVENTF_HWHEEL: u32 = 0x1000;

    pub const KEYEVENTF_KEYUP: u32 = 0x0002;

    pub const SM_CXSCREEN: i32 = 0;
    pub const SM_CYSCREEN: i32 = 1;

    pub const SRCCOPY: u32 = 0x00CC0020;
    pub const DIB_RGB_COLORS: u32 = 0;

    pub const CF_UNICODETEXT: u32 = 13;
    pub const GMEM_MOVEABLE: u32 = 0x0002;

    pub fn get_mouse_position_raw() -> (i32, i32) {
        let mut pt = POINT { x: 0, y: 0 };
        unsafe {
            if GetCursorPos(&mut pt) != 0 {
                (pt.x, pt.y)
            } else {
                (0, 0)
            }
        }
    }

    pub fn set_mouse_position_raw(x: i32, y: i32) {
        unsafe {
            SetCursorPos(x, y);
        }
    }

    pub fn get_screen_size_raw() -> (i32, i32) {
        unsafe {
            let cx = GetSystemMetrics(SM_CXSCREEN);
            let cy = GetSystemMetrics(SM_CYSCREEN);
            (cx, cy)
        }
    }

    pub fn mouse_click_raw(button: &str, down: bool) -> Result<(), &'static str> {
        let flags = match (button, down) {
            ("LEFT", true) => MOUSEEVENTF_LEFTDOWN,
            ("LEFT", false) => MOUSEEVENTF_LEFTUP,
            ("RIGHT", true) => MOUSEEVENTF_RIGHTDOWN,
            ("RIGHT", false) => MOUSEEVENTF_RIGHTUP,
            ("MIDDLE", true) => MOUSEEVENTF_MIDDLEDOWN,
            ("MIDDLE", false) => MOUSEEVENTF_MIDDLEUP,
            _ => return Err("invalid mouse button, use LEFT, RIGHT, or MIDDLE"),
        };
        unsafe {
            mouse_event(flags, 0, 0, 0, 0);
        }
        Ok(())
    }

    pub fn mouse_scroll_raw(intensity: u32, direction: &str) -> Result<(), &'static str> {
        let (flags, data) = match direction {
            "UP" => (MOUSEEVENTF_WHEEL, intensity as i32 * 120),
            "DOWN" => (MOUSEEVENTF_WHEEL, -(intensity as i32 * 120)),
            _ => return Err("invalid scroll direction, use UP or DOWN"),
        };
        unsafe {
            mouse_event(flags, 0, 0, data as u32, 0);
        }
        Ok(())
    }

    pub fn keyboard_event_raw(vk: u8, up: bool) {
        let flags = if up { KEYEVENTF_KEYUP } else { 0 };
        unsafe {
            keybd_event(vk, 0, flags, 0);
        }
    }

    pub fn keyboard_type_raw(text: &str) {
        let utf16: Vec<u16> = text.encode_utf16().collect();
        for &ch in &utf16 {
            unsafe {
                let mut inputs: [INPUT; 2] = [
                    INPUT {
                        r#type: INPUT_KEYBOARD,
                        Anonymous: INPUT_UNION {
                            ki: KEYBDINPUT {
                                wVk: 0,
                                wScan: ch,
                                dwFlags: KEYEVENTF_UNICODE,
                                time: 0,
                                dwExtraInfo: 0,
                            },
                        },
                    },
                    INPUT {
                        r#type: INPUT_KEYBOARD,
                        Anonymous: INPUT_UNION {
                            ki: KEYBDINPUT {
                                wVk: 0,
                                wScan: ch,
                                dwFlags: KEYEVENTF_UNICODE | KEYEVENTF_KEYUP,
                                time: 0,
                                dwExtraInfo: 0,
                            },
                        },
                    },
                ];
                SendInput(2, inputs.as_mut_ptr(), std::mem::size_of::<INPUT>() as i32);
            }
        }
    }

    pub fn capture_screen_raw(x: i32, y: i32, w: i32, h: i32) -> Option<(u32, u32, Vec<u32>)> {
        unsafe {
            let hdc_screen = GetDC(std::ptr::null_mut());
            if hdc_screen.is_null() {
                return None;
            }
            let hdc_mem = CreateCompatibleDC(hdc_screen);
            if hdc_mem.is_null() {
                ReleaseDC(std::ptr::null_mut(), hdc_screen);
                return None;
            }

            let hbmp = CreateCompatibleBitmap(hdc_screen, w, h);
            if hbmp.is_null() {
                DeleteDC(hdc_mem);
                ReleaseDC(std::ptr::null_mut(), hdc_screen);
                return None;
            }

            let hbmp_old = SelectObject(hdc_mem, hbmp);
            BitBlt(hdc_mem, 0, 0, w, h, hdc_screen, x, y, SRCCOPY);

            let mut bmi = BITMAPINFO {
                bmiHeader: BITMAPINFOHEADER {
                    biSize: std::mem::size_of::<BITMAPINFOHEADER>() as u32,
                    biWidth: w,
                    biHeight: -h,
                    biPlanes: 1,
                    biBitCount: 32,
                    biCompression: 0,
                    biSizeImage: 0,
                    biXPelsPerMeter: 0,
                    biYPelsPerMeter: 0,
                    biClrUsed: 0,
                    biClrImportant: 0,
                },
                bmiColors: [0],
            };

            let mut pixels = vec![0u32; (w * h) as usize];
            let res = GetDIBits(
                hdc_mem,
                hbmp,
                0,
                h as u32,
                pixels.as_mut_ptr() as *mut c_void,
                &mut bmi,
                DIB_RGB_COLORS,
            );

            SelectObject(hdc_mem, hbmp_old);
            DeleteObject(hbmp);
            DeleteDC(hdc_mem);
            ReleaseDC(std::ptr::null_mut(), hdc_screen);

            if res > 0 {
                Some((w as u32, h as u32, pixels))
            } else {
                None
            }
        }
    }

    pub fn get_pixel_raw(x: i32, y: i32) -> Option<(u8, u8, u8, u8)> {
        unsafe {
            let hdc = GetDC(std::ptr::null_mut());
            if hdc.is_null() {
                return None;
            }
            let color = GetPixel(hdc, x, y);
            ReleaseDC(std::ptr::null_mut(), hdc);
            if color == 0xFFFFFFFF {
                return None;
            }
            let r = (color >> 0) as u8;
            let g = (color >> 8) as u8;
            let b = (color >> 16) as u8;
            let a = 0xFF;
            Some((r, g, b, a))
        }
    }

    pub fn get_monitors_raw() -> Vec<(i32, i32, i32, i32, bool)> {
        struct MonContext {
            monitors: Vec<(i32, i32, i32, i32, bool)>,
        }
        unsafe extern "system" fn enum_mon_callback(
            _hmon: *mut c_void,
            _hdc: *mut c_void,
            rect: *mut RECT,
            lparam: isize,
        ) -> i32 {
            let ctx = &mut *(lparam as *mut MonContext);
            let r = &*rect;
            ctx.monitors.push((
                r.left, r.top, r.right - r.left, r.bottom - r.top, false,
            ));
            1
        }
        let mut ctx = MonContext {
            monitors: Vec::new(),
        };
        unsafe {
            EnumDisplayMonitors(
                std::ptr::null_mut(),
                std::ptr::null_mut(),
                enum_mon_callback,
                &mut ctx as *mut MonContext as isize,
            );
        }
        // Mark first monitor as primary
        if let Some(ref mut m) = ctx.monitors.first_mut() {
            m.4 = true;
        }
        ctx.monitors
    }

    pub fn clipboard_get_text_raw() -> Option<String> {
        unsafe {
            if OpenClipboard(std::ptr::null_mut()) == 0 {
                return None;
            }
            let handle = GetClipboardData(CF_UNICODETEXT);
            if handle.is_null() {
                CloseClipboard();
                return None;
            }
            let locked = GlobalLock(handle);
            if locked.is_null() {
                CloseClipboard();
                return None;
            }
            let size = GlobalSize(handle);
            if size > 0 {
                let slice = std::slice::from_raw_parts(locked as *const u16, size / 2 - 1);
                let text = String::from_utf16_lossy(slice);
                GlobalUnlock(handle);
                CloseClipboard();
                Some(text)
            } else {
                GlobalUnlock(handle);
                CloseClipboard();
                Some(String::new())
            }
        }
    }

    pub fn clipboard_set_text_raw(text: &str) -> bool {
        unsafe {
            if OpenClipboard(std::ptr::null_mut()) == 0 {
                return false;
            }
            EmptyClipboard();
            let utf16: Vec<u16> = text.encode_utf16().chain(std::iter::once(0)).collect();
            let bytes = utf16.len() * 2;
            let hmem = GlobalAlloc(GMEM_MOVEABLE, bytes);
            if hmem.is_null() {
                CloseClipboard();
                return false;
            }
            let locked = GlobalLock(hmem);
            if locked.is_null() {
                CloseClipboard();
                return false;
            }
            std::ptr::copy_nonoverlapping(utf16.as_ptr(), locked as *mut u16, utf16.len());
            GlobalUnlock(hmem);
            let result = SetClipboardData(CF_UNICODETEXT, hmem);
            CloseClipboard();
            !result.is_null()
        }
    }

    struct EnumContext {
        title_substring: String,
        found_hwnd: *mut c_void,
    }

    unsafe extern "system" fn enum_windows_callback(hwnd: *mut c_void, lparam: isize) -> i32 {
        let ctx = &mut *(lparam as *mut EnumContext);
        let mut buffer = [0u16; 512];
        let len = GetWindowTextW(hwnd, buffer.as_mut_ptr(), 512);
        if len > 0 {
            let title = String::from_utf16_lossy(&buffer[..len as usize]);
            if title
                .to_lowercase()
                .contains(&ctx.title_substring.to_lowercase())
                && IsWindowVisible(hwnd) != 0
            {
                ctx.found_hwnd = hwnd;
                return 0;
            }
        }
        1
    }

    pub fn focus_window_raw(title_substring: &str) -> bool {
        unsafe {
            let mut ctx = EnumContext {
                title_substring: title_substring.to_string(),
                found_hwnd: std::ptr::null_mut(),
            };
            EnumWindows(enum_windows_callback, &mut ctx as *mut EnumContext as isize);

            let hwnd = ctx.found_hwnd;
            if hwnd.is_null() {
                return false;
            }

            if IsIconic(hwnd) != 0 {
                ShowWindow(hwnd, 9);
            }
            ShowWindow(hwnd, 5);

            let fg_hwnd = GetForegroundWindow();
            if fg_hwnd != hwnd {
                let fg_thread = GetWindowThreadProcessId(fg_hwnd, std::ptr::null_mut());
                let current_thread = GetCurrentThreadId();

                if fg_thread != current_thread {
                    AttachThreadInput(current_thread, fg_thread, 1);
                    SetForegroundWindow(hwnd);
                    SetFocus(hwnd);
                    AttachThreadInput(current_thread, fg_thread, 0);
                } else {
                    SetForegroundWindow(hwnd);
                    SetFocus(hwnd);
                }

                if GetForegroundWindow() != hwnd {
                    mouse_event(0, 0, 0, 0, 0);
                    keybd_event(18, 0, 0, 0);
                    SetForegroundWindow(hwnd);
                    keybd_event(18, 0, 2, 0);
                }
            } else {
                SetForegroundWindow(hwnd);
                SetFocus(hwnd);
            }
            true
        }
    }

    pub fn window_exists_raw(title_substring: &str) -> bool {
        unsafe {
            let mut ctx = EnumContext {
                title_substring: title_substring.to_string(),
                found_hwnd: std::ptr::null_mut(),
            };
            EnumWindows(enum_windows_callback, &mut ctx as *mut EnumContext as isize);
            !ctx.found_hwnd.is_null()
        }
    }

    pub fn get_active_window_raw() -> *mut c_void {
        unsafe { GetForegroundWindow() }
    }

    pub fn get_all_windows_raw() -> Vec<*mut c_void> {
        struct ListContext {
            hwnds: Vec<*mut c_void>,
        }
        unsafe extern "system" fn list_windows_callback(hwnd: *mut c_void, lparam: isize) -> i32 {
            let ctx = &mut *(lparam as *mut ListContext);
            if IsWindowVisible(hwnd) != 0 {
                ctx.hwnds.push(hwnd);
            }
            1
        }
        let mut ctx = ListContext { hwnds: Vec::new() };
        unsafe {
            EnumWindows(list_windows_callback, &mut ctx as *mut ListContext as isize);
        }
        ctx.hwnds
    }

    pub fn get_window_title_raw(hwnd: *mut c_void) -> String {
        let mut buffer = [0u16; 512];
        unsafe {
            let len = GetWindowTextW(hwnd, buffer.as_mut_ptr(), 512);
            if len > 0 {
                String::from_utf16_lossy(&buffer[..len as usize])
            } else {
                String::new()
            }
        }
    }

    pub fn focus_window_by_handle_raw(hwnd: *mut c_void) -> bool {
        unsafe {
            if hwnd.is_null() {
                return false;
            }
            if IsIconic(hwnd) != 0 {
                ShowWindow(hwnd, 9);
            }
            ShowWindow(hwnd, 5);

            let fg_hwnd = GetForegroundWindow();
            if fg_hwnd != hwnd {
                let fg_thread = GetWindowThreadProcessId(fg_hwnd, std::ptr::null_mut());
                let current_thread = GetCurrentThreadId();

                if fg_thread != current_thread {
                    AttachThreadInput(current_thread, fg_thread, 1);
                    SetForegroundWindow(hwnd);
                    SetFocus(hwnd);
                    AttachThreadInput(current_thread, fg_thread, 0);
                } else {
                    SetForegroundWindow(hwnd);
                    SetFocus(hwnd);
                }

                if GetForegroundWindow() != hwnd {
                    mouse_event(0, 0, 0, 0, 0);
                    keybd_event(18, 0, 0, 0);
                    SetForegroundWindow(hwnd);
                    keybd_event(18, 0, 2, 0);
                }
            } else {
                SetForegroundWindow(hwnd);
                SetFocus(hwnd);
            }
            true
        }
    }

    pub fn close_window_raw(hwnd: *mut c_void) -> bool {
        unsafe {
            if hwnd.is_null() {
                return false;
            }
            PostMessageW(hwnd, WM_CLOSE, 0, 0) != 0
        }
    }

    pub fn minimize_window_raw(hwnd: *mut c_void) -> bool {
        unsafe {
            if hwnd.is_null() {
                return false;
            }
            ShowWindow(hwnd, 6) != 0
        }
    }

    pub fn maximize_window_raw(hwnd: *mut c_void) -> bool {
        unsafe {
            if hwnd.is_null() {
                return false;
            }
            ShowWindow(hwnd, 3) != 0
        }
    }

    pub fn restore_window_raw(hwnd: *mut c_void) -> bool {
        unsafe {
            if hwnd.is_null() {
                return false;
            }
            ShowWindow(hwnd, 9) != 0
        }
    }

    pub fn get_window_geometry_raw(hwnd: *mut c_void) -> (i32, i32, i32, i32) {
        unsafe {
            if hwnd.is_null() {
                return (0, 0, 0, 0);
            }
            let mut rect = RECT {
                left: 0,
                top: 0,
                right: 0,
                bottom: 0,
            };
            if GetWindowRect(hwnd, &mut rect) != 0 {
                let x = rect.left;
                let y = rect.top;
                let w = rect.right - rect.left;
                let h = rect.bottom - rect.top;
                (x, y, w, h)
            } else {
                (0, 0, 0, 0)
            }
        }
    }

    pub fn set_window_geometry_raw(hwnd: *mut c_void, x: i32, y: i32, w: i32, h: i32) -> bool {
        unsafe {
            if hwnd.is_null() {
                return false;
            }
            MoveWindow(hwnd, x, y, w, h, 1) != 0
        }
    }

    pub fn is_window_minimized_raw(hwnd: *mut c_void) -> bool {
        unsafe {
            if hwnd.is_null() {
                return false;
            }
            IsIconic(hwnd) != 0
        }
    }

    pub fn is_window_maximized_raw(hwnd: *mut c_void) -> bool {
        unsafe {
            if hwnd.is_null() {
                return false;
            }
            IsZoomed(hwnd) != 0
        }
    }

    pub fn is_window_visible_raw(hwnd: *mut c_void) -> bool {
        unsafe {
            if hwnd.is_null() {
                return false;
            }
            IsWindowVisible(hwnd) != 0
        }
    }

    const GWL_EXSTYLE: i32 = -20;
    const WS_EX_LAYERED: i32 = 0x80000;
    const WS_EX_TRANSPARENT: i32 = 0x20;
    const LWA_ALPHA: u32 = 0x2;

    pub fn window_set_transparency_raw(hwnd: *mut c_void, alpha: u8) -> bool {
        unsafe {
            if hwnd.is_null() {
                return false;
            }
            let style = GetWindowLongA(hwnd, GWL_EXSTYLE);
            SetWindowLongA(hwnd, GWL_EXSTYLE, style | WS_EX_LAYERED);
            SetLayeredWindowAttributes(hwnd, 0, alpha, LWA_ALPHA) != 0
        }
    }

    pub fn window_set_click_through_raw(hwnd: *mut c_void, enabled: bool) -> bool {
        unsafe {
            if hwnd.is_null() {
                return false;
            }
            let style = GetWindowLongA(hwnd, GWL_EXSTYLE);
            if enabled {
                SetWindowLongA(hwnd, GWL_EXSTYLE, style | WS_EX_LAYERED | WS_EX_TRANSPARENT);
            } else {
                SetWindowLongA(hwnd, GWL_EXSTYLE, style & !(WS_EX_LAYERED | WS_EX_TRANSPARENT));
            }
            true
        }
    }
}

#[cfg(not(target_os = "windows"))]
mod win32 {
    pub fn get_mouse_position_raw() -> (i32, i32) {
        (0, 0)
    }
    pub fn set_mouse_position_raw(_x: i32, _y: i32) {}
    pub fn get_screen_size_raw() -> (i32, i32) {
        (1920, 1080)
    }
    pub fn mouse_click_raw(_button: &str, _down: bool) -> Result<(), &'static str> {
        Ok(())
    }
    pub fn mouse_scroll_raw(_intensity: u32, _direction: &str) -> Result<(), &'static str> {
        Ok(())
    }
    pub fn keyboard_event_raw(_vk: u8, _up: bool) {}
    pub fn keyboard_type_raw(_text: &str) {}
    pub fn capture_screen_raw(_x: i32, _y: i32, _w: i32, _h: i32) -> Option<(u32, u32, Vec<u32>)> {
        None
    }
    pub fn get_pixel_raw(_x: i32, _y: i32) -> Option<(u8, u8, u8, u8)> {
        None
    }
    pub fn get_monitors_raw() -> Vec<(i32, i32, i32, i32, bool)> {
        vec![(0, 0, 1920, 1080, true)]
    }
    pub fn clipboard_get_text_raw() -> Option<String> {
        None
    }
    pub fn clipboard_set_text_raw(_text: &str) -> bool {
        false
    }
    pub fn focus_window_raw(_title_substring: &str) -> bool {
        false
    }
    pub fn window_exists_raw(_title_substring: &str) -> bool {
        false
    }
    pub fn get_active_window_raw() -> *mut std::ffi::c_void {
        std::ptr::null_mut()
    }
    pub fn get_all_windows_raw() -> Vec<*mut std::ffi::c_void> {
        Vec::new()
    }
    pub fn get_window_title_raw(_hwnd: *mut std::ffi::c_void) -> String {
        String::new()
    }
    pub fn focus_window_by_handle_raw(_hwnd: *mut std::ffi::c_void) -> bool {
        false
    }
    pub fn close_window_raw(_hwnd: *mut std::ffi::c_void) -> bool {
        false
    }
    pub fn minimize_window_raw(_hwnd: *mut std::ffi::c_void) -> bool {
        false
    }
    pub fn maximize_window_raw(_hwnd: *mut std::ffi::c_void) -> bool {
        false
    }
    pub fn restore_window_raw(_hwnd: *mut std::ffi::c_void) -> bool {
        false
    }
    pub fn get_window_geometry_raw(_hwnd: *mut std::ffi::c_void) -> (i32, i32, i32, i32) {
        (0, 0, 0, 0)
    }
    pub fn set_window_geometry_raw(_hwnd: *mut std::ffi::c_void, _x: i32, _y: i32, _w: i32, _h: i32) -> bool {
        false
    }
    pub fn is_window_minimized_raw(_hwnd: *mut std::ffi::c_void) -> bool {
        false
    }
    pub fn is_window_maximized_raw(_hwnd: *mut std::ffi::c_void) -> bool {
        false
    }
    pub fn is_window_visible_raw(_hwnd: *mut std::ffi::c_void) -> bool {
        false
    }
    pub fn window_set_transparency_raw(_hwnd: *mut std::ffi::c_void, _alpha: u8) -> bool {
        false
    }
    pub fn window_set_click_through_raw(_hwnd: *mut std::ffi::c_void, _enabled: bool) -> bool {
        false
    }
}

fn get_vk_code(key: &str) -> u8 {
    let lower = key.to_lowercase();
    match lower.as_str() {
        "enter" | "return" => 0x0D,
        "space" => 0x20,
        "control" | "ctrl" => 0x11,
        "alt" => 0x12,
        "shift" => 0x10,
        "win" | "command" | "super" => 0x5B,
        "backspace" => 0x08,
        "tab" => 0x09,
        "escape" | "esc" => 0x1B,
        "up" => 0x26,
        "down" => 0x28,
        "left" => 0x25,
        "right" => 0x27,
        _ => {
            if key.len() == 1 {
                let c = key.as_bytes()[0];
                if c.is_ascii_alphabetic() {
                    c.to_ascii_uppercase()
                } else if c.is_ascii_digit() {
                    c
                } else if c == b' ' {
                    0x20
                } else if c == b'-' {
                    0xBD
                } else if c == b'=' {
                    0xBB
                } else if c == b',' {
                    0xBC
                } else if c == b'.' {
                    0xBE
                } else if c == b'/' {
                    0xBF
                } else if c == b';' {
                    0xBA
                } else if c == b'\'' {
                    0xDE
                } else if c == b'[' {
                    0xDB
                } else if c == b']' {
                    0xDD
                } else if c == b'\\' {
                    0xDC
                } else if c == b'`' {
                    0xC0
                } else {
                    0
                }
            } else {
                0
            }
        }
    }
}

fn save_bmp(path: &str, width: u32, height: u32, pixels: &[u32]) -> std::io::Result<()> {
    let mut file = File::create(path)?;
    let file_header_size = 14;
    let info_header_size = 40;
    let pixel_data_size = width * height * 4;
    let total_file_size = file_header_size + info_header_size + pixel_data_size;

    file.write_all(b"BM")?;
    file.write_all(&total_file_size.to_le_bytes())?;
    file.write_all(&0u16.to_le_bytes())?;
    file.write_all(&0u16.to_le_bytes())?;
    file.write_all(&(file_header_size + info_header_size).to_le_bytes())?;

    file.write_all(&info_header_size.to_le_bytes())?;
    file.write_all(&(width as i32).to_le_bytes())?;
    file.write_all(&(-(height as i32)).to_le_bytes())?;
    file.write_all(&1u16.to_le_bytes())?;
    file.write_all(&32u16.to_le_bytes())?;
    file.write_all(&0u32.to_le_bytes())?;
    file.write_all(&pixel_data_size.to_le_bytes())?;
    file.write_all(&0i32.to_le_bytes())?;
    file.write_all(&0i32.to_le_bytes())?;
    file.write_all(&0u32.to_le_bytes())?;
    file.write_all(&0u32.to_le_bytes())?;

    for &p in pixels {
        let a = ((p >> 24) & 0xFF) as u8;
        let r = ((p >> 16) & 0xFF) as u8;
        let g = ((p >> 8) & 0xFF) as u8;
        let b = (p & 0xFF) as u8;
        file.write_all(&[b, g, r, a])?;
    }
    Ok(())
}

fn load_bmp(path: &str) -> std::io::Result<(u32, u32, Vec<u32>)> {
    let bytes = std::fs::read(path)?;
    if bytes.len() < 54 || &bytes[0..2] != b"BM" {
        return Err(std::io::Error::new(std::io::ErrorKind::InvalidData, "Invalid BMP file"));
    }

    let off_bits = u32::from_le_bytes(bytes[10..14].try_into().unwrap()) as usize;
    let width = i32::from_le_bytes(bytes[18..22].try_into().unwrap());
    let height = i32::from_le_bytes(bytes[22..26].try_into().unwrap());
    let bit_count = u16::from_le_bytes(bytes[28..30].try_into().unwrap());

    if bit_count != 24 && bit_count != 32 {
        return Err(std::io::Error::new(std::io::ErrorKind::InvalidData, "Only 24-bit and 32-bit BMPs supported"));
    }

    let w = width.unsigned_abs();
    let h = height.unsigned_abs();
    let top_down = height < 0;

    let mut pixels = vec![0u32; (w * h) as usize];
    let row_stride = (bit_count as u32 * w).div_ceil(32) * 4;

    for y in 0..h {
        let file_y = if top_down { y } else { h - 1 - y };
        let row_offset = off_bits + (file_y as usize * row_stride as usize);
        for x in 0..w {
            let pixel_idx = (y * w + x) as usize;
            if bit_count == 24 {
                let o = row_offset + (x as usize * 3);
                if o + 2 < bytes.len() {
                    let b = bytes[o];
                    let g = bytes[o + 1];
                    let r = bytes[o + 2];
                    pixels[pixel_idx] = 0xFF000000 | ((r as u32) << 16) | ((g as u32) << 8) | (b as u32);
                }
            } else {
                let o = row_offset + (x as usize * 4);
                if o + 3 < bytes.len() {
                    let b = bytes[o];
                    let g = bytes[o + 1];
                    let r = bytes[o + 2];
                    let a = bytes[o + 3];
                    pixels[pixel_idx] = ((a as u32) << 24) | ((r as u32) << 16) | ((g as u32) << 8) | (b as u32);
                }
            }
        }
    }
    Ok((w, h, pixels))
}

// ---------------------------------------------------------------------------
// LUA FFI EXPORTS
// ---------------------------------------------------------------------------

unsafe extern "C-unwind" fn lua_change_debug_state(l: *mut lua_State) -> i32 {
    let state = lua_toboolean(l, 1) != 0;
    if let Ok(mut debug) = DEBUG_STATE.lock() {
        *debug = state;
    }
    0
}

unsafe extern "C-unwind" fn lua_set_suppress_warnings(l: *mut lua_State) -> i32 {
    let suppress = lua_toboolean(l, 1) != 0;
    if let Ok(mut s) = SUPPRESS_WARNINGS.lock() {
        *s = suppress;
    }
    0
}

unsafe extern "C-unwind" fn lua_get_screen_size(l: *mut lua_State) -> i32 {
    let (w, h) = win32::get_screen_size_raw();
    lua_pushinteger(l, w as i64);
    lua_pushinteger(l, h as i64);
    2
}

unsafe extern "C-unwind" fn lua_get_mouse_position(l: *mut lua_State) -> i32 {
    let (x, y) = win32::get_mouse_position_raw();
    lua_pushinteger(l, x as i64);
    lua_pushinteger(l, y as i64);
    2
}

unsafe extern "C-unwind" fn lua_set_mouse_position(l: *mut lua_State) -> i32 {
    let x = lua_tointeger(l, 1) as i32;
    let y = lua_tointeger(l, 2) as i32;
    win32::set_mouse_position_raw(x, y);
    0
}

unsafe extern "C-unwind" fn lua_mouse_click(l: *mut lua_State) -> i32 {
    let button_ptr = lua_tostring(l, 1);
    let down = lua_toboolean(l, 2) != 0;
    if button_ptr.is_null() {
        lua_error_msg(l, "mouse_click: button argument is required (LEFT/RIGHT/MIDDLE)");
    }
    let button = std::ffi::CStr::from_ptr(button_ptr).to_str().unwrap_or("LEFT");
    if let Err(e) = win32::mouse_click_raw(button, down) {
        lua_error_msg(l, e);
    }
    0
}

unsafe extern "C-unwind" fn lua_mouse_scroll(l: *mut lua_State) -> i32 {
    let intensity = lua_tointeger(l, 1) as u32;
    let dir_ptr = lua_tostring(l, 2);
    if dir_ptr.is_null() {
        lua_error_msg(l, "mouse_scroll: direction argument is required (UP/DOWN)");
    }
    let dir = std::ffi::CStr::from_ptr(dir_ptr).to_str().unwrap_or("UP");
    if let Err(e) = win32::mouse_scroll_raw(intensity, dir) {
        lua_error_msg(l, e);
    }
    0
}

unsafe extern "C-unwind" fn lua_keyboard_event(l: *mut lua_State) -> i32 {
    let key_ptr = lua_tostring(l, 1);
    let down = lua_toboolean(l, 2) != 0;
    if key_ptr.is_null() {
        lua_error_msg(l, "keyboard_event: key argument is required");
    }
    let key = std::ffi::CStr::from_ptr(key_ptr).to_str().unwrap_or("");
    let vk = get_vk_code(key);
    if vk == 0 {
        lua_error_msg(l, &format!("keyboard_event: unknown key '{}'", key));
    }
    win32::keyboard_event_raw(vk, !down);
    0
}

unsafe extern "C-unwind" fn lua_keyboard_type(l: *mut lua_State) -> i32 {
    let text_ptr = lua_tostring(l, 1);
    if text_ptr.is_null() {
        lua_error_msg(l, "keyboard_type: text argument is required");
    }
    let text = std::ffi::CStr::from_ptr(text_ptr).to_str().unwrap_or("");
    win32::keyboard_type_raw(text);
    0
}

unsafe extern "C-unwind" fn lua_save_screenshot(l: *mut lua_State) -> i32 {
    let path_ptr = lua_tostring(l, 1);
    let x = lua_tointeger(l, 2) as i32;
    let y = lua_tointeger(l, 3) as i32;
    let w_arg = lua_tointeger(l, 4) as i32;
    let h_arg = lua_tointeger(l, 5) as i32;

    if path_ptr.is_null() {
        lua_error_msg(l, "save_screenshot: path argument is required");
    }
    let path = std::ffi::CStr::from_ptr(path_ptr).to_str().unwrap_or("");

    let (screen_w, screen_h) = win32::get_screen_size_raw();
    let cap_w = if w_arg > 0 { w_arg } else { screen_w };
    let cap_h = if h_arg > 0 { h_arg } else { screen_h };
    let cap_x = if w_arg > 0 { x } else { 0 };
    let cap_y = if h_arg > 0 { y } else { 0 };

    match win32::capture_screen_raw(cap_x, cap_y, cap_w, cap_h) {
        Some((w, h, pixels)) => {
            if let Err(e) = save_bmp(path, w, h, &pixels) {
                lua_error_msg(l, &format!("save_screenshot: failed to save BMP: {}", e));
            }
            0
        }
        None => lua_error_msg(l, "save_screenshot: failed to capture screen"),
    }
}

unsafe extern "C-unwind" fn lua_capture_screenshot(l: *mut lua_State) -> i32 {
    match win32::capture_screen_raw(0, 0, win32::get_screen_size_raw().0, win32::get_screen_size_raw().1) {
        Some((w, h, pixels)) => {
            let buf = lua_newbuffer(l, (pixels.len() * 4) as usize);
            let buf_slice = std::slice::from_raw_parts_mut(buf as *mut u32, pixels.len());
            buf_slice.copy_from_slice(&pixels);
            lua_pushinteger(l, w as i64);
            lua_pushinteger(l, h as i64);
            3
        }
        None => lua_error_msg(l, "capture_screenshot: failed to capture screen"),
    }
}

unsafe extern "C-unwind" fn lua_get_pixel(l: *mut lua_State) -> i32 {
    let x = lua_tointeger(l, 1) as i32;
    let y = lua_tointeger(l, 2) as i32;
    match win32::get_pixel_raw(x, y) {
        Some((r, g, b, a)) => {
            lua_pushinteger(l, r as i64);
            lua_pushinteger(l, g as i64);
            lua_pushinteger(l, b as i64);
            lua_pushinteger(l, a as i64);
            4
        }
        None => lua_error_msg(l, &format!("get_pixel: failed to read pixel at ({}, {})", x, y)),
    }
}

unsafe extern "C-unwind" fn lua_get_monitors(l: *mut lua_State) -> i32 {
    let monitors = win32::get_monitors_raw();
    lua_createtable(l, monitors.len() as i32, 0);
    for (i, (mx, my, mw, mh, primary)) in monitors.iter().enumerate() {
        lua_createtable(l, 0, 5);
        lua_pushinteger(l, *mx as i64);
        lua_setfield(l, -2, c"x".as_ptr());
        lua_pushinteger(l, *my as i64);
        lua_setfield(l, -2, c"y".as_ptr());
        lua_pushinteger(l, *mw as i64);
        lua_setfield(l, -2, c"width".as_ptr());
        lua_pushinteger(l, *mh as i64);
        lua_setfield(l, -2, c"height".as_ptr());
        lua_pushboolean(l, if *primary { 1 } else { 0 });
        lua_setfield(l, -2, c"primary".as_ptr());
        lua_rawseti(l, -2, (i + 1) as i64);
    }
    1
}

unsafe extern "C-unwind" fn lua_clipboard_get_text(l: *mut lua_State) -> i32 {
    match win32::clipboard_get_text_raw() {
        Some(text) => {
            let c_text = std::ffi::CString::new(text).unwrap_or_default();
            lua_pushstring(l, c_text.as_ptr());
            1
        }
        None => {
            lua_pushstring(l, c"".as_ptr());
            1
        }
    }
}

unsafe extern "C-unwind" fn lua_clipboard_set_text(l: *mut lua_State) -> i32 {
    let text_ptr = lua_tostring(l, 1);
    if text_ptr.is_null() {
        lua_error_msg(l, "clipboard_set_text: text argument is required");
    }
    let text = std::ffi::CStr::from_ptr(text_ptr).to_str().unwrap_or("");
    if !win32::clipboard_set_text_raw(text) {
        lua_error_msg(l, "clipboard_set_text: failed to set clipboard text");
    }
    0
}

unsafe extern "C-unwind" fn lua_prepare_template_from_file(l: *mut lua_State) -> i32 {
    let path_ptr = lua_tostring(l, 1);
    if path_ptr.is_null() {
        lua_error_msg(l, "prepare_template_from_file: path argument is required");
    }
    let path = std::ffi::CStr::from_ptr(path_ptr).to_str().unwrap_or("");
    match load_bmp(path) {
        Ok((w, h, pixels)) => {
            if let Ok(mut tmpl) = TEMPLATE.lock() {
                *tmpl = Some(Template { width: w, height: h, pixels });
            }
            0
        }
        Err(e) => lua_error_msg(l, &format!("prepare_template_from_file: {}", e)),
    }
}

unsafe extern "C-unwind" fn lua_find_image_on_screen(l: *mut lua_State) -> i32 {
    let threshold = lua_tonumber(l, 1) as f32;
    let search_x = lua_tointeger(l, 2) as i32;
    let search_y = lua_tointeger(l, 3) as i32;
    let search_w = lua_tointeger(l, 4) as i32;
    let search_h = lua_tointeger(l, 5) as i32;

    let tmpl_guard = TEMPLATE.lock().unwrap_or_else(|_| lua_error_msg(l, "find_image_on_screen: internal mutex error"));
    let tmpl = match &*tmpl_guard {
        Some(t) => t,
        None => lua_error_msg(l, "find_image_on_screen: no template loaded, call prepare_template_from_file first"),
    };

    let (screen_w, screen_h) = win32::get_screen_size_raw();
    let (sx, sy, sw, sh) = if search_w > 0 && search_h > 0 {
        (search_x, search_y, search_w, search_h)
    } else {
        (0, 0, screen_w, screen_h)
    };

    match win32::capture_screen_raw(sx, sy, sw, sh) {
        Some((cap_w, cap_h, screen_pixels)) => {
            if tmpl.width > cap_w || tmpl.height > cap_h {
                lua_pushnil(l);
                return 1;
            }

            let end_y = cap_h - tmpl.height;
            let end_x = cap_w - tmpl.width;
            let total_pixels = tmpl.width * tmpl.height;
            let mut best_x = 0;
            let mut best_y = 0;
            let mut best_score = 0.0f32;
            let step = if threshold < 0.95 { 2 } else { 1 };

            let mut y = 0;
            while y <= end_y {
                let mut x = 0;
                while x <= end_x {
                    let mut match_count = 0;
                    let mut mismatch_count = 0;
                    let max_mismatches = (total_pixels as f32 * (1.0 - threshold)) as usize;
                    let mut ty = 0;
                    let mut aborted = false;
                    while ty < tmpl.height {
                        let mut tx = 0;
                        while tx < tmpl.width {
                            let tmpl_pixel = tmpl.pixels[(ty * tmpl.width + tx) as usize];
                            let screen_pixel = screen_pixels[((y + ty) * cap_w + (x + tx)) as usize];
                            let tr = (tmpl_pixel >> 16) & 0xFF;
                            let tg = (tmpl_pixel >> 8) & 0xFF;
                            let tb = tmpl_pixel & 0xFF;
                            let sr = (screen_pixel >> 16) & 0xFF;
                            let sg = (screen_pixel >> 8) & 0xFF;
                            let sb = screen_pixel & 0xFF;
                            if tr.abs_diff(sr) <= 15 && tg.abs_diff(sg) <= 15 && tb.abs_diff(sb) <= 15 {
                                match_count += 1;
                            } else {
                                mismatch_count += 1;
                                if mismatch_count > max_mismatches {
                                    aborted = true;
                                    break;
                                }
                            }
                            tx += step;
                        }
                        if aborted {
                            break;
                        }
                        ty += step;
                    }

                    if !aborted {
                        let score = match_count as f32 / ((tmpl.width * tmpl.height) / (step * step)) as f32;
                        if score >= threshold && score > best_score {
                            best_score = score;
                            best_x = x;
                            best_y = y;
                            if best_score > 0.99 {
                                break;
                            }
                        }
                    }
                    x += step;
                }
                if best_score > 0.99 {
                    break;
                }
                y += step;
            }

            if best_score >= threshold {
                let cx = (sx + best_x as i32 + (tmpl.width as i32) / 2) as i64;
                let cy = (sy + best_y as i32 + (tmpl.height as i32) / 2) as i64;
                lua_pushinteger(l, cx);
                lua_pushinteger(l, cy);
                2
            } else {
                lua_pushnil(l);
                1
            }
        }
        None => lua_error_msg(l, "find_image_on_screen: failed to capture screen"),
    }
}

unsafe extern "C-unwind" fn lua_focus_window(l: *mut lua_State) -> i32 {
    let title_ptr = lua_tostring(l, 1);
    if title_ptr.is_null() {
        lua_error_msg(l, "focus_window: title argument is required");
    }
    let title = std::ffi::CStr::from_ptr(title_ptr).to_str().unwrap_or("");
    let ok = win32::focus_window_raw(title);
    lua_pushboolean(l, if ok { 1 } else { 0 });
    1
}

unsafe extern "C-unwind" fn lua_window_exists(l: *mut lua_State) -> i32 {
    let title_ptr = lua_tostring(l, 1);
    if title_ptr.is_null() {
        lua_pushboolean(l, 0);
        return 1;
    }
    let title = std::ffi::CStr::from_ptr(title_ptr).to_str().unwrap_or("");
    let exists = win32::window_exists_raw(title);
    lua_pushboolean(l, if exists { 1 } else { 0 });
    1
}

unsafe extern "C-unwind" fn lua_get_active_window(l: *mut lua_State) -> i32 {
    let hwnd = win32::get_active_window_raw();
    if hwnd.is_null() {
        lua_pushnil(l);
    } else {
        lua_pushlightuserdata(l, hwnd);
    }
    1
}

unsafe extern "C-unwind" fn lua_get_all_windows(l: *mut lua_State) -> i32 {
    let hwnds = win32::get_all_windows_raw();
    lua_createtable(l, hwnds.len() as i32, 0);
    for (i, &hwnd) in hwnds.iter().enumerate() {
        lua_pushlightuserdata(l, hwnd);
        lua_rawseti(l, -2, (i + 1) as i64);
    }
    1
}

unsafe extern "C-unwind" fn lua_get_window_title(l: *mut lua_State) -> i32 {
    let hwnd = lua_touserdata(l, 1);
    if hwnd.is_null() {
        lua_error_msg(l, "get_window_title: invalid window handle");
    }
    let title = win32::get_window_title_raw(hwnd);
    let c_title = std::ffi::CString::new(title).unwrap_or_default();
    lua_pushstring(l, c_title.as_ptr());
    1
}

unsafe extern "C-unwind" fn lua_window_get_handle(_l: *mut lua_State) -> i32 {
    0
}

unsafe extern "C-unwind" fn lua_focus_window_by_handle(l: *mut lua_State) -> i32 {
    let hwnd = lua_touserdata(l, 1);
    if hwnd.is_null() {
        lua_pushboolean(l, 0);
        return 1;
    }
    if !win32::focus_window_by_handle_raw(hwnd) {
        lua_pushboolean(l, 0);
        return 1;
    }
    lua_pushboolean(l, 1);
    1
}

unsafe extern "C-unwind" fn lua_close_window(l: *mut lua_State) -> i32 {
    let hwnd = lua_touserdata(l, 1);
    if hwnd.is_null() {
        lua_pushboolean(l, 0);
        return 1;
    }
    lua_pushboolean(l, if win32::close_window_raw(hwnd) { 1 } else { 0 });
    1
}

unsafe extern "C-unwind" fn lua_minimize_window(l: *mut lua_State) -> i32 {
    let hwnd = lua_touserdata(l, 1);
    if hwnd.is_null() {
        lua_pushboolean(l, 0);
        return 1;
    }
    lua_pushboolean(l, if win32::minimize_window_raw(hwnd) { 1 } else { 0 });
    1
}

unsafe extern "C-unwind" fn lua_maximize_window(l: *mut lua_State) -> i32 {
    let hwnd = lua_touserdata(l, 1);
    if hwnd.is_null() {
        lua_pushboolean(l, 0);
        return 1;
    }
    lua_pushboolean(l, if win32::maximize_window_raw(hwnd) { 1 } else { 0 });
    1
}

unsafe extern "C-unwind" fn lua_restore_window(l: *mut lua_State) -> i32 {
    let hwnd = lua_touserdata(l, 1);
    if hwnd.is_null() {
        lua_pushboolean(l, 0);
        return 1;
    }
    lua_pushboolean(l, if win32::restore_window_raw(hwnd) { 1 } else { 0 });
    1
}

unsafe extern "C-unwind" fn lua_get_window_geometry(l: *mut lua_State) -> i32 {
    let hwnd = lua_touserdata(l, 1);
    if hwnd.is_null() {
        lua_error_msg(l, "get_window_geometry: invalid window handle");
    }
    let (x, y, w, h) = win32::get_window_geometry_raw(hwnd);
    lua_pushinteger(l, x as i64);
    lua_pushinteger(l, y as i64);
    lua_pushinteger(l, w as i64);
    lua_pushinteger(l, h as i64);
    4
}

unsafe extern "C-unwind" fn lua_set_window_geometry(l: *mut lua_State) -> i32 {
    let hwnd = lua_touserdata(l, 1);
    let x = lua_tointeger(l, 2) as i32;
    let y = lua_tointeger(l, 3) as i32;
    let w = lua_tointeger(l, 4) as i32;
    let h = lua_tointeger(l, 5) as i32;
    if hwnd.is_null() {
        lua_pushboolean(l, 0);
        return 1;
    }
    lua_pushboolean(l, if win32::set_window_geometry_raw(hwnd, x, y, w, h) { 1 } else { 0 });
    1
}

unsafe extern "C-unwind" fn lua_is_window_minimized(l: *mut lua_State) -> i32 {
    let hwnd = lua_touserdata(l, 1);
    if hwnd.is_null() {
        lua_pushboolean(l, 0);
        return 1;
    }
    lua_pushboolean(l, if win32::is_window_minimized_raw(hwnd) { 1 } else { 0 });
    1
}

unsafe extern "C-unwind" fn lua_is_window_maximized(l: *mut lua_State) -> i32 {
    let hwnd = lua_touserdata(l, 1);
    if hwnd.is_null() {
        lua_pushboolean(l, 0);
        return 1;
    }
    lua_pushboolean(l, if win32::is_window_maximized_raw(hwnd) { 1 } else { 0 });
    1
}

unsafe extern "C-unwind" fn lua_is_window_visible(l: *mut lua_State) -> i32 {
    let hwnd = lua_touserdata(l, 1);
    if hwnd.is_null() {
        lua_pushboolean(l, 0);
        return 1;
    }
    lua_pushboolean(l, if win32::is_window_visible_raw(hwnd) { 1 } else { 0 });
    1
}

unsafe extern "C-unwind" fn lua_window_create(l: *mut lua_State) -> i32 {
    let hwnd = lua_touserdata(l, 1);
    if hwnd.is_null() {
        lua_pushnil(l);
        return 1;
    }
    lua_pushlightuserdata(l, hwnd);
    1
}

unsafe extern "C-unwind" fn lua_window_set_transparency(l: *mut lua_State) -> i32 {
    let hwnd = lua_touserdata(l, 1);
    let alpha = luaL_optinteger(l, 2, 255) as u8;
    if hwnd.is_null() {
        lua_pushboolean(l, 0);
        return 1;
    }
    lua_pushboolean(l, if win32::window_set_transparency_raw(hwnd, alpha) { 1 } else { 0 });
    1
}

unsafe extern "C-unwind" fn lua_window_set_click_through(l: *mut lua_State) -> i32 {
    let hwnd = lua_touserdata(l, 1);
    let enabled = lua_toboolean(l, 2) != 0;
    if hwnd.is_null() {
        lua_pushboolean(l, 0);
        return 1;
    }
    lua_pushboolean(l, if win32::window_set_click_through_raw(hwnd, enabled) { 1 } else { 0 });
    1
}

#[unsafe(no_mangle)]
pub unsafe extern "C-unwind" fn luau_export(l: *mut lua_State, api: *const LuauAPI) -> i32 {
    unsafe {
        init_api(api);

        lua_createtable(l, 0, 36);

        lua_pushcfunction(l, lua_change_debug_state);
        lua_setfield(l, -2, c"change_debug_state".as_ptr());

        lua_pushcfunction(l, lua_set_suppress_warnings);
        lua_setfield(l, -2, c"set_suppress_warnings".as_ptr());

        lua_pushcfunction(l, lua_get_screen_size);
        lua_setfield(l, -2, c"get_screen_size".as_ptr());

        lua_pushcfunction(l, lua_get_mouse_position);
        lua_setfield(l, -2, c"get_mouse_position".as_ptr());

        lua_pushcfunction(l, lua_set_mouse_position);
        lua_setfield(l, -2, c"set_mouse_position".as_ptr());

        lua_pushcfunction(l, lua_mouse_click);
        lua_setfield(l, -2, c"mouse_click".as_ptr());

        lua_pushcfunction(l, lua_mouse_scroll);
        lua_setfield(l, -2, c"mouse_scroll".as_ptr());

        lua_pushcfunction(l, lua_keyboard_event);
        lua_setfield(l, -2, c"keyboard_event".as_ptr());

        lua_pushcfunction(l, lua_keyboard_type);
        lua_setfield(l, -2, c"keyboard_type".as_ptr());

        lua_pushcfunction(l, lua_save_screenshot);
        lua_setfield(l, -2, c"save_screenshot".as_ptr());

        lua_pushcfunction(l, lua_capture_screenshot);
        lua_setfield(l, -2, c"capture_screenshot".as_ptr());

        lua_pushcfunction(l, lua_get_pixel);
        lua_setfield(l, -2, c"get_pixel".as_ptr());

        lua_pushcfunction(l, lua_get_monitors);
        lua_setfield(l, -2, c"get_monitors".as_ptr());

        lua_pushcfunction(l, lua_clipboard_get_text);
        lua_setfield(l, -2, c"clipboard_get_text".as_ptr());

        lua_pushcfunction(l, lua_clipboard_set_text);
        lua_setfield(l, -2, c"clipboard_set_text".as_ptr());

        lua_pushcfunction(l, lua_prepare_template_from_file);
        lua_setfield(l, -2, c"prepare_template_from_file".as_ptr());

        lua_pushcfunction(l, lua_find_image_on_screen);
        lua_setfield(l, -2, c"find_image_on_screen".as_ptr());

        lua_pushcfunction(l, lua_focus_window);
        lua_setfield(l, -2, c"focus_window".as_ptr());

        lua_pushcfunction(l, lua_window_exists);
        lua_setfield(l, -2, c"window_exists".as_ptr());

        lua_pushcfunction(l, lua_get_active_window);
        lua_setfield(l, -2, c"get_active_window".as_ptr());

        lua_pushcfunction(l, lua_get_all_windows);
        lua_setfield(l, -2, c"get_all_windows".as_ptr());

        lua_pushcfunction(l, lua_get_window_title);
        lua_setfield(l, -2, c"get_window_title".as_ptr());

        lua_pushcfunction(l, lua_window_get_handle);
        lua_setfield(l, -2, c"window_get_handle".as_ptr());

        lua_pushcfunction(l, lua_focus_window_by_handle);
        lua_setfield(l, -2, c"focus_window_by_handle".as_ptr());

        lua_pushcfunction(l, lua_close_window);
        lua_setfield(l, -2, c"close_window".as_ptr());

        lua_pushcfunction(l, lua_minimize_window);
        lua_setfield(l, -2, c"minimize_window".as_ptr());

        lua_pushcfunction(l, lua_maximize_window);
        lua_setfield(l, -2, c"maximize_window".as_ptr());

        lua_pushcfunction(l, lua_restore_window);
        lua_setfield(l, -2, c"restore_window".as_ptr());

        lua_pushcfunction(l, lua_get_window_geometry);
        lua_setfield(l, -2, c"get_window_geometry".as_ptr());

        lua_pushcfunction(l, lua_set_window_geometry);
        lua_setfield(l, -2, c"set_window_geometry".as_ptr());

        lua_pushcfunction(l, lua_is_window_minimized);
        lua_setfield(l, -2, c"is_window_minimized".as_ptr());

        lua_pushcfunction(l, lua_is_window_maximized);
        lua_setfield(l, -2, c"is_window_maximized".as_ptr());

        lua_pushcfunction(l, lua_is_window_visible);
        lua_setfield(l, -2, c"is_window_visible".as_ptr());

        lua_pushcfunction(l, lua_window_create);
        lua_setfield(l, -2, c"window_create".as_ptr());

        lua_pushcfunction(l, lua_window_set_transparency);
        lua_setfield(l, -2, c"window_set_transparency".as_ptr());

        lua_pushcfunction(l, lua_window_set_click_through);
        lua_setfield(l, -2, c"window_set_click_through".as_ptr());

        1
    }
}
