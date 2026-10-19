import 'package:flutter/widgets.dart';
import '../../icons/compass_svg_icons.dart';
import '../../theme/compass_colors.dart';
import '../../theme/compass_theme.dart';
import '../../theme/compass_typography.dart';
import 'compass_modal.dart';

/// Converted from src/components/DropDatabaseModal.tsx
class DropDatabaseModal extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onClose;
  final VoidCallback onConfirm;
  final String dbName;
  final int collectionsCount;

  const DropDatabaseModal({
    super.key,
    required this.isOpen,
    required this.onClose,
    required this.onConfirm,
    required this.dbName,
    this.collectionsCount = 0,
  });

  @override
  State<DropDatabaseModal> createState() => _DropDatabaseModalState();
}

class _DropDatabaseModalState extends State<DropDatabaseModal> {
  late final TextEditingController _typedController = TextEditingController();

  @override
  void didUpdateWidget(covariant DropDatabaseModal oldWidget) {
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

  bool get _isConfirmed => _typedController.text.trim() == widget.dbName;

  void _submit() {
    if (_isConfirmed) {
      widget.onConfirm();
      widget.onClose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = CompassTheme.of(context);
    return CompassModalShell(
      isOpen: widget.isOpen,
      maxWidth: 448.0,
      onBackdropTap: widget.onClose,
      children: [
        CompassModalHeader(
          title: 'Drop Database',
          subtitle: 'Permanent deletion of database and all its collections',
          iconSvg: CompassSvgIcons.database,
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
                      'You are about to drop database ${widget.dbName}',
                      style: CompassTypography.bodyMedium(color: CompassColors.errorRed),
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      'Dropping this database will permanently destroy all its ${widget.collectionsCount} collections and all documents within them.',
                      style: CompassTypography.caption(color: CompassColors.errorRed),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12.0),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Type "${widget.dbName}" to confirm:',
                style: CompassTypography.caption(color: theme.textSecondary),
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _typedController.text = widget.dbName),
              child: Text('Auto-fill', style: CompassTypography.badge(color: theme.accent)),
            ),
          ],
        ),
        const SizedBox(height: 6.0),
        CompassInput(
          controller: _typedController,
          placeholder: 'Type "${widget.dbName}"',
          autofocus: true,
          onChanged: (_) => setState(() {}),
        ),

        CompassModalFooter(
          children: [
            CompassSecondaryButton(label: 'Cancel', onTap: widget.onClose),
            CompassDangerButton(
              label: 'Drop Database',
              iconSvg: CompassSvgIcons.trash,
              onTap: _isConfirmed ? _submit : null,
            ),
          ],
        ),
      ],
    );
  }
}
