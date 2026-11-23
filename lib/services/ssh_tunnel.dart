import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dartssh2/dartssh2.dart';

import '../models/ssh_tunnel_config.dart';

/// A failure while opening or using an SSH tunnel.
///
/// [message] is written for the user and surfaced by the connection dialog, so
/// it must not contain stack traces or raw driver dumps.
class SshTunnelException implements Exception {
  final String message;

  const SshTunnelException(this.message);

  @override
  String toString() => message;
}

/// Returns the MongoDB host and port that [uri] points at.
///
/// Only a direct `mongodb://host:port` URI is supported: SRV discovery can
/// resolve to several hosts, and a single local port cannot stand in for more
/// than one target.
({String host, int port}) parseMongoUriTarget(String uri) {
  final trimmed = uri.trim();
  if (trimmed.isEmpty) {
    throw const SshTunnelException('Enter a MongoDB connection string.');
  }
  if (trimmed.startsWith('mongodb+srv://')) {
    throw const SshTunnelException(
      'SSH tunneling needs a direct mongodb:// URI with an explicit host and port. '
      'mongodb+srv:// host discovery is not supported through a tunnel.',
    );
  }

  final authority = _uriAuthority(trimmed);
  if (authority.contains(',')) {
    throw const SshTunnelException(
      'SSH tunneling supports a single MongoDB host. Use a URI with one host:port.',
    );
  }

  final at = authority.lastIndexOf('@');
  final hostPort = at >= 0 ? authority.substring(at + 1) : authority;
  if (hostPort.isEmpty) {
    throw const SshTunnelException('The connection string is missing its host.');
  }
  if (hostPort.contains('[')) {
    throw const SshTunnelException(
      'IPv6 MongoDB addresses are not supported through an SSH tunnel yet.',
    );
  }

  final colon = hostPort.lastIndexOf(':');
  if (colon < 0) return (host: hostPort, port: 27017);

  final host = hostPort.substring(0, colon);
  final port = int.tryParse(hostPort.substring(colon + 1));
  if (host.isEmpty || port == null || port < 1 || port > 65535) {
    throw const SshTunnelException(
      'The connection string has an invalid host or port.',
    );
  }
  return (host: host, port: port);
}

/// Rewrites [uri] so the driver connects to `127.0.0.1:[localPort]` instead of
/// the original host, preserving credentials, database path and options.
String rewriteMongoUriForLocalPort(String uri, int localPort) {
  final trimmed = uri.trim();
  final authorityStart = trimmed.indexOf('://') + 3;
  final rest = trimmed.substring(authorityStart);
  var authorityEnd = rest.length;
  for (final separator in const ['/', '?', '#']) {
    final index = rest.indexOf(separator);
    if (index >= 0 && index < authorityEnd) authorityEnd = index;
  }

  final authority = rest.substring(0, authorityEnd);
  final suffix = rest.substring(authorityEnd);
  final at = authority.lastIndexOf('@');
  final credentials = at >= 0 ? authority.substring(0, at + 1) : '';

  return '${trimmed.substring(0, authorityStart)}$credentials'
      '${InternetAddress.loopbackIPv4.address}:$localPort$suffix';
}

String _uriAuthority(String uri) {
  final start = uri.indexOf('://');
  final authorityStart = start >= 0 ? start + 3 : 0;
  final rest = uri.substring(authorityStart);
  var end = rest.length;
  for (final separator in const ['/', '?', '#']) {
    final index = rest.indexOf(separator);
    if (index >= 0 && index < end) end = index;
  }
  return rest.substring(0, end);
}

/// A local TCP port forwarded over SSH to the MongoDB server.
///
/// [open] authenticates against the bastion and binds `127.0.0.1:0`; every
/// connection to [localPort] is tunnelled to the remote MongoDB host. The
/// driver is then pointed at the local port.
///
/// The bastion's host key is pinned per profile: the first successful
/// connection records [hostKeyFingerprint] (trust on first use) and later
/// connections refuse a different key until the user clears the pin. Close the
/// tunnel with [close] when the session ends.
///
/// Note: because the driver reaches MongoDB at `127.0.0.1`, a TLS server
/// certificate issued for the real host name will not match. Such connections
/// need `tlsAllowInvalidCertificates=true` in the URI (Dart's `SecureSocket`
/// has no separate host-name option), which is why the dialog's tunnel hint
/// mentions it.
class SshTunnel {
  SshTunnel._(this._client, this._server, this._remoteHost, this._remotePort);

