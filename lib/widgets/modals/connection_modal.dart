import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../../theme/compass_colors.dart';
import '../../theme/compass_density.dart';
import '../../theme/compass_theme.dart';
import '../../theme/compass_typography.dart';
import '../../icons/compass_svg_icons.dart';
import '../../models/mongo_models.dart';
import '../../models/ssh_tunnel_config.dart';
import '../../utils/mongo_uri.dart';
import '../compass_hover.dart';
import '../compass_icon_button.dart';
import 'compass_modal.dart';

/// Converted from src/components/ConnectionModal.tsx
/// Adheres strictly to:
/// 1. Layout & Flexbox (centered modal card, URI input, saved connections list)
/// 2. Color & Styling (CompassColors, modal overlay, rounded 12px)
/// 3. Typography (CompassTypography with JetBrains Mono)
/// 4. Platform Agnosticism (desktop connection dialog)
/// 5. Icons (CompassSvg instead of generic Icon)
///
/// Beyond the React original this dialog also exposes:
///  * Advanced Connection Options (host / port / username / password) that
///    compose the URI as they are edited.
///  * An optional SSH tunnel: the bastion host/port/username plus either a
///    password or a private key file. Connecting forwards the URI's host:port
///    through the bastion (see `lib/services/ssh_tunnel.dart`).
///  * Per-saved-connection deletion.
///  * Per-saved-connection editing: the form loads the saved profile and
///    "Update & Connect" saves the changes back onto the same profile.
///  * A "Save & Connect" action in the footer next to "Connect".
///  * A "Sample Data" option that connects to the bundled local sample
///    datasets (the port of React's "Load Sample Datasets" affordance).
class ConnectionModal extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onClose;
  final List<ConnectionProfile> savedConnections;

  /// Opens a connection. Returns `null` on success or a human-readable error
  /// message when the server could not be reached/authenticated.
  final Future<String?> Function(ConnectionProfile profile) onConnect;

  final ValueChanged<ConnectionProfile> onSaveConnection;
  final ValueChanged<String> onDeleteConnection;

  /// Connects to the bundled sample datasets (`library`,
  /// `social_networks`) and loads them into the workspace.
  final VoidCallback onConnectSampleData;

  /// Tests the connection without saving or navigating. Returns `null` on
  /// success or a human-readable error message on failure.
  final Future<String?> Function(ConnectionProfile profile)? onTestConnection;

  const ConnectionModal({
    super.key,
    required this.isOpen,
    required this.onClose,
    required this.savedConnections,
    required this.onConnect,
    required this.onSaveConnection,
    required this.onDeleteConnection,
    required this.onConnectSampleData,
    this.onTestConnection,
  });

  @override
  State<ConnectionModal> createState() => _ConnectionModalState();
}

class _ConnectionModalState extends State<ConnectionModal> {
  CompassTheme get _theme => CompassTheme.of(context);

  late final TextEditingController _uriController;
  late final TextEditingController _nameController;
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;

  /// Database the MongoDB credentials are defined in (`authSource`).
  /// Defaults to `admin`, which is where `MONGO_INITDB_ROOT_USERNAME` users
  /// live; clearing the field leaves authSource out of the URI.
  late final TextEditingController _authSourceController;

  late final TextEditingController _sshHostController;
  late final TextEditingController _sshPortController;
  late final TextEditingController _sshUserController;
  late final TextEditingController _sshPasswordController;
  late final TextEditingController _sshKeyPathController;
  late final TextEditingController _sshPassphraseController;

  /// PEM captured from the file picker and saved with the profile. Mobile
  /// pickers return a path into an app-private cache, which may be gone on the
  /// next launch, so the tunnel uses these bytes instead of that path.
  String _sshKeyPem = '';

  /// The path the picker reported for [_sshKeyPem]. Editing the field by hand
  /// invalidates the cached PEM so a typed path is read from disk again.
  String? _pickedKeyPath;

  bool _sshEnabled = false;
  SshAuthMethod _sshAuthMethod = SshAuthMethod.password;

  /// Host key pinned on the saved profile, if any. Shown read-only with a
  /// Clear action so a rotated bastion key can be re-trusted.
  String? _sshHostKeyFingerprint;

  bool _showAdvanced = false;
  bool _syncingUri = false;
  bool _isConnecting = false;
  bool _isTesting = false;
  String? _connectError;
  String? _testMessage;

