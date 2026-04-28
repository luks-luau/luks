#[derive(Clone, Debug, Default)]
pub struct Permissions {
    pub allow_read: bool,
    pub allow_native: bool,
    pub allow_import: bool,
}

impl Permissions {
    /// Lê configurações de permissão do ambiente.
    /// - Modo padrão: Allow-by-Default (tudo liberado)
    /// - Modo Strict: Deny-by-Default (requer ALLOW_* explícito)
    /// - Flags DENY_* têm precedência sobre allow-by-default
    pub fn current() -> Self {
        let strict = std::env::var("LUKS_STRICT")
            .map(|v| v == "1" || v.eq_ignore_ascii_case("true"))
            .unwrap_or(false);

        if strict {
            // Sandbox: negado por padrão, requer ALLOW_* explícito
            Permissions {
                allow_read: std::env::var("LUKS_ALLOW_READ").is_ok(),
                allow_native: std::env::var("LUKS_ALLOW_NATIVE").is_ok(),
                allow_import: std::env::var("LUKS_ALLOW_IMPORT").is_ok(),
            }
        } else {
            // Dev: permitido por padrão, mas DENY_* bloqueia
            Permissions {
                allow_read: std::env::var("LUKS_DENY_READ").is_err(),
                allow_native: std::env::var("LUKS_DENY_NATIVE").is_err(),
                allow_import: std::env::var("LUKS_DENY_IMPORT").is_err(),
            }
        }
    }

    pub fn check_read(&self) -> bool { self.allow_read }
    pub fn check_native(&self) -> bool { self.allow_native }
    pub fn check_import(&self) -> bool { self.allow_import }
}

pub fn check_native_safely() -> Result<bool, &'static str> {
    std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        Permissions::current().check_native()
    }))
    .map_err(|_| "internal permission error")
}

pub fn check_import_safely() -> Result<bool, &'static str> {
    std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        Permissions::current().check_import()
    }))
    .map_err(|_| "internal permission error")
}
