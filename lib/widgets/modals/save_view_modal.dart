import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../../icons/compass_svg_icons.dart';
import '../../services/mongo_engine.dart';
import '../../theme/compass_colors.dart';
import '../../theme/compass_theme.dart';
import '../../theme/compass_typography.dart';
import 'compass_modal.dart';

/// Converted from src/components/SaveViewModal.tsx
class SaveViewModal extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onClose;
  final String dbName;
  final String sourceCollName;
  final List<dynamic> pipeline;
  final String pipelineJsonString;
  final Function(String newViewName) onViewSaved;

  const SaveViewModal({
    super.key,
    required this.isOpen,
    required this.onClose,
    required this.dbName,
    required this.sourceCollName,
    required this.pipeline,
    required this.pipelineJsonString,
    required this.onViewSaved,
  });

  @override
  State<SaveViewModal> createState() => _SaveViewModalState();
}

class _SaveViewModalState extends State<SaveViewModal> {
  late final TextEditingController _nameController = TextEditingController();
  bool _copied = false;
  String? _error;
  bool _isSubmitting = false;

  @override
  void didUpdateWidget(covariant SaveViewModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen && !oldWidget.isOpen) {
      var candidate = '${widget.sourceCollName}_view';
      final db = mongoEngine.getDatabase(widget.dbName);
      if (db != null && db.collections.containsKey(candidate)) {
        final suffix = DateTime.now().millisecondsSinceEpoch.toString();
        candidate = '${widget.sourceCollName}_view_${suffix.substring(suffix.length - 4)}';
      }
      _nameController.text = candidate;
      _error = null;
      _isSubmitting = false;
      _copied = false;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String? _validateName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'View name is required.';
    if (trimmed.contains('\$') || trimmed.startsWith('.')) {
      return 'View name cannot contain "\$" or begin with a dot.';
    }
    final db = mongoEngine.getDatabase(widget.dbName);
    if (db != null && db.collections.containsKey(trimmed)) {
      final isExistingView = db.collections[trimmed]!.isView;
      return 'A ${isExistingView ? 'view' : 'collection'} named "$trimmed" already exists in ${widget.dbName}.';
    }
    return null;
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.pipelineJsonString));
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  void _submit() {
    final validationErr = _validateName(_nameController.text);
    if (validationErr != null) {
      setState(() => _error = validationErr);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final trimmed = _nameController.text.trim();
      mongoEngine.createView(
        widget.dbName,
        trimmed,
        widget.sourceCollName,
        widget.pipeline,
      );
      widget.onViewSaved(trimmed);
      widget.onClose();
    } catch (err) {
      setState(() {
        _error = err.toString().replaceFirst('Exception: ', '');
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = CompassTheme.of(context);
    final currentError = _error ?? _validateName(_nameController.text);
    final isValid = currentError == null && _nameController.text.trim().isNotEmpty;

    return CompassModalShell(
      isOpen: widget.isOpen,
      maxWidth: 512.0,
      onBackdropTap: widget.onClose,
      children: [
        CompassModalHeader(
          title: 'Save Pipeline as View',
          subtitle: 'Create a read-only MongoDB view in database ${widget.dbName}',
          iconSvg: CompassSvgIcons.eye,
          iconColor: CompassColors.warningAmber,
          iconBg: CompassColors.warningAmberBg,
          iconBorder: CompassColors.warningAmberBorder,
          onClose: widget.onClose,
        ),
        const SizedBox(height: 14.0),

        // Source collection badge
        Container(
          padding: const EdgeInsets.all(10.0),
          decoration: BoxDecoration(
            color: theme.bgSubtle,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: theme.border, width: 1.0),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CompassSvg(
                    svgString: CompassSvgIcons.database,
                    size: 13.0,
                    color: theme.accent,
                  ),
                  const SizedBox(width: 6.0),
                  Text('Source Collection:', style: CompassTypography.caption(color: theme.textMuted)),
                ],
              ),
              Text(
                '${widget.dbName}.${widget.sourceCollName}',
                style: CompassTypography.monoMedium(color: theme.textPrimary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12.0),

        const CompassFieldLabel(label: 'View Name', hint: '* required'),
        CompassInput(
          controller: _nameController,
          placeholder: 'e.g. active_books_view',
          autofocus: true,
          onSubmitted: (_) => _submit(),
          onChanged: (_) => setState(() => _error = null),
        ),
        const SizedBox(height: 6.0),
        if (currentError != null)
          Row(
            children: [
              const CompassSvg(svgString: CompassSvgIcons.activity, size: 12.0, color: CompassColors.errorRed),
              const SizedBox(width: 6.0),
              Expanded(
                child: Text(currentError, style: CompassTypography.caption(color: CompassColors.errorRed)),
              ),
            ],
          )
        else
          Text(
            'Will be listed alongside collections in the database tree view with a VIEW badge.',
            style: CompassTypography.caption(color: theme.textMuted),
          ),
        const SizedBox(height: 12.0),

        // Pipeline preview
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                CompassSvg(svgString: CompassSvgIcons.layers, size: 13.0, color: theme.accent),
                const SizedBox(width: 6.0),
                Text(
                  'Underlying Pipeline Definition (${widget.pipeline.length} stages)',
                  style: CompassTypography.bodyMedium(color: theme.textSecondary),
                ),
              ],
            ),
            GestureDetector(
              onTap: _copy,
              child: Row(
                children: [
                  CompassSvg(
                    svgString: _copied ? CompassSvgIcons.check : CompassSvgIcons.copy,
                    size: 12.0,
                    color: _copied ? theme.accent : theme.textMuted,
                  ),
                  const SizedBox(width: 4.0),
                  Text(
                    _copied ? 'Copied' : 'Copy',
                    style: CompassTypography.caption(color: theme.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6.0),
        Container(
          constraints: const BoxConstraints(maxHeight: 160.0),
          padding: const EdgeInsets.all(10.0),
          decoration: BoxDecoration(
            color: theme.bgInput,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: theme.border, width: 1.0),
          ),
          child: SingleChildScrollView(
            child: Text(
              widget.pipelineJsonString.isEmpty ? '[]' : widget.pipelineJsonString,
              style: CompassTypography.monoSmall(color: theme.textSecondary),
            ),
          ),
        ),
        const SizedBox(height: 12.0),

        // Info callout
        Container(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: theme.bgSubtle,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: theme.border, width: 1.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CompassSvg(svgString: CompassSvgIcons.eye, size: 13.0, color: CompassColors.warningAmber),
                  const SizedBox(width: 6.0),
                  Text(
                    'MongoDB View Characteristics',
                    style: CompassTypography.bodyMedium(color: theme.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 4.0),
              Text(
                'Views behave like read-only collections. When queried with filters or projections, operations are executed on top of this aggregation pipeline. Underlying data remains authoritatively in ${widget.sourceCollName}.',
                style: CompassTypography.caption(color: theme.textMuted),
              ),
            ],
          ),
        ),

        CompassModalFooter(
          children: [
            CompassSecondaryButton(label: 'Cancel', onTap: widget.onClose),
            CompassPrimaryButton(
              label: _isSubmitting ? 'Saving View...' : 'Save View',
              iconSvg: CompassSvgIcons.eye,
              onTap: (isValid && !_isSubmitting) ? _submit : null,
            ),
          ],
        ),
      ],
    );
  }
}
