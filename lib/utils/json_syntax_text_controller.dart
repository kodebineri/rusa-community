import 'package:flutter/cupertino.dart';
import 'package:rusa/theme/compass_theme.dart';

/// Builds a syntax-coloured [TextSpan] for a JSON string.
///
/// Shared by [JsonSyntaxTextController] (editable fields such as the query
/// bar's filter/project/sort) and read-only JSON renderers (the documents
/// view's JSON cards), so both use exactly the same colouring rules.
TextSpan buildJsonSyntaxSpan(
  String textValue, {
  TextStyle? style,
  required CompassTheme theme,
}) {
  final List<TextSpan> children = [];

  final keyStyle = style?.copyWith(color: theme.accent);
  final stringStyle = style?.copyWith(color: const Color(0xFF6A9955));
  final numberStyle = style?.copyWith(color: const Color(0xFFB5CEA8));
  final boolNullStyle = style?.copyWith(color: const Color(0xFF569CD6));
  final punctuationStyle = style?.copyWith(color: theme.textMuted);
  final constructorStyle = style?.copyWith(color: theme.bsonObjectId);

  final regex = RegExp(
    r'((?:new\s+)?ObjectId\s*\(\s*"(?:[^"\\]|\\.)*"\s*\)|(?:ISODate|new\s+Date)\s*\(\s*"(?:[^"\\]|\\.)*"\s*\))|("(?:[^"\\]|\\.)*")\s*:|("(?:[^"\\]|\\.)*")|(\b-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?\b)|(\btrue\b|\bfalse\b|\bnull\b)|([{}\[\]:,])',
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
      children.add(TextSpan(text: fullMatch, style: constructorStyle));
    } else if (match.group(2) != null) {
      final keyText = match.group(2)!;
      final colonText = fullMatch.substring(keyText.length);
      children.add(TextSpan(text: keyText, style: keyStyle));
      children.add(TextSpan(text: colonText, style: punctuationStyle));
    } else if (match.group(3) != null) {
      children.add(TextSpan(text: fullMatch, style: stringStyle));
    } else if (match.group(4) != null) {
      children.add(TextSpan(text: fullMatch, style: numberStyle));
    } else if (match.group(5) != null) {
      children.add(TextSpan(text: fullMatch, style: boolNullStyle));
    } else if (match.group(6) != null) {
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
    return buildJsonSyntaxSpan(text, style: style, theme: theme);
  }
}
