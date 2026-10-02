# EnvOps — Agent Knowledge Base & Developer Guidelines

> **Target Audience**: AI Agents (Antigravity, Claude Code, Cursor, Copilot, Windsurf, Cline) and Human Contributors.
> **Last Updated**: October 2026

---

## 1. Project Overview & Mission

**EnvOps** (`env_ops`) is a client-only mobile DevOps console and SSH client built with Flutter. It empowers systems engineers and infrastructure administrators to monitor, diagnose, and securely manage Linux VPS clusters and Docker containers directly from iOS/Android devices.

### Core Architectural Axiom: Zero Third-Party Cloud
- **No external server**: There is no intermediary backend server, Supabase, Firebase, or external API broker.
- **Direct P2P SSH**: All telemetry, Docker controls, and terminal sessions communicate directly via peer-to-peer SSH (port 22 or custom port) over private networks (e.g. Tailscale, WireGuard, private VPN).
- **Client-Side Cryptography**: Private keys never leave the device unencrypted. Backups use client-side PBKDF2 + AES-256-CBC with user-provided Master Passwords.

---

## 2. Tech Stack & Dependencies

| Layer | Technology | Key Package |
|---|---|---|
| **Framework** | Flutter 3.x (Dart 3.x) | `flutter` |
| **State Management** | Riverpod 3 | `flutter_riverpod: ^3.4.3` |
| **SSH Transport** | Direct SSH v2 Client | `dartssh2: ^4.1.0` |
| **Terminal Emulation**| VT100 / xterm ANSI | `xterm: ^4.0.0` |
| **Key Storage** | Android KeyStore / iOS Keychain | `flutter_secure_storage: ^11.2.0` |
| **Local Persistence** | SharedPreferences | `shared_preferences: ^2.5.5` |
| **Offline Encryption** | PBKDF2 + AES-256-CBC | `pointycastle: 4.0.0` |
| **Biometrics** | Biometric / App PIN Lock | `local_auth: ^3.0.2` |
| **Navigation** | Declarative Router | `go_router: ^18.0.2` |
| **Testing** | Unit & Widget Tests | `flutter_test`, `mocktail: ^1.0.5` |

---

## 3. Architecture & Codebase Layout

EnvOps follows strict **Clean Architecture** with separation of concerns:

```
lib/
├── core/
│   ├── errors/             # Custom Failure classes (SshConnectionFailure, HostKeyMismatchFailure)
│   ├── security/           # Hardware secure storage, PBKDF2 AES-256 backup crypto, secret redactor
│   ├── theme/              # High-contrast dark cybersecurity UI theme (AppTheme)
│   └── utils/              # Shell escaping utilities
├── data/
│   ├── repositories/       # DartSshRepository, LocalServerRepository, LocalSshKeyRepository, MockSshRepository
│   └── services/           # BackupService (export/import), FullDiagnoseService, HttpHealthService
├── domain/
│   ├── models/             # ServerConfig, SshKeyModel, DockerContainer, ServerProfile, AuditLog
│   └── repositories/       # Abstract repository interfaces (ServerRepository, SshKeyRepository, etc.)
└── presentation/
    ├── providers/          # Riverpod providers (serverListProvider, sshKeyListProvider, etc.)
    ├── router/             # AppRouter (go_router route table)
    ├── screens/
    │   ├── dashboard/      # Fleet status & quick telemetry overview
    │   ├── servers/        # Server detail, metrics, and Add/Edit server forms
    │   ├── terminal/       # PTY-backed interactive SSH terminal screen
    │   ├── docker/         # Live container status, log streaming, and restart dialogs
    │   ├── diagnostics/    # Full diagnose suite and sanitized AI copy dialogs
    │   ├── keys/           # SSH key manager (import, generate, inspect fingerprints)
    │   └── settings/       # Master password backup export/import, App Lock, Dev mode
    └── widgets/            # Reusable UI widgets (EnvBadge, TerminalToolbar, HostKeyMismatchDialog)
```

---

## 4. Critical Engineering Rules for Agents (Do NOT Violate)

### Rule 1: Mandatory `flutter analyze` & `flutter test`
- **Rule**: NEVER mark any task as complete without running and verifying that `flutter analyze` returns `0 issues` and `flutter test` passes 100%.
- Any newly created code must strictly adhere to `analysis_options.yaml` (avoid unused imports, prefer initializing formals, proper typed constructors).

