# Contributing to luks-luau

Thank you for your interest in contributing to luks-luau! Contributions are welcome and appreciated, regardless of their size.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Project Structure](#project-structure)
- [Testing](#testing)
- [Code Style and Guidelines](#code-style-and-guidelines)
- [Pull Request Process](#pull-request-process)
- [Security](#security)

## Code of Conduct

This project adheres to a Code of Conduct. By participating, you are expected to uphold this code. Please see [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) for details.

## Getting Started

### Prerequisites

- **Rust**: 1.70 or later
- **Cargo**: Included with Rust
- **Git**: For version control

### Building the Project

```bash
# Clone the repository
git clone https://github.com/luks-luau/luks.git
cd luks

# Build in debug mode
cargo build

# Build in release mode (optimized)
cargo build --release
```

The release build produces optimized binaries with:
- Maximum optimization (`opt-level = "z"`)
- Link-time optimization (`lto = "fat"`)
- Single codegen unit for better optimization
- Stripped binaries

### Platform-Specific Builds

The project includes build scripts for different platforms:

```bash
# Windows
.\build-win.bat

# Linux/macOS
./build.sh

# Android
./build-android.sh
```

## Development Workflow

### 1. Create a Branch

```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/your-bug-fix
```

### 2. Make Your Changes

- Write code following the project's style guidelines
- Add tests for new functionality
- Update documentation as needed

### 3. Test Your Changes

```bash
# Run Rust tests
cargo test

# Run Luau test suite
.\target\release\lukscli.exe .\tests\main.luau
# or on Unix
./target/release/lukscli ./tests/main.luau
```

### 4. Format and Lint

```bash
# Format code
cargo fmt

# Run linter
cargo clippy -- -D warnings
```

### 5. Commit Your Changes

Follow the conventional commits format:

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `perf`: Performance improvements
- `test`: Adding or updating tests
- `chore`: Build process or tooling changes
- `ci`: CI/CD changes

**Scopes:**
- `runtime`: Core runtime library
- `cli`: Command-line interface
- `loader`: Native module loading
- `require`: Module require system
- `docs`: Documentation

**Example:**
```
feat(runtime): add support for custom library paths

Add LUKS_PATH environment variable to allow users to specify
additional library search paths for dlopen. This works across
all platforms and respects platform-specific path separators.

Closes #123
```

## Project Components

luks-luau consists of several key components:

- **luksruntime**: Core runtime library providing the C FFI interface.
  - Implements custom `require()` with module caching and `@self/` path resolution.
  - Provides `dlopen()` for loading native modules that export `luau_export`.
  - Manages runtime permissions and path resolution.
  - Includes async task scheduling via `mlua-luau-scheduler`.

- **lukscli**: Command-line interface for the runtime.
  - Script execution (`run` command), one-shot evaluation (`eval`), and interactive REPL.
  - Permission flags (`--no-read`, `--no-native`, `--no-import`, `--strict`).

- **mlua-luau-scheduler**: Async scheduler crate for Luau, using mlua.
  - Provides `Scheduler`, `Functions`, and traits for async task scheduling.
  - Supports `spawn`, `defer`, `cancel`, and coroutine wrapping.

- **Test Suite**: Located in `tests/`, uses a custom Luau test framework with auto-discovery.
  - Test runner: `main.luau` discovers and executes test cases.
  - Helpers: `helpers.luau` provides assertion functions.
  - Categories: Tests are organized by category (e.g., `require/`, `dlopen/`, `task/`).

### Key Components

- **luksruntime**: Core runtime library that provides C-compatible FFI interface
  - Implements custom `require()` function with module caching
  - Provides `dlopen()` for native module loading
  - Manages runtime permissions
  - Handles path resolution with `@self/` support

- **lukscli**: Command-line interface for the runtime
  - Script execution (`run` command)
  - One-shot evaluation (`eval` command)
  - Interactive REPL
  - Permission flags (`--no-read`, `--no-native`, `--no-import`, `--strict`)

## Testing

### Rust Tests

Rust tests are located alongside the code they test and use the standard Rust testing framework:

```bash
# Run all tests
cargo test

# Run specific test
cargo test test_library_file_names

# Run tests with output
cargo test -- --nocapture
```

### Luau Test Suite

The project uses a custom Luau test framework located in `tests/`:

#### Test Structure

The test suite uses a modular framework with auto-discovery:

- **Test Runner**: `main.luau` automatically discovers and executes test cases
- **Helpers**: `helpers.luau` provides assertion functions (`expect_eq`, `expect_true`, etc.)
- **Categories**: Tests are organized by category (e.g., `require/cases/`, `dlopen/cases/`, `task/cases/`)
- **Naming**: Test files follow sequential numbering: `cases/#1.luau`, `cases/#2.luau`, etc.

#### Running Tests

```bash
# Build the CLI first
cargo build --release

# Run the test suite
.\target\release\lukscli.exe .\tests\main.luau
```

#### Adding New Tests

1. Create a new test file in the appropriate category:
   ```
   tests/<category>/cases/#N.luau
   ```
   where `N` is the next sequential number.

2. Follow the test format:
   ```lua
   local h = require("../../helpers")

   return function(expect)
       h.suite("Test Suite Name", function()
           h.test("Test Name", function()
               -- Test code here
               expect.eq(actual, expected, "Optional message")
           end)
       end)
   end
   ```

3. The test runner will auto-discover and execute your test.

#### Available Assertions

- `expect_eq(a, b, msg?)` - Equality check
- `expect_true(v, msg?)` - True check
- `expect_false(v, msg?)` - False check
- `expect_nil(v, msg?)` - Nil check
- `expect_not_nil(v, msg?)` - Not nil check
- `expect_type(v, t, msg?)` - Type check
- `expect_error(fn, msg?)` - Expects function to error
- `expect_same_ref(a, b, msg?)` - Same reference check

#### Important Testing Notes

- **Always wrap error-prone operations in `pcall`**: The runtime converts internal panics to Luau errors, so use `pcall` to test error conditions
- **Test both success and failure paths**: Especially for `require()` and `dlopen()` operations
- **Use `@self/` for relative paths**: When testing path resolution, use the `@self/` prefix
- **Consider permission flags**: Test behavior with different permission settings

## Code Style and Guidelines

### Rust Code

- Use `cargo fmt` for formatting
- Follow standard Rust conventions
- Run `cargo clippy` and address all warnings
- Prefer idiomatic Rust patterns

### Luau Code

- Follow standard Luau/Lua conventions
- Use meaningful variable names
- Add comments for complex logic
- Test both success and error cases

### FFI and Unsafe Code

The project contains significant FFI and unsafe code, particularly in:
- `luksruntime/src/lib.rs` - Lua C API interactions
- `luksruntime/src/loader/platform.rs` - Dynamic library loading
- `luksruntime/src/luau_require.rs` - Require implementation

**Guidelines for unsafe code:**
- Isolate unsafe operations in well-documented functions
- Use `catch_unwind` at FFI boundaries to prevent panics from crossing
- Document safety invariants clearly
- Prefer safe wrappers when possible
- Test unsafe code thoroughly

### Error Handling

- Convert internal panics to Luau runtime errors where appropriate
- Use `catch_unwind` with `AssertUnwindSafe` for FFI safety
- Provide clear error messages
- Use fail-safe defaults (deny on error for permission checks)

## Pull Request Process

### Guidelines

- Don't ask to be assigned to an issue, just send a reasonably complete PR
- Your PR must include test coverage
- Avoid cosmetic changes to unrelated files in the same commit
- Use a feature branch instead of the main branch
- Use a rebase workflow. After addressing review comments, it's fine to force-push

### PR Stages

Pull requests have two stages: Draft and Ready for review.

1. **Create a Draft PR** while you are not requesting feedback and still working on the PR
2. **Change your PR to Ready** when the PR is ready for review
   - You can convert back to Draft at any time

Do not add labels like `[RFC]` or `[WIP]` in the title to indicate the state of your PR.

### PR Description

For bugfixes, your PR title should be essentially the same as the problem statement and the test-case name.

Include:
- **Description**: Brief description of changes
- **Type of Change**: Bug fix, new feature, breaking change, documentation update
- **Testing**: How you tested your changes
- **Checklist**: Code follows project style, tests added/updated, documentation updated

### Commit Messages

Follow the conventional commits format to make reviews easier and make the VCS/git logs more valuable.

**Structure:**
```
type(scope): subject

Problem:
...

Solution:
...
```

**Subject:**
- Prefix with a type: `build`, `ci`, `docs`, `feat`, `fix`, `perf`, `refactor`, `revert`, `test`
- Append an optional scope such as `(runtime)`, `(cli)`, `(loader)`, etc.
- Use the imperative voice: "Fix bug" rather than "Fixed bug" or "Fixes bug"
- Keep it short (under 72 characters)

**Body:**
- Concisely describe the Problem/Solution in the commit body
- Use the present tense
- Wrap at 72 characters

## Security

luks-luau is a runtime environment capable of executing code and loading native modules. Security is critical for this project.

For detailed security policies, trust model, permission system, and vulnerability reporting guidelines, see [SECURITY.md](SECURITY.md).

Key security considerations for contributors:
- The runtime is not sandboxed by default
- Permission system controls access to sensitive operations
- FFI boundaries require careful handling
- Always follow fail-safe defaults (deny on error)

## Platform Support

The project aims to support:
- **Windows**: Primary development platform
- **Linux**: Full support
- **macOS**: Full support
- **Android**: Experimental support

When adding features:
- Consider platform differences
- Use conditional compilation (`#[cfg(...)]`) when necessary
- Test on multiple platforms when possible
- Document platform-specific behavior

## Getting Help

If you need help:
- Open an issue for bugs or questions
- Check existing issues and discussions
- Review the code and tests for examples
- Contact maintainers at [hryan5192+luks-luau@gmail.com](mailto:hryan5192+luks-luau@gmail.com)

## License

By contributing, you agree that your contributions will be licensed under the MIT License.