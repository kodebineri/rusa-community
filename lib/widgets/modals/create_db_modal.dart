import 'package:flutter/widgets.dart';
import '../../icons/compass_svg_icons.dart';
import 'compass_modal.dart';

/// Converted from src/components/CreateDbModal.tsx
///
/// Creates a new database (with an initial collection) or, when
/// [isCollectionOnly] is true, just a collection inside [defaultDbName].
class CreateDbModal extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onClose;
  final Function(String dbName, String collName) onSubmit;
  final String defaultDbName;
  final bool isCollectionOnly;

  const CreateDbModal({
    super.key,
    required this.isOpen,
    required this.onClose,
    required this.onSubmit,
    this.defaultDbName = '',
    this.isCollectionOnly = false,
  });

  @override
  State<CreateDbModal> createState() => _CreateDbModalState();
}

class _CreateDbModalState extends State<CreateDbModal> {
  late final TextEditingController _dbController = TextEditingController(text: widget.defaultDbName);
  late final TextEditingController _collController = TextEditingController();
  String? _errorMsg;

  @override
  void didUpdateWidget(covariant CreateDbModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen && !oldWidget.isOpen) {
      _dbController.text = widget.defaultDbName;
      _collController.text = '';
      _errorMsg = null;
    }
  }

  @override
  void dispose() {
    _dbController.dispose();
    _collController.dispose();
    super.dispose();
  }

  void _submit() {
    final dbName = _dbController.text.trim();
    final collName = _collController.text.trim();

    if (!widget.isCollectionOnly && dbName.isEmpty) {
      setState(() => _errorMsg = 'Database name is required');
      return;
    }
    if (collName.isEmpty) {
      setState(() => _errorMsg = 'Collection name is required');
      return;
    }

    widget.onSubmit(widget.isCollectionOnly ? widget.defaultDbName : dbName, collName);
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    return CompassModalShell(
      isOpen: widget.isOpen,
      maxWidth: 448.0,
      onBackdropTap: widget.onClose,
      children: [
        CompassModalHeader(
          title: widget.isCollectionOnly
              ? 'Create Collection in "${widget.defaultDbName}"'
              : 'Create Database',
          iconSvg: widget.isCollectionOnly ? CompassSvgIcons.table : CompassSvgIcons.database,
          onClose: widget.onClose,
        ),
        const SizedBox(height: 12.0),
        if (!widget.isCollectionOnly) ...[
          const CompassFieldLabel(label: 'Database Name'),
          CompassInput(
            controller: _dbController,
            placeholder: 'e.g. inventory, blog_production',
            autofocus: true,
            onChanged: (_) {
              if (_errorMsg != null) setState(() => _errorMsg = null);
            },
          ),
          const SizedBox(height: 12.0),
        ],
        const CompassFieldLabel(label: 'Collection Name'),
        CompassInput(
          controller: _collController,
          placeholder: 'e.g. items, users, logs',
          autofocus: widget.isCollectionOnly,
          onSubmitted: (_) => _submit(),
          onChanged: (_) {
            if (_errorMsg != null) setState(() => _errorMsg = null);
          },
        ),
        if (_errorMsg != null) ...[
          const SizedBox(height: 12.0),
          CompassErrorBanner(message: _errorMsg!),
        ],
        CompassModalFooter(
          children: [
            CompassSecondaryButton(label: 'Cancel', onTap: widget.onClose),
            CompassPrimaryButton(
              label: widget.isCollectionOnly ? 'Create Collection' : 'Create Database',
              onTap: _submit,
            ),
          ],
        ),
      ],
    );
  }
}
