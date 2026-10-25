import 'package:flutter/widgets.dart';
import '../../theme/compass_colors.dart';
import '../../theme/compass_theme.dart';
import '../../theme/compass_typography.dart';
import '../../icons/compass_svg_icons.dart';
import '../../models/mongo_models.dart';
import '../../theme/compass_density.dart';
import '../compass_icon_button.dart';

/// Converted from src/components/DocumentTreeView.tsx
/// Adheres strictly to:
/// 1. Layout & Flexbox (Column, Row, Wrap, recursive indentation)
/// 2. Color & Styling (exact BSON type colors, borders, badges)
/// 3. Typography (CompassTypography with JetBrains Mono)
/// 4. Platform Agnosticism (desktop style document cards)
/// 5. Icons (CompassSvg instead of generic Icon)
class DocumentTreeView extends StatelessWidget {
  final List<MongoDocument> documents;
  final Function(MongoDocument doc) onEditDocument;
  final Function(MongoDocument doc) onCloneDocument;
  final Function(String docId, MongoDocument? doc) onDeleteDocument;

  const DocumentTreeView({
    super.key,
    required this.documents,
    required this.onEditDocument,
    required this.onCloneDocument,
    required this.onDeleteDocument,
  });

  @override
  Widget build(BuildContext context) {
    final theme = CompassTheme.of(context);
    final density = CompassDensity.of(context);
    if (documents.isEmpty) {
      return Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 48.0),
        child: Text(
          'No documents match the current query',
          style: CompassTypography.caption(color: theme.textMuted),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(density.isTouch ? 12.0 : 16.0),
      itemCount: documents.length,
      itemBuilder: (context, i) => _buildDocumentCard(context, documents[i], i, theme),
    );
  }

  Widget _buildDocumentCard(BuildContext context, MongoDocument doc, int index, CompassTheme theme) {
    final density = CompassDensity.of(context);
    return Container(
      margin: EdgeInsets.only(bottom: density.isTouch ? 10.0 : 12.0),
      decoration: BoxDecoration(
        color: theme.bgPanel,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: theme.border, width: 1.0),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 4.0,
            offset: Offset(0, 1),
          ),
        ],
      ),
      padding: EdgeInsets.all(density.isTouch ? 10.0 : 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Document Card Header
          Container(
            padding: const EdgeInsets.only(bottom: 8.0),
            margin: const EdgeInsets.only(bottom: 8.0),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: theme.border, width: 1.0),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // The id badge ellipsizes instead of pushing the action
                // buttons off the card.
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        '#${index + 1}',
                        style: CompassTypography.monoSmall(color: theme.textMuted),
                      ),
                      const SizedBox(width: 8.0),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                          decoration: BoxDecoration(
                            color: theme.greenBadgeBg,
                            borderRadius: BorderRadius.circular(4.0),
                            border: Border.all(color: theme.greenBadgeBorder, width: 1.0),
                          ),
                          child: Text(
                            'ObjectId("${doc.id}")',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: CompassTypography.monoBold(color: theme.accent, size: 11.0),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Actions Strip
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CompassIconButton(
                      svgString: CompassSvgIcons.copy,
                      onTap: () => onCloneDocument(doc),
                      size: 13.0,
                      padding: 4.0,
                      color: theme.textMuted,
                      semanticLabel: 'Clone document',
                    ),
                    const SizedBox(width: 4.0),
                    CompassIconButton(
                      svgString: CompassSvgIcons.pencil,
                      onTap: () => onEditDocument(doc),
                      size: 13.0,
                      padding: 4.0,
                      color: CompassColors.warningAmber,
                      semanticLabel: 'Edit document',
                    ),
                    const SizedBox(width: 4.0),
                    CompassIconButton(
                      svgString: CompassSvgIcons.trash,
                      onTap: () => onDeleteDocument(doc.id, doc),
                      size: 13.0,
                      padding: 4.0,
                      color: CompassColors.errorRed,
                      semanticLabel: 'Delete document',
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Tree Node Structure
          for (final entry in doc.data.entries)
            _TreeNodeWidget(
              propKey: entry.key,
              value: entry.value,
            ),
        ],
      ),
    );
  }
}

class _TreeNodeWidget extends StatefulWidget {
  final String propKey;
  final dynamic value;

  const _TreeNodeWidget({
    required this.propKey,
    required this.value,
  });

  @override
  State<_TreeNodeWidget> createState() => _TreeNodeWidgetState();
}

class _TreeNodeWidgetState extends State<_TreeNodeWidget> {
  late bool _isExpanded;

  CompassTheme get _theme => CompassTheme.of(context);

  @override
  void initState() {
    super.initState();
    // Documents open with every Object/Array node collapsed (at all depths),
    // so the tree shows `{ ... }` / `[ ... n items ]` until the user expands
    // it. (The React reference expanded `depth < 2`; collapsed-by-default is a
    // deliberate deviation.)
    _isExpanded = false;
  }

