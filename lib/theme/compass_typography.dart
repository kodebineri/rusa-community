import 'package:flutter/painting.dart';
import 'compass_colors.dart';

/// Explicit Typography definitions matching the CSS font rules:
/// - Primary sans-serif: Inter
/// - Titles / wordmark: Outfit
/// - Code/Monospace: JetBrains Mono
/// All three families are bundled (see `flutter: fonts:` in `pubspec.yaml`) so
/// the same faces render on Windows, Android and iOS.
/// Adheres strictly to UI constraint #3: NO generic Flutter Theme presets.
class CompassTypography {
  static const String fontSans = 'Inter';
  static const String fontMono = 'JetBrains Mono';
  static const String fontTitle = 'Outfit';

  // --- Sans Serif Text Styles ---

  static TextStyle title({Color color = CompassColors.darkTextPrimary}) =>
      TextStyle(
        fontFamily: fontTitle,
        fontSize: 14.0,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: -0.2,
      );

  static TextStyle header({Color color = CompassColors.darkTextPrimary}) =>
      TextStyle(
        fontFamily: fontSans,
        fontSize: 13.0,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: -0.1,
      );

  static TextStyle bodyMedium({Color color = CompassColors.darkTextPrimary}) =>
      TextStyle(
        fontFamily: fontSans,
        fontSize: 12.0,
        fontWeight: FontWeight.w500,
        color: color,
        letterSpacing: 0.0,
      );

  static TextStyle bodyRegular(
          {Color color = CompassColors.darkTextSecondary}) =>
      TextStyle(
        fontFamily: fontSans,
        fontSize: 12.0,
        fontWeight: FontWeight.w400,
        color: color,
        letterSpacing: 0.0,
      );

  static TextStyle caption({Color color = CompassColors.darkTextMuted}) =>
      TextStyle(
        fontFamily: fontSans,
        fontSize: 11.0,
        fontWeight: FontWeight.w400,
        color: color,
        letterSpacing: 0.0,
      );

  static TextStyle badge({Color color = CompassColors.greenAccent}) =>
      TextStyle(
        fontFamily: fontSans,
        fontSize: 10.0,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: 0.2,
      );

  // --- Monospace / Code Text Styles ---

  static TextStyle monoBold(
          {Color color = CompassColors.darkTextPrimary, double size = 12.0}) =>
      TextStyle(
        fontFamily: fontMono,
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: color,
        letterSpacing: -0.2,
      );

  static TextStyle monoMedium(
          {Color color = CompassColors.darkTextPrimary, double size = 12.0}) =>
      TextStyle(
        fontFamily: fontMono,
        fontSize: size,
        fontWeight: FontWeight.w500,
        color: color,
        letterSpacing: 0.0,
      );

  static TextStyle monoRegular(
          {Color color = CompassColors.darkTextSecondary,
          double size = 12.0}) =>
      TextStyle(
        fontFamily: fontMono,
        fontSize: size,
        fontWeight: FontWeight.w400,
        color: color,
        letterSpacing: 0.0,
      );

  static TextStyle monoSmall({Color color = CompassColors.darkTextMuted}) =>
      TextStyle(
        fontFamily: fontMono,
        fontSize: 11.0,
        fontWeight: FontWeight.w400,
        color: color,
        letterSpacing: 0.0,
      );

  static TextStyle queryInput({Color color = CompassColors.darkTextPrimary}) =>
      TextStyle(
        fontFamily: fontMono,
        fontSize: 12.0,
        fontWeight: FontWeight.w400,
        color: color,
        letterSpacing: 0.0,
      );

  static TextStyle terminal({Color color = const Color(0xFFA0AEC0)}) =>
      TextStyle(
        fontFamily: fontMono,
        fontSize: 12.0,
        fontWeight: FontWeight.w400,
        color: color,
        height: 1.5,
        letterSpacing: 0.0,
      );
}
