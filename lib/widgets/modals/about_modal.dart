import 'package:flutter/widgets.dart';
import '../../icons/compass_svg_icons.dart';
import '../../theme/compass_theme.dart';
import '../../theme/compass_typography.dart';
import 'compass_modal.dart';

/// About dialog: logo, app name and version.
///
/// Opened from the header more-menu (desktop) and from the touch action sheet.
/// It follows the same `CompassModalShell` conventions as the other modals, so
/// it is a permanent child of the root `Stack` in `main.dart` and renders
/// `SizedBox.shrink()` while closed.
class AboutModal extends StatelessWidget {
  final bool isOpen;
  final VoidCallback onClose;

  /// Keep in sync with the version badge in `CompassHeader` (`7.0.8`).
  static const String appVersion = '7.0.8';

  const AboutModal({super.key, required this.isOpen, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final theme = CompassTheme.of(context);

    return CompassModalShell(
      isOpen: isOpen,
      maxWidth: 320.0,
      onBackdropTap: onClose,
      children: [
        const SizedBox(height: 8.0),

        // Logo: the same leaf-on-green-gradient badge as the header, scaled up.
        Center(
          child: Container(
            alignment: Alignment.center,
            child: const CompassSvg(
              svgString: CompassSvgIcons.rusa,
              size: 72.0,
              color: Color(0xFFFFFFFF),
            ),
          ),
        ),

        const SizedBox(height: 16.0),

        // App name.
        Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'r u s a',
              style: CompassTypography.title(color: theme.textPrimary)
                  .copyWith(fontSize: 22.0),
            ),
          ),
        ),

        const SizedBox(height: 4.0),

        // Descriptive tagline (generic, to avoid implying affiliation).
        Center(
          child: Text(
            'A MongoDB database client',
            style: CompassTypography.caption(color: theme.textSecondary),
          ),
        ),

        const SizedBox(height: 10.0),

        // Version badge, same shape as the header's `7.0.8` chip.
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
            decoration: BoxDecoration(
              color: theme.bgSubtle,
              borderRadius: BorderRadius.circular(4.0),
              border: Border.all(color: theme.border, width: 1.0),
            ),
            child: Text(
              'Version $appVersion',
              style: CompassTypography.monoSmall(color: theme.textMuted),
            ),
          ),
        ),

        const SizedBox(height: 8.0),

        // Non-affiliation disclaimer (trademark hygiene).
        Center(
          child: Text(
            'Rusa is an independent, unofficial client. It is not affiliated '
            'with, endorsed by, or sponsored by MongoDB, Inc. "MongoDB" is a '
            'trademark of MongoDB, Inc., used only to describe compatibility.',
            textAlign: TextAlign.center,
            style: CompassTypography.caption(color: theme.textMuted),
          ),
        ),

        const SizedBox(height: 8.0),

        CompassModalFooter(
          children: [
            CompassSecondaryButton(label: 'Close', onTap: onClose),
          ],
        ),
      ],
    );
  }
}
