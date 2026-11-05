import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../../icons/compass_svg_icons.dart';
import '../../models/mongo_models.dart';
import '../../theme/compass_colors.dart';
import '../../theme/compass_theme.dart';
import '../../theme/compass_typography.dart';
import '../compass_icon_button.dart';
import 'compass_modal.dart';

/// Converted from src/components/DeleteDocumentModal.tsx
class DeleteDocumentModal extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onClose;
  final VoidCallback onConfirm;
  final String dbName;
  final String collName;
  final String documentId;
  final MongoDocument? document;

  const DeleteDocumentModal({
    super.key,
    required this.isOpen,
    required this.onClose,
    required this.onConfirm,
    required this.dbName,
    required this.collName,
    required this.documentId,
    this.document,
  });

  @override
  State<DeleteDocumentModal> createState() => _DeleteDocumentModalState();
}

class _DeleteDocumentModalState extends State<DeleteDocumentModal> {
  CompassTheme get _theme => CompassTheme.of(context);

  bool _copied = false;

  @override
  void didUpdateWidget(covariant DeleteDocumentModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen && !oldWidget.isOpen) {
      _copied = false;
    }
  }

  Future<void> _copyId() async {
    await Clipboard.setData(ClipboardData(text: widget.documentId));
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  String get _idLabel {
    final raw = widget.document?.data['_id'];
    return raw is MongoObjectId
        ? 'ObjectId("${widget.documentId}")'
        : '"${widget.documentId}"';
  }

  String get _docPreview {
    final doc = widget.document;
    if (doc == null) return '';
    try {
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(doc.data);
    } catch (_) {
      return doc.data.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _docPreview;
    return CompassModalShell(
      isOpen: widget.isOpen,
      maxWidth: 448.0,
      onBackdropTap: widget.onClose,
      children: [
        CompassModalHeader(
          title: 'Delete Document',
          subtitle: 'From ${widget.dbName}.${widget.collName}',
          iconSvg: CompassSvgIcons.trash,
          iconColor: CompassColors.errorRed,
          iconBg: CompassColors.errorRedBg,
          iconBorder: CompassColors.errorRedBorder,
          onClose: widget.onClose,
        ),
        const SizedBox(height: 14.0),

        Container(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: CompassColors.errorRedBg,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: CompassColors.errorRedBorder, width: 1.0),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CompassSvg(
                svgString: CompassSvgIcons.activity,
                size: 15.0,
                color: CompassColors.errorRed,
              ),
              const SizedBox(width: 10.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Are you sure you want to delete this document?',
                      style: CompassTypography.bodyMedium(color: CompassColors.errorRed),
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      'This operation is immediate and permanent. The document cannot be recovered.',
                      style: CompassTypography.caption(color: CompassColors.errorRed),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12.0),

        // Document ID
        Text(
          'DOCUMENT TARGET ID',
          style: CompassTypography.badge(color: _theme.textSecondary),
        ),
        const SizedBox(height: 6.0),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: _theme.bgSubtle,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: _theme.border, width: 1.0),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _idLabel,
                  overflow: TextOverflow.ellipsis,
                  style: CompassTypography.monoSmall(color: _theme.accent),
                ),
              ),
              const SizedBox(width: 8.0),
              CompassIconButton(
                svgString: _copied ? CompassSvgIcons.check : CompassSvgIcons.copy,
                onTap: _copyId,
                size: 14.0,
                padding: 4.0,
                color: _copied ? _theme.accent : _theme.textMuted,
                semanticLabel: _copied ? 'Copied' : 'Copy document id',
              ),
            ],
          ),
        ),

        if (preview.isNotEmpty) ...[
          const SizedBox(height: 12.0),
          Row(
            children: [
              CompassSvg(
                svgString: CompassSvgIcons.layers,
                size: 12.0,
                color: _theme.textMuted,
              ),
              const SizedBox(width: 6.0),
              Text(
                'Document Preview',
                style: CompassTypography.bodyMedium(color: _theme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 6.0),
          Container(
            constraints: const BoxConstraints(maxHeight: 150.0),
            padding: const EdgeInsets.all(10.0),
            decoration: BoxDecoration(
              color: _theme.bgApp,
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: _theme.border, width: 1.0),
            ),
            child: SingleChildScrollView(
              child: Text(
                preview,
                style: CompassTypography.monoSmall(color: const Color(0xFFE8EDEB)),
              ),
            ),
          ),
        ],

        CompassModalFooter(
          children: [
            CompassSecondaryButton(label: 'Cancel', onTap: widget.onClose),
            CompassDangerButton(
              label: 'Delete Document',
              iconSvg: CompassSvgIcons.trash,
              onTap: () {
                widget.onConfirm();
                widget.onClose();
              },
            ),
          ],
        ),
      ],
    );
  }
}
