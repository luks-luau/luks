# Security Policy

## Supported Versions

Security updates are provided for the latest version of luks-luau. Users are strongly encouraged to keep their installations up to date.

## Reporting a Vulnerability

If you discover a security vulnerability, please do NOT open a public issue. Instead, send your report privately to the maintainers.

### How to Report

1. **GitHub Security Advisory** (Preferred):
   - Open a new advisory at https://github.com/luks-luau/luks/security/advisories/new
   - This provides a private, coordinated disclosure process

2. **Email**:
   - Send to [hryan5192+luks-luau@gmail.com](mailto:hryan5192+luks-luau@gmail.com)
   - Include "SECURITY" in the subject line

### What to Include

Please include as much of the following information as possible:
- Description of the vulnerability
- Steps to reproduce the issue
- Potential impact of the vulnerability
- Any suggested mitigation or fix

### Response Timeline

- **Acknowledgment**: We aim to acknowledge reports within 48 hours
- **Initial Assessment**: We will provide an initial assessment within 7 days
- **Fix Timeline**: Depending on severity, fixes are typically released within 7-14 days

## Security Model

luks-luau is a **general-purpose runtime** designed to execute trusted or audited code, following the philosophy of Python, Node.js, and Bun.

### Important: Not Sandboxed by Default

⚠️ **luks-luau is NOT sandboxed by default.**

If you intend to execute third-party or untrusted code, you MUST use operating system-level isolation:
- Docker containers
- cgroups
- Linux namespaces
- Virtual machines
- Other OS-level sandboxing mechanisms

### Defense in Depth

We recommend a layered security approach:

| Layer | Responsibility | Example Configuration |
|--------|----------------|-------------------------|
| **Operating System** | Non-root users, no-new-privileges, read-only filesystem, resource limits | Docker: `--user 1000:1000 --read-only --memory=512m` |
| **Host Runtime (luks-luau)** | Granular control of I/O and native modules | Flags `--no-read`, `--no-native`, `--no-import`, `--strict` |
| **Luau VM (mlua)** | Execution limits, stdlib sandboxing, type checking | `LuauOptions { sandboxed: true }`, `set_instruction_limit()` |
| **Host Application** | Input validation, module whitelisting, audit logging | Bytecode signature verification, rate limiting |

## Runtime Permissions

luks-luau provides a permission system to control access to sensitive operations:

### Permission Flags

| Flag | Behavior |
|------|---------------|
| `--no-read` | Denies reading scripts and modules from disk |
| `--no-native` | Denies dynamic loading of libraries (`dlopen`) |
| `--no-import` | Denies `require`/`import` between Luau modules |
| `--strict` | Deny-by-default mode (explicit `ALLOW_*` env vars required) |

### Permission Modes

**Allow-by-default (default mode):**
- All permissions are granted by default
- Use deny flags to restrict specific capabilities
- Suitable for development and trusted code execution

**Deny-by-default (strict mode):**
- All permissions are denied by default
- Use `LUKS_ALLOW_*` environment variables to grant specific permissions
- Recommended for production and untrusted code scenarios

### Environment Variables

- `LUKS_STRICT=1`: Enable strict mode
- `LUKS_DENY_READ=1`: Deny read permission
- `LUKS_DENY_NATIVE=1`: Deny native module loading
- `LUKS_DENY_IMPORT=1`: Deny module imports
- `LUKS_ALLOW_READ=1`: Allow read (in strict mode)
- `LUKS_ALLOW_NATIVE=1`: Allow native modules (in strict mode)
- `LUKS_ALLOW_IMPORT=1`: Allow imports (in strict mode)

## Security Best Practices for Contributors

When contributing to luks-luau, keep these security considerations in mind:

### Permission System
- Default to deny on internal errors (fail-safe)
- Test both allowed and denied states
- Document permission requirements clearly

### Native Module Loading
- Validate all inputs before processing
- Use safe path resolution
- Consider the implications of library search paths
- Test with malicious inputs

### FFI Safety
- Never let Rust panics cross FFI boundaries
- Validate all data from Lua before use
- Use `catch_unwind` consistently at FFI boundaries
- Document all safety assumptions

### Error Handling
- Convert internal panics to Luau runtime errors where appropriate
- Provide clear error messages without exposing sensitive information
- Use fail-safe defaults

## Security Announcements

Security advisories and updates will be published through:
- GitHub Security Advisories
- Release notes in CHANGELOG.md
- GitHub releases

## Reaching the Security Team

For security-related questions or concerns that are not vulnerability reports:
- Email: [hryan5192+luks-luau@gmail.com](mailto:hryan5192+luks-luau@gmail.com)
- Include "SECURITY QUESTION" in the subject line