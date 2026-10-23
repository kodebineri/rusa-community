import 'package:flutter/widgets.dart';

import '../icons/compass_svg_icons.dart';
import '../theme/compass_density.dart';
import '../theme/compass_theme.dart';
import 'compass_hover.dart';

/// A tappable icon with a guaranteed hit area.
///
/// Why this exists
/// ───────────────
/// Every icon control in the app used to be a bare `GestureDetector` around a
/// `CompassSvg`. `GestureDetector` defaults to `HitTestBehavior.deferToChild`,
/// so the padding wrapped around the glyph never counted towards the tap
/// area — the tappable region was literally the SVG's own 11-16 px box, an
/// order of magnitude below the 44 dp a finger needs.
///
/// This widget keeps the *visual* size of the glyph exactly as it was (so the
/// desktop layout is unchanged) but guarantees a hit area of at least
/// [CompassDensity.minTapTarget] in both dimensions. It also adds the hover
/// affordance and pointer cursor that the desktop build never had, plus an
/// optional semantic label so screen readers announce the button.
///
/// The glyph is centred inside the (possibly larger) target with a `Stack`
/// rather than a `Center`: `Center` would try to expand to the biggest
/// possible size, which is infinite inside a `Row`.
class CompassIconButton extends StatelessWidget {
  /// The SVG literal to render (see `CompassSvgIcons`).
  final String svgString;

  /// Invoked on tap. `null` disables the button.
  final VoidCallback? onTap;

  /// Optional long-press handler (used for touch-only overflow menus).
  final VoidCallback? onLongPress;

  /// Glyph colour. `null` keeps the SVG's own colour.
  final Color? color;

  /// Visual size of the glyph, before [CompassDensity.iconScale].
  final double size;

  /// Breathing room kept around the glyph inside the target.
  final double padding;

  /// Accessible name. When omitted the button is not exposed to assistive
  /// technology (an unlabelled button is worse than no button).
  final String? semanticLabel;

  /// Optional chip fill drawn behind the glyph.
  final Color? background;

  /// Optional chip border drawn around the glyph.
  final Color? borderColor;

  /// Corner radius of the chip / hover highlight.
  final double borderRadius;

  /// Forces a square target of at least this size (used by the square icon
  /// chips such as the query bar's reset button). The density minimum still
  /// wins, so a 36 px chip grows to 44 px on touch layouts.
  final double? boxSize;

  /// Fill used while the pointer hovers the button. Defaults to the theme's
  /// hover surface.
  final Color? hoverBackground;

  /// Whether the hover highlight is drawn at all.
  final bool showHoverBackground;

  const CompassIconButton({
    super.key,
    required this.svgString,
    required this.onTap,
    this.onLongPress,
    this.color,
    this.size = 14.0,
    this.padding = 4.0,
    this.semanticLabel,
    this.background,
    this.borderColor,
    this.borderRadius = 6.0,
    this.boxSize,
    this.hoverBackground,
    this.showHoverBackground = true,
  });

  @override
  Widget build(BuildContext context) {
    final density = CompassDensity.of(context);
    final theme = CompassTheme.of(context);

    final bool enabled = onTap != null;

    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: density.minTapTarget,
        minHeight: density.minTapTarget,
      ),
      child: CompassHover(
        onTap: onTap,
        onLongPress: onLongPress,
        semanticLabel: semanticLabel,
        builder: (hovered) {
          final bool highlighted =
              hovered && enabled && showHoverBackground;

          Color? fill = background;
          if (highlighted) {
            fill = hoverBackground ?? theme.bgHover;
          }

          Widget chip = Container(
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(borderRadius),
              border: borderColor != null
                  ? Border.all(color: borderColor!, width: 1.0)
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                CompassSvg(
                  svgString: svgString,
                  size: size * density.iconScale,
                  color: color,
                ),
              ],
            ),
          );

          if (boxSize != null) {
            final target = boxSize! > density.minTapTarget
                ? boxSize!
                : density.minTapTarget;
            chip = ConstrainedBox(
              constraints: BoxConstraints(minWidth: target, minHeight: target),
              child: chip,
            );
          }

          return chip;
        },
      ),
    );
  }
}
