import 'package:flutter/widgets.dart';

import 'compass_theme_presets.dart';

/// InheritedWidget that propagates the selected [CompassThemeVariant] down the
/// widget tree without threading the variant through every widget constructor.
///
/// Usage
/// ─────
/// Read the selected variant anywhere inside the tree:
///   final variant = CompassTheme.of(context).variant;
///
/// …or read a fully resolved colour straight from the palette:
///   final theme = CompassTheme.of(context);
///   Container(color: theme.bgPanel, …);
///
/// Wrap the root widget with:
///   CompassTheme(variant: _themeVariant, child: ...)
class CompassTheme extends InheritedWidget {
  /// The selected theme. Defaults to [CompassThemeVariant.defaultVariant]
  /// (Dracula, dark) so a bare `CompassTheme(child: …)` stays dark.
  final CompassThemeVariant variant;

  const CompassTheme({
    super.key,
    this.variant = CompassThemeVariant.defaultVariant,
    required super.child,
  });

  /// A palette-only instance: unlike the widget that wraps the tree, this one
  /// exists purely to resolve colours for a known [variant] and is never
  /// inserted into the tree.
  ///
  /// Needed *above* the root provider — e.g. by `CompassApp`'s own `build`,
  /// whose `context` sits above the `CompassTheme` it creates, so
  /// `CompassTheme.of(context)` would miss it and fall back to Dracula.
  const CompassTheme.palette(this.variant, {super.key})
      : super(child: const SizedBox.shrink());

  /// Returns the nearest [CompassTheme] ancestor.
  /// Falls back to the default (Dracula, dark) when no ancestor is found.
  static CompassTheme of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<CompassTheme>() ??
        const CompassTheme(child: SizedBox.shrink());
  }

  /// Whether the selected variant is dark. Kept as a convenience because the
  /// system chrome and a few widgets only care about brightness.
  bool get isDarkMode => variant.isDark;

  /// The resolved palette for the selected variant.
  CompassPalette get palette => variant.palette;

  // --- Resolved palette ------------------------------------------------------
  // Widgets read these getters instead of branching on dark/light, so adding a
  // theme never requires touching a call site.

  Color get bgApp => palette.bgApp;
  Color get bgSidebar => palette.bgSidebar;
  Color get bgPanel => palette.bgPanel;
  Color get bgSubtle => palette.bgSubtle;
  Color get bgHover => palette.bgHover;
  Color get bgInput => palette.bgInput;
  Color get border => palette.border;
  Color get borderHover => palette.borderHover;
  Color get textPrimary => palette.textPrimary;
  Color get textSecondary => palette.textSecondary;
  Color get textMuted => palette.textMuted;

  // --- Accents ---------------------------------------------------------------

  /// Accent used for accent text, icons, values, underlines and fills.
  Color get accent => palette.accent;

  /// Accent fill while a control is hovered.
  Color get accentHover => palette.accentHover;

  /// Colour drawn on top of an [accent] fill (primary buttons, pills).
  Color get onAccent => palette.onAccent;

  Color get greenBadgeBg => palette.greenBadgeBg;
  Color get greenBadgeBorder => palette.greenBadgeBorder;

  // --- BSON syntax colours ---------------------------------------------------

  Color get bsonObjectId => palette.bsonObjectId;
  Color get bsonString => palette.bsonString;
  Color get bsonNumber => palette.bsonNumber;
  Color get bsonBoolean => palette.bsonBoolean;
  Color get bsonDate => palette.bsonDate;
  Color get bsonNull => palette.bsonNull;

  @override
  bool updateShouldNotify(CompassTheme oldWidget) => variant != oldWidget.variant;
}
