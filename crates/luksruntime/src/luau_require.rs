use mlua::{Lua, Result as LuaResult, Function, Require, NavigateError};
use std::io::{self, Read};
use std::path::{Path, PathBuf};
use std::fs::File;
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
    /// Caminho final do módulo encontrado (populado quando has_module encontra algo)
    resolved_path: Option<PathBuf>,
}

impl LuksRequirer {
    pub fn new() -> Self {
        Self {
            current_path: PathBuf::from("."),
            script_dir: PathBuf::from("."),
            resolved_path: None,
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
        
        // Tenta init.luau ou init.lua no diretório
        for ext in ["luau", "lua"] {
            let init = base.join(format!("init.{}", ext));
            if init.is_file() {
                return Some(init);
            }
        }
        
        None
    }

    /// Resolve um caminho de módulo, considerando @self/ e caminhos relativos
    fn resolve_module_path(&self, input: &str) -> PathBuf {
        // Se começa com @self/, resolve relativo ao script_dir
        if let Some(rest) = input.strip_prefix("@self/") {
            return self.script_dir.join(rest);
        }
        if input == "@self" {
            return self.script_dir.clone();
        }

        let p = Path::new(input);
        
        // Caminho relativo explícito: resolve relativo ao script_dir
        if input.starts_with("./") || input.starts_with("../") {
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
    fn is_require_allowed(&self, _chunk_name: &str) -> bool {
        true // Sempre permitir
    }

    /// Reseta o estado para o diretório do chunk que está fazendo require
    fn reset(&mut self, chunk_name: &str) -> StdResult<(), NavigateError> {
        // Define current_path como o caminho completo do arquivo (não o diretório)
        // O Luau vai chamar to_parent para navegar para o diretório quando necessário
        self.current_path = PathBuf::from(chunk_name);
        
        // O script_dir é o diretório do chunk (usado para resolver @self/)
        self.script_dir = Path::new(chunk_name)
            .parent()
            .map(|p| p.to_path_buf())
            .unwrap_or_else(|| PathBuf::from("."));
        self.resolved_path = None;
        
        Ok(())
    }

    /// Navega para um alias (caminho absoluto/relativo completo)
    fn jump_to_alias(&mut self, path: &str) -> StdResult<(), NavigateError> {
        self.current_path = self.resolve_module_path(path);
        self.resolved_path = None;
        Ok(())
    }

    /// Navega para o diretório pai
    fn to_parent(&mut self) -> StdResult<(), NavigateError> {
        self.current_path.pop();
        self.resolved_path = None;
        Ok(())
    }

    /// Navega para um subdiretório/nome
    fn to_child(&mut self, name: &str) -> StdResult<(), NavigateError> {
        self.current_path.push(name);
        self.resolved_path = None;
        Ok(())
    }

    /// Verifica se o caminho atual aponta para um módulo existente
    fn has_module(&self) -> bool {
        self.find_module().is_some()
    }

    /// Retorna a chave de cache para o módulo atual
    /// Usada pelo Luau para cache em package.loaded
    fn cache_key(&self) -> String {
        // Usa o caminho canônico como chave de cache
        if let Some(resolved) = &self.resolved_path {
            resolved.to_string_lossy().to_string()
        } else if let Some(module) = self.find_module() {
            module.to_string_lossy().to_string()
        } else {
            self.current_path.to_string_lossy().to_string()
        }
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
        let path = self.find_module()
            .ok_or_else(|| mlua::Error::runtime(
                format!("módulo não encontrado: {}", self.current_path.display())
            ))?;
        
        // Lê o arquivo
        let mut file = File::open(&path)
            .map_err(|e| mlua::Error::runtime(
                format!("abrir '{}': {}", path.display(), e)
            ))?;
        
        let mut source = String::new();
        file.read_to_string(&mut source)
            .map_err(|e| mlua::Error::runtime(
                format!("ler '{}': {}", path.display(), e)
            ))?;
        
        // Compila e retorna a função
        // O mlua/Luau gerencia o cache e o ambiente
        lua.load(&source)
            .set_name(path.to_string_lossy())
            .into_function()
    }
}
