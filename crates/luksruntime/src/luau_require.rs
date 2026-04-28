use mlua::{Function, Lua, NavigateError, Require, Result as LuaResult};
use std::fs::File;
use std::io::{self, Read};
use std::path::{Path, PathBuf};
use std::result::Result as StdResult;

/// `mlua::Require` implementation for the Luks module system.
///
/// This struct stores navigation state while resolving a module path.
/// Luau calls navigation methods (`reset`, `to_parent`, `to_child`) to build
/// the target path, then checks `has_module()` and calls `loader()`.
pub struct LuksRequirer {
    /// Current path while navigating module segments.
    current_path: PathBuf,
    /// Directory of the script that initiated `require` (`__script_dir__`).
    script_dir: PathBuf,
    /// Additional roots from `LUKS_REQUIRE_PATH`.
    require_paths: Vec<PathBuf>,
}

impl LuksRequirer {
    pub fn new() -> Self {
        Self {
            current_path: PathBuf::from("."),
            script_dir: PathBuf::from("."),
            require_paths: std::env::var("LUKS_REQUIRE_PATH")
                .ok()
                .map(|v| {
                    let separator = if cfg!(windows) { ';' } else { ':' };
                    v.split(separator)
                        .map(str::trim)
                        .filter(|s| !s.is_empty())
                        .map(PathBuf::from)
                        .collect::<Vec<_>>()
                })
                .unwrap_or_default(),
        }
    }

    /// Finds the module file that matches the current path.
    /// Tries `.luau` / `.lua` and `init.luau` / `init.lua` for directories.
    fn find_module(&self) -> Option<PathBuf> {
        let base = &self.current_path;

        // Try as a file with `.luau` or `.lua` extension.
        for ext in ["luau", "lua"] {
            let with_ext = base.with_extension(ext);
            if with_ext.is_file() {
                return Some(with_ext);
            }
        }

        if !self.require_paths.is_empty() {
            if let Ok(rel) = base.strip_prefix(&self.script_dir) {
                for root in &self.require_paths {
                    for ext in ["luau", "lua"] {
                        let with_ext = root.join(rel).with_extension(ext);
                        if with_ext.is_file() {
                            return Some(with_ext);
                        }
                    }
                }
            }
        }

        // Try `init.luau` or `init.lua` inside the directory.
        for ext in ["luau", "lua"] {
            let init = base.join(format!("init.{}", ext));
            if init.is_file() {
                return Some(init);
            }
        }

        if !self.require_paths.is_empty() {
            if let Ok(rel) = base.strip_prefix(&self.script_dir) {
                for root in &self.require_paths {
                    for ext in ["luau", "lua"] {
                        let init = root.join(rel).join(format!("init.{}", ext));
                        if init.is_file() {
                            return Some(init);
                        }
                    }
                }
            }
        }

        None
    }

    /// Resolves a module path, including `@self/` and relative paths.
    fn resolve_module_path(&self, input: &str) -> PathBuf {
        crate::path_resolution::resolve_from_base(&self.script_dir, input)
    }
}

impl Default for LuksRequirer {
    fn default() -> Self {
        Self::new()
    }
}

impl Require for LuksRequirer {
    /// Checks whether `require` is allowed for the current runtime policy.
    fn is_require_allowed(&self, chunk_name: &str) -> bool {
        match crate::permissions::check_import_safely() {
            Ok(true) => true, // Allowed.
            Ok(false) => {
                crate::utils::runtime_warn(&format!(
                    "Permission denied: require('{}')",
                    chunk_name
                ));
                false // Denied.
            }
            Err(_) => {
                crate::utils::runtime_warn(&format!(
                    "Internal permission error. Denying require('{}')",
                    chunk_name
                ));
                false // Fail-safe: deny on internal errors.
            }
        }
    }

    /// Resets state to the directory of the chunk performing `require`.
    fn reset(&mut self, chunk_name: &str) -> StdResult<(), NavigateError> {
        let chunk_name = chunk_name.strip_prefix('@').unwrap_or(chunk_name);

        // Set current_path to the file path, not the directory.
        // Luau will call `to_parent` when directory navigation is needed.
        self.current_path = PathBuf::from(chunk_name);

        // script_dir is used to resolve `@self/` aliases.
        self.script_dir = Path::new(chunk_name)
            .parent()
            .map(|p| p.to_path_buf())
            .unwrap_or_else(|| PathBuf::from("."));

        Ok(())
    }

    /// Jumps to an alias path (absolute or fully relative).
    fn jump_to_alias(&mut self, path: &str) -> StdResult<(), NavigateError> {
        self.current_path = self.resolve_module_path(path);
        Ok(())
    }

    /// Moves to parent directory.
    fn to_parent(&mut self) -> StdResult<(), NavigateError> {
        if !self.current_path.as_os_str().is_empty() {
            self.current_path.pop();
        }
        Ok(())
    }

    /// Appends a child segment.
    fn to_child(&mut self, name: &str) -> StdResult<(), NavigateError> {
        self.current_path.push(name);
        Ok(())
    }

    /// Checks whether the current path points to an existing module.
    fn has_module(&self) -> bool {
        self.find_module().is_some()
    }

    /// Returns the cache key for the current module.
    /// Used by Luau for `package.loaded` caching.
    fn cache_key(&self) -> String {
        // Use shared helper to keep behavior consistent with `dlopen`.
        let Some(module) = self.find_module() else {
            return self.current_path.to_string_lossy().to_string();
        };

        crate::path_resolution::canonicalize_or_absolute(&module)
            .to_string_lossy()
            .to_string()
    }

    /// Indicates whether contextual config exists (unused).
    fn has_config(&self) -> bool {
        false
    }

    /// Returns config payload (unused).
    fn config(&self) -> io::Result<Vec<u8>> {
        Err(io::Error::new(io::ErrorKind::NotFound, "no config"))
    }

    /// Builds and returns the loader function for the current module.
    fn loader(&self, lua: &Lua) -> LuaResult<Function> {
        let path = self.find_module().ok_or_else(|| {
            mlua::Error::runtime(format!(
                "módulo não encontrado: {}",
                self.current_path.display()
            ))
        })?;
        // Read the module file.
        let mut file = File::open(&path)
            .map_err(|e| mlua::Error::runtime(format!("abrir '{}': {}", path.display(), e)))?;

        let mut source = String::new();
        file.read_to_string(&mut source)
            .map_err(|e| mlua::Error::runtime(format!("ler '{}': {}", path.display(), e)))?;

        // Compile and return the function.
        // mlua/Luau manages module cache and execution environment.
        lua.load(&source)
            .set_name(path.to_string_lossy())
            .into_function()
    }
}
