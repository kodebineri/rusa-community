// SSH tunnel support: URI targeting/rewriting, profile persistence, and the
// connection dialog's tunnel form.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rusa/icons/compass_svg_icons.dart';
import 'package:rusa/models/mongo_models.dart';
import 'package:rusa/models/ssh_tunnel_config.dart';
import 'package:rusa/services/ssh_tunnel.dart';
import 'package:rusa/widgets/modals/compass_modal.dart';
import 'package:rusa/widgets/modals/connection_modal.dart';

import 'support/modal_harness.dart';

void main() {
  group('parseMongoUriTarget', () {
    test('reads host and port, ignoring credentials and options', () {
      final target = parseMongoUriTarget(
        'mongodb://user:p%40ss@db.internal:27018/app?authSource=admin',
      );
      expect(target.host, 'db.internal');
      expect(target.port, 27018);
    });

    test('defaults to port 27017 when the URI omits it', () {
      final target = parseMongoUriTarget('mongodb://db.internal/app');
      expect(target.host, 'db.internal');
      expect(target.port, 27017);
    });

    test('rejects SRV URIs, multi-host URIs and empty input', () {
      expect(
        () => parseMongoUriTarget('mongodb+srv://u:p@cluster.example.net/app'),
        throwsA(isA<SshTunnelException>()),
      );
      expect(
        () => parseMongoUriTarget('mongodb://a:27017,b:27018/app'),
        throwsA(isA<SshTunnelException>()),
      );
      expect(
        () => parseMongoUriTarget('  '),
        throwsA(isA<SshTunnelException>()),
      );
    });
  });

  group('rewriteMongoUriForLocalPort', () {
    test('swaps only the host/port and keeps credentials, path and query', () {
      final rewritten = rewriteMongoUriForLocalPort(
        'mongodb://user:secret@db.internal:27018/app?authSource=admin&tls=true',
        53123,
      );
      expect(
        rewritten,
        'mongodb://user:secret@127.0.0.1:53123/app?authSource=admin&tls=true',
      );
    });

    test('keeps a URI without credentials or path intact', () {
      expect(
        rewriteMongoUriForLocalPort('mongodb://db.internal:27017', 49152),
        'mongodb://127.0.0.1:49152',
      );
    });
  });

  group('SshTunnelConfig', () {
    test('round-trips every field through JSON', () {
      const config = SshTunnelConfig(
        host: 'bastion.example.com',
        port: 2222,
        username: 'deploy',
        authMethod: SshAuthMethod.privateKey,
        privateKeyPath: '~/.ssh/id_ed25519',
        privateKeyPassphrase: 'open sesame',
        hostKeyFingerprint: 'SHA256:abc123',
      );

      final restored = SshTunnelConfig.fromJson(config.toJson());
      expect(restored.enabled, isTrue);
      expect(restored.host, 'bastion.example.com');
      expect(restored.port, 2222);
      expect(restored.username, 'deploy');
      expect(restored.authMethod, SshAuthMethod.privateKey);
      expect(restored.privateKeyPath, '~/.ssh/id_ed25519');
      expect(restored.privateKeyPassphrase, 'open sesame');
      expect(restored.hostKeyFingerprint, 'SHA256:abc123');
    });

    test('copyWith can clear the pinned host key', () {
      const config = SshTunnelConfig(
        host: 'bastion',
        username: 'deploy',
        hostKeyFingerprint: 'SHA256:abc123',
      );
      expect(config.copyWith().hostKeyFingerprint, 'SHA256:abc123');
      expect(
        config.copyWith(clearHostKeyFingerprint: true).hostKeyFingerprint,
        isNull,
      );
      expect(
        config.copyWith(hostKeyFingerprint: 'SHA256:def456').hostKeyFingerprint,
        'SHA256:def456',
      );
    });

    test('falls back to port 22 and password auth for junk input', () {
      final restored = SshTunnelConfig.fromJson(<String, dynamic>{
        'host': 'bastion',
        'port': 'not-a-port',
        'authMethod': 'somethingElse',
      });
      expect(restored.port, 22);
      expect(restored.authMethod, SshAuthMethod.password);
      expect(restored.username, '');
    });
  });

  group('ConnectionProfile with a tunnel', () {
    test('round-trips the tunnel through JSON', () {
      final profile = ConnectionProfile(
        id: 'profile-1',
        name: 'Behind bastion',
        uri: 'mongodb://db.internal:27017/app',
        sshTunnel: const SshTunnelConfig(
          host: 'bastion.example.com',
          username: 'deploy',
          password: 'hunter2',
        ),
      );

      final restored = ConnectionProfile.fromJson(profile.toJson());
      expect(restored.sshTunnel, isNotNull);
      expect(restored.sshTunnel!.host, 'bastion.example.com');
      expect(restored.sshTunnel!.username, 'deploy');
      expect(restored.sshTunnel!.password, 'hunter2');
    });

    test('a profile without a tunnel stays null', () {
      final profile = ConnectionProfile(
        id: 'profile-2',
        name: 'Direct',
        uri: 'mongodb://localhost:27017',
      );
      expect(profile.toJson()['sshTunnel'], isNull);
      expect(ConnectionProfile.fromJson(profile.toJson()).sshTunnel, isNull);
    });

    test('a journaled profile never stores a tunnel it did not have', () {
      final legacyJson = <String, dynamic>{
        'id': 'legacy',
        'name': 'Legacy',
        'uri': 'mongodb://localhost:27017',
        'readOnly': false,
      };
      expect(ConnectionProfile.fromJson(legacyJson).sshTunnel, isNull);
    });
  });

  group('SshTunnel.hostKeyMatches', () {
    test('an absent or blank pin accepts any key', () {
      expect(SshTunnel.hostKeyMatches(null, 'SHA256:abc'), isTrue);
      expect(SshTunnel.hostKeyMatches('  ', 'SHA256:abc'), isTrue);
    });

    test('a pin requires the exact fingerprint', () {
      expect(SshTunnel.hostKeyMatches('SHA256:abc', 'SHA256:abc'), isTrue);
      expect(SshTunnel.hostKeyMatches('SHA256:abc', 'SHA256:def'), isFalse);
      expect(SshTunnel.hostKeyMatches('SHA256:abc', null), isFalse);
    });
  });

  group('SshTunnel.open validation', () {
    test('rejects a missing host before touching the network', () async {
      await expectLater(
        SshTunnel.open(
          config: const SshTunnelConfig(username: 'deploy', password: 'x'),
          remoteHost: 'db.internal',
          remotePort: 27017,
        ),
        throwsA(isA<SshTunnelException>()),
      );
    });

    test('rejects a username-less config', () async {
      await expectLater(
        SshTunnel.open(
          config: const SshTunnelConfig(host: 'bastion', password: 'x'),
          remoteHost: 'db.internal',
          remotePort: 27017,
        ),
        throwsA(isA<SshTunnelException>()),
      );
    });

    test('rejects a config with neither password nor key', () async {
      await expectLater(
        SshTunnel.open(
          config: const SshTunnelConfig(host: 'bastion', username: 'deploy'),
          remoteHost: 'db.internal',
          remotePort: 27017,
        ),
        throwsA(isA<SshTunnelException>()),
      );
    });
  });

  testWidgets('the connect dialog saves an SSH tunnel on the profile',
      (WidgetTester tester) async {
    const size = Size(1200.0, 1000.0);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    ConnectionProfile? saved;

    await tester.pumpWidget(
      modalHarness(
        size: size,
        touch: false,
        child: ConnectionModal(
          isOpen: true,
          onClose: () {},
          savedConnections: const [],
          // Never reaches the network: the dialog only needs a result to decide
          // whether to close.
          onConnect: (_) async => 'stubbed failure',
          onSaveConnection: (profile) => saved = profile,
          onDeleteConnection: (_) {},
          onConnectSampleData: () {},
        ),
      ),
    );
    await tester.pump();

    // The tunnel form lives inside Advanced Connection Options.
    final advanced = find.text('Advanced Connection Options');
    await tester.ensureVisible(advanced);
    await tester.pump();
    await tester.tap(advanced);
    await tester.pump();

    final toggle = find.text('Connect through an SSH tunnel');
    await tester.ensureVisible(toggle);
    await tester.pump();
    await tester.tap(toggle);
    await tester.pump();

    expect(find.text('SSH Host'), findsOneWidget);
    expect(find.text('SSH Username'), findsOneWidget);
    expect(find.text('SSH Password'), findsOneWidget);

    void fill(String placeholder, String value) {
      final field = find.ancestor(
        of: find.text(placeholder),
        matching: find.byType(CompassInput),
      );
      expect(field, findsOneWidget, reason: 'missing field $placeholder');
      tester.widget<CompassInput>(field).controller.text = value;
    }

    fill('bastion.example.com', 'bastion.example.com');
    fill('deploy', 'deploy');
    fill('Bastion password', 'hunter2');
    await tester.pump();

    // Switching to key auth swaps the credential fields.
    await tester.tap(find.text('Private Key'));
    await tester.pump();
    expect(find.text('Private Key File'), findsOneWidget);
    expect(find.text('Key Passphrase'), findsOneWidget);
    expect(find.text('SSH Password'), findsNothing);

    // Back to password auth for the saved profile.
    await tester.tap(find.text('Password'));
    await tester.pump();

    final saveAndConnect = find.text('Save & Connect');
    await tester.ensureVisible(saveAndConnect);
    await tester.pump();
    await tester.tap(saveAndConnect);
    await tester.pump();
    await tester.pump();

    expect(saved, isNotNull);
    final tunnel = saved!.sshTunnel;
    expect(tunnel, isNotNull);
    expect(tunnel!.enabled, isTrue);
    expect(tunnel.host, 'bastion.example.com');
    expect(tunnel.port, 22);
    expect(tunnel.username, 'deploy');
    expect(tunnel.authMethod, SshAuthMethod.password);
    expect(tunnel.password, 'hunter2');
    // The URI keeps pointing at the MongoDB host; the engine rewrites it.
    expect(saved!.uri, 'mongodb://localhost:27017');
  });

  testWidgets('a pinned SSH host key is shown, clearable, and saved',
      (WidgetTester tester) async {
    const size = Size(1200.0, 1000.0);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final profile = ConnectionProfile(
      id: 'saved-1',
      name: 'Behind bastion',
      uri: 'mongodb://db.internal:27017/app',
      sshTunnel: const SshTunnelConfig(
        host: 'bastion.example.com',
        username: 'deploy',
        password: 'hunter2',
        hostKeyFingerprint: 'SHA256:abc123',
      ),
    );
    ConnectionProfile? saved;

    await tester.pumpWidget(
      modalHarness(
        size: size,
        touch: false,
        child: ConnectionModal(
          isOpen: true,
          onClose: () {},
          savedConnections: [profile],
          onConnect: (_) async => 'stubbed failure',
          onSaveConnection: (updated) => saved = updated,
          onDeleteConnection: (_) {},
          onConnectSampleData: () {},
        ),
      ),
    );
    await tester.pump();

    // Load the saved profile into the form.
    final pencil = find.byWidgetPredicate(
      (w) => w is CompassSvg && w.svgString == CompassSvgIcons.pencil,
    );
    await tester.ensureVisible(pencil);
    await tester.pump();
    await tester.tap(pencil);
    await tester.pump();

    final advanced = find.text('Advanced Connection Options');
    await tester.ensureVisible(advanced);
    await tester.pump();
    await tester.tap(advanced);
    await tester.pump();

    expect(find.text('Pinned host key'), findsOneWidget);
    expect(find.text('SHA256:abc123'), findsOneWidget);

    await tester.tap(find.text('Clear'));
    await tester.pump();
    expect(find.text('Pinned host key'), findsNothing);

    final saveAndConnect = find.text('Update & Connect');
    await tester.ensureVisible(saveAndConnect);
    await tester.pump();
    await tester.tap(saveAndConnect);
    await tester.pump();
    await tester.pump();

    expect(saved, isNotNull);
    expect(saved!.sshTunnel, isNotNull);
    expect(saved!.sshTunnel!.hostKeyFingerprint, isNull);
    // Clearing the key must not wipe the rest of the tunnel settings.
    expect(saved!.sshTunnel!.host, 'bastion.example.com');
    expect(saved!.sshTunnel!.username, 'deploy');
  });

  testWidgets('mobile: the SSH tunnel form fits a 320 px phone',
      (WidgetTester tester) async {
    const size = Size(320.0, 560.0);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      modalHarness(
        size: size,
        touch: true,
        child: ConnectionModal(
          isOpen: true,
          onClose: () {},
          savedConnections: const [],
          onConnect: (_) async => 'stubbed failure',
          onSaveConnection: (_) {},
          onDeleteConnection: (_) {},
          onConnectSampleData: () {},
        ),
      ),
    );
    await tester.pump();

    final advanced = find.text('Advanced Connection Options');
    await tester.ensureVisible(advanced);
    await tester.pump();
    await tester.tap(advanced);
    await tester.pump();

    final toggle = find.text('Connect through an SSH tunnel');
    await tester.ensureVisible(toggle);
    await tester.pump();
    await tester.tap(toggle);
    await tester.pump();

    expect(tester.takeException(), isNull,
        reason: 'the tunnel fields must not overflow a phone');
    expect(find.text('SSH Host'), findsOneWidget);
    expect(find.text('SSH Password'), findsOneWidget);
  });
}
