import 'package:flutter/widgets.dart';
import '../../theme/compass_colors.dart';
import '../../theme/compass_theme.dart';
import '../../theme/compass_typography.dart';
import '../../icons/compass_svg_icons.dart';
import '../../models/mongo_models.dart';
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
///  * Per-saved-connection deletion.
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

  const ConnectionModal({
    super.key,
    required this.isOpen,
    required this.onClose,
    required this.savedConnections,
    required this.onConnect,
    required this.onSaveConnection,
    required this.onDeleteConnection,
    required this.onConnectSampleData,
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

  bool _showAdvanced = false;
  bool _syncingUri = false;
  bool _isConnecting = false;
  String? _connectError;

  @override
  void initState() {
    super.initState();
    _uriController = TextEditingController();
    _nameController = TextEditingController();
    _hostController = TextEditingController();
    _portController = TextEditingController();
    _usernameController = TextEditingController();
    _passwordController = TextEditingController();
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
    _showAdvanced = false;
    _isConnecting = false;
    _connectError = null;
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
    final host = _hostController.text.trim().isEmpty ? 'localhost' : _hostController.text.trim();
    final port = _portController.text.trim().isEmpty ? '27017' : _portController.text.trim();
    final user = _usernameController.text.trim();
    final pass = _passwordController.text;
    final credentials = user.isEmpty ? '' : '$user${pass.isEmpty ? '' : ':$pass'}@';
    return 'mongodb://$credentials$host:$port';
  }

  String _effectiveUri() {
    final typed = _uriController.text.trim();
    return typed.isEmpty ? _composeUri() : typed;
  }

  ConnectionProfile _buildProfile() {
    final name = _nameController.text.trim();
    return ConnectionProfile(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.isEmpty ? 'MongoDB Cluster' : name,
      uri: _effectiveUri(),
      lastConnected: 'Just now',
    );
  }

  Future<void> _connect() => _attemptConnect(_buildProfile());

  Future<void> _saveAndConnect() async {
    final profile = _buildProfile();
    widget.onSaveConnection(profile);
    await _attemptConnect(profile);
  }

  /// Attempts to open a connection. [ConnectionModal.onConnect] resolves to a
  /// failure message (or `null` on success), so the dialog can stay open and
  /// show the error instead of silently closing.
  Future<void> _attemptConnect(ConnectionProfile profile) async {
    if (_isConnecting) return;
    setState(() {
      _isConnecting = true;
      _connectError = null;
    });
    final error = await widget.onConnect(profile);
    if (!mounted) return;
    if (error == null) {
      widget.onClose();
      return;
    }
    setState(() {
      _isConnecting = false;
      _connectError = error;
    });
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
                        if (_connectError != null) ...[
                          const SizedBox(height: 12.0),
                          CompassErrorBanner(message: _connectError!),
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
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [CompassColors.greenAccent, CompassColors.greenForest],
                    ),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  alignment: Alignment.center,
                  child: const CompassSvg(
                    svgString: CompassSvgIcons.mongoLeaf,
                    size: 18.0,
                  ),
                ),
                const SizedBox(width: 10.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Connect to MongoDB',
                        style: CompassTypography.title(color: _theme.textPrimary),
                      ),
                      const SizedBox(height: 2.0),
                      Text(
                        'Connect to a standalone instance, replica set, or Atlas cluster',
                        style: CompassTypography.caption(color: _theme.textMuted),
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

  Widget _buildNameSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CompassFieldLabel(label: 'Friendly Connection Name', hint: 'Optional'),
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
              Text(
                'Advanced Connection Options',
                style: CompassTypography.bodyMedium(color: _theme.accent),
              ),
              const SizedBox(width: 4.0),
              CompassSvg(
                svgString: _showAdvanced ? CompassSvgIcons.chevronUp : CompassSvgIcons.chevronDown,
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
                          const CompassFieldLabel(label: 'Authentication Username', hint: 'Optional'),
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
                          const CompassFieldLabel(label: 'Authentication Password', hint: 'Optional'),
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
              ],
            ),
          ),
        ],
      ],
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
                  border: Border.all(color: _theme.greenBadgeBorder, width: 1.0),
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
                      style: CompassTypography.header(color: _theme.textPrimary),
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
          for (final profile in widget.savedConnections) _buildSavedItem(profile),
        ],
      ),
    );
  }

  Widget _buildSavedItem(ConnectionProfile profile) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6.0),
      padding: const EdgeInsets.all(10.0),
      decoration: BoxDecoration(
        color: _theme.bgSubtle,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: _theme.border, width: 1.0),
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
                ],
              ),
            ),
          ),
          const SizedBox(width: 8.0),
          GestureDetector(
            onTap: _isConnecting ? null : () => _attemptConnect(profile),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(20.0, 12.0, 20.0, 12.0),
      decoration: BoxDecoration(
        color: _theme.bgSubtle,
        border: Border(top: BorderSide(color: _theme.border, width: 1.0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'MongoDB Compass v1.42.0 Web Client',
            style: CompassTypography.caption(color: _theme.textMuted),
          ),
          Row(
            children: [
              CompassSecondaryButton(
                label: 'Save & Connect',
                onTap: _isConnecting ? null : _saveAndConnect,
              ),
              const SizedBox(width: 8.0),
              CompassPrimaryButton(
                label: _isConnecting ? 'Connecting…' : 'Connect',
                onTap: _isConnecting ? null : _connect,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
