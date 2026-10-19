import 'package:flutter/widgets.dart';
import '../../icons/compass_svg_icons.dart';
import '../../models/mongo_models.dart';
import '../../services/mongo_engine.dart';
import '../../theme/compass_theme.dart';
import '../../theme/compass_typography.dart';
import 'compass_modal.dart';

/// Converted from src/components/CreateCollectionModal.tsx
///
/// Includes the advanced Compass collection options (capped + collation).
class CreateCollectionModal extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onClose;
  final List<MongoDatabase> databases;
  final String targetDbName;
  final Function(String dbName, String collName) onCreated;

  const CreateCollectionModal({
    super.key,
    required this.isOpen,
    required this.onClose,
    required this.databases,
    required this.targetDbName,
    required this.onCreated,
  });

  @override
  State<CreateCollectionModal> createState() => _CreateCollectionModalState();
}

class _CreateCollectionModalState extends State<CreateCollectionModal> {
  CompassTheme get _theme => CompassTheme.of(context);

  late final TextEditingController _collController = TextEditingController();
  String _selectedDb = '';
  String? _errorMsg;
  bool _showAdvanced = false;
  bool _isCapped = false;
  bool _useCustomCollation = false;
  String _collationLocale = 'en';

  final _collationLocales = const ['en', 'es', 'fr', 'de', 'ja'];

