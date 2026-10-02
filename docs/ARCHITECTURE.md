# EnvOps Architecture & Systems Design

This document details the architectural decisions, data flow diagrams, security mechanisms, and threading models employed in **EnvOps**.

---

## 1. High-Level System Architecture

EnvOps is a completely standalone mobile client that interfaces directly with remote Linux servers over SSH v2.

```
┌─────────────────────────────────────────────────────────────┐
│                       EnvOps Mobile App                     │
│                                                             │
│   ┌─────────────────────┐       ┌──────────────────────┐    │
│   │  Presentation Layer │       │     Domain Layer     │    │
│   │  (Riverpod + UI)    │◄─────►│   (Entities & Use)   │    │
│   └──────────┬──────────┘       └──────────▲───────────┘    │
│              │                             │                │
│              ▼                             │                │
│   ┌────────────────────────────────────────┴───────────┐    │
│   │                     Data Layer                     │    │
│   │  - DartSshRepository      - BackupService          │    │
│   │  - LocalServerRepository  - SecureStorageService   │    │
│   └──────────┬─────────────────────────────┬───────────┘    │
└──────────────┼─────────────────────────────┼────────────────┘
               │                             │
               │ Hardware KeyStore / Files   │ Direct TCP Port 22 (SSH v2)
               ▼                             ▼
   ┌───────────────────────┐     ┌───────────────────────┐
   │ Android KeyStore /    │     │   Remote Linux VPS    │
   │ SharedPreferences     │     │   - Docker Daemon     │
   │                       │     │   - Systemd Services  │
   │ - Private Keys (AES)  │     │   - Host SSHD         │
   │ - Server Meta (JSON)  │     │   - PTY Shell         │
   └───────────────────────┘     └───────────────────────┘
```

---

## 2. Core Subsystems

### A. SSH Transport & Isolate Threading
- **Library**: `dartssh2: ^4.1.0`
- **Key Decryption Offloading**: OpenSSH private keys encrypted with modern Bcrypt KDF (24+ rounds) require substantial CPU computation. In `DartSshRepository`, key parsing is offloaded to a background Dart isolate using `Isolate.run()` to prevent main UI thread frame drops.
- **Client Session Pooling**: Quick telemetry requests (e.g. CPU load, memory, disk usage) reuse the active `SSHClient` connection (`_activeClient`), avoiding repeated TCP handshakes and key negotiations.
- **Interactive Terminal**: Driven by `xterm.dart` connected to an SSH pseudo-terminal (`SSHChannel`) with dynamic window size negotiation (`SIGWINCH`).

### B. Hardware-Backed Security Model
- **`SecureStorageService`**: Wraps `flutter_secure_storage`.
  - Android: AES-GCM encryption with master key wrapped in Android KeyStore.
  - iOS: Stored in the iOS Keychain with `kSecAttrAccessibleAfterFirstUnlock`.
- **Stored in Secure Storage**:
  - `key_priv_{keyId}`: OpenSSH private key PEM.
  - `key_pass_{keyId}`: Passphrase for the private key (if encrypted).
- **Stored in Standard Storage (`SharedPreferences`)**:
  - `env_ops_servers_v1`: Server definitions (IP, port, username, tags, profile, host fingerprint).
  - `env_ops_ssh_key_meta_v1`: Key metadata (name, keyType, fingerprint, creation date).

### C. Offline Cryptographic Backup & Migration
- **Standard**: PBKDF2 with SHA-256 HMAC (10,000 iterations) + AES-256-CBC with PKCS7 padding.
- **Implementation**: Native `pointycastle: 4.0.0` directly without intermediary wrappers.
- **Payload Format**:
  ```
  ENVOPS_ENC_V1:<base64(16_bytes_salt + 16_bytes_iv + ciphertext)>
  ```
- **Portability**: Users can export the string from one device, send it via any messaging app or notes, and restore it on another device without third-party cloud leaks.

### D. Safety Barriers & Safeguards
- **Production Confirmation Dialog**: Production servers require typing `"CONFIRM RESTART"` before sending `docker restart` or service stoppage commands.
- **Strict Host Key Fingerprinting**: When connecting to a server, the host key received during SSH handshake is hashed with SHA-256 and compared against the trusted fingerprint. Any discrepancy aborts the connection with `HostKeyMismatchFailure`.
- **Secret Redactor**: Diagnostic text and log output copied for AI analysis automatically strips private keys, tokens, bearer headers, and passwords.

---

## 3. State Management (Riverpod)

- **`serverListProvider`**: `StateNotifierProvider` managing the fleet list.
- **`sshKeyListProvider`**: `StateNotifierProvider` managing SSH key metadata.
- **`appLockProvider`**: Manages biometric app-lock state and authentication.
- **`mockModeProvider`**: Toggles between live SSH network transport and offline mock simulation.
