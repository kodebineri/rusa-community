import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// A complete, resolved colour palette for one Compass theme.
///
/// Every value a widget needs comes from here, so switching themes is a single
/// swap of [CompassTheme.variant] rather than a branch on dark/light.
@immutable
class CompassPalette {
  final Color bgApp;
  final Color bgSidebar;
  final Color bgPanel;
  final Color bgSubtle;
  final Color bgHover;
  final Color bgInput;
  final Color border;
  final Color borderHover;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;
  final Color accentHover;
  final Color onAccent;
  final Color greenBadgeBg;
  final Color greenBadgeBorder;
  final Color bsonObjectId;
  final Color bsonString;
  final Color bsonNumber;
  final Color bsonBoolean;
  final Color bsonDate;
  final Color bsonNull;

  const CompassPalette({
    required this.bgApp,
    required this.bgSidebar,
    required this.bgPanel,
    required this.bgSubtle,
    required this.bgHover,
    required this.bgInput,
    required this.border,
    required this.borderHover,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.accentHover,
    required this.onAccent,
    required this.greenBadgeBg,
    required this.greenBadgeBorder,
    required this.bsonObjectId,
    required this.bsonString,
    required this.bsonNumber,
    required this.bsonBoolean,
    required this.bsonDate,
    required this.bsonNull,
  });
}

