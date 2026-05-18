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

type ResolveModuleCallback = unsafe extern "C" fn(
    context: *mut c_void,
    current_module: *const c_char,
    required_name: *const c_char,
) -> *const c_char;

extern "C" {
    fn luau_analyzer_create() -> *mut LuauAnalyzerOpaque;
    fn luau_analyzer_destroy(analyzer: *mut LuauAnalyzerOpaque);
    fn luau_analyzer_add_definitions(analyzer: *mut LuauAnalyzerOpaque, source: *const c_char);
    fn luau_analyzer_check(
        analyzer: *mut LuauAnalyzerOpaque,
        module_name: *const c_char,
        read_callback: Option<ReadSourceCallback>,
        resolve_callback: Option<ResolveModuleCallback>,
        diag_callback: Option<DiagnosticCallback>,
        context: *mut c_void,
    );
}

struct CheckContext<'a> {
    diagnostics: Vec<Diagnostic>,
    cached_strings: HashMap<String, CString>,
    resolver: &'a dyn Fn(&str) -> Option<String>,
    path_resolver: &'a dyn Fn(&str, &str) -> Option<String>,
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

    pub fn check<F, P>(
        &mut self,
        module_name: &str,
        resolver: F,
        path_resolver: P,
    ) -> Vec<Diagnostic>
    where
        F: Fn(&str) -> Option<String>,
        P: Fn(&str, &str) -> Option<String>,
    {
        let mut context = CheckContext {
            diagnostics: Vec::new(),
            cached_strings: HashMap::new(),
            resolver: &resolver,
            path_resolver: &path_resolver,
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

            unsafe extern "C" fn resolve_callback(
                ctx_ptr: *mut c_void,
                curr_mod: *const c_char,
                req_name: *const c_char,
            ) -> *const c_char {
                let ctx = &mut *(ctx_ptr as *mut CheckContext);
                if curr_mod.is_null() || req_name.is_null() {
                    return std::ptr::null();
                }
                let curr_mod_str = CStr::from_ptr(curr_mod).to_string_lossy();
                let req_name_str = CStr::from_ptr(req_name).to_string_lossy();

                let cache_key = format!("RESOLVED:{}:{}", curr_mod_str, req_name_str);
                if let Some(c_str) = ctx.cached_strings.get(&cache_key) {
                    return c_str.as_ptr();
                }

                if let Some(resolved) =
                    (ctx.path_resolver)(curr_mod_str.as_ref(), req_name_str.as_ref())
                {
                    if let Ok(c_str) = CString::new(resolved) {
                        let ptr = c_str.as_ptr();
                        ctx.cached_strings.insert(cache_key, c_str);
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
                    Some(resolve_callback),
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