  /// Briefly true after the URI is copied, so the icon can show a check.
  bool _uriCopied = false;

  /// The saved connection currently being edited, if any. When set, saving
  /// updates that profile in place (same id) instead of adding a new one.
  String? _editingId;
  String? _editingName;

  @override
  void initState() {
    super.initState();
    _uriController = TextEditingController();
    _nameController = TextEditingController();
    _hostController = TextEditingController();
    _portController = TextEditingController();
    _usernameController = TextEditingController();
    _passwordController = TextEditingController();
    _authSourceController = TextEditingController();
    _sshHostController = TextEditingController();
    _sshPortController = TextEditingController();
    _sshUserController = TextEditingController();
    _sshPasswordController = TextEditingController();
    _sshKeyPathController = TextEditingController();
    _sshPassphraseController = TextEditingController();
    _resetFields();
    _wireAdvancedSync();
  }

  void _resetFields() {
    _syncingUri = true;
    _uriController.text = 'mongodb://localhost:27017';
    _nameController.text = 'Local Standalone';
    _hostController.text = 'localhost';
    _portController.text = '27017';
    _usernameController.text = '';
    _passwordController.text = '';
    _authSourceController.text = 'admin';
    _sshEnabled = false;
    _sshAuthMethod = SshAuthMethod.password;
    _sshHostController.text = '';
    _sshPortController.text = '22';
    _sshUserController.text = '';
    _sshPasswordController.text = '';
    _sshKeyPathController.text = '';
    _sshPassphraseController.text = '';
    _sshKeyPem = '';
    _pickedKeyPath = null;
    _sshHostKeyFingerprint = null;
    _showAdvanced = false;
    _isConnecting = false;
    _isTesting = false;
    _connectError = null;
    _testMessage = null;
    _uriCopied = false;
    _editingId = null;
    _editingName = null;
    _syncingUri = false;
  }

  @override
  void didUpdateWidget(covariant ConnectionModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    // React unmounts the dialog when closed, resetting its local state; mirror
    // that by resetting the form each time the dialog is (re)opened.
    if (widget.isOpen && !oldWidget.isOpen) {
      setState(_resetFields);
    }
  }

  @override
  void dispose() {
    _uriController.dispose();
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _authSourceController.dispose();
    _sshHostController.dispose();
    _sshPortController.dispose();
    _sshUserController.dispose();
    _sshPasswordController.dispose();
    _sshKeyPathController.dispose();
    _sshPassphraseController.dispose();
    super.dispose();
  }

  /// Keeps the URI string in sync while the advanced fields are edited so the
  /// user always sees the connection string that will actually be used.
  void _wireAdvancedSync() {
    for (final controller in [
      _hostController,
      _portController,
      _usernameController,
      _passwordController,
      _authSourceController,
    ]) {
      controller.addListener(_syncUriFromAdvanced);
    }
  }

  void _syncUriFromAdvanced() {
    if (_syncingUri) return;
    final composed = _composeUri();
    _syncingUri = true;
    _uriController.value = TextEditingValue(
      text: composed,
      selection: TextSelection.collapsed(offset: composed.length),
    );
    _syncingUri = false;
    if (mounted) setState(() {});
  }

  String _composeUri() {
    final host = _hostController.text.trim().isEmpty
        ? 'localhost'
        : _hostController.text.trim();
    final port = _portController.text.trim().isEmpty
        ? '27017'
        : _portController.text.trim();
    final user = _usernameController.text.trim();
    final pass = _passwordController.text;
    final credentials =
        user.isEmpty ? '' : '$user${pass.isEmpty ? '' : ':$pass'}@';
    return appendAuthSource(
      'mongodb://$credentials$host:$port',
      _authSourceController.text,
    );
  }

  String _effectiveUri() {
    final typed = _uriController.text.trim();
    final base = typed.isEmpty ? _composeUri() : typed;
    // A typed URI may carry credentials without an authSource; scope it to the
    // Authentication Database field (default `admin`) unless it already names
    // one.
    return appendAuthSource(base, _authSourceController.text);
  }

  ConnectionProfile? get _editingProfile {
    final id = _editingId;
    if (id == null) return null;
    for (final c in widget.savedConnections) {
      if (c.id == id) return c;
    }
    return null;
  }

