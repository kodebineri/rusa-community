import 'package:flutter/services.dart';

/// Auto-indents JSON (and JSON-like) text as the user types.
///
/// Pressing Enter keeps the current line's indentation, adds one level when the
/// cursor sits right after an opening `{` / `[`, and — when the matching closing
/// bracket is already on the next line — inserts the closing line at the parent
/// indentation with the cursor on the indented blank line:
///
/// ```text
/// {|        ->      {
///                     |
///                   }
/// ```
///
/// Only a single typed newline is rewritten; pastes and multi-character edits
/// are left untouched.
class JsonAutoIndentFormatter extends TextInputFormatter {
  const JsonAutoIndentFormatter();

  static const String _indentUnit = '  ';

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Only react to a single newline typed at a collapsed cursor.
    if (newValue.text.length != oldValue.text.length + 1) return newValue;
    final selection = newValue.selection;
    if (!selection.isCollapsed) return newValue;
    final cursor = selection.baseOffset;
    if (cursor <= 0 || cursor > newValue.text.length) return newValue;
    if (newValue.text[cursor - 1] != '\n') return newValue;

    // Confirm the only change is the inserted newline.
    final withoutNewline = newValue.text.substring(0, cursor - 1) +
        newValue.text.substring(cursor);
    if (withoutNewline != oldValue.text) return newValue;

    final searchStart = cursor - 2;
    final lineStart =
        searchStart < 0 ? 0 : newValue.text.lastIndexOf('\n', searchStart) + 1;
    final currentLine = newValue.text.substring(lineStart, cursor - 1);
    final baseIndent = _leadingWhitespace(currentLine);

    final prevChar = cursor >= 2 ? newValue.text[cursor - 2] : '';
    final nextChar =
        cursor < newValue.text.length ? newValue.text[cursor] : '';

    final opensBlock = prevChar == '{' || prevChar == '[';
    final closesBlock = nextChar == '}' || nextChar == ']';

    if (opensBlock) {
      final innerIndent = baseIndent + _indentUnit;
      if (closesBlock) {
        final text =
            '${newValue.text.substring(0, cursor)}$innerIndent\n$baseIndent'
            '${newValue.text.substring(cursor)}';
        return TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: cursor + innerIndent.length),
        );
      }
      final text = newValue.text.substring(0, cursor) +
          innerIndent +
          newValue.text.substring(cursor);
      return TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: cursor + innerIndent.length),
      );
    }

    // Plain newline: keep the current line's indentation.
    if (baseIndent.isEmpty) return newValue;
    final text = newValue.text.substring(0, cursor) +
        baseIndent +
        newValue.text.substring(cursor);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: cursor + baseIndent.length),
    );
  }

  String _leadingWhitespace(String line) {
    final match = RegExp(r'^[ \t]*').firstMatch(line);
    return match?.group(0) ?? '';
  }
}
