use mlua::Lua;
use std::path::{Path, PathBuf};

pub fn get_caller_dir(lua: &Lua) -> Option<PathBuf> {
    lua.inspect_stack(2, |dbg| {
        let src = dbg.source();
        // short_src: Option<Cow<str>>
        src.short_src.as_deref().and_then(|s| {
            s.strip_prefix('@')
                .map(|p| Path::new(p).parent().map(|pp| pp.to_path_buf()))
                .flatten()
        })
    })
    .flatten()
}

pub fn resolve_path(lua: &Lua, input: &str) -> PathBuf {
    let base = get_caller_dir(lua)
        .or_else(|| std::env::current_dir().ok())
        .unwrap_or_else(|| PathBuf::from("."));

    if let Some(rest) = input
        .strip_prefix("@self/")
        .or_else(|| input.strip_prefix("@self\\"))
    {
        return base.join(rest);
    }
    if input == "@self" {
        return base;
    }

    let p = Path::new(input);
    if input.starts_with("./")
        || input.starts_with("../")
        || input.starts_with(".\\")
        || input.starts_with("..\\")
    {
        base.join(p)
    } else if p.is_absolute() {
        p.to_path_buf()
    } else {
        base.join(p)
    }
}

/// Canonicaliza um caminho, com fallback para caminho absoluto se o arquivo não existir.
/// Isso garante uma chave de cache consistente mesmo se o arquivo ainda não foi criado.
///
/// Prioridade:
/// 1. `fs::canonicalize`: Resolve symlinks e caminho absoluto (falha se não existir)
/// 2. `path::absolute`: Resolve caminho absoluto sem resolver symlinks (não verifica existência)
/// 3. Fallback: Retorna o path original se tudo falhar
pub fn canonicalize_or_absolute(path: &Path) -> PathBuf {
    std::fs::canonicalize(path)
        .or_else(|_| std::path::absolute(path))
        .unwrap_or_else(|_| path.to_path_buf())
}