  @override
  void didUpdateWidget(covariant CreateCollectionModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen && !oldWidget.isOpen) {
      _selectedDb = widget.targetDbName.isNotEmpty
          ? widget.targetDbName
          : (widget.databases.isNotEmpty ? widget.databases.first.name : '');
      _collController.text = '';
      _errorMsg = null;
      _isCapped = false;
      _showAdvanced = false;
      _useCustomCollation = false;
    }
  }

  @override
  void dispose() {
    _collController.dispose();
    super.dispose();
  }

  void _submit() {
    final trimmed = _collController.text.trim();
    if (trimmed.isEmpty) {
      setState(() => _errorMsg = 'Collection name is required');
      return;
    }
    if (_selectedDb.isEmpty) {
      setState(() => _errorMsg = 'Please select a target database');
      return;
    }
    if (trimmed.contains('\$')) {
      setState(() => _errorMsg = 'Collection names cannot contain the "\$" character');
      return;
    }
    if (trimmed.startsWith('system.')) {
      setState(() => _errorMsg = 'Collection names cannot start with the "system." prefix');
      return;
    }

    final service = mongoEngine;
    final db = service.getDatabase(_selectedDb);
    if (db != null && db.collections.containsKey(trimmed)) {
      setState(() => _errorMsg = 'A collection named "$trimmed" already exists in database "$_selectedDb"');
      return;
    }

    final success = service.createCollection(_selectedDb, trimmed);
    if (!success) {
      setState(() => _errorMsg = 'Failed to create collection "$trimmed" in "$_selectedDb"');
      return;
    }

    widget.onCreated(_selectedDb, trimmed);
    widget.onClose();
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
          title: 'Create Collection',
          subtitle: 'Add a new collection to your database',
          iconSvg: CompassSvgIcons.table,
          onClose: widget.onClose,
        ),
        const SizedBox(height: 14.0),

        // Target database selector
        const CompassFieldLabel(
          label: 'Target Database',
          hint: 'Where the collection will be created',
        ),
        Wrap(
          spacing: 6.0,
          runSpacing: 6.0,
          children: [
            for (final db in widget.databases)
              _buildDbPill(db),
          ],
        ),
        const SizedBox(height: 14.0),

        // Collection name
        const CompassFieldLabel(label: 'Collection Name', hint: 'e.g. orders, logs'),
        CompassInput(
          controller: _collController,
          placeholder: 'Enter collection name',
          autofocus: true,
          onSubmitted: (_) => _submit(),
          onChanged: (_) {
            if (_errorMsg != null) setState(() => _errorMsg = null);
          },
        ),
        const SizedBox(height: 12.0),

        // Advanced options toggle
        GestureDetector(
          onTap: () => setState(() => _showAdvanced = !_showAdvanced),
          child: Row(
            children: [
              CompassSvg(svgString: CompassSvgIcons.sliders, size: 13.0, color: theme.accent),
              const SizedBox(width: 6.0),
              Text(
                'Advanced Options (Capped, Collation)',
                style: CompassTypography.bodyMedium(color: theme.accent),
              ),
              const SizedBox(width: 6.0),
              CompassSvg(
                svgString: _showAdvanced ? CompassSvgIcons.chevronUp : CompassSvgIcons.chevronDown,
                size: 12.0,
                color: theme.accent,
              ),
            ],
          ),
        ),

        if (_showAdvanced) ...[
          const SizedBox(height: 10.0),
          Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: theme.bgSubtle,
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: theme.border, width: 1.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCheckRow(
                  label: 'Capped Collection',
                  description: 'Fixed-size collection that overwrites oldest entries when full',
                  value: _isCapped,
                  onChanged: (v) => setState(() => _isCapped = v),
                ),
                if (_isCapped) ...[
                  const SizedBox(height: 8.0),
                  Row(
                    children: [
                      Expanded(child: _buildMiniField('Max Size (bytes)', '1048576')),
                      const SizedBox(width: 8.0),
                      Expanded(child: _buildMiniField('Max Documents', '1000')),
                    ],
                  ),
                ],
                const SizedBox(height: 8.0),
                Container(height: 1.0, color: theme.border),
                const SizedBox(height: 8.0),
                _buildCheckRow(
                  label: 'Custom Collation',
                  description: null,
                  value: _useCustomCollation,
                  onChanged: (v) => setState(() => _useCustomCollation = v),
                ),
                if (_useCustomCollation) ...[
                  const SizedBox(height: 8.0),
                  Wrap(
                    spacing: 6.0,
                    children: [
                      for (final locale in _collationLocales) _buildLocalePill(locale),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],

        if (_errorMsg != null) ...[
          const SizedBox(height: 12.0),
          CompassErrorBanner(message: _errorMsg!),
        ],

        CompassModalFooter(
          children: [
            CompassSecondaryButton(label: 'Cancel', onTap: widget.onClose),
            CompassPrimaryButton(
              label: 'Create Collection',
              iconSvg: CompassSvgIcons.table,
              onTap: _submit,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDbPill(MongoDatabase db) {
    final selected = db.name == _selectedDb;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedDb = db.name;
          _errorMsg = null;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: selected ? _theme.greenBadgeBg : _theme.bgInput,
          borderRadius: BorderRadius.circular(6.0),
          border: Border.all(
            color: selected ? _theme.greenBadgeBorder : _theme.border,
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CompassSvg(
              svgString: CompassSvgIcons.database,
              size: 12.0,
              color: selected ? _theme.accent : _theme.textMuted,
            ),
            const SizedBox(width: 6.0),
            Text(
              '${db.name} (${db.collections.length})',
              style: CompassTypography.monoSmall(
                color: selected ? _theme.accent : _theme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocalePill(String locale) {
    final selected = locale == _collationLocale;
    return GestureDetector(
      onTap: () => setState(() => _collationLocale = locale),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
        decoration: BoxDecoration(
          color: selected ? _theme.greenBadgeBg : _theme.bgInput,
          borderRadius: BorderRadius.circular(6.0),
          border: Border.all(
            color: selected ? _theme.greenBadgeBorder : _theme.border,
            width: 1.0,
          ),
        ),
        child: Text(
          locale,
          style: CompassTypography.monoSmall(
            color: selected ? _theme.accent : _theme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildCheckRow({
    required String label,
    required String? description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 15.0,
            height: 15.0,
            margin: const EdgeInsets.only(top: 1.0),
            decoration: BoxDecoration(
              color: value ? _theme.accent : _theme.bgInput,
              borderRadius: BorderRadius.circular(3.0),
              border: Border.all(
                color: value ? _theme.accent : _theme.border,
                width: 1.0,
              ),
            ),
            alignment: Alignment.center,
            child: value
                ? CompassSvg(svgString: CompassSvgIcons.check, size: 11.0, color: _theme.onAccent)
                : null,
          ),
          const SizedBox(width: 8.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: CompassTypography.bodyMedium(color: _theme.textPrimary)),
                if (description != null)
                  Text(description, style: CompassTypography.caption(color: _theme.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: CompassTypography.caption(color: _theme.textMuted)),
        const SizedBox(height: 4.0),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 7.0),
          decoration: BoxDecoration(
            color: _theme.bgInput,
            borderRadius: BorderRadius.circular(4.0),
            border: Border.all(color: _theme.border, width: 1.0),
          ),
          child: Text(value, style: CompassTypography.monoSmall(color: _theme.textPrimary)),
        ),
      ],
    );
  }
}