### Rule 2: PointyCastle vs Encrypt Dependency Conflict
- **CRITICAL**: Do **NOT** add the `encrypt` package (`encrypt: ^5.x`) to `pubspec.yaml`.
- **Reason**: The `encrypt` package pins `pointycastle: ^3.x`, which conflicts directly with `dartssh2: ^4.1.0` (which requires `pointycastle: 4.0.0`).
- **Solution**: Use `pointycastle: 4.0.0` directly for AES-256 and PBKDF2 as implemented in `lib/core/security/backup_crypto_service.dart`.

### Rule 3: Strict Host Key Verification
- EnvOps enforces strict host-key verification against MITM attacks.
- If a server's presented fingerprint does not match the stored SHA-256 fingerprint, throw `HostKeyMismatchFailure` and **strictly block** connection. Never provide an automated bypass.

### Rule 4: Non-Blocking SSH & Isolate Offloading
- SSH key parsing using Bcrypt KDF (24 rounds) or heavy RSA/Ed25519 calculations can cause UI jank (freeze) on mobile devices if run on the main isolate.
- Always perform heavy key parsing inside `Isolate.run(...)` and cache parsed keys in `_keyPairCache`.
- Quick telemetry calls reuse pooled SSH client sessions via `_activeClient` / `_activeServerId` in `DartSshRepository`.

### Rule 5: Riverpod State Mutation Timing
- Never mutate a provider (e.g. `ref.read(...).load()`) synchronously inside a widget's `build()` method.
- Always defer lifecycle mutations using `WidgetsBinding.instance.addPostFrameCallback(...)` or `Future.microtask(...)`.

### Rule 6: Shell Escaping & Raw Strings
- In Dart, string interpolation evaluates `$` symbols. When generating remote bash/shell scripts containing shell variables like `$DK`, always use Dart raw string literals (`r'$DK'`) or properly escaped `\$DK`.

### Rule 7: Zero Secrets & Sanitization
- Never commit or log private keys, passwords, live production IPs, or corporate customer names in code, documentation, or test fixtures.
- The `SecretRedactor` class (`lib/core/security/secret_redactor.dart`) must always be used before copying diagnostic outputs or logs for external AI analysis.

---

## 5. Domain Models Quick Reference

### `ServerConfig` (`lib/domain/models/server_config.dart`)
- Represents a remote Linux VPS.
- Fields: `id`, `name`, `hostname`, `port`, `username`, `environment` (`production`, `staging`, `development`, `monitoring`, `other`), `keyId`, `hostKeyFingerprint`, `profile`, `tags`.
- `isProduction`: Boolean getter indicating whether production safeguards (strict confirmation modals) apply.

### `SshKeyModel` (`lib/domain/models/ssh_key_model.dart`)
- Metadata for an imported or generated SSH key.
- Sensitive secrets (`privateKeyPem`, `passphrase`) are **never** stored in the model or SharedPreferences; they are stored exclusively in hardware-backed `SecureStorageService`.

### `BackupService` (`lib/data/services/backup_service.dart`)
- **Export**: Packs all servers and SSH keys into JSON schema `env_ops_backup` and encrypts with `BackupCryptoService.encrypt` using AES-256-CBC + PBKDF2.
- **Import**: Decrypts payload with Master Password and restores both SharedPreferences metadata and KeyStore secrets.
- **Prefix**: `ENVOPS_ENC_V1:<salt_base64>:<iv_base64>:<ciphertext_base64>`. (Backward-compatible with legacy `CASOPS_ENC_V1:`).

---

## 6. Development & Testing Commands

```bash
# Analyze code for static errors & lint warnings (MUST BE 0 ISSUES)
flutter analyze

# Run all unit and widget tests (MUST ALL PASS)
flutter test

# Run a specific test file
flutter test test/unit/backup_service_test.dart

# Build Ultra-Slim ARM64 Release APK (Windows PowerShell):
.\scripts\build_release_arm64.ps1

# Build with --no-tree-shake-icons (if custom icon fonts fail tree-shaking):
.\scripts\build_release_arm64.ps1 -NoTreeShake

# Build Ultra-Slim ARM64 Release APK (Bash / Linux / macOS / CI):
./scripts/build_release_arm64.sh

> **Agent Note**: When a user tags `scripts/build_release_arm64.ps1` or asks to build an optimized APK for their phone, execute this script directly. It targets `android-arm64`, applies `--obfuscate`, and strips debug symbols to produce the smallest possible standalone APK.
```
