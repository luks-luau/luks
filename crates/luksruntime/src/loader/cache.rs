// Cache simplificado - por enquanto apenas placeholder
// A biblioteca é mantida viva via Box::leak em platform.rs
// Futuramente pode-se implementar contagem de referências

pub struct ModuleCache;

impl ModuleCache {
    pub fn new() -> Self {
        Self
    }
}

impl Default for ModuleCache {
    fn default() -> Self {
        Self::new()
    }
}
