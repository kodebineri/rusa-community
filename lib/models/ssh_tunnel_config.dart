/// How an SSH tunnel authenticates against the bastion host.
enum SshAuthMethod {
  /// Username + password.
  password,

  /// A private key file (OpenSSH or PEM), optionally passphrase-protected.
  privateKey,
}

/// SSH bastion settings attached to a [ConnectionProfile].
///
/// When [enabled] is true, connecting opens a local port forward through the
/// bastion and points the MongoDB driver at `127.0.0.1:<temporary port>`, so a
/// server that is only reachable from the bastion can still be browsed.
///
/// The password / passphrase live in the same secure-storage entry as the
/// profile URI ([AppPreferences.savedConnections]); they are never uploaded.
class SshTunnelConfig {
  /// Whether the tunnel is switched on for this profile. Kept separate from a
  /// `null` [ConnectionProfile.sshTunnel] so the form can remember the last
  /// settings while the toggle is off.
  final bool enabled;

  /// Bastion host name or IP address.
  final String host;

  /// SSH port on the bastion (default 22).
  final int port;

  /// SSH login name on the bastion.
  final String username;

  /// Which credential [password] / [privateKeyPath] applies.
  final SshAuthMethod authMethod;

  /// Password for [SshAuthMethod.password].
  final String password;

  /// Path shown in the form for [SshAuthMethod.privateKey].
  ///
  /// When [privateKeyPem] is set this is only a label: mobile file pickers hand
  /// back a path into a temporary cache that may not survive a restart.
  final String privateKeyPath;

  /// Key contents captured when the user picked a file.
  ///
  /// Stored in the same encrypted [AppPreferences.savedConnections] entry as
  /// the password / passphrase. Empty for hand-typed paths, which the tunnel
  /// still reads from disk.
  final String privateKeyPem;

  /// Passphrase protecting the private key, if it is encrypted.
  final String privateKeyPassphrase;

  /// SHA-256 fingerprint of the bastion's host key, as reported by the SSH
  /// handshake (`SHA256:<base64>`).
  ///
  /// `null` means "not pinned yet": the next successful connection records the
  /// key (trust on first use) and callers persist it onto the saved profile.
  /// Once set, a different key is refused until the user clears it.
  final String? hostKeyFingerprint;

  const SshTunnelConfig({
    this.enabled = true,
    this.host = '',
    this.port = 22,
    this.username = '',
    this.authMethod = SshAuthMethod.password,
    this.password = '',
    this.privateKeyPath = '',
    this.privateKeyPem = '',
    this.privateKeyPassphrase = '',
    this.hostKeyFingerprint,
  });

  /// True when the tunnel is switched on. Missing fields are reported by the
  /// tunnel itself so a misconfigured profile fails with a clear message instead
  /// of silently connecting directly.
  bool get isActive => enabled;

  /// True when the bastion host and username are filled in.
  bool get isComplete => host.trim().isNotEmpty && username.trim().isNotEmpty;

  /// True when nothing has been entered yet (used to skip serialising).
  bool get isEmpty =>
      host.trim().isEmpty &&
      username.trim().isEmpty &&
      password.isEmpty &&
      privateKeyPath.trim().isEmpty &&
      privateKeyPem.trim().isEmpty &&
      privateKeyPassphrase.isEmpty;

  SshTunnelConfig copyWith({
    bool? enabled,
    String? host,
    int? port,
    String? username,
    SshAuthMethod? authMethod,
    String? password,
    String? privateKeyPath,
    String? privateKeyPem,
    String? privateKeyPassphrase,
    String? hostKeyFingerprint,
    bool clearHostKeyFingerprint = false,
  }) {
    return SshTunnelConfig(
      enabled: enabled ?? this.enabled,
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      authMethod: authMethod ?? this.authMethod,
      password: password ?? this.password,
      privateKeyPath: privateKeyPath ?? this.privateKeyPath,
      privateKeyPem: privateKeyPem ?? this.privateKeyPem,
      privateKeyPassphrase: privateKeyPassphrase ?? this.privateKeyPassphrase,
      hostKeyFingerprint: clearHostKeyFingerprint
          ? null
          : (hostKeyFingerprint ?? this.hostKeyFingerprint),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'enabled': enabled,
        'host': host,
        'port': port,
        'username': username,
        'authMethod': authMethod.name,
        'password': password,
        'privateKeyPath': privateKeyPath,
        'privateKeyPem': privateKeyPem,
        'privateKeyPassphrase': privateKeyPassphrase,
        'hostKeyFingerprint': hostKeyFingerprint,
      };

  /// Restores a config written by [toJson]. Missing / unknown fields fall back
  /// to safe defaults so a hand-edited or older entry cannot break startup.
  factory SshTunnelConfig.fromJson(Map<String, dynamic> json) {
    final method = json['authMethod'] as String?;
    return SshTunnelConfig(
      enabled: json['enabled'] as bool? ?? true,
      host: json['host'] as String? ?? '',
      port: _asPort(json['port']),
      username: json['username'] as String? ?? '',
      authMethod: method == SshAuthMethod.privateKey.name
          ? SshAuthMethod.privateKey
          : SshAuthMethod.password,
      password: json['password'] as String? ?? '',
      privateKeyPath: json['privateKeyPath'] as String? ?? '',
      privateKeyPem: json['privateKeyPem'] as String? ?? '',
      privateKeyPassphrase: json['privateKeyPassphrase'] as String? ?? '',
      hostKeyFingerprint: _asFingerprint(json['hostKeyFingerprint']),
    );
  }

  static String? _asFingerprint(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return trimmed;
  }

  static int _asPort(Object? value) {
    final parsed = value is int ? value : int.tryParse('${value ?? ''}');
    if (parsed == null || parsed < 1 || parsed > 65535) return 22;
    return parsed;
  }
}