  String _detectType(dynamic val) {
    if (val == null) return 'null';
    if (val is bool) return 'Boolean';
    if (val is int || val is double) return 'number';
    if (val is String) {
      if (val.length == 24 && RegExp(r'^[a-fA-F0-9]{24}$').hasMatch(val)) {
        return 'ObjectId';
      }
      // Detect ISO 8601 date strings
      if (RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:?\d{2})?$').hasMatch(val)) {
        return 'Date';
      }
      return 'String';
    }
    if (val is List) return 'Array';
    if (val is Map) return 'Object';
    if (val is DateTime) return 'Date';
    return 'unknown';
  }

  Color _getTypeColor(String type, CompassTheme theme) {
    switch (type) {
      case 'ObjectId':
        return theme.accent;
      case 'String':
        return theme.bsonString;
      case 'number':
        return theme.bsonNumber;
      case 'Boolean':
        return theme.bsonBoolean;
      case 'Date':
        return theme.bsonDate;
      case 'null':
        return theme.bsonNull;
      default:
        return theme.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = _detectType(widget.value);
    final isExpandable = (type == 'Object' || type == 'Array') && widget.value != null;
    final density = CompassDensity.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Row(
            // On touch the expand chevron becomes a finger-sized button, so
            // the row centres its children instead of top-aligning them.
            crossAxisAlignment: density.isTouch
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              if (isExpandable)
                CompassIconButton(
                  svgString: _isExpanded
                      ? CompassSvgIcons.chevronDown
                      : CompassSvgIcons.chevronRight,
                  onTap: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                  size: 11.0,
                  padding: 0.0,
                  color: _theme.textMuted,
                  semanticLabel: _isExpanded ? 'Collapse value' : 'Expand value',
                )
              else
                // Keeps non-expandable values aligned with the ones that have
                // a chevron in front of them.
                SizedBox(width: density.minTapTarget),

              // On a phone the key, the type and the value share the width of
              // the row, so the longer ones ellipsize instead of overflowing.
              if (density.isTouch) ...[
                Flexible(
                  flex: 3,
                  child: Text(
                    '${widget.propKey}:',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: CompassTypography.monoBold(color: _theme.textPrimary, size: 12.0),
                  ),
                ),
                const SizedBox(width: 6.0),
                Flexible(
                  flex: 2,
                  child: Text(
                    type == 'Array'
                        ? 'Array (${(widget.value as List).length})'
                        : type,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: CompassTypography.caption(color: _theme.textMuted),
                  ),
                ),
                const SizedBox(width: 6.0),
                if (!isExpandable)
                  Expanded(
                    flex: 5,
                    child: Text(
                      type == 'String' ? '"${widget.value}"' : '${widget.value}',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: CompassTypography.monoRegular(
                        color: _getTypeColor(type, _theme),
                        size: 12.0,
                      ),
                    ),
                  )
                else if (!_isExpanded)
                  Flexible(
                    child: Text(
                      type == 'Array'
                          ? '[ ... ${(widget.value as List).length} items ]'
                          : '{ ... }',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: CompassTypography.monoRegular(
                        color: _theme.textMuted,
                        size: 12.0,
                      ),
                    ),
                  ),
              ] else ...[
                Text(
                  '${widget.propKey}:',
                  style: CompassTypography.monoBold(color: _theme.textPrimary, size: 12.0),
                ),
                const SizedBox(width: 6.0),
                Text(
                  type == 'Array'
                      ? 'Array (${(widget.value as List).length})'
                      : type,
                  style: CompassTypography.caption(color: _theme.textMuted),
                ),
                const SizedBox(width: 6.0),

                if (!isExpandable)
                  Expanded(
                    child: Text(
                      type == 'String' ? '"${widget.value}"' : type == 'Date' ? 'ISODate("${widget.value}")' : '${widget.value}',
                      style: CompassTypography.monoRegular(
                        color: _getTypeColor(type, _theme),
                        size: 12.0,
                      ),
                    ),
                  )
                else if (!_isExpanded)
                  Text(
                    type == 'Array'
                        ? '[ ... ${(widget.value as List).length} items ]'
                        : '{ ... }',
                    style: CompassTypography.monoRegular(
                      color: _theme.textMuted,
                      size: 12.0,
                    ),
                  ),
              ],
            ],
          ),
        ),

        // Recursive Children
        if (isExpandable && _isExpanded)
          Container(
            margin: const EdgeInsets.only(left: 14.0),
            padding: const EdgeInsets.only(left: 8.0),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: _theme.border, width: 1.0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (type == 'Array')
                  for (int i = 0; i < (widget.value as List).length; i++)
                    _TreeNodeWidget(
                      propKey: '$i',
                      value: (widget.value as List)[i],
                    )
                else if (type == 'Object')
                  for (final entry in (widget.value as Map).entries)
                    _TreeNodeWidget(
                      propKey: entry.key.toString(),
                      value: entry.value,
                    ),
              ],
            ),
          ),
      ],
    );
  }
}
