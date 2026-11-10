import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../../icons/compass_svg_icons.dart';
import '../../models/mongo_models.dart';
import '../../services/mongo_engine.dart';
import '../../theme/compass_colors.dart';
import '../../theme/compass_density.dart';
import '../../theme/compass_theme.dart';
import '../../theme/compass_typography.dart';
import '../../utils/json_syntax_text_controller.dart';
import '../compass_hover.dart';
import '../compass_icon_button.dart';
import '../modals/compass_modal.dart';

class AggregationPreset {
  final String id;
  final String name;
  final String description;
  final List<PipelineStage> stages;

  const AggregationPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.stages,
  });
}

const Map<String, String> _defaultTemplates = {
  r'$match': '{}',
  r'$group': '{\n  "_id": "\$publisher_id",\n  "count": { "\$sum": 1 },\n  "avgRating": { "\$avg": "\$rating" }\n}',
  r'$sort': '{\n  "_id": -1\n}',
  r'$project': '{\n  "title": 1,\n  "published_year": 1,\n  "rating": 1\n}',
  r'$limit': '10',
  r'$skip': '0',
  r'$unwind': '"\$genre_ids"',
  r'$count': '"total_books"',
  r'$addFields': '{\n  "isRecent": { "\$gte": ["\$published_year", 2020] }\n}',
  r'$lookup': '{\n  "from": "publishers",\n  "localField": "publisher_id",\n  "foreignField": "_id",\n  "as": "publisher"\n}',
};

const List<String> _availableOperators = [
  r'$match',
  r'$group',
  r'$sort',
  r'$project',
  r'$limit',
  r'$skip',
  r'$unwind',
  r'$count',
  r'$addFields',
  r'$lookup',
];

/// Aggregations pipeline builder and runner (Compass-style).
/// Supports visual stage editing, operator changing, stage reordering,
/// raw JSON/mongosh script execution, and interactive live pipeline results.
class AggregationsView extends StatefulWidget {
  final String dbName;
  final String collName;
  final Function(List<dynamic> pipeline, String pipelineJson)? onSaveAsView;

  /// Optional pipeline to seed the builder with (e.g. copied from a view's
  /// "Show DDL" tab). When null/empty the default sample stages are used.
  final List<dynamic>? initialPipeline;

  const AggregationsView({
    super.key,
    required this.dbName,
    required this.collName,
    this.onSaveAsView,
    this.initialPipeline,
  });

  @override
  State<AggregationsView> createState() => _AggregationsViewState();
}

class _AggregationsViewState extends State<AggregationsView> {
  CompassTheme get _theme => CompassTheme.of(context);

  String _activeMode = 'visual'; // 'visual' or 'raw'

  /// The pipeline starts empty (like MongoDB Compass): an empty pipeline
  /// returns the collection's own documents, so **Run Pipeline** shows data
  /// immediately. Presets and the quick-add chips fill it in. The previous
  /// hard-coded demo stages filtered on `published_year`, which only exists in
  /// the bundled sample data, so running them against a real collection always
  /// produced "0 docs".
  final List<PipelineStage> _stages = [];

  final Map<String, JsonSyntaxTextController> _stageControllers = {};
  late final JsonSyntaxTextController _rawController;
  bool _initializedControllers = false;

  String? _operatorPickerStageId;
  List<MongoDocument> _results = [];
  int _totalResultCount = 0;
  double _executionTimeMs = 0.0;
  String? _errorMessage;
  bool _isRunning = false;
  bool _isCopied = false;

  /// Results are a paged preview: only [_resultPageSize] documents are rendered
  /// at a time (the full pipeline output is kept in memory).
  static const int _resultPageSize = 20;
  int _resultPage = 0;

  /// Tracks the active collection's on-demand load so a run that happened while
  /// the mirror was still empty is repeated once the documents arrive.
  bool _wasCollLoading = false;
  String _resultViewMode = 'json'; // 'json' or 'table'

  /// Anchors the results panel so an explicit run can scroll it into view.
  final GlobalKey _resultsKey = GlobalKey();

