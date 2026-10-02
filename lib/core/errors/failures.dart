sealed class SshFailure {
  final String message;
  final String? technicalDetails;

  const SshFailure(this.message, [this.technicalDetails]);

  @override
  String toString() => message;
}

class HostUnreachableFailure extends SshFailure {
  const HostUnreachableFailure([String? details])
      : super('Server host is unreachable. Check network, DNS, or VPN/Tailscale status.', details);
}

class ConnectionTimeoutFailure extends SshFailure {
  const ConnectionTimeoutFailure([String? details])
      : super('Connection timed out while reaching the SSH server.', details);
}

class AuthenticationFailure extends SshFailure {
  const AuthenticationFailure([String? details])
      : super('SSH authentication failed. Verify username and private key/passphrase.', details);
}

class HostKeyMismatchFailure extends SshFailure {
  final String expectedFingerprint;
  final String receivedFingerprint;
  final String host;
  final int port;

  const HostKeyMismatchFailure({
    required this.expectedFingerprint,
    required this.receivedFingerprint,
    required this.host,
    required this.port,
    String? details,
  }) : super(
          'HOST KEY MISMATCH DETECTED! The host identity presented by $host:$port differs from the trusted fingerprint.',
          details,
        );
}

class InvalidPrivateKeyFailure extends SshFailure {
  const InvalidPrivateKeyFailure([String? details])
      : super('Invalid or unparseable SSH private key. Ensure OpenSSH format (ED25519/RSA).', details);
}

class KeyPassphraseRequiredFailure extends SshFailure {
  const KeyPassphraseRequiredFailure([String? details])
      : super('The private key is encrypted. A passphrase is required.', details);
}

class RemoteDisconnectedFailure extends SshFailure {
  const RemoteDisconnectedFailure([String? details])
      : super('The remote server closed the SSH connection unexpectedly.', details);
}

class CommandTimeoutFailure extends SshFailure {
  const CommandTimeoutFailure([String? details])
      : super('Command execution timed out before completion.', details);
}

class PermissionDeniedFailure extends SshFailure {
  const PermissionDeniedFailure([String? details])
      : super('Permission denied / sudo required. Elevated privileges are needed on the server.', details);
}

class SshGenericFailure extends SshFailure {
  const SshGenericFailure(super.message, [super.technicalDetails]);
}
