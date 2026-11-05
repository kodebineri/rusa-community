import 'dart:convert';
import 'package:flutter/widgets.dart';
import '../../theme/compass_colors.dart';
import '../../theme/compass_density.dart';
import '../../theme/compass_theme.dart';
import '../../theme/compass_typography.dart';
import '../../icons/compass_svg_icons.dart';
import '../../models/mongo_models.dart';
import '../../utils/json_syntax_text_controller.dart';
import '../compass_icon_button.dart';
import '../modals/compass_modal.dart';

/// Converted from src/components/DocumentJsonView.tsx
/// Adheres strictly to:
/// 1. Layout & Flexbox (Column, Row, card with header and code body)
/// 2. Color & Styling (CompassColors, rounded 8px, borders)
/// 3. Typography (CompassTypography with JetBrains Mono)
/// 4. Platform Agnosticism (desktop styled code cards)
/// 5. Icons (CompassSvg instead of generic Icon)
///
/// The pencil action toggles an inline JSON editor: while editing, the card
/// body becomes a multi-line [CompassInput] and the header swaps the pencil for
/// **Save** (check) / **Cancel** (close). Saving parses the text and calls
/// [onUpdateDocument] with the edited document (the `_id` is always forced back
/// to the original, so the editor cannot rewrite it). Because a plain-map
/// update is a full replacement in the engine, **a field removed from the JSON
/// is removed persistently**.
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
  static const JsonEncoder _jsonEncoder = JsonEncoder.withIndent('  ');

  String? _editingId;

  /// Reused across edits so it is never disposed while an [EditableText] still
  /// references it (only disposed in [dispose]). It is a
  /// [JsonSyntaxTextController] so the inline editor is syntax-coloured exactly
  /// like the read-only body and the query bar's JSON fields.
  late final JsonSyntaxTextController _editController =
      JsonSyntaxTextController(theme: _theme);

  String? _editError;

  CompassTheme get _theme => CompassTheme.of(context);

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DocumentJsonView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the document being edited is no longer in the list (filter change,
    // delete, db/coll switch), drop the edit state without rebuilding again.
    if (_editingId != null &&
        !widget.documents.any((d) => d.id == _editingId)) {
      _editingId = null;
      _editError = null;
    }
  }

  void _startEditing(MongoDocument doc) {
    _editController.text = _jsonEncoder.convert(doc.data);
    setState(() {
      _editingId = doc.id;
      _editError = null;
    });
  }

  void _stopEditing() {
    setState(() {
      _editingId = null;
      _editError = null;
    });
  }

  void _saveEditing(MongoDocument doc) {
    Object? decoded;
    try {
      decoded = jsonDecode(_editController.text);
    } catch (_) {
      decoded = null;
    }

    if (decoded is! Map) {
      setState(() => _editError =
          'Invalid JSON. The document must be a single JSON object.');
      return;
    }

    final updated = Map<String, dynamic>.from(decoded);
    // The editor must never change the identity of the document.
    updated['_id'] = doc.id;
    widget.onUpdateDocument(doc.id, updated);
    _stopEditing();
  }

  @override
  Widget build(BuildContext context) {
    final density = CompassDensity.of(context);
    // Keep the inline editor's syntax colours in sync with the active theme.
    _editController.theme = _theme;
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
    final formattedJson = _jsonEncoder.convert(doc.data);

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
                    if (isEditing) ...[
                      CompassIconButton(
                        svgString: CompassSvgIcons.check,
                        onTap: () => _saveEditing(doc),
                        size: 13.0,
                        padding: 4.0,
                        color: _theme.accent,
                        semanticLabel: 'Save changes',
                      ),
                      const SizedBox(width: 6.0),
                      CompassIconButton(
                        svgString: CompassSvgIcons.close,
                        onTap: _stopEditing,
                        size: 13.0,
                        padding: 4.0,
                        color: _theme.textMuted,
                        semanticLabel: 'Cancel editing',
                      ),
                    ] else
                      CompassIconButton(
                        svgString: CompassSvgIcons.pencil,
                        onTap: () => _startEditing(doc),
                        size: 13.0,
                        padding: 4.0,
                        color: CompassColors.warningAmber,
                        semanticLabel: 'Edit document',
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

          // JSON Content Body (read-only text, or the inline editor)
          Container(
            padding: const EdgeInsets.all(12.0),
            color: _theme.bgInput,
            child: isEditing
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CompassInput(
                        controller: _editController,
                        maxLines: 24,
                        minLines: 8,
                        autofocus: true,
                        autoIndent: true,
                      ),
                      if (_editError != null) ...[
                        const SizedBox(height: 8.0),
                        CompassErrorBanner(message: _editError!),
                      ],
                    ],
                  )
                : Text.rich(
                    buildJsonSyntaxSpan(
                      formattedJson,
                      style: CompassTypography.monoRegular(
                        color: _theme.textSecondary,
                        size: 12.0,
                      ),
                      theme: _theme,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
