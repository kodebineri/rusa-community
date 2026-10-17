import 'package:flutter/widgets.dart';
import '../../icons/compass_svg_icons.dart';
import '../../theme/compass_colors.dart';
import '../../theme/compass_typography.dart';
import 'compass_modal.dart';

/// Converted from src/components/DropCollectionModal.tsx
class DropCollectionModal extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onClose;
  final VoidCallback onConfirm;
  final String dbName;
  final String collName;
  final int documentCount;
  final int indexesCount;
  final bool isView;

  const DropCollectionModal({
    super.key,
    required this.isOpen,
    required this.onClose,
    required this.onConfirm,
    required this.dbName,
    required this.collName,
    this.documentCount = 0,
    this.indexesCount = 1,
    this.isView = false,
  });

  @override
  State<DropCollectionModal> createState() => _DropCollectionModalState();
}

class _DropCollectionModalState extends State<DropCollectionModal> {
  late final TextEditingController _typedController = TextEditingController();

  @override
  void didUpdateWidget(covariant DropCollectionModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen && !oldWidget.isOpen) {
      _typedController.text = '';
    }
  }

  @override
  void dispose() {
    _typedController.dispose();
    super.dispose();
  }

  bool get _isConfirmed => _typedController.text.trim() == widget.collName;

  void _submit() {
    if (_isConfirmed) {
      widget.onConfirm();
      widget.onClose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isView = widget.isView;
    final accent = isView ? CompassColors.warningAmber : CompassColors.errorRed;
    final accentBg = isView ? CompassColors.warningAmberBg : CompassColors.errorRedBg;
    final accentBorder = isView ? CompassColors.warningAmberBorder : CompassColors.errorRedBorder;

    return CompassModalShell(
      isOpen: widget.isOpen,
      maxWidth: 448.0,
      onBackdropTap: widget.onClose,
      children: [
        CompassModalHeader(
          title: isView ? 'Drop View' : 'Drop Collection',
          subtitle: '${isView ? 'Remove saved view from' : 'Permanent deletion from'} ${widget.dbName}',
          iconSvg: isView ? CompassSvgIcons.eye : CompassSvgIcons.table,
          iconColor: accent,
          iconBg: accentBg,
          iconBorder: accentBorder,
          onClose: widget.onClose,
        ),
        const SizedBox(height: 14.0),

        // Warning banner
        Container(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: accentBg,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: accentBorder, width: 1.0),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CompassSvg(svgString: CompassSvgIcons.activity, size: 15.0, color: accent),
              const SizedBox(width: 10.0),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'You are about to drop ${isView ? 'view' : 'collection'} ${widget.collName}',
                      style: CompassTypography.bodyMedium(color: accent),
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      isView
                          ? 'Dropping this view will remove the view definition. The underlying source collection and its documents will remain intact and unaffected.'
                          : 'Dropping this collection will permanently remove all documents, indexes, and custom schema configurations. This action cannot be undone.',
                      style: CompassTypography.caption(color: accent),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12.0),

        // Metadata
        Container(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: CompassColors.darkBgSubtle,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: CompassColors.darkBorder, width: 1.0),
          ),
          child: Column(
            children: [
              _metaRow('Database:', widget.dbName, CompassColors.darkTextPrimary),
              const SizedBox(height: 6.0),
              _metaRow(
                isView ? 'View Name:' : 'Collection Name:',
                widget.collName,
                accent,
              ),
              const SizedBox(height: 6.0),
              _metaRow(
                'Documents Affected:',
                '${widget.documentCount}',
                CompassColors.darkTextPrimary,
              ),
              if (!isView) ...[
                const SizedBox(height: 6.0),
                _metaRow('Indexes Affected:', '${widget.indexesCount}', CompassColors.darkTextPrimary),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12.0),

        // Confirm by typing
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Type "${widget.collName}" to confirm:',
                style: CompassTypography.caption(color: CompassColors.darkTextSecondary),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _typedController.text = widget.collName),
              child: Text(
                'Auto-fill',
                style: CompassTypography.badge(color: CompassColors.greenAccent),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6.0),
        CompassInput(
          controller: _typedController,
          placeholder: 'Type "${widget.collName}"',
          autofocus: true,
          onChanged: (_) => setState(() {}),
        ),

        CompassModalFooter(
          children: [
            CompassSecondaryButton(label: 'Cancel', onTap: widget.onClose),
            CompassDangerButton(
              label: isView ? 'Drop View' : 'Drop Collection',
              iconSvg: CompassSvgIcons.trash,
              onTap: _isConfirmed ? _submit : null,
            ),
          ],
        ),
      ],
    );
  }

  Widget _metaRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: CompassTypography.caption(color: CompassColors.darkTextMuted)),
        const SizedBox(width: 12.0),
        Flexible(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: CompassTypography.monoMedium(color: valueColor),
          ),
        ),
      ],
    );
  }
}
