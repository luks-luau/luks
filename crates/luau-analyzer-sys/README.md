# luau-analyzer-sys

High-level ergonomic Rust bindings and low-level C++ FFI bindings for the native [Luau](https://luau.org/) static type analyzer and compiler frontend.

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Rust](https://img.shields.io/badge/rust-1.70%2B-orange.svg)

## Overview

`luau-analyzer-sys` provides a bridge between Rust and Luau's C++ static type checking engine (`Luau::Frontend`). It abstracts away internal type resolution scopes, AST traversal checks, and linting routines into a safe, easy-to-use Rust interface (`NativeAnalyzer`).

### Key Features

- **Embedded Type Analysis**: Perform zero-overhead static checking of Luau codebases directly from Rust.
- **Custom Definitions**: Inject global environment mapping definitions dynamically via Luau `.d.luau` files.
- **Dependency Resolution**: Fully recursive module path resolution via safe Rust closures.
- **Granular Diagnostics**: Capture detailed warnings, errors, and lint output complete with source span offsets.
- **Deprecation Linting**: Native static interception of deprecated functions (e.g. `getfenv`) mapped via dynamic line deduplication.

## Usage

Add `luau-analyzer-sys` as a dependency in your `Cargo.toml`:

```toml
[dependencies]
luau-analyzer-sys = { path = "../luau-analyzer-sys" }
```

### Example: Checking a Luau Module

```rust
use luau_analyzer_sys::NativeAnalyzer;

fn main() {
    let mut analyzer = NativeAnalyzer::new();

    // 1. Inject global type definitions
    analyzer.add_definitions(r#"
declare task: {
    spawn: (...any) -> thread
}
"#);

    // 2. Check source code using a recursive string-resolving closure
    let source = "task.spawn(function() print('Checking native type structures') end)";
    let diagnostics = analyzer.check("main.luau", |module_name| {
        if module_name == "main.luau" {
            Some(source.to_string())
        } else {
            None
        }
    });

    if diagnostics.is_empty() {
        println!("Type checking completed successfully with zero errors.");
    } else {
        for diag in diagnostics {
            let severity = if diag.severity == 0 { "error" } else { "warning" };
            println!("{}: {} at line {}:{}", severity, diag.message, diag.line + 1, diag.col + 1);
        }
    }
}
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
