use mlua::{Function, Lua, NavigateError, Require, Result as LuaResult};
use std::fs::File;
use std::io::{self, Read};
use std::path::{Path, PathBuf};
use std::result::Result as StdResult;

/// Implementação do trait Require do mlua para o sistema de módulos Luks
///
/// Esta struct mantém o estado de navegação durante a resolução de um módulo.
/// O Luau chama os métodos de navegação (reset, to_parent, to_child) para
/// construir o caminho do módulo, depois verifica has_module() e chama loader().
pub struct LuksRequirer {
    /// Caminho atual durante a navegação
    current_path: PathBuf,
    /// Diretório do script que está fazendo require (de __script_dir__)
    script_dir: PathBuf,
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

    /// Encontra o arquivo de módulo correspondente ao caminho atual.
    /// Tenta as extensões .luau e .lua, e também init.luau/init.lua para diretórios.
    fn find_module(&self) -> Option<PathBuf> {
        let base = &self.current_path;

        // Tenta como arquivo com extensão .luau ou .lua
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

        // Tenta init.luau ou init.lua no diretório
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

    /// Resolve um caminho de módulo, considerando @self/ e caminhos relativos
    fn resolve_module_path(&self, input: &str) -> PathBuf {
        // Se começa com @self/, resolve relativo ao script_dir
        if let Some(rest) = input
            .strip_prefix("@self/")
            .or_else(|| input.strip_prefix("@self\\"))
        {
            return self.script_dir.join(rest);
        }
        if input == "@self" {
            return self.script_dir.clone();
        }

        let p = Path::new(input);

        // Caminho relativo explícito: resolve relativo ao script_dir
        if input.starts_with("./")
            || input.starts_with("../")
            || input.starts_with(".\\")
            || input.starts_with("..\\")
        {
            self.script_dir.join(p)
        } else if p.is_absolute() {
            // Caminho absoluto
            p.to_path_buf()
        } else {
            // Nome simples: tenta relativo ao script_dir primeiro
            self.script_dir.join(p)
        }
    }
}

impl Default for LuksRequirer {
    fn default() -> Self {
        Self::new()
    }
}

impl Require for LuksRequirer {
    /// Verifica se require é permitido para o chunk especificado
    fn is_require_allowed(&self, chunk_name: &str) -> bool {
        // Tenta verificar a permissão de forma segura com proteção contra panic
        match std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
            crate::permissions::Permissions::current().check_import()
        })) {
            Ok(true) => true, // Permitido
            Ok(false) => {
                eprintln!("[LUKS] Permission Denied: require('{}')", chunk_name);
                false // Bloqueado
            }
            Err(_) => {
                eprintln!("[LUKS] Internal Error: Permission check panicked. Denying access to '{}'.", chunk_name);
                false // Fail-safe: negar em caso de erro interno
            }
        }
    }

    /// Reseta o estado para o diretório do chunk que está fazendo require
    fn reset(&mut self, chunk_name: &str) -> StdResult<(), NavigateError> {
        let chunk_name = chunk_name.strip_prefix('@').unwrap_or(chunk_name);

        // Define current_path como o caminho completo do arquivo (não o diretório)
        // O Luau vai chamar to_parent para navegar para o diretório quando necessário
        self.current_path = PathBuf::from(chunk_name);

        // O script_dir é o diretório do chunk (usado para resolver @self/)
        self.script_dir = Path::new(chunk_name)
            .parent()
            .map(|p| p.to_path_buf())
            .unwrap_or_else(|| PathBuf::from("."));

        Ok(())
    }

    /// Navega para um alias (caminho absoluto/relativo completo)
    fn jump_to_alias(&mut self, path: &str) -> StdResult<(), NavigateError> {
        self.current_path = self.resolve_module_path(path);
        Ok(())
    }

    /// Navega para o diretório pai
    fn to_parent(&mut self) -> StdResult<(), NavigateError> {
        if !self.current_path.as_os_str().is_empty() {
            self.current_path.pop();
        }
        Ok(())
    }

    /// Navega para um subdiretório/nome
    fn to_child(&mut self, name: &str) -> StdResult<(), NavigateError> {
        self.current_path.push(name);
        Ok(())
    }

    /// Verifica se o caminho atual aponta para um módulo existente
    fn has_module(&self) -> bool {
        self.find_module().is_some()
    }

    /// Retorna a chave de cache para o módulo atual
    /// Usada pelo Luau para cache em package.loaded
    fn cache_key(&self) -> String {
        // Usa o helper unificado para garantir consistência com dlopen
        let Some(module) = self.find_module() else {
            return self.current_path.to_string_lossy().to_string();
        };

        crate::utils::canonicalize_or_absolute(&module)
            .to_string_lossy()
            .to_string()
    }

    /// Verifica se existe configuração no contexto atual (não usado)
    fn has_config(&self) -> bool {
        false
    }

    /// Retorna o conteúdo da configuração (não usado)
    fn config(&self) -> io::Result<Vec<u8>> {
        Err(io::Error::new(io::ErrorKind::NotFound, "no config"))
    }

    /// Cria e retorna a função loader para o módulo atual
    fn loader(&self, lua: &Lua) -> LuaResult<Function> {
        let path = self.find_module().ok_or_else(|| {
            mlua::Error::runtime(format!(
                "módulo não encontrado: {}",
                self.current_path.display()
            ))
        })?;

        // Lê o arquivo
        let mut file = File::open(&path)
            .map_err(|e| mlua::Error::runtime(format!("abrir '{}': {}", path.display(), e)))?;

        let mut source = String::new();
        file.read_to_string(&mut source)
            .map_err(|e| mlua::Error::runtime(format!("ler '{}': {}", path.display(), e)))?;

        // Compila e retorna a função
        // O mlua/Luau gerencia o cache e o ambiente
        lua.load(&source)
            .set_name(path.to_string_lossy())
            .into_function()
    }
}
