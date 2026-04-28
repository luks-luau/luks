/// Emits runtime warnings only when `LUKS_VERBOSE` is enabled.
pub fn runtime_warn(message: &str) {
    let verbose = std::env::var("LUKS_VERBOSE")
        .map(|v| v == "1" || v.eq_ignore_ascii_case("true"))
        .unwrap_or(false);

    if verbose {
        eprintln!("[LUKS] {}", message);
    }
}