/// The selectable themes, modelled after popular VS Code colour themes.
///
/// Three dark and three light variants. [dracula] is the default (see
/// [defaultVariant]); the rest are grouped by [isDark] in the options menu.
enum CompassThemeVariant {
  dracula(
    label: 'Dracula',
    isDark: true,
    palette: CompassPalette(
      bgApp: Color(0xFF282A36),
      bgSidebar: Color(0xFF21222C),
      bgPanel: Color(0xFF21222C),
      bgSubtle: Color(0xFF343746),
      bgHover: Color(0xFF44475A),
      bgInput: Color(0xFF282A36),
      border: Color(0xFF44475A),
      borderHover: Color(0xFF6272A4),
      textPrimary: Color(0xFFF8F8F2),
      textSecondary: Color(0xFFC8C8C8),
      textMuted: Color(0xFF6272A4),
      accent: Color(0xFFBD93F9),
      accentHover: Color(0xFFA97FEF),
      onAccent: Color(0xFF21222C),
      greenBadgeBg: Color(0x26BD93F9),
      greenBadgeBorder: Color(0x4DBD93F9),
      bsonObjectId: Color(0xFF50FA7B),
      bsonString: Color(0xFFF1FA8C),
      bsonNumber: Color(0xFFBD93F9),
      bsonBoolean: Color(0xFF8BE9FD),
      bsonDate: Color(0xFFFF79C6),
      bsonNull: Color(0xFFFF5555),
    ),
  ),
  tokyoNight(
    label: 'Tokyo Night',
    isDark: true,
    palette: CompassPalette(
      bgApp: Color(0xFF1A1B26),
      bgSidebar: Color(0xFF16161E),
      bgPanel: Color(0xFF16161E),
      bgSubtle: Color(0xFF24283B),
      bgHover: Color(0xFF292E42),
      bgInput: Color(0xFF1A1B26),
      border: Color(0xFF2F3549),
      borderHover: Color(0xFF3B4261),
      textPrimary: Color(0xFFC0CAF5),
      textSecondary: Color(0xFFA9B1D6),
      textMuted: Color(0xFF565F89),
      accent: Color(0xFF7AA2F7),
      accentHover: Color(0xFF5E8BE8),
      onAccent: Color(0xFF1A1B26),
      greenBadgeBg: Color(0x267AA2F7),
      greenBadgeBorder: Color(0x4D7AA2F7),
      bsonObjectId: Color(0xFF2AC3DE),
      bsonString: Color(0xFF9ECE6A),
      bsonNumber: Color(0xFFFF9E64),
      bsonBoolean: Color(0xFF7AA2F7),
      bsonDate: Color(0xFFBB9AF7),
      bsonNull: Color(0xFFF7768E),
    ),
  ),
  nightOwl(
    label: 'Night Owl',
    isDark: true,
    palette: CompassPalette(
      bgApp: Color(0xFF011627),
      bgSidebar: Color(0xFF0B2942),
      bgPanel: Color(0xFF0B2942),
      bgSubtle: Color(0xFF1D3B53),
      bgHover: Color(0xFF234E6B),
      bgInput: Color(0xFF011627),
      border: Color(0xFF1D3B53),
      borderHover: Color(0xFF2E5A7A),
      textPrimary: Color(0xFFD6DEEB),
      textSecondary: Color(0xFFA7B6C2),
      textMuted: Color(0xFF637777),
      accent: Color(0xFF82AAFF),
      accentHover: Color(0xFF6A97F5),
      onAccent: Color(0xFF011627),
      greenBadgeBg: Color(0x2682AAFF),
      greenBadgeBorder: Color(0x4D82AAFF),
      bsonObjectId: Color(0xFF7FDBCA),
      bsonString: Color(0xFFC5E478),
      bsonNumber: Color(0xFFF78C6C),
      bsonBoolean: Color(0xFF82AAFF),
      bsonDate: Color(0xFFC792EA),
      bsonNull: Color(0xFFEF5350),
    ),
  ),
  monokaiLight(
    label: 'Monokai Light',
    isDark: false,
    palette: CompassPalette(
      bgApp: Color(0xFFFAF4E5),
      bgSidebar: Color(0xFFF3EBD8),
      bgPanel: Color(0xFFFFFBF0),
      bgSubtle: Color(0xFFF2EBDD),
      bgHover: Color(0xFFEAE2D0),
      bgInput: Color(0xFFFFFBF0),
      border: Color(0xFFE3D9C6),
      borderHover: Color(0xFFCFC3A9),
      textPrimary: Color(0xFF2C292D),
      textSecondary: Color(0xFF5C565C),
      textMuted: Color(0xFF8A8088),
      accent: Color(0xFFC94F6D),
      accentHover: Color(0xFFB4415E),
      onAccent: Color(0xFFFFFBF0),
      greenBadgeBg: Color(0x26C94F6D),
      greenBadgeBorder: Color(0x4DC94F6D),
      bsonObjectId: Color(0xFFC94F6D),
      bsonString: Color(0xFF4C8A3F),
      bsonNumber: Color(0xFFB15C00),
      bsonBoolean: Color(0xFF7A4FBF),
      bsonDate: Color(0xFFA34BA3),
      bsonNull: Color(0xFFC62828),
    ),
  ),
  tokyoNightLight(
    label: 'Tokyo Night Light',
    isDark: false,
    palette: CompassPalette(
      bgApp: Color(0xFFE6E7ED),
      bgSidebar: Color(0xFFDFE2EA),
      bgPanel: Color(0xFFF7F7FA),
      bgSubtle: Color(0xFFD3D7E3),
      bgHover: Color(0xFFC4C8DA),
      bgInput: Color(0xFFFFFFFF),
      border: Color(0xFFC4C8DA),
      borderHover: Color(0xFFA8AECB),
      textPrimary: Color(0xFF343B58),
      textSecondary: Color(0xFF4E5579),
      textMuted: Color(0xFF7A82A6),
      accent: Color(0xFF2E7DE9),
      accentHover: Color(0xFF1F6AD0),
      onAccent: Color(0xFFFFFFFF),
      greenBadgeBg: Color(0x262E7DE9),
      greenBadgeBorder: Color(0x4D2E7DE9),
      bsonObjectId: Color(0xFF2E7DE9),
      bsonString: Color(0xFF587539),
      bsonNumber: Color(0xFFB15C00),
      bsonBoolean: Color(0xFF9854F1),
      bsonDate: Color(0xFF8C4EC4),
      bsonNull: Color(0xFFF52A65),
    ),
  ),
  materialLight(
    label: 'Material Light',
    isDark: false,
    palette: CompassPalette(
      bgApp: Color(0xFFFAFAFA),
      bgSidebar: Color(0xFFF5F5F5),
      bgPanel: Color(0xFFFFFFFF),
      bgSubtle: Color(0xFFF0F0F0),
      bgHover: Color(0xFFE7E7E7),
      bgInput: Color(0xFFFFFFFF),
      border: Color(0xFFE0E0E0),
      borderHover: Color(0xFFBDBDBD),
      textPrimary: Color(0xFF212121),
      textSecondary: Color(0xFF616161),
      textMuted: Color(0xFF9E9E9E),
      accent: Color(0xFF1976D2),
      accentHover: Color(0xFF1565C0),
      onAccent: Color(0xFFFFFFFF),
      greenBadgeBg: Color(0x261976D2),
      greenBadgeBorder: Color(0x4D1976D2),
      bsonObjectId: Color(0xFF1976D2),
      bsonString: Color(0xFF2E7D32),
      bsonNumber: Color(0xFFEF6C00),
      bsonBoolean: Color(0xFF6A1B9A),
      bsonDate: Color(0xFFAD1457),
      bsonNull: Color(0xFFC62828),
    ),
  );

  const CompassThemeVariant({
    required this.label,
    required this.isDark,
    required this.palette,
  });

  /// Human-readable name shown in the theme picker.
  final String label;

  /// Whether this is a dark variant. Drives system chrome brightness.
  final bool isDark;

  /// Fully resolved colours for this variant.
  final CompassPalette palette;

  /// Theme used on first launch.
  static const CompassThemeVariant defaultVariant = CompassThemeVariant.dracula;

  /// Dark variants, in menu order.
  static List<CompassThemeVariant> get darkThemes =>
      values.where((variant) => variant.isDark).toList(growable: false);

  /// Light variants, in menu order.
  static List<CompassThemeVariant> get lightThemes =>
      values.where((variant) => !variant.isDark).toList(growable: false);

  /// Resolves a persisted variant [name] (an enum `name`, see
  /// `AppPreferences.themeVariantKey`) back to a variant, falling back to
  /// [defaultVariant] for a missing or unknown name.
  static CompassThemeVariant fromName(String? name) {
    if (name == null) return defaultVariant;
    for (final variant in values) {
      if (variant.name == name) return variant;
    }
    return defaultVariant;
  }
}
