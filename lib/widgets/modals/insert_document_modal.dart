import 'dart:convert';

import 'package:flutter/widgets.dart';
import '../../icons/compass_svg_icons.dart';
import '../../services/mongo_engine.dart';
import '../../theme/compass_colors.dart';
import '../../theme/compass_typography.dart';
import 'compass_modal.dart';

/// Converted from src/components/InsertDocModal.tsx
///
/// Used both for inserting a brand-new document and for editing an existing
/// one (when [initialDoc] is supplied).
class InsertDocumentModal extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onClose;
  final Function(Map<String, dynamic> doc) onInsert;
  final Map<String, dynamic>? initialDoc;

  const InsertDocumentModal({
    super.key,
    required this.isOpen,
    required this.onClose,
    required this.onInsert,
    this.initialDoc,
  });

  @override
  State<InsertDocumentModal> createState() => _InsertDocumentModalState();
}

class _InsertDocumentModalState extends State<InsertDocumentModal> {
  late final TextEditingController _controller = TextEditingController();
  String? _errorMsg;

  static const JsonEncoder _encoder = JsonEncoder.withIndent('  ');

  String _defaultText() {
    final initial = widget.initialDoc;
    if (initial != null) {
      return _encoder.convert(initial);
    }
    return _encoder.convert({
      '_id': mongoEngine.generateObjectId(),
      'title': 'New Entry',
      'createdAt': DateTime.now().toIso8601String(),
      'status': 'active',
      'tags': ['sample'],
    });
  }

  @override
  void initState() {
    super.initState();
    _controller.text = _defaultText();
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
      final parsed = jsonDecode(_controller.text);
      if (parsed is! Map) {
        setState(() => _errorMsg = 'Document must be a JSON object.');
        return;
      }
      widget.onInsert(Map<String, dynamic>.from(parsed));
      widget.onClose();
    } catch (err) {
      setState(() => _errorMsg = 'JSON Parse Error: $err');
    }
  }

  void _generateNewId() {
    try {
      final parsed = jsonDecode(_controller.text);
      if (parsed is Map) {
        parsed['_id'] = mongoEngine.generateObjectId();
        _controller.text = _encoder.convert(parsed);
        setState(() => _errorMsg = null);
      }
    } catch (_) {
      // ignore invalid JSON
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initialDoc != null;
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
            Text('JSON DOCUMENT', style: CompassTypography.monoSmall(color: CompassColors.darkTextMuted)),
            GestureDetector(
              onTap: _generateNewId,
              child: Text(
                'Generate New _id',
                style: CompassTypography.badge(color: CompassColors.greenAccent),
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
              label: isEdit ? 'Save Changes' : 'Insert',
              onTap: _submit,
            ),
          ],
        ),
      ],
    );
  }
}