  final SSHClient _client;
  final ServerSocket _server;
  final String _remoteHost;
  final int _remotePort;
  final Set<SSHForwardChannel> _channels = <SSHForwardChannel>{};

  bool _closed = false;
  String? _hostKeyFingerprint;
  String? _lastForwardError;

  /// The fingerprint the bastion presented during this session
  /// (`SHA256:<base64>`), or `null` if the handshake did not get that far.
  ///
  /// Callers persist this onto the saved profile when it was not pinned before.
  String? get hostKeyFingerprint => _hostKeyFingerprint;

  /// Why the bastion could not open the last connection to the MongoDB side
  /// (channel open failures: refused port, unknown host, blocked by the
  /// server). `null` once a forward succeeds.
  ///
  /// The driver only sees a socket that closes immediately, so callers surface
  /// this to explain *why* instead of a generic "could not reach MongoDB".
  String? get lastForwardError => _lastForwardError;

  /// Loopback address the driver should connect to.
  String get localHost => InternetAddress.loopbackIPv4.address;

  /// Ephemeral local port that is forwarded to the MongoDB server.
  int get localPort => _server.port;

  /// The MongoDB host the bastion connects to.
  String get remoteHost => _remoteHost;

  /// The MongoDB port the bastion connects to.
  int get remotePort => _remotePort;

  bool get isClosed => _closed;

