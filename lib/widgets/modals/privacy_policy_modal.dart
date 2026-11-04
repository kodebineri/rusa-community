import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../../icons/compass_svg_icons.dart';
import '../../theme/compass_theme.dart';
import '../../theme/compass_typography.dart';
import '../compass_markdown_view.dart';
import 'compass_modal.dart';

/// Privacy Policy dialog.
///
/// The policy text is *not* duplicated in Dart: it is read from the bundled
/// `PRIVACY.md` asset (declared in `pubspec.yaml`) and rendered with
/// [CompassMarkdownView], so editing the Markdown file is enough to update the
/// dialog. The file is loaded once, when this modal is first mounted (it is a
/// permanent child of the root `Stack`), so opening it later never waits.
///
/// Opened from the header more-menu (desktop) and from the touch action sheet.
class PrivacyPolicyModal extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onClose;

  const PrivacyPolicyModal({
    super.key,
    required this.isOpen,
    required this.onClose,
  });

  @override
  State<PrivacyPolicyModal> createState() => _PrivacyPolicyModalState();
}

class _PrivacyPolicyModalState extends State<PrivacyPolicyModal> {
  /// Asset path of the policy text, relative to `pubspec.yaml`.
  static const String _assetPath = 'PRIVACY.md';

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
      setState(() => _error = 'Could not load the privacy policy ($_assetPath).');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = CompassTheme.of(context);

    return CompassModalShell(
      isOpen: widget.isOpen,
      maxWidth: 640.0,
      onBackdropTap: widget.onClose,
      children: [
        CompassModalHeader(
          title: 'Privacy Policy',
          subtitle: 'Version 1.0',
          iconSvg: CompassSvgIcons.shieldCheck,
          onClose: widget.onClose,
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
              'Loading privacy policy...',
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
            CompassSecondaryButton(label: 'Close', onTap: widget.onClose),
          ],
        ),
      ],
    );
  }
}
