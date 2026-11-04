import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../../icons/compass_svg_icons.dart';
import '../../theme/compass_theme.dart';
import '../../theme/compass_typography.dart';
import '../compass_markdown_view.dart';
import 'compass_modal.dart';

/// First-run EULA gate.
///
/// Shown *over everything else* until the user explicitly accepts the licence
/// (it is the topmost child of the root `Stack` in `main.dart`). Unlike
/// [EulaModal] it has **no** close button and **no** backdrop dismissal — the
/// only way past it is the **I Accept** button, whose [onAccept] persists the
/// acceptance so the gate never appears again on this device.
///
/// The licence text is read from the bundled `EULA.md` asset (declared in
/// `pubspec.yaml`) and rendered with [CompassMarkdownView], so editing the
/// Markdown is enough to change the text.
class EulaAcceptanceModal extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onAccept;

  const EulaAcceptanceModal({
    super.key,
    required this.isOpen,
    required this.onAccept,
  });

  @override
  State<EulaAcceptanceModal> createState() => _EulaAcceptanceModalState();
}

class _EulaAcceptanceModalState extends State<EulaAcceptanceModal> {
  /// Asset path of the licence text, relative to `pubspec.yaml`.
  static const String _assetPath = 'EULA.md';

  String? _markdown;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final text = await rootBundle.loadString(_assetPath);
      if (!mounted) return;
      setState(() => _markdown = text);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not load the license text ($_assetPath).');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = CompassTheme.of(context);

    return CompassModalShell(
      isOpen: widget.isOpen,
      maxWidth: 640.0,
      // No backdrop dismissal: the gate cannot be skipped.
      children: [
        const CompassModalHeader(
          title: 'End User License Agreement',
          subtitle: 'Version 1.1',
          iconSvg: CompassSvgIcons.file,
          showClose: false,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 12.0),
          child: Text(
            'Please review and accept the End User License Agreement to use '
            'MongoDB Compass Flutter Client.',
            style: CompassTypography.bodyRegular(color: theme.textSecondary),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: CompassErrorBanner(message: _error!),
          )
        else if (_markdown == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Text(
              'Loading license text...',
              textAlign: TextAlign.center,
              style: CompassTypography.bodyRegular(color: theme.textMuted),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: CompassMarkdownView(markdown: _markdown!),
          ),
        CompassModalFooter(
          children: [
            CompassPrimaryButton(
              label: 'I Accept',
              onTap: widget.onAccept,
              fullWidth: true,
            ),
          ],
        ),
      ],
    );
  }
}
