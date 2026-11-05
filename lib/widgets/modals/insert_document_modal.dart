import 'package:flutter/widgets.dart';
import '../../icons/compass_svg_icons.dart';
import '../../models/mongo_models.dart';
import '../../services/mongo_engine.dart';
import '../../theme/compass_theme.dart';
import '../../theme/compass_typography.dart';
import '../../utils/json_syntax_text_controller.dart';
import '../../utils/mongo_json_encoder.dart';
import 'compass_modal.dart';

/// Converted from src/components/InsertDocModal.tsx
///
/// Used for inserting a brand-new document, editing an existing one (when
/// [initialDoc] is supplied), and — when [isClone] is set — reviewing a copy
/// of an existing document before inserting it (the duplicate action).
class InsertDocumentModal extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onClose;

  /// Inserts the (possibly edited) document. Returns `null` on success or a
  /// human-readable error message, which the dialog shows in its error banner.
  final String? Function(Map<String, dynamic> doc) onInsert;

  /// Document the dialog opens pre-filled with: the document being edited, or
  /// the copied document when [isClone] is set.
  final Map<String, dynamic>? initialDoc;

  /// Set by the duplicate/copy action: [initialDoc] is then a copy of an
  /// existing document (given a fresh `_id` by the caller) which is inserted
  /// as a new document instead of updating the original.
  final bool isClone;

  const InsertDocumentModal({
    super.key,
    required this.isOpen,
    required this.onClose,
    required this.onInsert,
    this.initialDoc,
    this.isClone = false,
  });

  @override
  State<InsertDocumentModal> createState() => _InsertDocumentModalState();
}

class _InsertDocumentModalState extends State<InsertDocumentModal> {
  late final JsonSyntaxTextController _controller;
  bool _initializedController = false;
  String? _errorMsg;

  String _defaultText() {
    final initial = widget.initialDoc;
    if (initial != null) {
      return encodeMongoJson(initial);
    }
    return encodeMongoJson({
      '_id': MongoObjectId(mongoEngine.generateObjectId()),
      'title': 'New Entry',
      'createdAt': DateTime.now().toIso8601String(),
      'status': 'active',
      'tags': ['sample'],
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final theme = CompassTheme.of(context);
    if (!_initializedController) {
      _controller = JsonSyntaxTextController(
        text: _defaultText(),
        theme: theme,
      );
      _initializedController = true;
    } else {
      // Keep syntax colours in sync when the app theme changes.
      _controller.theme = theme;
    }
  }

  @override
  void didUpdateWidget(covariant InsertDocumentModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen && !oldWidget.isOpen) {
      _controller.text = _defaultText();
      _errorMsg = null;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    try {
      final parsed = mongoEngine.tolerantParse(_controller.text);
      if (parsed is! Map) {
        setState(() => _errorMsg = 'Document must be a JSON object.');
        return;
      }
      final error = widget.onInsert(Map<String, dynamic>.from(parsed));
      if (error != null) {
        setState(() => _errorMsg = error);
        return;
      }
      widget.onClose();
    } catch (err) {
      setState(() => _errorMsg = 'JSON Parse Error: $err');
    }
  }

  void _generateNewId() {
    try {
      final parsed = mongoEngine.tolerantParse(_controller.text);
      if (parsed is Map) {
        parsed['_id'] = MongoObjectId(mongoEngine.generateObjectId());
        _controller.text = encodeMongoJson(parsed);
        setState(() => _errorMsg = null);
      }
    } catch (_) {
      // ignore invalid JSON
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = CompassTheme.of(context);
    final isEdit = widget.initialDoc != null && !widget.isClone;
    return CompassModalShell(
      isOpen: widget.isOpen,
      maxWidth: 576.0,
      onBackdropTap: widget.onClose,
      children: [
        CompassModalHeader(
          title: isEdit ? 'Edit Document' : 'Insert Document',
          iconSvg: CompassSvgIcons.code,
          onClose: widget.onClose,
        ),
        const SizedBox(height: 14.0),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('JSON DOCUMENT', style: CompassTypography.monoSmall(color: theme.textMuted)),
            GestureDetector(
              onTap: _generateNewId,
              child: Text(
                'Generate New _id',
                style: CompassTypography.badge(color: theme.accent),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6.0),
        CompassInput(
          controller: _controller,
          maxLines: 12,
          minLines: 12,
          minLinesAuto: false,
          autofocus: true,
          autoIndent: true,
          placeholder: '{ "_id": "...", "title": "..." }',
          onChanged: (_) {
            if (_errorMsg != null) setState(() => _errorMsg = null);
          },
        ),

        if (_errorMsg != null) ...[
          const SizedBox(height: 10.0),
          CompassErrorBanner(message: _errorMsg!),
        ],

        CompassModalFooter(
          children: [
            CompassSecondaryButton(label: 'Cancel', onTap: widget.onClose),
            CompassPrimaryButton(
              label: isEdit
                  ? 'Save Changes'
                  : (widget.isClone ? 'Insert Document' : 'Insert'),
              onTap: _submit,
            ),
          ],
        ),
      ],
    );
  }
}