  final List<AggregationPreset> _presets = [
    AggregationPreset(
      id: 'match-group-sort',
      name: 'Match & Group',
      description: 'Filter published_year >= 2015, group by publisher with count & avg rating, sort descending',
      stages: [
        PipelineStage(id: 'p1', operator: r'$match', content: '{\n  "published_year": { "\$gte": 2015 }\n}', enabled: true),
        PipelineStage(id: 'p2', operator: r'$group', content: '{\n  "_id": "\$publisher_id",\n  "count": { "\$sum": 1 },\n  "avgRating": { "\$avg": "\$rating" }\n}', enabled: true),
        PipelineStage(id: 'p3', operator: r'$sort', content: '{\n  "count": -1\n}', enabled: true),
      ],
    ),
    AggregationPreset(
      id: 'unwind-genres',
      name: 'Unwind & Count',
      description: 'Deconstruct genre_ids array and calculate count per genre',
      stages: [
        PipelineStage(id: 'u1', operator: r'$unwind', content: '"\$genre_ids"', enabled: true),
        PipelineStage(id: 'u2', operator: r'$group', content: '{\n  "_id": "\$genre_ids",\n  "count": { "\$sum": 1 }\n}', enabled: true),
        PipelineStage(id: 'u3', operator: r'$sort', content: '{\n  "count": -1\n}', enabled: true),
        PipelineStage(id: 'u4', operator: r'$limit', content: '10', enabled: true),
      ],
    ),
    AggregationPreset(
      id: 'top-rated',
      name: 'Top 10 Rated',
      description: 'Sort by rating descending and project fields',
      stages: [
        PipelineStage(id: 't1', operator: r'$sort', content: '{\n  "rating": -1\n}', enabled: true),
        PipelineStage(id: 't2', operator: r'$project', content: '{\n  "title": 1,\n  "published_year": 1,\n  "rating": 1,\n  "genre_ids": 1\n}', enabled: true),
        PipelineStage(id: 't3', operator: r'$limit', content: '10', enabled: true),
      ],
    ),
    AggregationPreset(
      id: 'lookup-publishers',
      name: 'Lookup Publishers',
      description: 'Join books collection with publishers',
      stages: [
        PipelineStage(id: 'l1', operator: r'$match', content: '{\n  "published_year": { "\$gte": 2015 }\n}', enabled: true),
        PipelineStage(id: 'l2', operator: r'$lookup', content: '{\n  "from": "publishers",\n  "localField": "publisher_id",\n  "foreignField": "_id",\n  "as": "publisher"\n}', enabled: true),
        PipelineStage(id: 'l3', operator: r'$project', content: '{\n  "title": 1,\n  "published_year": 1,\n  "publisher": 1\n}', enabled: true),
        PipelineStage(id: 'l4', operator: r'$limit', content: '5', enabled: true),
      ],
    ),
    AggregationPreset(
      id: 'count-aggregate',
      name: 'Count Documents',
      description: 'Filter books and count total',
      stages: [
        PipelineStage(id: 'c1', operator: r'$match', content: '{\n  "published_year": { "\$gte": 2015 }\n}', enabled: true),
        PipelineStage(id: 'c2', operator: r'$count', content: '"total_books"', enabled: true),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    final initial = widget.initialPipeline;
    if (initial != null && initial.isNotEmpty) {
      _loadPipelineIntoStages(initial);
    }
    _wasCollLoading =
        mongoEngine.getCollection(widget.dbName, widget.collName)?.isLoading ?? false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runAggregation();
    });
  }

