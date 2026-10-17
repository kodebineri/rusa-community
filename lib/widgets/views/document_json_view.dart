import 'dart:convert';
import 'package:flutter/widgets.dart';
import '../../theme/compass_colors.dart';
import '../../theme/compass_typography.dart';
import '../../icons/compass_svg_icons.dart';
import '../../models/mongo_models.dart';

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

  @override
  Widget build(BuildContext context) {
    if (widget.documents.isEmpty) {
      return Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 48.0),
        child: Text(
          'No documents match the current query',
          style: CompassTypography.caption(color: CompassColors.darkTextMuted),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < widget.documents.length; i++)
          _buildJsonCard(widget.documents[i], i),
      ],
    );
  }

  Widget _buildJsonCard(MongoDocument doc, int index) {
    final isEditing = _editingId == doc.id;
    const jsonEncoder = JsonEncoder.withIndent('  ');
    final formattedJson = jsonEncoder.convert(doc.data);

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: CompassColors.darkBgPanel,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: CompassColors.darkBorder, width: 1.0),
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
            decoration: const BoxDecoration(
              color: CompassColors.darkBgSubtle,
              border: Border(
                bottom: BorderSide(color: CompassColors.darkBorder, width: 1.0),
              ),
              borderRadius: BorderRadius.only(
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
                      style: CompassTypography.monoSmall(color: CompassColors.darkTextMuted),
                    ),
                    const SizedBox(width: 8.0),
                    Text(
                      '_id: "${doc.id}"',
                      style: CompassTypography.monoBold(color: CompassColors.greenAccent, size: 11.0),
                    ),
                  ],
                ),
                // Action Buttons
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => widget.onCloneDocument(doc),
                      child: Container(
                        padding: const EdgeInsets.all(4.0),
                        child: const CompassSvg(
                          svgString: CompassSvgIcons.copy,
                          size: 13.0,
                          color: CompassColors.darkTextMuted,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6.0),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _editingId = isEditing ? null : doc.id;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4.0),
                        child: CompassSvg(
                          svgString: CompassSvgIcons.pencil,
                          size: 13.0,
                          color: isEditing ? CompassColors.greenAccent : CompassColors.warningAmber,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6.0),
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
              ],
            ),
          ),

          // JSON Content Body
          Container(
            padding: const EdgeInsets.all(12.0),
            color: CompassColors.darkBgInput,
            child: Text(
              formattedJson,
              style: CompassTypography.monoRegular(
                color: CompassColors.darkTextSecondary,
                size: 12.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
