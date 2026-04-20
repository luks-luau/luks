use mlua::{Lua, Result, Value, Table, Error};
use std::fs;
use crate::utils;

pub fn init_require(lua: &Lua) -> Result<()> {
    if lua.named_registry_value::<Table>("_LUKS_MODULES").is_err() {
        let t = lua.create_table()?;
        lua.set_named_registry_value("_LUKS_MODULES", t)?;
    }

    let require_fn = lua.create_function(move |lua, module: String| -> Result<Value> {
        let cache: Table = lua.named_registry_value("_LUKS_MODULES")?;

        if let Ok(v) = cache.get::<Value>(module.as_str()) {
            return Ok(v);
        }

        let base_target = utils::resolve_path(lua, &module);
        let mut found = None;
        for ext in ["luau", "lua"] {
            let with_ext = base_target.with_extension(ext);
            if with_ext.is_file() {
                found = Some(with_ext);
                break;
            }
            let init = base_target.join(format!("init.{}", ext));
            if init.is_file() {
                found = Some(init);
                break;
            }
        }
        let path = found.ok_or_else(|| Error::runtime(format!("require: '{}' não encontrado", module)))?;

        let source = fs::read_to_string(&path)
            .map_err(|e| Error::runtime(format!("ler '{}': {}", path.display(), e)))?;

        let compiler = mlua::Compiler::new().set_optimization_level(1).set_debug_level(1);
        let bytecode = compiler.compile(&source)
            .map_err(|e| Error::runtime(format!("syntax '{}': {}", path.display(), e)))?;

        let result: Value = lua.load(&bytecode).set_name(path.to_string_lossy()).eval()?;
        cache.set(module.as_str(), result.clone())?;
        Ok(result)
    })?;

    lua.globals().set("require", require_fn)?;
    Ok(())
}