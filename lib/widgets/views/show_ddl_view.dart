import 'dart:convert';

import 'package:flutter/widgets.dart';
import '../../icons/compass_svg_icons.dart';
import '../../services/mongo_engine.dart';
import '../../theme/compass_colors.dart';
import '../../theme/compass_theme.dart';
import '../../theme/compass_typography.dart';
import '../../utils/json_syntax_text_controller.dart';
import '../modals/compass_modal.dart';

/// "Show DDL" tab for a MongoDB view.
///
/// Renders the view's underlying aggregation pipeline as an editable,
/// syntax-coloured JSON script, with two actions:
///  * **Update View** — re-applies the edited pipeline to the view definition.
///  * **Copy to Aggregations** — loads the pipeline into the Aggregations tab.
class ShowDdlView extends StatefulWidget {
  final String dbName;

  /// The view's name.
  final String collName;

  /// The collection the view is defined on.
  final String viewOn;

  /// The view's current pipeline (a list of `{ $stage: <value> }` maps).
  final List<dynamic> pipeline;

  /// Applies an edited pipeline to the view. Returns `null` on success or a
  /// human-readable error message.
  final String? Function(List<dynamic> pipeline) onUpdateView;

  /// Sends a pipeline to the Aggregations tab.
  final void Function(List<dynamic> pipeline) onCopyToAggregations;

  const ShowDdlView({
    super.key,
    required this.dbName,
    required this.collName,
    required this.viewOn,
    required this.pipeline,
    required this.onUpdateView,
    required this.onCopyToAggregations,
  });

  @override
  State<ShowDdlView> createState() => _ShowDdlViewState();
}

class _ShowDdlViewState extends State<ShowDdlView> {
  static const JsonEncoder _encoder = JsonEncoder.withIndent('  ');

  late final JsonSyntaxTextController _controller;
  bool _initializedController = false;

  String? _error;
  String? _success;

  CompassTheme get _theme => CompassTheme.of(context);

  String _jsonText() {
    try {
      return _encoder.convert(widget.pipeline);
    } catch (_) {
      return '[]';
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final theme = _theme;
    if (!_initializedController) {
      _controller = JsonSyntaxTextController(text: _jsonText(), theme: theme);
      _initializedController = true;
    } else {
      _controller.theme = theme;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Parses the editor text as a pipeline array, or null when invalid.
  List<dynamic>? _parsePipeline() {
    try {
      final parsed = mongoEngine.tolerantParse(_controller.text);
      if (parsed is List) return parsed;
    } catch (_) {}
    return null;
  }

  void _updateView() {
    final pipeline = _parsePipeline();
    if (pipeline == null) {
      setState(() {
        _error = 'Invalid JSON. The DDL must be a JSON array of stages.';
        _success = null;
      });
      return;
    }
    final error = widget.onUpdateView(pipeline);
    setState(() {
      _error = error;
      _success = error == null ? 'View "${widget.collName}" updated.' : null;
    });
  }

  void _copyToAggregations() {
    final pipeline = _parsePipeline();
    if (pipeline == null) {
      setState(() {
        _error = 'Invalid JSON. The DDL must be a JSON array of stages.';
        _success = null;
      });
      return;
    }
    widget.onCopyToAggregations(pipeline);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: view identity + source collection.
          Row(
            children: [
              const CompassSvg(
                svgString: CompassSvgIcons.eye,
                size: 15.0,
                color: CompassColors.warningAmber,
              ),
              const SizedBox(width: 8.0),
              Expanded(
                child: Text(
                  'View DDL — ${widget.dbName}.${widget.collName}',
                  style: CompassTypography.header(color: _theme.textPrimary),
                ),
              ),
              if (widget.viewOn.isNotEmpty)
                Text(
                  'on ${widget.dbName}.${widget.viewOn}',
                  style: CompassTypography.monoSmall(color: _theme.textMuted),
                ),
            ],
          ),
          const SizedBox(height: 4.0),
          Text(
            'Aggregation pipeline that defines this view. Edit it and press Update View.',
            style: CompassTypography.caption(color: _theme.textMuted),
          ),
          const SizedBox(height: 12.0),

          CompassInput(
            controller: _controller,
            mono: true,
            autoIndent: true,
            maxLines: 24,
            minLines: 10,
            minLinesAuto: false,
            placeholder: '[\n  { "\$match": { ... } }\n]',
          ),

          if (_error != null) ...[
            const SizedBox(height: 12.0),
            CompassErrorBanner(message: _error!),
          ],
          if (_success != null) ...[
            const SizedBox(height: 12.0),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
              decoration: BoxDecoration(
                color: _theme.greenBadgeBg,
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: _theme.greenBadgeBorder, width: 1.0),
              ),
              child: Row(
                children: [
                  CompassSvg(
                    svgString: CompassSvgIcons.check,
                    size: 16.0,
                    color: _theme.accent,
                  ),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Text(
                      _success!,
                      style: CompassTypography.bodyMedium(color: _theme.accent),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16.0),
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: [
              CompassSecondaryButton(
                label: 'Copy to Aggregations',
                iconSvg: CompassSvgIcons.copy,
                onTap: _copyToAggregations,
              ),
              CompassPrimaryButton(
                label: 'Update View',
                iconSvg: CompassSvgIcons.check,
                onTap: _updateView,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