  /// Opens an SSH session and starts forwarding to [remoteHost]:[remotePort].
  ///
  /// Throws [SshTunnelException] with a user-facing message when the bastion is
  /// unreachable, authentication fails, or the key file cannot be read.
  static Future<SshTunnel> open({
    required SshTunnelConfig config,
    required String remoteHost,
    required int remotePort,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final host = config.host.trim();
    final username = config.username.trim();
    if (host.isEmpty) {
      throw const SshTunnelException('Enter the SSH bastion host.');
    }
    if (username.isEmpty) {
      throw const SshTunnelException('Enter the SSH username.');
    }

    final identities = await _loadIdentities(config);
    if (identities.isEmpty && config.password.isEmpty) {
      throw const SshTunnelException(
        'Provide an SSH password or a private key file for the tunnel.',
      );
    }

    final SSHSocket socket;
    try {
      socket = await SSHSocket.connect(
        host,
        config.port,
        timeout: const Duration(seconds: 20),
      );
    } on SocketException catch (error) {
      throw SshTunnelException(
        'Could not reach the SSH server at $host:${config.port}: '
        '${error.osError?.message ?? error.message}',
      );
    } on TimeoutException {
      throw SshTunnelException(
        'Timed out connecting to the SSH server at $host:${config.port}.',
      );
    }

    String? presentedHostKey;
    final client = SSHClient(
      socket,
      username: username,
      identities: identities.isEmpty ? null : identities,
      onPasswordRequest:
          config.password.isEmpty ? null : () => config.password,
      // Some servers disable RFC 4252 "password" auth and only offer
      // "keyboard-interactive" (PAM). Answer a single password prompt with the
      // same secret; multi-prompt challenges (OTP) are left to key auth.
      onUserInfoRequest: config.password.isEmpty
          ? null
          : (request) {
              if (request.prompts.length != 1) return null;
              return <String>[config.password];
            },
      onVerifyHostKey: (type, fingerprint) {
        presentedHostKey = utf8.decode(fingerprint, allowMalformed: true);
        return hostKeyMatches(config.hostKeyFingerprint, presentedHostKey);
      },
      keepAliveInterval: const Duration(seconds: 15),
    );

    try {
      await client.authenticated.timeout(timeout);
    } on SSHAuthError catch (error) {
      unawaited(client.close());
      if (!hostKeyMatches(config.hostKeyFingerprint, presentedHostKey)) {
        throw SshTunnelException(
          'SSH host key mismatch for $host. '
          'Pinned: ${config.hostKeyFingerprint}; presented: $presentedHostKey. '
          'If the bastion was rebuilt or its key was rotated, open Advanced '
          'connection options and clear the pinned host key, then reconnect.',
        );
      }
      throw SshTunnelException(
        'SSH authentication failed for "$username@$host": ${error.message}',
      );
    } catch (error) {
      unawaited(client.close());
      throw SshTunnelException(
        'SSH connection to $host:${config.port} failed: ${_cleanError(error)}',
      );
    }

    final ServerSocket server;
    try {
      server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    } catch (error) {
      unawaited(client.close());
      throw SshTunnelException(
        'Could not open a local port for the SSH tunnel: ${_cleanError(error)}',
      );
    }

    final tunnel = SshTunnel._(client, server, remoteHost, remotePort);
    tunnel._hostKeyFingerprint = presentedHostKey;
    server.listen(tunnel._accept, onError: (Object _) {});
    return tunnel;
  }

  /// Whether [presented] is acceptable against [pinned].
  ///
  /// An empty or missing pin accepts the key (trust on first use); the caller
  /// then persists [presented]. A set pin requires an exact match.
  static bool hostKeyMatches(String? pinned, String? presented) {
    final expected = pinned?.trim();
    if (expected == null || expected.isEmpty) return true;
    return presented != null && expected == presented;
  }

  /// A client connecting to [localPort] is paired with a fresh SSH forward
  /// channel; bytes are pumped in both directions until either side closes.
  Future<void> _accept(Socket socket) async {
    if (_closed) {
      socket.destroy();
      return;
    }

    final SSHForwardChannel channel;
    try {
      channel = await _client.forwardLocal(_remoteHost, _remotePort);
      _lastForwardError = null;
    } catch (error) {
      _lastForwardError = _cleanError(error);
      socket.destroy();
      return;
    }

    _channels.add(channel);
    unawaited(channel.done.whenComplete(() => _channels.remove(channel)));

    try {
      await Future.wait<void>([
        channel.sink.addStream(socket),
        socket.addStream(channel.stream),
      ]);
    } catch (_) {
      // Either side dropping is normal (the driver closes idle sockets).
    } finally {
      _channels.remove(channel);
      try {
        channel.destroy();
      } catch (_) {}
      socket.destroy();
    }
  }

  /// Stops accepting connections, drops open channels, then closes the SSH
  /// session. Safe to call more than once.
  Future<void> close() async {
    if (_closed) return;
    _closed = true;

    try {
      await _server.close();
    } catch (_) {}

    for (final channel in List<SSHForwardChannel>.of(_channels)) {
      try {
        channel.destroy();
      } catch (_) {}
    }
    _channels.clear();

    try {
      await _client.close();
    } catch (_) {}
  }

  static Future<List<SSHKeyPair>> _loadIdentities(
    SshTunnelConfig config,
  ) async {
    final path = config.privateKeyPath.trim();
    if (path.isEmpty) return const <SSHKeyPair>[];

    final resolved = _expandHome(path);
    final String pem;
    try {
      pem = await File(resolved).readAsString();
    } on FileSystemException catch (error) {
      throw SshTunnelException(
        'Could not read the SSH private key at "$resolved": '
        '${error.osError?.message ?? error.message}',
      );
    }

    try {
      return SSHKeyPair.fromPem(
        pem,
        config.privateKeyPassphrase.isEmpty
            ? null
            : config.privateKeyPassphrase,
      );
    } catch (_) {
      throw SshTunnelException(
        'Could not read the private key at "$resolved". '
        'Check that it is an unencrypted or correctly-passphrased PEM / OpenSSH key.',
      );
    }
  }

  /// Expands a leading `~` to the current user's home directory.
  static String _expandHome(String path) {
    if (!path.startsWith('~')) return path;
    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home == null || home.isEmpty) return path;
    return path.replaceFirst('~', home);
  }

  static String _cleanError(Object error) {
    if (error is SSHMessageError) return error.message;
    return error.toString().replaceFirst('Exception: ', '');
  }
}