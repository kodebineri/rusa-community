import 'package:flutter/cupertino.dart';
import 'package:mongodb_compass_flutter/theme/compass_theme.dart';

class JsonSyntaxTextController extends TextEditingController {
  CompassTheme theme;

  JsonSyntaxTextController({
    super.text,
    required this.theme,
  });

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final List<TextSpan> children = [];
    final textValue = text;

    final keyStyle = style?.copyWith(color: theme.accent);
    final stringStyle = style?.copyWith(color: const Color(0xFF6A9955));
    final numberStyle = style?.copyWith(color: const Color(0xFFB5CEA8));
    final boolNullStyle = style?.copyWith(color: const Color(0xFF569CD6));
    final punctuationStyle = style?.copyWith(color: theme.textMuted);

    final regex = RegExp(
      r'("(?:[^"\\]|\\.)*")\s*:|("(?:[^"\\]|\\.)*")|(\b-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?\b)|(\btrue\b|\bfalse\b|\bnull\b)|([{}\[\]:,])',
      multiLine: true,
    );

    int lastMatchEnd = 0;

    for (final Match match in regex.allMatches(textValue)) {
      if (match.start > lastMatchEnd) {
        children.add(TextSpan(
          text: textValue.substring(lastMatchEnd, match.start),
          style: style,
        ));
      }

      final fullMatch = match.group(0)!;

      if (match.group(1) != null) {
        final keyText = match.group(1)!;
        final colonText = fullMatch.substring(keyText.length);
        children.add(TextSpan(text: keyText, style: keyStyle));
        children.add(TextSpan(text: colonText, style: punctuationStyle));
      } else if (match.group(2) != null) {
        children.add(TextSpan(text: fullMatch, style: stringStyle));
      } else if (match.group(3) != null) {
        children.add(TextSpan(text: fullMatch, style: numberStyle));
      } else if (match.group(4) != null) {
        children.add(TextSpan(text: fullMatch, style: boolNullStyle));
      } else if (match.group(5) != null) {
        children.add(TextSpan(text: fullMatch, style: punctuationStyle));
      }

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < textValue.length) {
      children.add(TextSpan(
        text: textValue.substring(lastMatchEnd),
        style: style,
      ));
    }

    return TextSpan(style: style, children: children);
  }
}
