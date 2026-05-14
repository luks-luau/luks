use mlua::{Compiler, Function, Lua, NavigateError, Require, Result as LuaResult};
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
    /// For init.luau/init.lua, this is the module folder (where init file is).
    /// Used for `@self` resolution so `@self/sub` works for submodules.
    module_folder: Option<PathBuf>,
    /// Additional roots from `LUKS_REQUIRE_PATH`.
    require_paths: Vec<PathBuf>,
}

impl LuksRequirer {
    pub fn new() -> Self {
        Self {
            current_path: PathBuf::from("."),
            script_dir: PathBuf::from("."),
            module_folder: None,
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

        if let Some(found) = crate::path_resolution::find_candidate_file(base) {
            return Some(found);
        }

        if !self.require_paths.is_empty() {
            if let Ok(rel) = base.strip_prefix(&self.script_dir) {
                for root in &self.require_paths {
                    if let Some(found) =
                        crate::path_resolution::find_candidate_file(&root.join(rel))
                    {
                        return Some(found);
                    }
                }
            }
        }

        // Universal fallback: find longest common ancestor between script_dir and base
        // to extract the cleanly requested suffix, then search upwards across ancestor directories.
        let mut suffix = None;
        for anc in base.ancestors() {
            if self.script_dir.starts_with(anc) {
                if let Ok(s) = base.strip_prefix(anc) {
                    if !s.as_os_str().is_empty() {
                        suffix = Some(s);
                        break;
                    }
                }
            }
        }

        if let Some(rel_suffix) = suffix {
            for anc in self.script_dir.ancestors() {
                if let Some(found) =
                    crate::path_resolution::find_candidate_file(&anc.join(rel_suffix))
                {
                    return Some(found);
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
        let clean_name = crate::path_resolution::clean_source_name(chunk_name);
        let path = Path::new(clean_name);

        let script_dir = path
            .parent()
            .map(|p| p.to_path_buf())
            .unwrap_or_else(|| PathBuf::from("."));
        let script_dir_abs = std::path::absolute(&script_dir).unwrap_or(script_dir);

        // O @self sempre se refere à pasta onde o script está localizado
        self.module_folder = Some(script_dir_abs.clone());
        self.script_dir = script_dir_abs.clone();
        self.current_path = PathBuf::from(clean_name);

        Ok(())
    }

    /// Jumps to an alias target path (absolute or fully relative).
    /// If an alias target uses `@self`, resolve it from the module folder.
    fn jump_to_alias(&mut self, path: &str) -> StdResult<(), NavigateError> {
        if path == "@self" || path.starts_with("@self/") || path.starts_with("@self\\") {
            let base = self.module_folder.as_deref().unwrap_or(&self.script_dir);
            self.current_path = crate::path_resolution::resolve_from_base(base, path);
            return Ok(());
        }

        self.current_path = self.resolve_module_path(path);
        Ok(())
    }

    /// Moves to parent directory.
    fn to_parent(&mut self) -> StdResult<(), NavigateError> {
        if self.current_path.as_os_str().is_empty() || !self.current_path.pop() {
            return Err(NavigateError::NotFound);
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
        std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
            self.find_module().is_some()
        }))
        .unwrap_or_else(|_| {
            crate::utils::runtime_warn("Internal panic in has_module(); returning false");
            false
        })
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
        std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
            let path = self.find_module().ok_or_else(|| {
                mlua::Error::runtime(format!("module not found: {}", self.current_path.display()))
            })?;
            // Read the module file.
            let mut file = File::open(&path)
                .map_err(|e| mlua::Error::runtime(format!("open '{}': {}", path.display(), e)))?;

            let mut source = String::new();
            file.read_to_string(&mut source)
                .map_err(|e| mlua::Error::runtime(format!("read '{}': {}", path.display(), e)))?;

            // Parse `--!native` and `--!optimize <num>` directives from the module source.
            let mut has_native = false;
            let mut opt_level = None;
            for line in source.lines().take(10) {
                let trimmed = line.trim();
                if trimmed.contains("--!native") {
                    has_native = true;
                }
                if let Some(idx) = trimmed.find("--!optimize") {
                    let remainder = &trimmed[idx + "--!optimize".len()..];
                    for c in remainder.chars() {
                        if c.is_ascii_digit() {
                            if let Ok(val) = c.to_string().parse::<u8>() {
                                if val <= 2 {
                                    opt_level = Some(val);
                                }
                            }
                            break;
                        }
                    }
                }
            }

            let final_opt = opt_level.unwrap_or(if has_native { 2 } else { 1 });
            let compiler = Compiler::new().set_optimization_level(final_opt);

            #[cfg(not(any(target_os = "android", all(target_os = "linux", target_arch = "x86"))))]
            {
                lua.enable_jit(has_native);
            }

            // Compile and return the function.
            // mlua/Luau manages module cache and execution environment.
            lua.load(&source)
                .set_compiler(compiler)
                .set_name(path.to_string_lossy())
                .into_function()
        }))
        .unwrap_or_else(|_| Err(mlua::Error::runtime("internal panic while loading module")))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use mlua::Lua;
    use std::fs;
    use std::time::{SystemTime, UNIX_EPOCH};

    #[test]
    fn self_parent_resolves_to_init_module() {
        let root = std::env::temp_dir().join(format!(
            "luks_require_self_parent_{}",
            SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap()
                .as_nanos()
        ));

        let http_dir = root.join("luks-std").join("Http");
        let signal_dir = root.join("luks-std").join("Signal");
        fs::create_dir_all(&http_dir).unwrap();
        fs::create_dir_all(&signal_dir).unwrap();

        fs::write(
            http_dir.join("init.luau"),
            r#"
                local Signal = require("@self/../Signal")
                return { signal = Signal.kind }
            "#,
        )
        .unwrap();
        fs::write(
            signal_dir.join("init.luau"),
            r#"return { kind = "signal-init" }"#,
        )
        .unwrap();

        let lua = Lua::new();
        let require = lua.create_require_function(LuksRequirer::new()).unwrap();
        lua.globals().set("require", require).unwrap();

        let main_path = root.join("main.luau");
        let result: String = lua
            .load(r#"return require("./luks-std/Http").signal"#)
            .set_name(main_path.to_string_lossy())
            .eval()
            .unwrap();

        fs::remove_dir_all(&root).unwrap();
        assert_eq!(result, "signal-init");
    }
}
