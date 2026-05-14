use std::collections::HashMap;
use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_int, c_uint, c_void};

#[derive(Debug, Clone)]
pub struct Diagnostic {
    pub severity: u8, // 0 for error, 1 for warning
    pub line: u32,
    pub col: u32,
    pub end_line: u32,
    pub end_col: u32,
    pub message: String,
}

#[repr(C)]
pub struct LuauAnalyzerOpaque {
    _private: [u8; 0],
}

type DiagnosticCallback = unsafe extern "C" fn(
    context: *mut c_void,
    severity: c_int,
    line: c_uint,
    col: c_uint,
    end_line: c_uint,
    end_col: c_uint,
    message: *const c_char,
);

type ReadSourceCallback =
    unsafe extern "C" fn(context: *mut c_void, module_name: *const c_char) -> *const c_char;

extern "C" {
    fn luau_analyzer_create() -> *mut LuauAnalyzerOpaque;
    fn luau_analyzer_destroy(analyzer: *mut LuauAnalyzerOpaque);
    fn luau_analyzer_add_definitions(analyzer: *mut LuauAnalyzerOpaque, source: *const c_char);
    fn luau_analyzer_check(
        analyzer: *mut LuauAnalyzerOpaque,
        module_name: *const c_char,
        read_callback: Option<ReadSourceCallback>,
        diag_callback: Option<DiagnosticCallback>,
        context: *mut c_void,
    );
}

struct CheckContext<'a> {
    diagnostics: Vec<Diagnostic>,
    cached_strings: HashMap<String, CString>,
    resolver: &'a dyn Fn(&str) -> Option<String>,
}

pub struct NativeAnalyzer {
    ptr: *mut LuauAnalyzerOpaque,
}

impl NativeAnalyzer {
    pub fn new() -> Self {
        unsafe {
            Self {
                ptr: luau_analyzer_create(),
            }
        }
    }

    pub fn add_definitions(&mut self, source: &str) {
        if let Ok(c_str) = CString::new(source) {
            unsafe {
                luau_analyzer_add_definitions(self.ptr, c_str.as_ptr());
            }
        }
    }

    pub fn check<F>(&mut self, module_name: &str, resolver: F) -> Vec<Diagnostic>
    where
        F: Fn(&str) -> Option<String>,
    {
        let mut context = CheckContext {
            diagnostics: Vec::new(),
            cached_strings: HashMap::new(),
            resolver: &resolver,
        };

        if let Ok(mod_cstr) = CString::new(module_name) {
            unsafe extern "C" fn read_callback(
                ctx_ptr: *mut c_void,
                mod_name: *const c_char,
            ) -> *const c_char {
                let ctx = &mut *(ctx_ptr as *mut CheckContext);
                if mod_name.is_null() {
                    return std::ptr::null();
                }
                let name_str = CStr::from_ptr(mod_name).to_string_lossy();
                if let Some(c_str) = ctx.cached_strings.get(name_str.as_ref()) {
                    return c_str.as_ptr();
                }
                if let Some(src) = (ctx.resolver)(name_str.as_ref()) {
                    if let Ok(c_str) = CString::new(src) {
                        let ptr = c_str.as_ptr();
                        ctx.cached_strings.insert(name_str.into_owned(), c_str);
                        return ptr;
                    }
                }
                std::ptr::null()
            }

            unsafe extern "C" fn diag_callback(
                ctx_ptr: *mut c_void,
                severity: c_int,
                line: c_uint,
                col: c_uint,
                end_line: c_uint,
                end_col: c_uint,
                message: *const c_char,
            ) {
                let ctx = &mut *(ctx_ptr as *mut CheckContext);
                let msg_str = if message.is_null() {
                    String::new()
                } else {
                    CStr::from_ptr(message).to_string_lossy().into_owned()
                };
                ctx.diagnostics.push(Diagnostic {
                    severity: severity as u8,
                    line,
                    col,
                    end_line,
                    end_col,
                    message: msg_str,
                });
            }

            unsafe {
                let ctx_void = &mut context as *mut CheckContext as *mut c_void;
                luau_analyzer_check(
                    self.ptr,
                    mod_cstr.as_ptr(),
                    Some(read_callback),
                    Some(diag_callback),
                    ctx_void,
                );
            }
        }

        context.diagnostics
    }
}

impl Default for NativeAnalyzer {
    fn default() -> Self {
        Self::new()
    }
}

impl Drop for NativeAnalyzer {
    fn drop(&mut self) {
        unsafe {
            if !self.ptr.is_null() {
                luau_analyzer_destroy(self.ptr);
                self.ptr = std::ptr::null_mut();
            }
        }
    }
}

unsafe impl Send for NativeAnalyzer {}
