import 'dart:convert';
import 'package:flutter/widgets.dart';
import '../../theme/compass_colors.dart';
import '../../theme/compass_density.dart';
import '../../theme/compass_theme.dart';
import '../../theme/compass_typography.dart';
import '../../icons/compass_svg_icons.dart';
import '../../models/mongo_models.dart';
import '../compass_icon_button.dart';

/// Converted from src/components/DocumentJsonView.tsx
/// Adheres strictly to:
/// 1. Layout & Flexbox (Column, Row, card with header and code body)
/// 2. Color & Styling (CompassColors, rounded 8px, borders)
/// 3. Typography (CompassTypography with JetBrains Mono)
/// 4. Platform Agnosticism (desktop styled code cards)
/// 5. Icons (CompassSvg instead of generic Icon)
class DocumentJsonView extends StatefulWidget {
  final List<MongoDocument> documents;
  final Function(String docId, Map<String, dynamic> updatedFields) onUpdateDocument;
  final Function(MongoDocument doc) onCloneDocument;
  final Function(String docId, MongoDocument? doc) onDeleteDocument;

  const DocumentJsonView({
    super.key,
    required this.documents,
    required this.onUpdateDocument,
    required this.onCloneDocument,
    required this.onDeleteDocument,
  });

  @override
  State<DocumentJsonView> createState() => _DocumentJsonViewState();
}

class _DocumentJsonViewState extends State<DocumentJsonView> {
  String? _editingId;

  CompassTheme get _theme => CompassTheme.of(context);

  @override
  Widget build(BuildContext context) {
    final density = CompassDensity.of(context);
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

    return ListView.builder(
      padding: EdgeInsets.all(density.isTouch ? 12.0 : 16.0),
      itemCount: widget.documents.length,
      itemBuilder: (context, i) => _buildJsonCard(widget.documents[i], i),
    );
  }

  Widget _buildJsonCard(MongoDocument doc, int index) {
    final density = CompassDensity.of(context);
    final isEditing = _editingId == doc.id;
    const jsonEncoder = JsonEncoder.withIndent('  ');
    final formattedJson = jsonEncoder.convert(doc.data);

    return Container(
      margin: EdgeInsets.only(bottom: density.isTouch ? 10.0 : 12.0),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // JSON Card Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: _theme.bgSubtle,
              border: Border(
                bottom: BorderSide(color: _theme.border, width: 1.0),
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8.0),
                topRight: Radius.circular(8.0),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      '#${index + 1}',
                      style: CompassTypography.monoSmall(color: _theme.textMuted),
                    ),
                    const SizedBox(width: 8.0),
                    Text(
                      '_id: "${doc.id}"',
                      style: CompassTypography.monoBold(color: _theme.accent, size: 11.0),
                    ),
                  ],
                ),
                // Action Buttons
                Row(
                  children: [
                    CompassIconButton(
                      svgString: CompassSvgIcons.copy,
                      onTap: () => widget.onCloneDocument(doc),
                      size: 13.0,
                      padding: 4.0,
                      color: _theme.textMuted,
                      semanticLabel: 'Clone document',
                    ),
                    const SizedBox(width: 6.0),
                    CompassIconButton(
                      svgString: CompassSvgIcons.pencil,
                      onTap: () {
                        setState(() {
                          _editingId = isEditing ? null : doc.id;
                        });
                      },
                      size: 13.0,
                      padding: 4.0,
                      color: isEditing ? _theme.accent : CompassColors.warningAmber,
                      semanticLabel: isEditing ? 'Finish editing' : 'Edit document',
                    ),
                    const SizedBox(width: 6.0),
                    CompassIconButton(
                      svgString: CompassSvgIcons.trash,
                      onTap: () => widget.onDeleteDocument(doc.id, doc),
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

          // JSON Content Body
          Container(
            padding: const EdgeInsets.all(12.0),
            color: _theme.bgInput,
            child: Text(
              formattedJson,
              style: CompassTypography.monoRegular(
                color: _theme.textSecondary,
                size: 12.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
