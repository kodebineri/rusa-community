import 'package:flutter/widgets.dart';
import '../../icons/compass_svg_icons.dart';
import '../../theme/compass_colors.dart';
import '../../theme/compass_theme.dart';
import '../../theme/compass_typography.dart';
import 'compass_modal.dart';

/// Converted from the `window.confirm()` drop flow in src/components/IndexesView.tsx
///
/// Flutter has no browser `confirm()`, so dropping an index goes through this
/// dedicated confirmation modal (same pattern as `DeleteDocumentModal`). The
/// engine mutation itself stays in `main.dart` (`onConfirm`), matching the
/// other drop modals.
///
/// The `_id_` index is never droppable: `IndexesView` renders "Protected"
/// instead of the trash button for it, and `LocalMongoEngine.dropIndex`
/// additionally refuses `_id_`.
class DropIndexModal extends StatelessWidget {
  final bool isOpen;
  final VoidCallback onClose;
  final VoidCallback onConfirm;
  final String dbName;
  final String collName;
  final String indexName;

  const DropIndexModal({
    super.key,
    required this.isOpen,
    required this.onClose,
    required this.onConfirm,
    required this.dbName,
    required this.collName,
    required this.indexName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = CompassTheme.of(context);
    return CompassModalShell(
      isOpen: isOpen,
      maxWidth: 448.0,
      onBackdropTap: onClose,
      children: [
        CompassModalHeader(
          title: 'Drop Index',
          subtitle: 'From $dbName.$collName',
          iconSvg: CompassSvgIcons.trash,
          iconColor: CompassColors.errorRed,
          iconBg: CompassColors.errorRedBg,
          iconBorder: CompassColors.errorRedBorder,
          onClose: onClose,
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
                      'Are you sure you want to drop this index?',
                      style: CompassTypography.bodyMedium(color: CompassColors.errorRed),
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      'Queries that rely on this index may become slower. This action cannot be undone.',
                      style: CompassTypography.caption(color: CompassColors.errorRed),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12.0),

        // Index name
        Text(
          'INDEX NAME',
          style: CompassTypography.badge(color: theme.textSecondary),
        ),
        const SizedBox(height: 6.0),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: theme.bgSubtle,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: theme.border, width: 1.0),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  indexName,
                  overflow: TextOverflow.ellipsis,
                  style: CompassTypography.monoSmall(color: theme.accent),
                ),
              ),
            ],
          ),
        ),

        CompassModalFooter(
          children: [
            CompassSecondaryButton(label: 'Cancel', onTap: onClose),
            CompassDangerButton(
              label: 'Drop Index',
              iconSvg: CompassSvgIcons.trash,
              onTap: () {
                onConfirm();
                onClose();
              },
            ),
          ],
        ),
      ],
    );
  }
}
