import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rusa/utils/json_auto_indent_formatter.dart';

void main() {
  const f = JsonAutoIndentFormatter();

  TextEditingValue v(String text, int cursor) => TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: cursor),
      );

  test('indents after opening brace', () {
    final old = v('{', 1);
    final neu = v('{\n', 2);
    final out = f.formatEditUpdate(old, neu);
    expect(out.text, '{\n  ');
    expect(out.selection.baseOffset, 4);
  });

  test('expands braces with closing line', () {
    final old = v('{}', 1);
    final neu = v('{\n}', 2);
    final out = f.formatEditUpdate(old, neu);
    expect(out.text, '{\n  \n}');
    expect(out.selection.baseOffset, 4);
  });

  test('keeps current indentation', () {
    final old = v('  "a": 1', 8);
    final neu = v('  "a": 1\n', 9);
    final out = f.formatEditUpdate(old, neu);
    expect(out.text, '  "a": 1\n  ');
    expect(out.selection.baseOffset, 11);
  });

  test('leaves paste alone', () {
    final old = v('', 0);
    final neu = v('{\n  "a": 1\n}', 12);
    final out = f.formatEditUpdate(old, neu);
    expect(out, neu);
  });
}
