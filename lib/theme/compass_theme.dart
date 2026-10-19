import 'package:flutter/widgets.dart';

import 'compass_colors.dart';

/// InheritedWidget that propagates the current theme mode (dark / light) down
/// the widget tree without threading an `isDarkMode` parameter through every
/// widget constructor.
///
/// Usage
/// ─────
/// Read the flag anywhere inside the tree:
///   final bool dark = CompassTheme.of(context).isDarkMode;
///
/// …or read a fully resolved colour straight from the palette:
///   final theme = CompassTheme.of(context);
///   Container(color: theme.bgPanel, …);
///
/// Wrap the root widget with:
///   CompassTheme(isDarkMode: _isDarkMode, child: ...)
class CompassTheme extends InheritedWidget {
  final bool isDarkMode;

  const CompassTheme({
    super.key,
    required this.isDarkMode,
    required super.child,
  });

  /// A palette-only instance: unlike the widget that wraps the tree, this one
  /// exists purely to resolve colours for a known [isDarkMode] and is never
  /// inserted into the tree.
  ///
  /// Needed *above* the root provider — e.g. by `CompassApp`'s own `build`,
  /// whose `context` sits above the `CompassTheme` it creates, so
  /// `CompassTheme.of(context)` would miss it and fall back to dark.
  const CompassTheme.palette(this.isDarkMode, {super.key})
      : super(child: const SizedBox.shrink());

  /// Returns the nearest [CompassTheme] ancestor.
  /// Falls back to dark mode when no ancestor is found (fail-safe).
  static CompassTheme of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<CompassTheme>() ??
        const CompassTheme(isDarkMode: true, child: SizedBox.shrink());
  }

  // --- Resolved palette ------------------------------------------------------
  // Dark and light colour pairs resolved for the current mode, so widgets do
  // not have to repeat `isDarkMode ? CompassColors.darkX : CompassColors.lightX`
  // at every call site.

  Color get bgApp => isDarkMode ? CompassColors.darkBgApp : CompassColors.lightBgApp;
  Color get bgSidebar => isDarkMode ? CompassColors.darkBgSidebar : CompassColors.lightBgSidebar;
  Color get bgPanel => isDarkMode ? CompassColors.darkBgPanel : CompassColors.lightBgPanel;
  Color get bgSubtle => isDarkMode ? CompassColors.darkBgSubtle : CompassColors.lightBgSubtle;
  Color get bgHover => isDarkMode ? CompassColors.darkBgHover : CompassColors.lightBgHover;
  Color get bgInput => isDarkMode ? CompassColors.darkBgInput : CompassColors.lightBgInput;
  Color get border => isDarkMode ? CompassColors.darkBorder : CompassColors.lightBorder;
  Color get borderHover =>
      isDarkMode ? CompassColors.darkBorderHover : CompassColors.lightBorderHover;
  Color get textPrimary =>
      isDarkMode ? CompassColors.darkTextPrimary : CompassColors.lightTextPrimary;
  Color get textSecondary =>
      isDarkMode ? CompassColors.darkTextSecondary : CompassColors.lightTextSecondary;
  Color get textMuted => isDarkMode ? CompassColors.darkTextMuted : CompassColors.lightTextMuted;

  // --- Accents ---------------------------------------------------------------

  /// Brand green used for accent text, icons, values, underlines and fills.
  /// Bright spring green on dark; forest green on light (readable on white).
  Color get accent => isDarkMode ? CompassColors.greenAccent : CompassColors.greenForest;

  /// Colour drawn on top of an [accent] fill (primary buttons, pills).
  Color get onAccent => isDarkMode ? CompassColors.greenNavy : CompassColors.lightOnAccent;

  Color get greenBadgeBg =>
      isDarkMode ? CompassColors.greenBadgeBg : CompassColors.lightGreenBadgeBg;
  Color get greenBadgeBorder =>
      isDarkMode ? CompassColors.greenBadgeBorder : CompassColors.lightGreenBadgeBorder;

  // --- BSON syntax colours ---------------------------------------------------

  Color get bsonObjectId =>
      isDarkMode ? CompassColors.bsonObjectId : CompassColors.lightBsonObjectId;
  Color get bsonString =>
      isDarkMode ? CompassColors.bsonString : CompassColors.lightBsonString;
  Color get bsonNumber =>
      isDarkMode ? CompassColors.bsonNumber : CompassColors.lightBsonNumber;
  Color get bsonBoolean =>
      isDarkMode ? CompassColors.bsonBoolean : CompassColors.lightBsonBoolean;
  Color get bsonDate => isDarkMode ? CompassColors.bsonDate : CompassColors.lightBsonDate;
  Color get bsonNull => isDarkMode ? CompassColors.bsonNull : CompassColors.lightBsonNull;

  @override
  bool updateShouldNotify(CompassTheme oldWidget) =>
      isDarkMode != oldWidget.isDarkMode;
}

