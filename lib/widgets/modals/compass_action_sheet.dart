import 'package:flutter/widgets.dart';

import '../../icons/compass_svg_icons.dart';
import '../../theme/compass_colors.dart';
import '../../theme/compass_density.dart';
import '../../theme/compass_theme.dart';
import '../../theme/compass_typography.dart';
import '../compass_hover.dart';

/// One entry of a [CompassActionSheet].
class CompassActionSheetItem {
  final String label;
  final String svg;
  final Color? color;
  final bool destructive;
  final VoidCallback onTap;

  const CompassActionSheetItem({
    required this.label,
    required this.svg,
    required this.onTap,
    this.color,
    this.destructive = false,
  });
}

/// A bottom sheet that hosts actions which do not fit on a narrow screen.
///
/// Why this exists
/// ───────────────
/// The desktop header carries five controls (logo, connection pill, reset
/// samples, `_mongosh`, theme toggle, disconnect). On a phone that is roughly
/// 780 px of content in a 390 px viewport, so the header overflows by a mile.
/// Instead of shrinking the desktop chrome, the touch layout keeps two icons
/// in the header and moves the rest into this sheet.
///
/// Like every other overlay in this app the sheet is a `Positioned.fill`
/// child of the root `Stack` in `main.dart` (there is no `Navigator` and no
/// Material `showModalBottomSheet`). A closed sheet renders
/// `SizedBox.shrink()`, so its children are never mounted.
class CompassActionSheet extends StatelessWidget {
  final bool isOpen;
  final String title;
  final List<CompassActionSheetItem> items;
  final VoidCallback onClose;

  const CompassActionSheet({
    super.key,
    required this.isOpen,
    required this.items,
    required this.onClose,
    this.title = '',
  });

  @override
  Widget build(BuildContext context) {
    if (!isOpen) return const SizedBox.shrink();

    final theme = CompassTheme.of(context);
    final density = CompassDensity.of(context);

    return Positioned.fill(
      child: Stack(
        children: [
          // Backdrop: tapping anywhere outside the sheet dismisses it.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onClose,
              child: Container(color: CompassColors.modalOverlay),
            ),
          ),

          // The sheet itself, pinned to the bottom of the screen.
          Positioned(
            left: 0.0,
            right: 0.0,
            bottom: 0.0,
            child: SafeArea(
              top: false,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.bgPanel,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16.0),
                  ),
                  border: Border.all(color: theme.border, width: 1.0),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 24.0,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(12.0, 10.0, 12.0, 12.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Grab handle.
                    Center(
                      child: Container(
                        width: 36.0,
                        height: 4.0,
                        decoration: BoxDecoration(
                          color: theme.border,
                          borderRadius: BorderRadius.circular(2.0),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12.0),

                    if (title.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0, bottom: 6.0),
                        child: Text(
                          title,
                          style: CompassTypography.title(color: theme.textPrimary),
                        ),
                      ),
                    ],

                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final item in items)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4.0),
                                child: _ActionSheetRow(
                                  item: item,
                                  minHeight: density.minTapTarget,
                                  onTap: () {
                                    onClose();
                                    item.onTap();
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 6.0),

                    // Explicit cancel target: closing via the backdrop alone is
                    // not discoverable enough with a finger.
                    ConstrainedBox(
                      constraints: BoxConstraints(minHeight: density.minTapTarget),
                      child: CompassHover(
                        onTap: onClose,
                        semanticLabel: 'Cancel',
                        builder: (hovered) => Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: hovered ? theme.bgHover : null,
                            borderRadius: BorderRadius.circular(8.0),
                            border: Border.all(color: theme.border, width: 1.0),
                          ),
                          child: Text(
                            'Cancel',
                            style: CompassTypography.bodyMedium(
                              color: theme.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single, finger-sized row inside a [CompassActionSheet].
class _ActionSheetRow extends StatelessWidget {
  final CompassActionSheetItem item;
  final double minHeight;
  final VoidCallback onTap;

  const _ActionSheetRow({
    required this.item,
    required this.minHeight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = CompassTheme.of(context);
    final color = item.color ??
        (item.destructive ? CompassColors.errorRed : theme.textPrimary);

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: CompassHover(
        onTap: onTap,
        semanticLabel: item.label,
        builder: (hovered) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
          decoration: BoxDecoration(
            color: hovered ? theme.bgHover : null,
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Row(
            children: [
              CompassSvg(
                svgString: item.svg,
                size: 18.0,
                color: color,
              ),
              const SizedBox(width: 12.0),
              Expanded(
                child: Text(
                  item.label,
                  style: CompassTypography.bodyMedium(color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
