import 'package:flutter/widgets.dart';
import '../../icons/compass_svg_icons.dart';
import '../../models/mongo_models.dart';
import '../../services/mongo_engine.dart';
import '../../theme/compass_theme.dart';
import '../../theme/compass_typography.dart';
import 'compass_modal.dart';

/// Converted from the Create Index modal embedded in src/components/IndexesView.tsx
///
/// In React the modal state lives inside `IndexesView`; in Flutter every modal
/// is permanently mounted in the root `Stack` (invariant #5), so this widget is
/// mounted by `main.dart` and driven by `_isCreateIndexModalOpen`.
///
/// The engine call mirrors the React submit handler: the index name is built as
/// `<field>_<direction>` and a name collision makes `createIndex` return false,
/// which surfaces as the modal's error banner.
class CreateIndexModal extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onClose;
  final String dbName;
  final String collName;

  /// Called after the engine accepted the new index (refreshes the table).
  final VoidCallback onCreated;

  const CreateIndexModal({
    super.key,
    required this.isOpen,
    required this.onClose,
    required this.dbName,
    required this.collName,
    required this.onCreated,
  });

  @override
  State<CreateIndexModal> createState() => _CreateIndexModalState();
}

class _CreateIndexModalState extends State<CreateIndexModal> {
  final TextEditingController _fieldController = TextEditingController();

  /// '1' (ascending), '-1' (descending) or 'text' — mirrors the React
  /// `<select>` options; there is no dropdown primitive in this codebase, so
  /// the choices are rendered as pills (same pattern as the collation locale
  /// selector in `CreateCollectionModal`).
  String _direction = '1';
  bool _isUnique = false;
  String? _errorMsg;

  static const Map<String, String> _directions = {
    '1': '1 (Ascending)',
    '-1': '-1 (Descending)',
    'text': 'text (Text Index)',
  };

  CompassTheme get _theme => CompassTheme.of(context);

  @override
  void didUpdateWidget(covariant CreateIndexModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen && !oldWidget.isOpen) {
      _fieldController.clear();
      _direction = '1';
      _isUnique = false;
      _errorMsg = null;
    }
  }

  @override
  void dispose() {
    _fieldController.dispose();
    super.dispose();
  }

  void _submit() {
    final field = _fieldController.text.trim();
    if (field.isEmpty) {
      setState(() => _errorMsg = 'Field name is required');
      return;
    }

    final dynamic keyValue = _direction == 'text' ? 'text' : int.parse(_direction);
    final indexName = '${field}_$_direction';
    final created = mongoEngine.createIndex(
      widget.dbName,
      widget.collName,
      MongoIndex(name: indexName, keys: {field: keyValue}, unique: _isUnique),
    );

    if (!created) {
      setState(() => _errorMsg = 'An index with this name or key pattern already exists');
      return;
    }

    widget.onCreated();
    widget.onClose();
  }

  Widget _buildDirectionPill(String value, String label) {
    final selected = _direction == value;
    return GestureDetector(
      onTap: () => setState(() => _direction = value),
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
          label,
          style: CompassTypography.monoSmall(
            color: selected ? _theme.accent : _theme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildUniqueRow() {
    return GestureDetector(
      onTap: () => setState(() => _isUnique = !_isUnique),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 15.0,
            height: 15.0,
            margin: const EdgeInsets.only(top: 1.0),
            decoration: BoxDecoration(
              color: _isUnique ? _theme.accent : _theme.bgInput,
              borderRadius: BorderRadius.circular(3.0),
              border: Border.all(color: _isUnique ? _theme.accent : _theme.border),
            ),
            alignment: Alignment.center,
            child: _isUnique
                ? CompassSvg(
                    svgString: CompassSvgIcons.check,
                    size: 11.0,
                    color: _theme.onAccent,
                  )
                : null,
          ),
          const SizedBox(width: 8.0),
          Expanded(
            child: Text(
              'Create as Unique Index (Rejects duplicate values)',
              style: CompassTypography.bodyMedium(color: _theme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompassModalShell(
      isOpen: widget.isOpen,
      maxWidth: 448.0,
      onBackdropTap: widget.onClose,
      children: [
        CompassModalHeader(
          title: 'Create New Index',
          iconSvg: CompassSvgIcons.key,
          onClose: widget.onClose,
        ),
        const SizedBox(height: 14.0),

        const CompassFieldLabel(label: 'Field Name'),
        CompassInput(
          controller: _fieldController,
          placeholder: 'e.g. email, year, user.address.city',
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 14.0),

        const CompassFieldLabel(label: 'Index Type / Direction'),
        Wrap(
          spacing: 6.0,
          runSpacing: 6.0,
          children: [
            for (final entry in _directions.entries)
              _buildDirectionPill(entry.key, entry.value),
          ],
        ),
        const SizedBox(height: 14.0),

        _buildUniqueRow(),

        if (_errorMsg != null) ...[
          const SizedBox(height: 12.0),
          CompassErrorBanner(message: _errorMsg!),
        ],

        CompassModalFooter(
          children: [
            CompassSecondaryButton(label: 'Cancel', onTap: widget.onClose),
            CompassPrimaryButton(label: 'Create', onTap: _submit),
          ],
        ),
      ],
    );
  }
}
