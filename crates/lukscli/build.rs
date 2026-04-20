fn main() {
    let target = std::path::PathBuf::from(env!("CARGO_MANIFEST_DIR"))
       .parent().unwrap().parent().unwrap()
       .join("target").join("release");

    println!("cargo:rustc-link-search=native={}", target.display());
    println!("cargo:rustc-link-lib=static=luksruntime");
    // o Rust já puxa ws2_32 etc sozinho
}