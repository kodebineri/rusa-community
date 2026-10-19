import 'package:flutter/widgets.dart';
import '../../theme/compass_colors.dart';
import '../../theme/compass_theme.dart';
import '../../theme/compass_typography.dart';
import '../../icons/compass_svg_icons.dart';
import '../../models/mongo_models.dart';

/// Converted from src/components/DocumentTableView.tsx
/// Adheres strictly to:
/// 1. Layout & Flexbox (SingleChildScrollView horizontal & vertical, precise row/column heights and padding)
/// 2. Color & Styling (exact CompassColors, table border lines, cell paddings)
/// 3. Typography (CompassTypography with JetBrains Mono)
/// 4. Platform Agnosticism (desktop data table view)
/// 5. Icons (CompassSvg instead of generic Icon)
class DocumentTableView extends StatefulWidget {
  final List<MongoDocument> documents;
  final Function(MongoDocument doc) onEditDocument;
  final Function(String docId, MongoDocument? doc) onDeleteDocument;

  const DocumentTableView({
    super.key,
    required this.documents,
    required this.onEditDocument,
    required this.onDeleteDocument,
  });

  @override
  State<DocumentTableView> createState() => _DocumentTableViewState();
}

class _DocumentTableViewState extends State<DocumentTableView> {
  String? _sortCol;
  bool _sortAsc = true;

  CompassTheme get _theme => CompassTheme.of(context);

  @override
  Widget build(BuildContext context) {
    if (widget.documents.isEmpty) {
      return Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 48.0),
        child: Text(
          'No documents match the current query',
          style: CompassTypography.caption(color: _theme.textMuted),
        ),
      );
    }

    // Extract unique keys
    final keysSet = <String>{};
    keysSet.add('_id');
    for (final doc in widget.documents) {
      keysSet.addAll(doc.data.keys);
    }
    final allKeys = keysSet.toList()
      ..sort((a, b) {
        if (a == '_id') return -1;
        if (b == '_id') return 1;
        return a.compareTo(b);
      });

    // Sorted documents
    final docs = List<MongoDocument>.from(widget.documents);
    if (_sortCol != null) {
      docs.sort((a, b) {
        final v1 = a[_sortCol!];
        final v2 = b[_sortCol!];
        if (v1 == v2) return 0;
        if (v1 == null) return 1;
        if (v2 == null) return -1;
        final res = v1.toString().compareTo(v2.toString());
        return _sortAsc ? res : -res;
      });
    }

    return Container(
      decoration: BoxDecoration(
        color: _theme.bgPanel,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: _theme.border, width: 1.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 4.0,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Table Header Row
            Container(
              height: 38.0,
              decoration: BoxDecoration(
                color: _theme.bgSubtle,
                border: Border(
                  bottom: BorderSide(color: _theme.border, width: 1.0),
                ),
              ),
              child: Row(
                children: [
                  // # column header
                  Container(
                    width: 48.0,
                    alignment: Alignment.center,
                    child: Text(
                      '#',
                      style: CompassTypography.monoBold(color: _theme.textMuted, size: 11.0),
                    ),
                  ),
                  for (final key in allKeys)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          if (_sortCol == key) {
                            _sortAsc = !_sortAsc;
                          } else {
                            _sortCol = key;
                            _sortAsc = true;
                          }
                        });
                      },
                      child: Container(
                        width: key == '_id' ? 220.0 : 160.0,
                        padding: const EdgeInsets.symmetric(horizontal: 12.0),
                        child: Row(
                          children: [
                            Text(
                              key,
                              style: key == '_id'
                                  ? CompassTypography.monoBold(color: _theme.accent, size: 11.0)
                                  : CompassTypography.monoBold(color: _theme.textPrimary, size: 11.0),
                            ),
                            const SizedBox(width: 4.0),
                            CompassSvg(
                              svgString: CompassSvgIcons.arrowUpDown,
                              size: 11.0,
                              color: _theme.textMuted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Actions header
                  Container(
                    width: 100.0,
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    alignment: Alignment.centerRight,
                    child: Text(
                      'ACTIONS',
                      style: CompassTypography.monoBold(color: _theme.textMuted, size: 10.0),
                    ),
                  ),
                ],
              ),
            ),

            // Table Rows
            for (int i = 0; i < docs.length; i++)
              _buildTableRow(docs[i], i, allKeys),
          ],
        ),
      ),
    );
  }

  Widget _buildTableRow(MongoDocument doc, int index, List<String> allKeys) {
    return Container(
      height: 36.0,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _theme.border, width: 1.0),
        ),
      ),
      child: Row(
        children: [
          // Index cell
          Container(
            width: 48.0,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: _theme.border, width: 1.0),
              ),
            ),
            child: Text(
              '${index + 1}',
              style: CompassTypography.monoSmall(color: _theme.textMuted),
            ),
          ),

          // Values cells
          for (final key in allKeys)
            Container(
              width: key == '_id' ? 220.0 : 160.0,
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              alignment: Alignment.centerLeft,
              child: _renderCellValue(key, doc[key]),
            ),

          // Actions cell
          Container(
            width: 100.0,
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            alignment: Alignment.centerRight,
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: _theme.border, width: 1.0),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () => widget.onEditDocument(doc),
                  child: Container(
                    padding: const EdgeInsets.all(4.0),
                    child: const CompassSvg(
                      svgString: CompassSvgIcons.pencil,
                      size: 13.0,
                      color: CompassColors.warningAmber,
                    ),
                  ),
                ),
                const SizedBox(width: 4.0),
                GestureDetector(
                  onTap: () => widget.onDeleteDocument(doc.id, doc),
                  child: Container(
                    padding: const EdgeInsets.all(4.0),
                    child: const CompassSvg(
                      svgString: CompassSvgIcons.trash,
                      size: 13.0,
                      color: CompassColors.errorRed,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _renderCellValue(String key, dynamic val) {
    if (key == '_id') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
        decoration: BoxDecoration(
          color: _theme.greenBadgeBg,
          borderRadius: BorderRadius.circular(4.0),
          border: Border.all(color: _theme.greenBadgeBorder, width: 1.0),
        ),
        child: Text(
          '$val',
          style: CompassTypography.monoBold(color: _theme.accent, size: 11.0),
          overflow: TextOverflow.ellipsis,
        ),
      );
    }
    if (val == null) {
      return Text('null', style: CompassTypography.monoSmall(color: _theme.bsonNull));
    }
    if (val is bool) {
      return Text(
        val.toString(),
        style: CompassTypography.monoMedium(
          color: val ? _theme.accent : CompassColors.errorRed,
          size: 11.0,
        ),
      );
    }
    if (val is num) {
      return Text(
        val.toString(),
        style: CompassTypography.monoMedium(color: _theme.bsonNumber, size: 11.0),
      );
    }
    if (val is List) {
      return Text(
        '[${val.length} items]',
        style: CompassTypography.monoSmall(color: _theme.textMuted),
      );
    }
    if (val is Map) {
      return Text(
        '{ ... }',
        style: CompassTypography.monoSmall(color: _theme.textMuted),
      );
    }
    return Text(
      val.toString(),
      style: CompassTypography.bodyRegular(color: _theme.textSecondary),
      overflow: TextOverflow.ellipsis,
    );
  }
}
