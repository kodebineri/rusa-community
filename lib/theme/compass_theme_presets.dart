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
/// Four dark and four light variants. [rainForestNight] is the default (see
/// [defaultVariant]); the rest are grouped by [isDark] in the options menu.
enum CompassThemeVariant {
  rainForestNight(
    label: 'Rain Forest Night',
    isDark: true,
    palette: CompassPalette(
      bgApp: Color(0xFF121417), // Neutral Dark Charcoal Base
      bgSidebar: Color(0xFF16191D), // Neutral Sidebar Surface
      bgPanel: Color(0xFF1E2228), // Clean Neutral Card Surface
      bgSubtle: Color(0xFF262B33), // Neutral Inner Container / Input Surface
      bgHover: Color(0xFF2F353E), // Crisp Neutral Hover State
      bgInput: Color(0xFF16191D), // Slate Input Surface
      border: Color(0xFF2A2E37), // Subtle Neutral Border
      borderHover: Color(0xFF10B981), // Subtle Emerald Focus Outline
      textPrimary: Color(0xFFE2E8F0), // Soft High-Contrast Slate White
      textSecondary: Color(0xFF94A3B8), // Clean Neutral Slate Secondary Text
      textMuted: Color(0xFF64748B), // Soft Muted Grey Text
      accent: Color(0xFF10B981), // Emerald Accent (Used selectively)
      accentHover: Color(0xFF059669), // Deep Emerald Hover
      onAccent: Color(0xFF0F172A), // Dark Text on Accent
      greenBadgeBg: Color(0x1F10B981), // Soft Emerald Badge Tint
      greenBadgeBorder: Color(0x4010B981), // Soft Emerald Badge Border
      // BSON Syntax Highlighting (Eye-Friendly Multi-Color Spectrum)
      bsonObjectId: Color(0xFF2DD4BF), // Soft Cyan / Mint Teal
      bsonString:
          Color(0xFFE2E8F0), // Crisp Off-White (High legibility for text data)
      bsonNumber: Color(0xFF38BDF8), // Soft Sky Blue
      bsonBoolean: Color(0xFFFBBF24), // Warm Amber Gold
      bsonDate: Color(0xFFF472B6), // Muted Rose Pink
      bsonNull: Color(0xFFF87171),
    ),
  ),
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
      bgApp:
          Color(0xFF0B0E14), // Deep Obsidian Slate Base (Eliminates blue glare)
      bgSidebar: Color(0xFF11151C), // Recessed Dark Slate Sidebar
      bgPanel: Color(0xFF161B22), // Dark Slate Surface Panel
      bgSubtle: Color(0xFF1F2631), // Soft Slate Surface (Containers / Inputs)
      bgHover: Color(0xFF283241), // Low-Fatigue Hover Highlight
      bgInput: Color(0xFF11151C), // Deep Input Surface
      border: Color(0xFF273140), // Muted Border Outline
      borderHover: Color(0xFF82AAFF), // Periwinkle Focus Outline
      textPrimary: Color(0xFFD6DEEB), // Crisp Night Owl Alabaster
      textSecondary: Color(0xFF94A3B8), // Neutral Slate Secondary Text
      textMuted: Color(0xFF637777), // Original Night Owl Muted Teal-Grey
      accent: Color(0xFF82AAFF), // Signature Periwinkle Accent
      accentHover: Color(0xFF6A97F5), // Deep Periwinkle Hover
      onAccent: Color(0xFF0B0E14), // Dark Text on Periwinkle Buttons
      greenBadgeBg: Color(0x2682AAFF), // Periwinkle Badge Tint
      greenBadgeBorder: Color(0x4D82AAFF), // Periwinkle Badge Outline
      // Authentic Night Owl BSON Syntax Highlighting
      bsonObjectId: Color(0xFF7FDBCA), // Soft Mint Teal
      bsonString: Color(0xFFC5E478), // Warm Lime Green
      bsonNumber: Color(0xFFF78C6C), // Soft Coral Peach
      bsonBoolean: Color(0xFF82AAFF), // Periwinkle Blue
      bsonDate: Color(0xFFC792EA), // Soft Lavender
      bsonNull: Color(0xFFEF5350), // Soft Red
    ),
  ),
  sunnyRainForest(
    label: 'Sunny Rain Forest',
    isDark: false,
    palette: CompassPalette(
      bgApp: Color(0xFFF4F7F5), // Crisp Stone White
      bgSidebar: Color(0xFFEAFFF4), // Cool Soft Tinted Sidebar
      bgPanel: Color(0xFFFFFFFF), // Clean White Panel
      bgSubtle: Color(0xFFE2EBE5), // Soft Sage Divider Surface
      bgHover: Color(0xFFD4E3DA), // Hover Tint
      bgInput: Color(0xFFFFFFFF), // White Input Canvas
      border: Color(0xFFCBDCD1), // Light Sage Border
      borderHover: Color(0xFF059669), // Focused Forest Border
      textPrimary: Color(0xFF112219), // High-Contrast Deep Charcoal/Green
      textSecondary: Color(0xFF3D5B4C), // Deep Sage Secondary Text
      textMuted: Color(0xFF6B8A7A), // Neutral Muted Green
      accent: Color(0xFF047857), // Deep Alpine Green
      accentHover: Color(0xFF065F46), // Forest Canopy Green
      onAccent: Color(0xFFFFFFFF), // White Text on Green Button
      greenBadgeBg: Color(0x20047857), // Tinted Alpine Badge
      greenBadgeBorder: Color(0x40047857), // Soft Alpine Outline
      // BSON Data Types syntax highlighting (Optimized for light background)
      bsonObjectId: Color(0xFF047857), // Rich Alpine Green
      bsonString: Color(0xFF15803D), // Lush Leaf Green
      bsonNumber: Color(0xFF0284C7), // Deep Ocean Blue
      bsonBoolean: Color(0xFFD97706), // Burnt Amber
      bsonDate: Color(0xFFC026D3), // Vivid Plum
      bsonNull: Color(0xFFDC2626),
    ),
  ),
  monokaiLight(
    label: 'Monokai Light',
    isDark: false,
    palette: CompassPalette(
      bgApp:
          Color(0xFFFAFAFA), // Crisp Neutral Surface (Eliminates yellow glare)
      bgSidebar: Color(0xFFF1F3F5), // Cool Soft Grey Sidebar
      bgPanel: Color(0xFFFFFFFF), // Clean White Container Cards
      bgSubtle: Color(0xFFE9ECEF), // Soft Grey Divider Surface / Containers
      bgHover: Color(0xFFDEE2E6), // Crisp Soft Hover Highlight
      bgInput: Color(0xFFFFFFFF), // Pure White Input Canvas
      border: Color(0xFFCED4DA), // Clean Slate Border Line
      borderHover: Color(0xFFD33682), // Monokai Berry Focus Line
      textPrimary: Color(0xFF212529), // Deep Charcoal for Crisp Legibility
      textSecondary: Color(0xFF495057), // Neutral Slate Secondary Text
      textMuted: Color(0xFF6C757D), // Muted Grey Label Text
      accent: Color(0xFFD33682), // Elegant Monokai Rose Accent
      accentHover: Color(0xFFB52A6F), // Richer Rose Hover
      onAccent: Color(0xFFFFFFFF), // Clean White Text on Accent Buttons
      greenBadgeBg: Color(0x1AD33682), // Subtle Rose Badge Tint
      greenBadgeBorder: Color(0x38D33682), // Soft Rose Badge Outline
      // Authentic Monokai BSON Syntax Highlighting (High contrast on light BG)
      bsonObjectId: Color(0xFFD33682), // Monokai Rose Pink
      bsonString: Color(0xFF2E7D32), // Deep Leaf Green
      bsonNumber: Color(0xFFE65100), // Warm Burnt Orange
      bsonBoolean: Color(0xFF6A1B9A), // Deep Purple
      bsonDate: Color(0xFFC2185B), // Rich Berry Red
      bsonNull: Color(0xFFC62828), // Vivid Red
    ),
  ),
  tokyoNightLight(
    label: 'Tokyo Night Light',
    isDark: false,
    palette: CompassPalette(
      bgApp:
          Color(0xFFF2F4F8), // Light Cool Canvas (Eliminates muddy grey tint)
      bgSidebar: Color(0xFFE6E9F0), // Soft Subdued Cool Sidebar
      bgPanel: Color(0xFFFFFFFF), // Crisp Pure White Cards
      bgSubtle: Color(0xFFE2E6F0), // Clean Divider Surface / Code Field
      bgHover: Color(0xFFD7DCE8), // Soft Cool Blue-Grey Hover State
      bgInput: Color(0xFFFFFFFF), // White Input Surface
      border: Color(0xFFD5DAE7), // Subtle Slate-Indigo Outline
      borderHover: Color(0xFF3478E3), // Indigo Focus Border Outline
      textPrimary: Color(0xFF1F2335), // Deep Ink Navy (Maximum readability)
      textSecondary: Color(0xFF4C5270), // Crisp Indigo-Slate Secondary Text
      textMuted: Color(0xFF787F9E), // Subdued Label Text
      accent: Color(0xFF3478E3), // Tokyo Night Electric Indigo/Blue Accent
      accentHover: Color(0xFF2761BE), // Rich Indigo Hover
      onAccent: Color(0xFFFFFFFF), // White Text on Accent Buttons
      greenBadgeBg: Color(0x1F3478E3), // Soft Indigo Badge Tint
      greenBadgeBorder: Color(0x383478E3), // Soft Indigo Badge Border
      // BSON Syntax Highlighting (Sharper Contrast on Light Canvas)
      bsonObjectId: Color(0xFF3478E3), // Tokyo Electric Blue
      bsonString: Color(
          0xFF38663D), // Deep Forest Green (High contrast value readability)
      bsonNumber: Color(0xFF965B00), // Rich Amber Orange
      bsonBoolean: Color(0xFF7038D0), // Vivid Royal Violet
      bsonDate: Color(0xFF8C4EC4), // Soft Amethyst
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
  static const CompassThemeVariant defaultVariant =
      CompassThemeVariant.rainForestNight;

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
