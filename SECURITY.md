# 🔒 Security Policy & Trust Model

## 🎯 Trust Model
`luks-luau` is a **general-purpose runtime** designed to execute trusted or audited code, following the philosophy of Python, Node.js, and Bun.

⚠️ **NOT sandboxed by default.** 
If you intend to execute third-party or untrusted code, you MUST use operating system-level isolation (Docker, cgroups, namespaces, VMs).

## 🛡️ Recommended Security Layers
| Layer | Responsibility | Example Configuration |
|--------|----------------|-------------------------|
| **Operating System** | Non-root users, `no-new-privileges`, `--read-only` FS, cgroups | Docker: `--user 1000:1000 --read-only --memory=512m` |
| **Host Runtime (luks-luau)** | Granular control of I/O and native modules | Flags `--no-read`, `--no-native`, `--no-import`, `--strict` |
| **Luau VM (mlua 0.11.6)** | Execution limits, stdlib sandboxing, type checking | `LuauOptions { sandboxed: true }`, `set_instruction_limit()`, `set_sandbox_mode()` |
| **Host Application** | Input validation, module whitelisting, audit logging | Bytecode signature verification, rate limiting |

## 🚨 Reporting Vulnerabilities
1. **Do NOT** open public issues for security flaws.
2. Please report vulnerabilities via one of the following channels:
   - Open a [GitHub Security Advisory](https://github.com/luks-luau/luks/security/advisories/new)
   - Email maintainers directly: [hryan5192+luks-luau@gmail.com](mailto:hryan5192+luks-luau@gmail.com)
3. We aim to acknowledge reports within 48 hours. Typical fix timeline: 7 days.

## 📜 Runtime Permissions
| Flag | Behavior |
|------|---------------|
| `--no-read` | Denies reading scripts and modules from disk |
| `--no-native` | Denies dynamic loading of libraries (`dlopen`) |
| `--no-import` | Denies `require`/`import` between Luau modules |
| `--strict` | Deny-by-default mode (`ALLOW_*` env vars become required) |

*Note: The current CLI is allow-by-default with deny flags. For stronger restriction use `--strict` plus explicit `LUKS_ALLOW_*` environment variables.*