  /// Replaces the visual builder's stages with [pipeline] (a list of
  /// `{ $stage: <value> }` maps), used by "Copy to Aggregations".
  void _loadPipelineIntoStages(List<dynamic> pipeline) {
    for (final c in _stageControllers.values) {
      c.dispose();
    }
    _stageControllers.clear();
    _stages.clear();
    for (var i = 0; i < pipeline.length; i++) {
      final stageMap = pipeline[i];
      if (stageMap is Map && stageMap.isNotEmpty) {
        final op = stageMap.keys.first.toString();
        final val = stageMap[op];
        final content = val is Map || val is List
            ? const JsonEncoder.withIndent('  ').convert(val)
            : (val is String ? '"$val"' : val.toString());
        _stages.add(PipelineStage(
          id: '${DateTime.now().millisecondsSinceEpoch}_$i',
          operator: op,
          content: content,
          enabled: true,
        ));
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final theme = _theme;
    if (!_initializedControllers) {
      _rawController = JsonSyntaxTextController(
        text: _pipelineJsonString(),
        theme: theme,
      );
      _initializedControllers = true;
    } else {
      // Keep syntax colours in sync when the app theme changes.
      _rawController.theme = theme;
      for (final c in _stageControllers.values) {
        c.theme = theme;
      }
    }
  }

  @override
  void didUpdateWidget(covariant AggregationsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dbName != widget.dbName || oldWidget.collName != widget.collName) {
      _runAggregation();
      _wasCollLoading =
          mongoEngine.getCollection(widget.dbName, widget.collName)?.isLoading ?? false;
      return;
    }
    // The first run may have happened while the collection was still streaming
    // into the mirror; re-run once it finishes loading.
    final loading =
        mongoEngine.getCollection(widget.dbName, widget.collName)?.isLoading ?? false;
    if (_wasCollLoading && !loading) {
      _runAggregation();
    }
    _wasCollLoading = loading;
  }

  @override
  void dispose() {
    for (final c in _stageControllers.values) {
      c.dispose();
    }
    _rawController.dispose();
    super.dispose();
  }

  JsonSyntaxTextController _getStageController(PipelineStage stage) {
    var controller = _stageControllers[stage.id];
    if (controller == null) {
      controller = JsonSyntaxTextController(
        text: stage.content,
        theme: _theme,
      );
      _stageControllers[stage.id] = controller;
    }
    return controller;
  }

  List<dynamic> _pipelineArray() {
    final result = <dynamic>[];
    for (final stage in _stages) {
      if (!stage.enabled) continue;
      dynamic parsed;
      try {
        parsed = mongoEngine.tolerantParse(stage.content.replaceAll(RegExp(r'//.*'), ''));
      } catch (_) {
        parsed = <String, dynamic>{};
      }
      result.add({stage.operator: parsed});
    }
    return result;
  }

  String _pipelineJsonString() {
    try {
      return const JsonEncoder.withIndent('  ').convert(_pipelineArray());
    } catch (_) {
      return '[]';
    }
  }

  /// Runs the pipeline. [revealResults] scrolls the Pipeline Results panel into
  /// view (used by the explicit **Run Pipeline** button so the user actually
  /// sees the output; live edits re-run without moving the viewport).
  void _runAggregation({bool revealResults = false}) {
    setState(() {
      _isRunning = true;
      _errorMessage = null;
      _resultPage = 0;
    });

    try {
      QueryResult queryResult;
      if (_activeMode == 'visual') {
        final pipeline = _pipelineArray();
        queryResult = mongoEngine.runAggregation(widget.dbName, widget.collName, pipeline);
      } else {
        final pipeline = mongoEngine.parseAggregationScript(_rawController.text);
        queryResult = mongoEngine.runAggregation(widget.dbName, widget.collName, pipeline);
      }

      setState(() {
        _results = queryResult.documents;
        _totalResultCount = queryResult.totalCount;
        _executionTimeMs = queryResult.executionTimeMs;
        _isRunning = false;
      });
    } catch (err) {
      setState(() {
        _errorMessage = 'Aggregation error: $err';
        _results = [];
        _totalResultCount = 0;
        _isRunning = false;
      });
    }

    if (revealResults) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _resultsKey.currentContext;
        if (ctx != null && mounted) {
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 250),
            alignment: 0.0,
          );
        }
      });
    }
  }

  void _switchMode(String modeKey) {
    if (_activeMode == modeKey) return;
    setState(() {
      _activeMode = modeKey;
      _errorMessage = null;
      if (modeKey == 'raw') {
        _rawController.text = _pipelineJsonString();
      } else {
        try {
          final parsed = mongoEngine.parseAggregationScript(_rawController.text);
          if (parsed.isNotEmpty) {
            for (final c in _stageControllers.values) {
              c.dispose();
            }
            _stageControllers.clear();
            _stages.clear();
            for (var i = 0; i < parsed.length; i++) {
              final stageMap = parsed[i];
              if (stageMap is Map && stageMap.isNotEmpty) {
                final op = stageMap.keys.first.toString();
                final val = stageMap[op];
                final content = val is Map || val is List
                    ? const JsonEncoder.withIndent('  ').convert(val)
                    : (val is String ? '"$val"' : val.toString());
                _stages.add(PipelineStage(
                  id: '${DateTime.now().millisecondsSinceEpoch}_$i',
                  operator: op,
                  content: content,
                  enabled: true,
                ));
              }
            }
          }
        } catch (_) {}
      }
    });
    _runAggregation();
  }

  void _loadPreset(AggregationPreset preset) {
    for (final c in _stageControllers.values) {
      c.dispose();
    }
    _stageControllers.clear();

    setState(() {
      _stages
        ..clear()
        ..addAll(preset.stages.map((s) => s.copyWith()));
      _rawController.text = _pipelineJsonString();
      _operatorPickerStageId = null;
    });
    _runAggregation();
  }

  void _addStage(String operator) {
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    final defaultContent = _defaultTemplates[operator] ?? '{\n}';
    final stage = PipelineStage(
      id: newId,
      operator: operator,
      content: defaultContent,
      enabled: true,
    );
    setState(() {
      _stages.add(stage);
      _rawController.text = _pipelineJsonString();
    });
    _runAggregation();
  }

  void _removeStage(String id) {
    final c = _stageControllers.remove(id);
    c?.dispose();
    setState(() {
      _stages.removeWhere((s) => s.id == id);
      if (_operatorPickerStageId == id) _operatorPickerStageId = null;
      _rawController.text = _pipelineJsonString();
    });
    _runAggregation();
  }

  void _duplicateStage(PipelineStage stage, int index) {
    final newId = DateTime.now().millisecondsSinceEpoch.toString();
    final copy = PipelineStage(
      id: newId,
      operator: stage.operator,
      content: stage.content,
      enabled: stage.enabled,
    );
    setState(() {
      _stages.insert(index + 1, copy);
      _rawController.text = _pipelineJsonString();
    });
    _runAggregation();
  }

  void _moveStageUp(int index) {
    if (index <= 0) return;
    setState(() {
      final s = _stages.removeAt(index);
      _stages.insert(index - 1, s);
      _rawController.text = _pipelineJsonString();
    });
    _runAggregation();
  }

  void _moveStageDown(int index) {
    if (index >= _stages.length - 1) return;
    setState(() {
      final s = _stages.removeAt(index);
      _stages.insert(index + 1, s);
      _rawController.text = _pipelineJsonString();
    });
    _runAggregation();
  }

  void _toggleStageEnabled(PipelineStage stage) {
    setState(() {
      stage.enabled = !stage.enabled;
      _rawController.text = _pipelineJsonString();
    });
    _runAggregation();
  }

  void _changeStageOperator(PipelineStage stage, String newOp) {
    setState(() {
      stage.operator = newOp;
      final template = _defaultTemplates[newOp] ?? '{\n}';
      stage.content = template;
      final controller = _getStageController(stage);
      controller.text = template;
      _operatorPickerStageId = null;
      _rawController.text = _pipelineJsonString();
    });
    _runAggregation();
  }

  void _copyResultsToClipboard() {
    final jsonText = const JsonEncoder.withIndent('  ').convert(
      _results.map((d) => d.data).toList(),
    );
    Clipboard.setData(ClipboardData(text: jsonText));
    setState(() => _isCopied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isCopied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Mode Switcher & Top Action Bar
        _buildActionBar(),

        const SizedBox(height: 10.0),

        // Presets Strip
        _buildPresetsBar(),

        const SizedBox(height: 12.0),

        // Mode Content: Visual or Raw
        if (_activeMode == 'visual')
          _buildVisualBuilder()
        else
          _buildRawEditor(),

        const SizedBox(height: 16.0),

        // Live Pipeline Results Panel
        KeyedSubtree(key: _resultsKey, child: _buildResultsPanel()),
      ],
    );
  }

  /// Mode switcher + primary actions. Stacks when the pane is narrow so the
  /// **Run Pipeline** button is never clipped off-screen (tablets/phones), and
  /// uses finger-sized targets on touch layouts.
  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: _theme.bgPanel,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: _theme.border, width: 1.0),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720.0;
          final switcher = _buildModeSwitcher(compact: compact);
          final actions = Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: [_buildRunButton(), _buildSaveAsViewButton()],
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                switcher,
                const SizedBox(height: 8.0),
                actions,
              ],
            );
          }
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [switcher, actions],
          );
        },
      ),
    );
  }

  /// The Visual/Raw toggle. On a phone there is no room for the per-tab badge,
  /// so the tabs share the row equally and their labels ellipsize.
  Widget _buildModeSwitcher({required bool compact}) {
    return Container(
      padding: const EdgeInsets.all(3.0),
      decoration: BoxDecoration(
        color: _theme.bgSubtle,
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(color: _theme.border, width: 1.0),
      ),
      child: Row(
        mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
        children: [
          if (compact)
            Expanded(
              child: _buildModeTab('visual', 'Visual Pipeline',
                  '${_stages.length} stages', compact: true),
            )
          else
            _buildModeTab('visual', 'Visual Pipeline',
                '${_stages.length} stages'),
          const SizedBox(width: 4.0),
          if (compact)
            Expanded(
              child: _buildModeTab(
                  'raw', 'Raw Aggregations', 'JSON Script', compact: true),
            )
          else
            _buildModeTab('raw', 'Raw Aggregations', 'JSON Script'),
        ],
      ),
    );
  }

  Widget _buildRunButton() {
    final density = CompassDensity.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: density.minTapTarget),
      child: CompassHover(
        onTap: () => _runAggregation(revealResults: true),
        semanticLabel: 'Run pipeline',
        builder: (hovered) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
          decoration: BoxDecoration(
            color: hovered ? _theme.accentHover : _theme.accent,
            borderRadius: BorderRadius.circular(6.0),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CompassSvg(
                svgString: CompassSvgIcons.play,
                size: 13.0,
                color: _theme.onAccent,
              ),
              const SizedBox(width: 6.0),
              Text(
                _isRunning ? 'Running...' : 'Run Pipeline',
                style: CompassTypography.header(color: _theme.onAccent),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSaveAsViewButton() {
    final density = CompassDensity.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: density.minTapTarget),
      child: CompassHover(
        onTap: widget.onSaveAsView == null
            ? null
            : () => widget.onSaveAsView!(_pipelineArray(), _pipelineJsonString()),
        semanticLabel: 'Save pipeline as view',
        builder: (hovered) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
          decoration: BoxDecoration(
            color: CompassColors.warningAmberBg,
            borderRadius: BorderRadius.circular(6.0),
            border: Border.all(color: CompassColors.warningAmberBorder, width: 1.0),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CompassSvg(
                svgString: CompassSvgIcons.eye,
                size: 13.0,
                color: CompassColors.warningAmber,
              ),
              const SizedBox(width: 6.0),
              Text(
                'Save as View',
                style: CompassTypography.bodyMedium(color: CompassColors.warningAmber),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeTab(
    String modeKey,
    String title,
    String badge, {
    bool compact = false,
  }) {
    final isActive = _activeMode == modeKey;
    final titleStyle = isActive
        ? CompassTypography.header(color: _theme.textPrimary)
        : CompassTypography.bodyRegular(color: _theme.textMuted);
    final titleText = Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: titleStyle,
    );

    return GestureDetector(
      onTap: () => _switchMode(modeKey),
      child: Container(
        alignment: compact ? Alignment.center : null,
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: isActive ? _theme.bgPanel : const Color(0x00000000),
          borderRadius: BorderRadius.circular(4.0),
          border: isActive ? Border.all(color: _theme.border, width: 1.0) : null,
        ),
        child: Row(
          mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CompassSvg(
              svgString: modeKey == 'visual' ? CompassSvgIcons.layers : CompassSvgIcons.code,
              size: 13.0,
              color: isActive ? _theme.accent : _theme.textMuted,
            ),
            const SizedBox(width: 6.0),
            if (compact) Flexible(child: titleText) else titleText,
            if (!compact) ...[
              const SizedBox(width: 6.0),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 1.0),
                decoration: BoxDecoration(
                  color: _theme.bgSubtle,
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: Text(
                  badge,
                  style: CompassTypography.caption(color: _theme.textMuted),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPresetsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: _theme.bgPanel,
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(color: _theme.border, width: 1.0),
      ),
      child: Row(
        children: [
          const CompassSvg(
            svgString: CompassSvgIcons.zap,
            size: 13.0,
            color: CompassColors.warningAmber,
          ),
          const SizedBox(width: 8.0),
          Text(
            'Presets:',
            style: CompassTypography.monoBold(color: _theme.textMuted, size: 11.0),
          ),
          const SizedBox(width: 8.0),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final preset in _presets)
                    GestureDetector(
                      onTap: () => _loadPreset(preset),
                      child: Container(
                        margin: const EdgeInsets.only(right: 6.0),
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                        decoration: BoxDecoration(
                          color: _theme.bgSubtle,
                          borderRadius: BorderRadius.circular(4.0),
                          border: Border.all(color: _theme.border, width: 1.0),
                        ),
                        child: Text(
                          preset.name,
                          style: CompassTypography.caption(color: _theme.textSecondary),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisualBuilder() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Controls Strip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: _theme.bgPanel,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: _theme.border, width: 1.0),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 720.0;
              final heading = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CompassSvg(
                    svgString: CompassSvgIcons.layers,
                    size: 14.0,
                    color: _theme.accent,
                  ),
                  const SizedBox(width: 8.0),
                  Flexible(
                    child: Text(
                      'Visual Pipeline Stages',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CompassTypography.header(color: _theme.textPrimary),
                    ),
                  ),
                ],
              );
              // Quick Stage Add Buttons
              final quickAdd = Wrap(
                spacing: 6.0,
                runSpacing: 6.0,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final op in const [r'$match', r'$group', r'$sort', r'$project', r'$limit'])
                    GestureDetector(
                      onTap: () => _addStage(op),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                        decoration: BoxDecoration(
                          color: _theme.bgSubtle,
                          borderRadius: BorderRadius.circular(4.0),
                          border: Border.all(color: _theme.border, width: 1.0),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CompassSvg(
                              svgString: CompassSvgIcons.plus,
                              size: 10.0,
                              color: _theme.accent,
                            ),
                            const SizedBox(width: 4.0),
                            Text(
                              op,
                              style: CompassTypography.monoSmall(color: _theme.accent),
                            ),
                          ],
                        ),
                      ),
                    ),
                  GestureDetector(
                    onTap: () => _addStage(r'$match'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                      decoration: BoxDecoration(
                        color: _theme.accent,
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CompassSvg(
                            svgString: CompassSvgIcons.plus,
                            size: 11.0,
                            color: _theme.onAccent,
                          ),
                          const SizedBox(width: 4.0),
                          Text(
                            'Add Stage',
                            style: CompassTypography.header(color: _theme.onAccent),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    heading,
                    const SizedBox(height: 8.0),
                    quickAdd,
                  ],
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [heading, quickAdd],
              );
            },
          ),
        ),

        const SizedBox(height: 12.0),

        // Stages List
        if (_stages.isEmpty)
          Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: _theme.bgPanel,
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: _theme.border, width: 1.0),
            ),
            child: Center(
              child: Column(
                children: [
                  CompassSvg(
                    svgString: CompassSvgIcons.layers,
                    size: 28.0,
                    color: _theme.textMuted,
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    'No pipeline stages added yet.',
                    style: CompassTypography.bodyMedium(color: _theme.textMuted),
                  ),
                  const SizedBox(height: 8.0),
                  GestureDetector(
                    onTap: () => _addStage(r'$match'),
                    child: Text(
                      '+ Add your first stage',
                      style: CompassTypography.header(color: _theme.accent),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          for (int i = 0; i < _stages.length; i++)
            _buildStageCard(_stages[i], i),
      ],
    );
  }

  Widget _buildStageCard(PipelineStage stage, int index) {
    final isPickerOpen = _operatorPickerStageId == stage.id;
    final controller = _getStageController(stage);

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: _theme.bgPanel,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: stage.enabled ? _theme.border : _theme.border.withValues(alpha: 0.5),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: stage.enabled ? _theme.bgSubtle : _theme.bgApp,
              border: Border(
                bottom: BorderSide(color: _theme.border, width: 1.0),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left: Stage number, Operator Selector, and Enable Toggle.
                // Flexible so the finger-sized action buttons on the right
                // never push this side off the card on a narrow screen.
                Flexible(
                  fit: FlexFit.loose,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Stage ${index + 1}:',
                        style: CompassTypography.monoSmall(color: _theme.textMuted),
                      ),
                      const SizedBox(width: 8.0),

                        // Clickable Operator Selector Badge
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _operatorPickerStageId = isPickerOpen ? null : stage.id;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                            decoration: BoxDecoration(
                              color: _theme.bgInput,
                              borderRadius: BorderRadius.circular(4.0),
                              border: Border.all(
                                color: isPickerOpen ? _theme.accent : _theme.border,
                                width: 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  stage.operator,
                                  style: CompassTypography.monoBold(
                                    color: stage.enabled ? _theme.accent : _theme.textMuted,
                                    size: 12.0,
                                  ),
                                ),
                                const SizedBox(width: 4.0),
                                CompassSvg(
                                  svgString: isPickerOpen ? CompassSvgIcons.chevronUp : CompassSvgIcons.chevronDown,
                                  size: 11.0,
                                  color: _theme.textMuted,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10.0),

                        // Enable / Disable Checkbox Button
                        GestureDetector(
                          onTap: () => _toggleStageEnabled(stage),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                            decoration: BoxDecoration(
                              color: stage.enabled
                                  ? _theme.greenBadgeBg
                                  : _theme.bgSubtle,
                              borderRadius: BorderRadius.circular(4.0),
                              border: Border.all(
                                color: stage.enabled
                                    ? _theme.greenBadgeBorder
                                    : _theme.border,
                                width: 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CompassSvg(
                                  svgString: stage.enabled ? CompassSvgIcons.check : CompassSvgIcons.close,
                                  size: 10.0,
                                  color: stage.enabled ? _theme.accent : _theme.textMuted,
                                ),
                                const SizedBox(width: 4.0),
                                Text(
                                  stage.enabled ? 'Enabled' : 'Disabled',
                                  style: CompassTypography.caption(
                                    color: stage.enabled ? _theme.accent : _theme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Right: Reorder, Duplicate, and Delete buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Move Up
                    if (index > 0)
                      CompassIconButton(
                        svgString: CompassSvgIcons.chevronUp,
                        onTap: () => _moveStageUp(index),
                        size: 13.0,
                        padding: 5.0,
                        color: _theme.textMuted,
                        semanticLabel: 'Move stage up',
                      ),
                    // Move Down
                    if (index < _stages.length - 1)
                      CompassIconButton(
                        svgString: CompassSvgIcons.chevronDown,
                        onTap: () => _moveStageDown(index),
                        size: 13.0,
                        padding: 5.0,
                        color: _theme.textMuted,
                        semanticLabel: 'Move stage down',
                      ),
                    const SizedBox(width: 4.0),
                    // Duplicate Stage
                    CompassIconButton(
                      svgString: CompassSvgIcons.copy,
                      onTap: () => _duplicateStage(stage, index),
                      size: 13.0,
                      padding: 5.0,
                      color: _theme.textMuted,
                      semanticLabel: 'Duplicate stage',
                    ),
                    const SizedBox(width: 4.0),
                    // Delete Stage
                    CompassIconButton(
                      svgString: CompassSvgIcons.trash,
                      onTap: () => _removeStage(stage.id),
                      size: 13.0,
                      padding: 5.0,
                      color: CompassColors.errorRed,
                      semanticLabel: 'Delete stage',
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Inline Operator Picker Row (when clicked)
          if (isPickerOpen)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              color: _theme.bgPanel,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select Stage Operator:',
                    style: CompassTypography.caption(color: _theme.textMuted),
                  ),
                  const SizedBox(height: 6.0),
                  Wrap(
                    spacing: 6.0,
                    runSpacing: 6.0,
                    children: [
                      for (final op in _availableOperators)
                        GestureDetector(
                          onTap: () => _changeStageOperator(stage, op),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                            decoration: BoxDecoration(
                              color: op == stage.operator
                                  ? _theme.greenBadgeBg
                                  : _theme.bgSubtle,
                              borderRadius: BorderRadius.circular(4.0),
                              border: Border.all(
                                color: op == stage.operator
                                    ? _theme.accent
                                    : _theme.border,
                                width: 1.0,
                              ),
                            ),
                            child: Text(
                              op,
                              style: CompassTypography.monoSmall(
                                color: op == stage.operator
                                    ? _theme.accent
                                    : _theme.textSecondary,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

          // Editable Code Area
          Container(
            padding: const EdgeInsets.all(10.0),
            color: _theme.bgInput,
            child: CompassInput(
              controller: controller,
              maxLines: 7,
              minLines: 3,
              minLinesAuto: false,
              mono: true,
              autoIndent: true,
              placeholder: '{\n  // stage definition\n}',
              onChanged: (newText) {
                stage.content = newText;
                _rawController.text = _pipelineJsonString();
                _runAggregation();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRawEditor() {
    return Container(
      decoration: BoxDecoration(
        color: _theme.bgPanel,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: _theme.border, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: _theme.bgSubtle,
              border: Border(
                bottom: BorderSide(color: _theme.border, width: 1.0),
              ),
            ),
            child: Text(
              'AGGREGATION SCRIPT (JSON OR SHELL)',
              style: CompassTypography.monoBold(color: _theme.textMuted, size: 11.0),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10.0),
            color: _theme.bgInput,
            child: CompassInput(
              controller: _rawController,
              maxLines: 14,
              minLines: 8,
              minLinesAuto: false,
              mono: true,
              autoIndent: true,
              placeholder: '[\n  { "\$match": { ... } }\n]',
              onChanged: (_) {
                // Update on typing
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Prev/next pager for the results preview ([start]..[end) of [total]).
  Widget _buildResultPager(int start, int end, int total) {
    final canPrev = start > 0;
    final canNext = end < total;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CompassIconButton(
          svgString: CompassSvgIcons.chevronLeft,
          onTap: canPrev ? () => setState(() => _resultPage--) : null,
          size: 12.0,
          padding: 2.0,
          color: canPrev ? _theme.textSecondary : _theme.border,
          semanticLabel: 'Previous results page',
        ),
        Text(
          '${start + 1}–$end of $total',
          style: CompassTypography.monoSmall(color: _theme.textMuted),
        ),
        CompassIconButton(
          svgString: CompassSvgIcons.chevronRight,
          onTap: canNext ? () => setState(() => _resultPage++) : null,
          size: 12.0,
          padding: 2.0,
          color: canNext ? _theme.textSecondary : _theme.border,
          semanticLabel: 'Next results page',
        ),
      ],
    );
  }

  Widget _buildResultsPanel() {
    // Only a page-sized preview of the results is rendered at a time.
    final total = _results.length;
    final pageCount = total == 0 ? 1 : (total / _resultPageSize).ceil();
    final page = _resultPage.clamp(0, pageCount - 1);
    final start = page * _resultPageSize;
    final end = (start + _resultPageSize) < total ? (start + _resultPageSize) : total;
    final pageResults =
        total == 0 ? const <MongoDocument>[] : _results.sublist(start, end);

    final formattedResultsJson = const JsonEncoder.withIndent('  ').convert(
      pageResults.map((d) => d.data).toList(),
    );

    return Container(
      decoration: BoxDecoration(
        color: _theme.bgPanel,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: _theme.border, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Results Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
            decoration: BoxDecoration(
              color: _theme.bgSubtle,
              border: Border(
                bottom: BorderSide(color: _theme.border, width: 1.0),
              ),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 8.0,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CompassSvg(
                      svgString: CompassSvgIcons.table,
                      size: 14.0,
                      color: _theme.accent,
                    ),
                    const SizedBox(width: 8.0),
                    Flexible(
                      child: Text(
                        'Pipeline Results',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: CompassTypography.header(color: _theme.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                        decoration: BoxDecoration(
                          color: _theme.bgInput,
                          borderRadius: BorderRadius.circular(10.0),
                          border: Border.all(color: _theme.border, width: 1.0),
                        ),
                        child: Text(
                          '$_totalResultCount docs (${_executionTimeMs.toStringAsFixed(1)} ms)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: CompassTypography.monoSmall(color: _theme.textMuted),
                        ),
                      ),
                    ),
                    if (total > 0) ...[
                      const SizedBox(width: 8.0),
                      _buildResultPager(start, end, total),
                    ],
                  ],
                ),

                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // View Mode Switcher: JSON / Table
                    Container(
                      padding: const EdgeInsets.all(2.0),
                      decoration: BoxDecoration(
                        color: _theme.bgInput,
                        borderRadius: BorderRadius.circular(4.0),
                        border: Border.all(color: _theme.border, width: 1.0),
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () => setState(() => _resultViewMode = 'json'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                              decoration: BoxDecoration(
                                color: _resultViewMode == 'json' ? _theme.bgSubtle : const Color(0x00000000),
                                borderRadius: BorderRadius.circular(3.0),
                              ),
                              child: Text(
                                'JSON',
                                style: CompassTypography.caption(
                                  color: _resultViewMode == 'json'
                                      ? _theme.textPrimary
                                      : _theme.textMuted,
                                ),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _resultViewMode = 'table'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                              decoration: BoxDecoration(
                                color: _resultViewMode == 'table' ? _theme.bgSubtle : const Color(0x00000000),
                                borderRadius: BorderRadius.circular(3.0),
                              ),
                              child: Text(
                                'Table',
                                style: CompassTypography.caption(
                                  color: _resultViewMode == 'table'
                                      ? _theme.textPrimary
                                      : _theme.textMuted,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8.0),

                    // Copy Results Button
                    GestureDetector(
                      onTap: _copyResultsToClipboard,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                        decoration: BoxDecoration(
                          color: _theme.bgSubtle,
                          borderRadius: BorderRadius.circular(4.0),
                          border: Border.all(color: _theme.border, width: 1.0),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CompassSvg(
                              svgString: _isCopied ? CompassSvgIcons.check : CompassSvgIcons.copy,
                              size: 12.0,
                              color: _isCopied ? _theme.accent : _theme.textSecondary,
                            ),
                            const SizedBox(width: 4.0),
                            Text(
                              _isCopied ? 'Copied!' : 'Copy',
                              style: CompassTypography.caption(
                                color: _isCopied ? _theme.accent : _theme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Error banner if any
          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(12.0),
              color: CompassColors.errorRed.withValues(alpha: 0.15),
              child: Text(
                _errorMessage!,
                style: CompassTypography.bodyRegular(color: CompassColors.errorRed),
              ),
            ),

          // Results Viewer
          if (_results.isEmpty && _errorMessage == null)
            Container(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Text(
                  'No documents matched the aggregation pipeline.',
                  style: CompassTypography.bodyRegular(color: _theme.textMuted),
                ),
              ),
            )
          else if (_resultViewMode == 'json')
            Container(
              padding: const EdgeInsets.all(12.0),
              color: _theme.bgInput,
              constraints: const BoxConstraints(maxHeight: 400.0),
              child: SingleChildScrollView(
                child: Text.rich(
                  buildJsonSyntaxSpan(
                    formattedResultsJson,
                    style: CompassTypography.monoRegular(
                      color: _theme.textPrimary,
                      size: 12.0,
                    ),
                    theme: _theme,
                  ),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12.0),
              color: _theme.bgInput,
              constraints: const BoxConstraints(maxHeight: 400.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (int i = 0; i < pageResults.length; i++)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6.0),
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: _theme.bgPanel,
                          borderRadius: BorderRadius.circular(4.0),
                          border: Border.all(color: _theme.border, width: 1.0),
                        ),
                        child: Text.rich(
                          buildJsonSyntaxSpan(
                            jsonEncode(pageResults[i].data),
                            style: CompassTypography.monoRegular(
                              color: _theme.textPrimary,
                              size: 11.0,
                            ),
                            theme: _theme,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
