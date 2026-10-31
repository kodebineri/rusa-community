import 'package:flutter/widgets.dart';
import '../theme/compass_theme.dart';
import '../theme/compass_typography.dart';

/// Minimal, dependency-free Markdown renderer.
///
/// The app ships no Markdown package (see `pubspec.yaml`), so long-form legal
/// text — the EULA — is parsed here instead of being dumped into a single
/// [Text] block. The subset is deliberately small and covers what those
/// documents use:
///
/// * `#`, `##`, `###` headings
/// * `-` / `*` / `+` bullet lists
/// * `1.` ordered lists
/// * `---` horizontal rules
/// * `**bold**`, `*italic*` / `_italic_`, and `` `code` `` inline spans
///
/// Anything unrecognised degrades to a paragraph, so the parser never throws.
class CompassMarkdownView extends StatelessWidget {
  final String markdown;

  /// Gap between blocks. Consecutive list rows stay tightly spaced.
  final double blockSpacing;

  const CompassMarkdownView({
    super.key,
    required this.markdown,
    this.blockSpacing = 10.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = CompassTheme.of(context);
    final blocks = _parseBlocks(theme);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < blocks.length; i++)
          Padding(
            padding: EdgeInsets.only(
              bottom: i == blocks.length - 1
                  ? 0.0
                  : (blocks[i].isListItem ? 0.0 : blockSpacing),
            ),
            child: blocks[i].child,
          ),
      ],
    );
  }

  List<_MarkdownBlock> _parseBlocks(CompassTheme theme) {
    final blocks = <_MarkdownBlock>[];
    final lines = markdown.replaceAll('\r\n', '\n').split('\n');

    // Paragraph lines accumulate until a blank line or another block starts.
    final paragraph = <String>[];
    void flushParagraph() {
      if (paragraph.isEmpty) return;
      final text = paragraph.join(' ').trim();
      paragraph.clear();
      if (text.isEmpty) return;
      blocks.add(_MarkdownBlock(
        _inlineText(
          text,
          CompassTypography.bodyRegular(color: theme.textSecondary),
          theme,
        ),
      ));
    }

    for (final rawLine in lines) {
      final trimmed = rawLine.trim();

      if (trimmed.isEmpty) {
        flushParagraph();
        continue;
      }

      // A Markdown hard break (two trailing spaces, or a trailing backslash)
      // ends the current paragraph instead of being joined with the next line.
      final hasHardBreak = rawLine.endsWith('  ') || rawLine.endsWith('\\');

      // Horizontal rule.
      if (RegExp(r'^(-{3,}|\*{3,}|_{3,})$').hasMatch(trimmed)) {
        flushParagraph();
        blocks.add(_MarkdownBlock(
          Container(height: 1.0, color: theme.border),
        ));
        continue;
      }

      // Headings.
      final heading = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(trimmed);
      if (heading != null) {
        flushParagraph();
        final level = heading.group(1)!.length;
        final text = heading.group(2)!.trim();
        final style = switch (level) {
          1 => CompassTypography.title(color: theme.textPrimary),
          2 => CompassTypography.header(color: theme.textPrimary),
          3 => CompassTypography.bodyMedium(color: theme.textPrimary)
              .copyWith(fontWeight: FontWeight.w700),
          _ => CompassTypography.bodyMedium(color: theme.textPrimary),
        };
        blocks.add(_MarkdownBlock(
          Padding(
            padding: EdgeInsets.only(top: level == 1 ? 0.0 : 8.0),
            child: _inlineText(text, style, theme),
          ),
        ));
        continue;
      }

      // Bullet list item.
      final bullet = RegExp(r'^[-*+]\s+(.*)$').firstMatch(trimmed);
      if (bullet != null) {
        flushParagraph();
        blocks.add(_MarkdownBlock(
          _listRow(marker: '\u2022', text: bullet.group(1)!, theme: theme),
          isListItem: true,
        ));
        continue;
      }

      // Ordered list item.
      final ordered = RegExp(r'^(\d+)[.)]\s+(.*)$').firstMatch(trimmed);
      if (ordered != null) {
        flushParagraph();
        blocks.add(_MarkdownBlock(
          _listRow(
            marker: '${ordered.group(1)}.',
            text: ordered.group(2)!,
            theme: theme,
          ),
          isListItem: true,
        ));
        continue;
      }

      paragraph.add(trimmed);
      if (hasHardBreak) flushParagraph();
    }

    flushParagraph();
    return blocks;
  }

  Widget _listRow({
    required String marker,
    required String text,
    required CompassTheme theme,
  }) {
    final style = CompassTypography.bodyRegular(color: theme.textSecondary);
    return Padding(
      padding: const EdgeInsets.only(left: 2.0, bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 18.0,
            child: Text(marker, style: style.copyWith(color: theme.textMuted)),
          ),
          Expanded(child: _inlineText(text, style, theme)),
        ],
      ),
    );
  }

  /// Parses `**bold**`, `*italic*`, `_italic_` and `` `code` `` inside [text].
  Widget _inlineText(String text, TextStyle baseStyle, CompassTheme theme) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(
      r'\*\*(.+?)\*\*|__(.+?)__|\*(.+?)\*|_(.+?)_|`(.+?)`',
      dotAll: true,
    );

    var cursor = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      if (match.group(1) != null || match.group(2) != null) {
        spans.add(TextSpan(
          text: match.group(1) ?? match.group(2),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ));
      } else if (match.group(3) != null || match.group(4) != null) {
        spans.add(TextSpan(
          text: match.group(3) ?? match.group(4),
          style: const TextStyle(fontStyle: FontStyle.italic),
        ));
      } else {
        spans.add(TextSpan(
          text: match.group(5),
          style: CompassTypography.monoRegular(
            color: theme.textPrimary,
            size: 11.0,
          ),
        ));
      }
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return Text.rich(
      TextSpan(style: baseStyle, children: spans),
      textAlign: TextAlign.left,
    );
  }
}

class _MarkdownBlock {
  const _MarkdownBlock(this.child, {this.isListItem = false});

  final Widget child;
  final bool isListItem;
}
