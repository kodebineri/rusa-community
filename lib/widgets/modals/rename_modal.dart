import 'package:flutter/widgets.dart';
import '../../icons/compass_svg_icons.dart';
import '../../services/mongo_engine.dart';
import '../../theme/compass_colors.dart';
import '../../theme/compass_typography.dart';
import 'compass_modal.dart';

enum RenameTarget { database, collection }

/// Converted from src/components/RenameModal.tsx
class RenameModal extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onClose;
  final RenameTarget type;
  final String dbName;
  final String? collName;
  final bool isView;
  final Function(String oldName, String newName, RenameTarget type) onSuccess;

  const RenameModal({
    super.key,
    required this.isOpen,
    required this.onClose,
    required this.type,
    required this.dbName,
    this.collName,
    this.isView = false,
    required this.onSuccess,
  });

  @override
  State<RenameModal> createState() => _RenameModalState();
}

class _RenameModalState extends State<RenameModal> {
  late final TextEditingController _nameController;
  String? _errorMsg;

  String get _currentName =>
      widget.type == RenameTarget.database ? widget.dbName : (widget.collName ?? '');

  String get _entityLabel {
    if (widget.type == RenameTarget.database) return 'Database';
    return widget.isView ? 'View' : 'Collection';
  }

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _currentName);
  }

  @override
  void didUpdateWidget(covariant RenameModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen && !oldWidget.isOpen) {
      _nameController.text = _currentName;
      _errorMsg = null;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    final trimmed = _nameController.text.trim();
    if (trimmed.isEmpty) {
      setState(() => _errorMsg = '$_entityLabel name cannot be empty.');
      return;
    }
    if (trimmed == _currentName) {
      setState(() => _errorMsg = 'New name is identical to the current name.');
      return;
    }

    try {
      final service = mongoEngine;
      if (widget.type == RenameTarget.database) {
        service.renameDatabase(widget.dbName, trimmed);
        widget.onSuccess(widget.dbName, trimmed, RenameTarget.database);
      } else {
        final coll = widget.collName;
        if (coll == null) throw Exception('No collection specified to rename');
        service.renameCollection(widget.dbName, coll, trimmed);
        widget.onSuccess(coll, trimmed, RenameTarget.collection);
      }
      widget.onClose();
    } catch (err) {
      setState(() => _errorMsg = err.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isView = widget.isView;
    return CompassModalShell(
      isOpen: widget.isOpen,
      maxWidth: 448.0,
      onBackdropTap: widget.onClose,
      children: [
        CompassModalHeader(
          title: 'Rename $_entityLabel',
          subtitle: widget.type == RenameTarget.database
              ? 'Change database name across all collections'
              : 'Change name in database "${widget.dbName}"',
          iconSvg: widget.type == RenameTarget.database
              ? CompassSvgIcons.database
              : (isView ? CompassSvgIcons.eye : CompassSvgIcons.table),
          iconColor: isView ? CompassColors.warningAmber : CompassColors.greenAccent,
          iconBg: isView ? CompassColors.warningAmberBg : CompassColors.greenBadgeBg,
          iconBorder: isView ? CompassColors.warningAmberBorder : CompassColors.greenBadgeBorder,
          onClose: widget.onClose,
        ),
        const SizedBox(height: 14.0),

        const CompassFieldLabel(label: 'Current Name'),
        Container(
          padding: const EdgeInsets.all(10.0),
          decoration: BoxDecoration(
            color: CompassColors.darkBgSubtle,
            borderRadius: BorderRadius.circular(6.0),
            border: Border.all(color: CompassColors.darkBorder, width: 1.0),
          ),
          child: Row(
            children: [
              CompassSvg(
                svgString: widget.type == RenameTarget.database
                    ? CompassSvgIcons.database
                    : (isView ? CompassSvgIcons.eye : CompassSvgIcons.table),
                size: 13.0,
                color: CompassColors.darkTextMuted,
              ),
              const SizedBox(width: 8.0),
              Expanded(
                child: Text(
                  _currentName,
                  overflow: TextOverflow.ellipsis,
                  style: CompassTypography.monoSmall(color: CompassColors.darkTextMuted),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12.0),

        const CompassFieldLabel(label: 'New Name', hint: '* required'),
        CompassInput(
          controller: _nameController,
          placeholder: 'Enter new $_entityLabel name'.toLowerCase(),
          autofocus: true,
          onSubmitted: (_) => _submit(),
          onChanged: (_) {
            if (_errorMsg != null) setState(() => _errorMsg = null);
          },
        ),
        const SizedBox(height: 12.0),

        // Contextual guidance
        Container(
          padding: const EdgeInsets.all(10.0),
          decoration: BoxDecoration(
            color: CompassColors.darkBgSubtle,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: const Color(0x9921313C), width: 1.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CompassSvg(
                    svgString: CompassSvgIcons.activity,
                    size: 12.0,
                    color: CompassColors.greenAccent,
                  ),
                  const SizedBox(width: 6.0),
                  Text(
                    'MongoDB Naming Rules',
                    style: CompassTypography.bodyMedium(color: CompassColors.darkTextPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 4.0),
              Text(
                widget.type == RenameTarget.database
                    ? 'Database names cannot contain spaces or any of: / \\ . " \$ * < > : | ? and must be under 64 characters.'
                    : (isView
                        ? 'Views will retain their pipeline definition and underlying collection source under the new name.'
                        : 'Collection names cannot contain "\$" or begin with "system.". Any views referencing this collection will automatically have their source updated.'),
                style: CompassTypography.caption(color: CompassColors.darkTextMuted),
              ),
            ],
          ),
        ),

        if (_errorMsg != null) ...[
          const SizedBox(height: 12.0),
          CompassErrorBanner(message: _errorMsg!),
        ],

        CompassModalFooter(
          children: [
            CompassSecondaryButton(label: 'Cancel', onTap: widget.onClose),
            CompassPrimaryButton(
              label: 'Rename',
              iconSvg: CompassSvgIcons.pencil,
              onTap: _submit,
            ),
          ],
        ),
      ],
    );
  }
}
