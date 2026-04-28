#[derive(Clone, Debug, Default)]
pub struct Permissions {
    pub allow_read: bool,
    pub allow_native: bool,
    pub allow_import: bool,
}

impl Permissions {
    /// Reads runtime permissions from environment variables.
    /// - Default mode: allow-by-default (everything enabled)
    /// - Strict mode: deny-by-default (explicit `ALLOW_*` required)
    /// - `DENY_*` flags override allow-by-default behavior
    pub fn current() -> Self {
        let strict = std::env::var("LUKS_STRICT")
            .map(|v| v == "1" || v.eq_ignore_ascii_case("true"))
            .unwrap_or(false);

        if strict {
            // Strict mode: deny by default, explicit `ALLOW_*` required.
            Permissions {
                allow_read: std::env::var("LUKS_ALLOW_READ").is_ok(),
                allow_native: std::env::var("LUKS_ALLOW_NATIVE").is_ok(),
                allow_import: std::env::var("LUKS_ALLOW_IMPORT").is_ok(),
            }
        } else {
            // Dev mode: allow by default, `DENY_*` can block capabilities.
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

/// Checks native-loading permission and converts panics into errors.
pub fn check_native_safely() -> Result<bool, &'static str> {
    std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        Permissions::current().check_native()
    }))
    .map_err(|_| "internal permission error")
}

/// Checks module-import permission and converts panics into errors.
pub fn check_import_safely() -> Result<bool, &'static str> {
    std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
        Permissions::current().check_import()
    }))
    .map_err(|_| "internal permission error")
}
