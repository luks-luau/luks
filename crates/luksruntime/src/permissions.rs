use std::path::PathBuf;

/// Modelo de permissões opt-in para o runtime.
/// Inspirado em Bun/Deno: seguro por escolha, não por padrão.
/// Complementa o `mlua::SandboxMode` atuando no nível do host (FS, dlopen, require).
#[derive(Debug, Clone)]
pub struct Permissions {
    pub allow_read: bool,
    pub allow_native: bool,
    pub allow_import: bool,
    // Futuro: sandbox de FS por diretório
    pub restricted_paths: Vec<PathBuf>,
}

impl Permissions {
    /// Reads permissions from environment variables.
    /// Called on each check; env var reads are cheap and avoid OnceLock complexity.
    pub fn current() -> Self {
        let strict = std::env::var("LUKS_STRICT")
            .map(|v| v == "1" || v.eq_ignore_ascii_case("true"))
            .unwrap_or(false);

        if strict {
            Permissions {
                allow_read: std::env::var("LUKS_ALLOW_READ")
                    .map(|v| v == "1" || v.eq_ignore_ascii_case("true"))
                    .unwrap_or(false),
                allow_native: std::env::var("LUKS_ALLOW_NATIVE")
                    .map(|v| v == "1" || v.eq_ignore_ascii_case("true"))
                    .unwrap_or(false),
                allow_import: std::env::var("LUKS_ALLOW_IMPORT")
                    .map(|v| v == "1" || v.eq_ignore_ascii_case("true"))
                    .unwrap_or(false),
                restricted_paths: vec![],
            }
        } else {
            // Developer mode: allow everything by default for compatibility
            Permissions {
                allow_read: true,
                allow_native: true,
                allow_import: true,
                restricted_paths: vec![],
            }
        }
    }

    /// Hook para leitura de módulos/scripts do disco
    pub fn check_read(&self, _path: &PathBuf) -> Result<(), &'static str> {
        if !self.allow_read {
            return Err("Read access denied. Use --allow-read to enable.");
        }
        Ok(())
    }

    /// Hook para carregamento de bibliotecas nativas (dlopen)
    pub fn check_native(&self) -> Result<(), &'static str> {
        if !self.allow_native {
            return Err("Native module loading denied. Use --allow-native to enable.");
        }
        Ok(())
    }

    /// Hook para require/import de módulos Luau
    pub fn check_import(&self) -> Result<(), &'static str> {
        if !self.allow_import {
            return Err("Module import denied. Use --allow-import to enable.");
        }
        Ok(())
    }
}