  ConnectionProfile _buildProfile() {
    final name = _nameController.text.trim();
    // Editing keeps the saved profile's identity and metadata; saving then
    // updates it in place instead of creating a duplicate.
    final base = _editingProfile;
    return ConnectionProfile(
      id: base?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.isEmpty ? (base?.name ?? 'MongoDB Cluster') : name,
      uri: _effectiveUri(),
      color: base?.color,
      favorite: base?.favorite ?? false,
      lastConnected: base?.lastConnected ?? 'Just now',
      readOnly: base?.readOnly ?? false,
      sshTunnel: _buildSshConfig(),
    );
  }

  /// The SSH tunnel settings from the form, or `null` when the toggle is off.
  SshTunnelConfig? _buildSshConfig() {
    if (!_sshEnabled) return null;
    final port = int.tryParse(_sshPortController.text.trim());
    return SshTunnelConfig(
      enabled: true,
      host: _sshHostController.text.trim(),
      port: (port == null || port < 1 || port > 65535) ? 22 : port,
      username: _sshUserController.text.trim(),
      authMethod: _sshAuthMethod,
      password: _sshPasswordController.text,
      privateKeyPath: _sshKeyPathController.text.trim(),
      privateKeyPem: _sshKeyPem,
      privateKeyPassphrase: _sshPassphraseController.text,
      hostKeyFingerprint: _sshHostKeyFingerprint,
    );
  }

  /// Loads a saved connection into the form so it can be edited and re-saved.
  void _startEditing(ConnectionProfile profile) {
    final parts = _parseUri(profile.uri);
    _syncingUri = true;
    _uriController.text = profile.uri;
    _nameController.text = profile.name;
    _hostController.text = parts.host;
    _portController.text = parts.port;
    _usernameController.text = parts.user;
    _passwordController.text = parts.password;
    _authSourceController.text = parts.authSource ?? 'admin';
    _syncingUri = false;

    final ssh = profile.sshTunnel;
    _sshEnabled = ssh?.enabled ?? false;
    _sshAuthMethod = ssh?.authMethod ?? SshAuthMethod.password;
    _sshHostController.text = ssh?.host ?? '';
    _sshPortController.text = '${ssh?.port ?? 22}';
    _sshUserController.text = ssh?.username ?? '';
    _sshPasswordController.text = ssh?.password ?? '';
    _sshKeyPathController.text = ssh?.privateKeyPath ?? '';
    _sshKeyPem = ssh?.privateKeyPem ?? '';
    _pickedKeyPath = _sshKeyPem.isEmpty ? null : (ssh?.privateKeyPath ?? '');
    _sshPassphraseController.text = ssh?.privateKeyPassphrase ?? '';
    _sshHostKeyFingerprint = ssh?.hostKeyFingerprint;

    setState(() {
      _editingId = profile.id;
      _editingName = profile.name;
      _connectError = null;
      _testMessage = null;
    });
  }

  void _cancelEditing() {
    setState(_resetFields);
  }

  /// Best-effort split of a connection URI into the advanced-form fields.
  ({String host, String port, String user, String password, String? authSource})
      _parseUri(String uri) {
    var rest = uri.trim();
    final scheme = rest.indexOf('://');
    if (scheme >= 0) rest = rest.substring(scheme + 3);
    // Drop the path, query string and any replica-set hosts after the first.
    for (final sep in ['/', '?']) {
      final i = rest.indexOf(sep);
      if (i >= 0) rest = rest.substring(0, i);
    }
    var hostPort = rest.split(',').first;

    var user = '';
    var password = '';
    final at = hostPort.lastIndexOf('@');
    if (at >= 0) {
      final userInfo = hostPort.substring(0, at);
      hostPort = hostPort.substring(at + 1);
      final colon = userInfo.indexOf(':');
      if (colon >= 0) {
        user = userInfo.substring(0, colon);
        password = userInfo.substring(colon + 1);
      } else {
        user = userInfo;
      }
    }

    var host = hostPort;
    var port = '';
    final colon = hostPort.lastIndexOf(':');
    if (colon >= 0) {
      host = hostPort.substring(0, colon);
      port = hostPort.substring(colon + 1);
    }
    return (
      host: host,
      port: port,
      user: user,
      password: password,
      authSource: authSourceFromUri(uri),
    );
  }

  /// How long to wait for a connection attempt. An SSH tunnel adds a bastion
  /// handshake before the driver can even reach MongoDB, so it gets a longer
  /// budget than a direct connection.
  Duration _connectTimeout(ConnectionProfile profile) {
    return (profile.sshTunnel?.enabled ?? false)
        ? const Duration(seconds: 90)
        : const Duration(seconds: 45);
  }

  Future<void> _connect() => _attemptConnect(_buildProfile());

  Future<void> _saveAndConnect() async {
    final profile = _buildProfile();
    widget.onSaveConnection(profile);
    await _attemptConnect(profile);
  }

  Future<void> _testConnection() async {
    if (_isConnecting || _isTesting) return;
    final tester = widget.onTestConnection;
    if (tester == null) {
      final profile = _buildProfile();
      setState(() {
        _isTesting = true;
        _testMessage = null;
        _connectError = null;
      });
      try {
        final error =
            await widget.onConnect(profile).timeout(_connectTimeout(profile));
        if (!mounted) return;
        setState(() {
          _isTesting = false;
          if (error == null) {
            _testMessage = 'Connection successful';
          } else {
            _connectError = error;
          }
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isTesting = false;
          _connectError = e
              .toString()
              .replaceFirst('Exception: ', '')
              .replaceFirst('TimeoutException after ', 'Timeout after ');
        });
      }
      return;
    }
    final profile = _buildProfile();
    setState(() {
      _isTesting = true;
      _testMessage = null;
      _connectError = null;
    });
    try {
      final error = await tester(profile).timeout(_connectTimeout(profile));
      if (!mounted) return;
      setState(() {
        _isTesting = false;
        if (error == null) {
          _testMessage = 'Connection successful';
        } else {
          _connectError = error;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTesting = false;
        _connectError = e
            .toString()
            .replaceFirst('Exception: ', '')
            .replaceFirst('TimeoutException after ', 'Timeout after ');
      });
    }
  }

  /// Attempts to open a connection. [ConnectionModal.onConnect] resolves to a
  /// failure message (or `null` on success), so the dialog can stay open and
  /// show the error instead of silently closing.
  Future<void> _attemptConnect(ConnectionProfile profile) async {
    if (_isConnecting) return;
    setState(() {
      _isConnecting = true;
      _connectError = null;
      _testMessage = null;
    });
    try {
      final error =
          await widget.onConnect(profile).timeout(_connectTimeout(profile));
      if (!mounted) return;
      if (error == null) {
        widget.onClose();
        return;
      }
      setState(() {
        _isConnecting = false;
        _connectError = error;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isConnecting = false;
        _connectError = e
            .toString()
            .replaceFirst('Exception: ', '')
            .replaceFirst('TimeoutException after ', 'Timeout after ');
      });
    }
  }

  void _connectToSampleData() {
    widget.onConnectSampleData();
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isOpen) return const SizedBox.shrink();

    return Positioned.fill(
      child: Container(
        color: CompassColors.modalOverlay,
        alignment: Alignment.center,
        child: SafeArea(
          child: Container(
            width: 560.0,
            margin: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: _theme.bgPanel,
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: _theme.border, width: 1.0),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 24.0,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildUriSection(),
                        if (_editingId != null) ...[
                          const SizedBox(height: 12.0),
                          _buildEditingBanner(),
                        ],
                        if (_connectError != null) ...[
                          const SizedBox(height: 12.0),
                          CompassErrorBanner(message: _connectError!),
                        ],
                        if (_testMessage != null) ...[
                          const SizedBox(height: 12.0),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12.0, vertical: 10.0),
                            decoration: BoxDecoration(
                              color: _theme.greenBadgeBg,
                              borderRadius: BorderRadius.circular(8.0),
                              border: Border.all(
                                  color: _theme.greenBadgeBorder, width: 1.0),
                            ),
                            child: Row(
                              children: [
                                CompassSvg(
                                  svgString: CompassSvgIcons.check,
                                  size: 16.0,
                                  color: _theme.accent,
                                ),
                                const SizedBox(width: 8.0),
                                Expanded(
                                  child: Text(
                                    _testMessage!,
                                    style: CompassTypography.bodyMedium(
                                        color: _theme.accent),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 16.0),
                        _buildNameSection(),
                        const SizedBox(height: 16.0),
                        _buildAdvancedSection(),
                        const SizedBox(height: 20.0),
                        _buildSampleDataSection(),
                        const SizedBox(height: 16.0),
                        _buildSavedSection(),
                      ],
                    ),
                  ),
                ),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 16.0),
      decoration: BoxDecoration(
        color: _theme.bgSubtle,
        border: Border(bottom: BorderSide(color: _theme.border, width: 1.0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 32.0,
                  height: 32.0,
                  alignment: Alignment.center,
                  child: CompassSvg(
                    svgString: CompassSvgIcons.rusa,
                    size: 32.0,
                    color: _theme.brandMark,
                  ),
                ),
                const SizedBox(width: 10.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Connect to MongoDB',
                        style:
                            CompassTypography.title(color: _theme.textPrimary),
                      ),
                      const SizedBox(height: 2.0),
                      Text(
                        'Connect to a standalone instance, replica set, or Atlas cluster',
                        style:
                            CompassTypography.caption(color: _theme.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          CompassIconButton(
            svgString: CompassSvgIcons.close,
            onTap: widget.onClose,
            size: 14.0,
            padding: 4.0,
            color: _theme.textMuted,
            semanticLabel: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildUriSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CompassFieldLabel(label: 'URI Connection String'),
        Row(
          children: [
            Expanded(
              child: CompassInput(
                controller: _uriController,
                placeholder: 'mongodb://localhost:27017 or mongodb+srv://...',
                suffix: _buildUriCopyButton(),
              ),
            ),
            const SizedBox(width: 8.0),
            CompassPrimaryButton(
              label: _isConnecting ? 'Connecting…' : 'Connect',
              onTap: _isConnecting ? null : _connect,
            ),
          ],
        ),
      ],
    );
  }

  /// Copies the connection string that Connect would use and briefly shows a
  /// check in place of the icon.
  void _copyUri() {
    final uri = _effectiveUri();
    if (uri.isEmpty) return;
    Clipboard.setData(ClipboardData(text: uri));
    setState(() => _uriCopied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _uriCopied = false);
    });
  }

  /// The copy-to-clipboard icon shown inside the URI field.
  Widget _buildUriCopyButton() {
    return CompassIconButton(
      svgString: _uriCopied ? CompassSvgIcons.check : CompassSvgIcons.copy,
      onTap: _copyUri,
      size: 14.0,
      padding: 4.0,
      color: _uriCopied ? _theme.accent : _theme.textMuted,
      semanticLabel: _uriCopied ? 'Copied' : 'Copy connection string',
    );
  }

  /// Banner shown while a saved connection is loaded for editing.
  Widget _buildEditingBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: _theme.greenBadgeBg,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: _theme.accent, width: 1.0),
      ),
      child: Row(
        children: [
          CompassSvg(
            svgString: CompassSvgIcons.pencil,
            size: 14.0,
            color: _theme.accent,
          ),
          const SizedBox(width: 8.0),
          Expanded(
            child: Text(
              'Editing “${_editingName ?? ''}”. Update & Connect to update it.',
              style: CompassTypography.bodyMedium(color: _theme.textPrimary),
            ),
          ),
          GestureDetector(
            onTap: _isConnecting ? null : _cancelEditing,
            child: Text(
              'Cancel',
              style: CompassTypography.header(color: _theme.accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CompassFieldLabel(
            label: 'Friendly Connection Name', hint: 'Optional'),
        CompassInput(
          controller: _nameController,
          mono: false,
          placeholder: 'e.g. Production Cluster, Localhost Dev',
        ),
      ],
    );
  }

  Widget _buildAdvancedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _showAdvanced = !_showAdvanced),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  'Advanced Connection Options',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: CompassTypography.bodyMedium(color: _theme.accent),
                ),
              ),
              const SizedBox(width: 4.0),
              CompassSvg(
                svgString: _showAdvanced
                    ? CompassSvgIcons.chevronUp
                    : CompassSvgIcons.chevronDown,
                size: 13.0,
                color: _theme.accent,
              ),
            ],
          ),
        ),
        if (_showAdvanced) ...[
          const SizedBox(height: 10.0),
          Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: _theme.bgSubtle,
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: _theme.border, width: 1.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const CompassFieldLabel(label: 'Host'),
                          CompassInput(controller: _hostController),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const CompassFieldLabel(label: 'Port'),
                          CompassInput(controller: _portController),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12.0),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const CompassFieldLabel(
                              label: 'Authentication Username',
                              hint: 'Optional'),
                          CompassInput(
                            controller: _usernameController,
                            mono: false,
                            placeholder: 'Optional',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12.0),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const CompassFieldLabel(
                              label: 'Authentication Password',
                              hint: 'Optional'),
                          CompassInput(
                            controller: _passwordController,
                            mono: false,
                            obscureText: true,
                            placeholder: 'Optional',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12.0),
                const CompassFieldLabel(
                  label: 'Authentication Database',
                  hint: 'Default: admin',
                ),
                CompassInput(
                  controller: _authSourceController,
                  placeholder: 'admin',
                ),
                const SizedBox(height: 14.0),
                Container(height: 1.0, color: _theme.border),
                const SizedBox(height: 10.0),
                _buildSshSection(),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// The "Connect through an SSH tunnel" toggle plus its fields. It lives
  /// inside Advanced Connection Options because it describes how to reach the
  /// MongoDB host rather than what to authenticate with once there.
  Widget _buildSshSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sshToggleRow(),
        if (_sshEnabled) ...[
          const SizedBox(height: 10.0),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const CompassFieldLabel(label: 'SSH Host'),
                    CompassInput(
                      controller: _sshHostController,
                      placeholder: 'bastion.example.com',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const CompassFieldLabel(label: 'SSH Port'),
                    CompassInput(
                      controller: _sshPortController,
                      placeholder: '22',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          const CompassFieldLabel(label: 'SSH Username'),
          CompassInput(
            controller: _sshUserController,
            mono: false,
            placeholder: 'deploy',
          ),
          const SizedBox(height: 12.0),
          const CompassFieldLabel(label: 'SSH Authentication'),
          _buildSshMethodChips(),
          const SizedBox(height: 12.0),
          if (_sshAuthMethod == SshAuthMethod.password)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const CompassFieldLabel(label: 'SSH Password'),
                CompassInput(
                  controller: _sshPasswordController,
                  mono: false,
                  obscureText: true,
                  placeholder: 'Bastion password',
                ),
              ],
            )
          else ...[
            const CompassFieldLabel(label: 'Private Key File'),
            CompassInput(
              controller: _sshKeyPathController,
              placeholder: '~/.ssh/id_ed25519',
              onChanged: (value) {
                if (value.trim() != (_pickedKeyPath ?? '')) {
                  _sshKeyPem = '';
                  _pickedKeyPath = null;
                }
              },
              suffix: CompassIconButton(
                svgString: CompassSvgIcons.file,
                onTap: _pickKeyFile,
                size: 14.0,
                padding: 4.0,
                color: _theme.textMuted,
                semanticLabel: 'Choose private key file',
              ),
            ),
            const SizedBox(height: 12.0),
            const CompassFieldLabel(
              label: 'Key Passphrase',
              hint: 'Optional',
            ),
            CompassInput(
              controller: _sshPassphraseController,
              mono: false,
              obscureText: true,
              placeholder: 'Only if the key is encrypted',
            ),
          ],
          const SizedBox(height: 8.0),
          if (_sshHostKeyFingerprint != null) ...[
            _buildPinnedKeyRow(),
            const SizedBox(height: 8.0),
          ],
          Text(
            'The MongoDB host and port above are reached through the bastion. '
            'Its host key is pinned on first use and a changed key is refused '
            'until cleared. For a TLS server, add '
            'tlsAllowInvalidCertificates=true to the URI: the tunnel terminates '
            'on 127.0.0.1, so the certificate cannot match the server name.',
            style: CompassTypography.caption(color: _theme.textMuted),
          ),
        ],
      ],
    );
  }

  /// Bordered checkbox row mirroring the onboarding acceptance control.
  Widget _sshToggleRow() {
    final density = CompassDensity.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: density.minTapTarget),
      child: CompassHover(
        onTap: () => setState(() => _sshEnabled = !_sshEnabled),
        semanticLabel: 'Connect through an SSH tunnel',
        builder: (hovered) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: _sshEnabled ? _theme.greenBadgeBg : _theme.bgInput,
            borderRadius: BorderRadius.circular(6.0),
            border: Border.all(
              color: _sshEnabled
                  ? _theme.accent
                  : (hovered ? _theme.borderHover : _theme.border),
              width: 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 16.0,
                height: 16.0,
                decoration: BoxDecoration(
                  color: _sshEnabled ? _theme.accent : _theme.bgPanel,
                  borderRadius: BorderRadius.circular(4.0),
                  border: Border.all(
                    color: _sshEnabled
                        ? _theme.accent
                        : (hovered ? _theme.borderHover : _theme.border),
                  ),
                ),
                alignment: Alignment.center,
                child: _sshEnabled
                    ? CompassSvg(
                        svgString: CompassSvgIcons.check,
                        size: 11.0,
                        color: _theme.onAccent,
                      )
                    : null,
              ),
              const SizedBox(width: 10.0),
              Expanded(
                child: Text(
                  'Connect through an SSH tunnel',
                  style:
                      CompassTypography.bodyRegular(color: _theme.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Password / private-key segmented control for the tunnel.
  Widget _buildSshMethodChips() {
    Widget chip(String label, SshAuthMethod method) {
      final selected = _sshAuthMethod == method;
      return CompassHover(
        onTap: () => setState(() => _sshAuthMethod = method),
        semanticLabel: 'SSH authentication: $label',
        builder: (hovered) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 7.0),
          decoration: BoxDecoration(
            color: selected ? _theme.accent : _theme.bgPanel,
            borderRadius: BorderRadius.circular(4.0),
            border: Border.all(
              color: selected
                  ? _theme.accent
                  : (hovered ? _theme.borderHover : _theme.border),
              width: 1.0,
            ),
          ),
          child: Text(
            label,
            style: CompassTypography.caption(
              color: selected ? _theme.onAccent : _theme.textSecondary,
            ),
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: [
        chip('Password', SshAuthMethod.password),
        chip('Private Key', SshAuthMethod.privateKey),
      ],
    );
  }

  Future<void> _pickKeyFile() async {
    try {
      const typeGroup = XTypeGroup(label: 'SSH private keys');
      final file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file == null || !mounted) return;

      // Android/iOS hand back a path into a temporary cache. Read the bytes
      // now so a saved profile keeps working after that cache is cleared.
      String? pem;
      try {
        pem = await file.readAsString();
      } catch (_) {
        // Fall back to the path (handy when the file is still on disk).
      }
      if (!mounted) return;
      setState(() {
        _sshKeyPathController.text = file.path;
        _sshKeyPem = pem ?? '';
        _pickedKeyPath = pem == null ? null : file.path;
      });
    } catch (_) {
      // Platform picker unavailable: the path can still be typed by hand.
    }
  }

  /// Read-only fingerprint of the bastion key pinned on the saved profile,
  /// with a Clear action for the "the bastion was rebuilt" case.
  Widget _buildPinnedKeyRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: _theme.bgInput,
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(color: _theme.border, width: 1.0),
      ),
      child: Row(
        children: [
          CompassSvg(
            svgString: CompassSvgIcons.shieldCheck,
            size: 14.0,
            color: _theme.accent,
          ),
          const SizedBox(width: 8.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pinned host key',
                  style: CompassTypography.caption(color: _theme.textMuted),
                ),
                const SizedBox(height: 2.0),
                Text(
                  _sshHostKeyFingerprint!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: CompassTypography.monoSmall(color: _theme.textPrimary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8.0),
          CompassHover(
            onTap: () => setState(() => _sshHostKeyFingerprint = null),
            semanticLabel: 'Clear pinned SSH host key',
            builder: (hovered) => Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
              decoration: BoxDecoration(
                color: _theme.bgPanel,
                borderRadius: BorderRadius.circular(4.0),
                border: Border.all(
                  color: hovered ? _theme.borderHover : _theme.border,
                  width: 1.0,
                ),
              ),
              child: Text(
                'Clear',
                style: CompassTypography.caption(color: _theme.accent),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSampleDataSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CompassFieldLabel(label: 'Sample Data'),
        Container(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: _theme.greenBadgeBg,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: _theme.greenBadgeBorder, width: 1.0),
          ),
          child: Row(
            children: [
              Container(
                width: 32.0,
                height: 32.0,
                decoration: BoxDecoration(
                  color: _theme.bgSubtle,
                  borderRadius: BorderRadius.circular(8.0),
                  border:
                      Border.all(color: _theme.greenBadgeBorder, width: 1.0),
                ),
                alignment: Alignment.center,
                child: CompassSvg(
                  svgString: CompassSvgIcons.database,
                  size: 16.0,
                  color: _theme.accent,
                ),
              ),
              const SizedBox(width: 10.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Local Sample Datasets',
                      style:
                          CompassTypography.header(color: _theme.textPrimary),
                    ),
                    const SizedBox(height: 2.0),
                    Text(
                      'library · social_networks',
                      style: CompassTypography.caption(color: _theme.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8.0),
              CompassPrimaryButton(
                label: 'Connect',
                onTap: _isConnecting ? null : _connectToSampleData,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSavedSection() {
    return Container(
      padding: const EdgeInsets.only(top: 16.0),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: _theme.border, width: 1.0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'SAVED CONNECTIONS (${widget.savedConnections.length})',
            style: CompassTypography.caption(color: _theme.textMuted),
          ),
          const SizedBox(height: 8.0),
          if (widget.savedConnections.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'No saved connections yet.',
                style: CompassTypography.bodyMedium(color: _theme.textMuted),
              ),
            ),
          for (final profile in widget.savedConnections)
            _buildSavedItem(profile),
        ],
      ),
    );
  }

  Widget _buildSavedItem(ConnectionProfile profile) {
    final isEditing = profile.id == _editingId;
    return Container(
      margin: const EdgeInsets.only(bottom: 6.0),
      padding: const EdgeInsets.all(10.0),
      decoration: BoxDecoration(
        color: isEditing ? _theme.greenBadgeBg : _theme.bgSubtle,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: isEditing ? _theme.accent : _theme.border,
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _isConnecting ? null : () => _attemptConnect(profile),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.name,
                    style: CompassTypography.header(color: _theme.textPrimary),
                  ),
                  const SizedBox(height: 2.0),
                  Text(
                    profile.uri,
                    style: CompassTypography.monoSmall(color: _theme.textMuted),
                  ),
                  if (profile.sshTunnel?.enabled ?? false) ...[
                    const SizedBox(height: 2.0),
                    Text(
                      'via SSH ${profile.sshTunnel!.username}'
                      '@${profile.sshTunnel!.host}:${profile.sshTunnel!.port}',
                      style: CompassTypography.caption(color: _theme.accent),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8.0),
          GestureDetector(
            onTap: _isConnecting ? null : () => _attemptConnect(profile),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
              decoration: BoxDecoration(
                color: _theme.bgPanel,
                borderRadius: BorderRadius.circular(4.0),
                border: Border.all(color: _theme.border, width: 1.0),
              ),
              child: Text(
                'Connect',
                style: CompassTypography.caption(color: _theme.accent),
              ),
            ),
          ),
          const SizedBox(width: 8.0),
          // Edit saved connection
          CompassIconButton(
            svgString: CompassSvgIcons.pencil,
            onTap: _isConnecting ? null : () => _startEditing(profile),
            size: 13.0,
            padding: 4.0,
            color: isEditing ? _theme.accent : _theme.textMuted,
            semanticLabel: 'Edit saved connection',
          ),
          const SizedBox(width: 6.0),
          // Delete saved connection
          CompassIconButton(
            svgString: CompassSvgIcons.trash,
            onTap: () => widget.onDeleteConnection(profile.id),
            size: 14.0,
            padding: 4.0,
            color: CompassColors.errorRed,
            semanticLabel: 'Delete saved connection',
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    final busy = _isConnecting || _isTesting;
    return Container(
      padding: const EdgeInsets.fromLTRB(20.0, 12.0, 20.0, 12.0),
      decoration: BoxDecoration(
        color: _theme.bgSubtle,
        border: Border(top: BorderSide(color: _theme.border, width: 1.0)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560.0;
          final actions = Wrap(
            alignment: WrapAlignment.end,
            spacing: 8.0,
            runSpacing: 8.0,
            children: [
              if (_editingId != null)
                CompassSecondaryButton(
                  label: 'Cancel',
                  onTap: _isConnecting ? null : _cancelEditing,
                ),
              CompassSecondaryButton(
                label: _isTesting ? 'Testing…' : 'Test',
                onTap: busy ? null : _testConnection,
              ),
              CompassSecondaryButton(
                label:
                    _editingId != null ? 'Update & Connect' : 'Save & Connect',
                onTap: _isConnecting ? null : _saveAndConnect,
              ),
              CompassPrimaryButton(
                label: _isConnecting ? 'Connecting…' : 'Connect',
                onTap: _isConnecting ? null : _connect,
              ),
            ],
          );
          final signature = Text(
            'Rusa — a MongoDB client',
            style: CompassTypography.caption(color: _theme.textMuted),
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                signature,
                const SizedBox(height: 8.0),
                actions,
              ],
            );
          }
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              signature,
              const SizedBox(width: 12.0),
              Flexible(child: actions),
            ],
          );
        },
      ),
    );
  }
}
