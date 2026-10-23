import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../../icons/compass_svg_icons.dart';
import '../../models/mongo_models.dart';
import '../../services/mongo_engine.dart';
import '../../theme/compass_colors.dart';
import '../../theme/compass_theme.dart';
import '../../theme/compass_typography.dart';
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
  r'$match': '{\n  "published_year": { "\$gte": 2015 }\n}',
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

/// MongoDB Compass Aggregations Pipeline Builder and Runner.
/// Supports visual stage editing, operator changing, stage reordering,
/// raw JSON/mongosh script execution, and interactive live pipeline results.
class AggregationsView extends StatefulWidget {
  final String dbName;
  final String collName;
  final Function(List<dynamic> pipeline, String pipelineJson)? onSaveAsView;
  final VoidCallback? onExportCode;

  const AggregationsView({
    super.key,
    required this.dbName,
    required this.collName,
    this.onSaveAsView,
    this.onExportCode,
  });

  @override
  State<AggregationsView> createState() => _AggregationsViewState();
}

class _AggregationsViewState extends State<AggregationsView> {
  CompassTheme get _theme => CompassTheme.of(context);

  String _activeMode = 'visual'; // 'visual' or 'raw'

  final List<PipelineStage> _stages = [
    PipelineStage(
      id: '1',
      operator: r'$match',
      content: '{\n  "published_year": { "\$gte": 2015 }\n}',
      enabled: true,
    ),
    PipelineStage(
      id: '2',
      operator: r'$group',
      content: '{\n  "_id": "\$publisher_id",\n  "count": { "\$sum": 1 },\n  "avgRating": { "\$avg": "\$rating" }\n}',
      enabled: true,
    ),
    PipelineStage(
      id: '3',
      operator: r'$sort',
      content: '{\n  "_id": -1\n}',
      enabled: true,
    ),
  ];

  final Map<String, TextEditingController> _stageControllers = {};
  late final TextEditingController _rawController;

  String? _operatorPickerStageId;
  List<MongoDocument> _results = [];
  int _totalResultCount = 0;
  double _executionTimeMs = 0.0;
  String? _errorMessage;
  bool _isRunning = false;
  bool _isCopied = false;
  String _resultViewMode = 'json'; // 'json' or 'table'

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
    _rawController = TextEditingController(text: _pipelineJsonString());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runAggregation();
    });
  }

  @override
  void didUpdateWidget(covariant AggregationsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dbName != widget.dbName || oldWidget.collName != widget.collName) {
      _runAggregation();
    }
  }

  @override
  void dispose() {
    for (final c in _stageControllers.values) {
      c.dispose();
    }
    _rawController.dispose();
    super.dispose();
  }

  TextEditingController _getStageController(PipelineStage stage) {
    var controller = _stageControllers[stage.id];
    if (controller == null) {
      controller = TextEditingController(text: stage.content);
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

  void _runAggregation() {
    setState(() {
      _isRunning = true;
      _errorMessage = null;
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
        Container(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: _theme.bgPanel,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: _theme.border, width: 1.0),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Segmented Tab Switcher (Visual vs Raw)
              Container(
                padding: const EdgeInsets.all(3.0),
                decoration: BoxDecoration(
                  color: _theme.bgSubtle,
                  borderRadius: BorderRadius.circular(6.0),
                  border: Border.all(color: _theme.border, width: 1.0),
                ),
                child: Row(
                  children: [
                    _buildModeTab('visual', 'Visual Pipeline', '${_stages.length} stages'),
                    const SizedBox(width: 4.0),
                    _buildModeTab('raw', 'Raw Aggregations', 'JSON Script'),
                  ],
                ),
              ),

              // Action Buttons
              Row(
                children: [
                  // Run Aggregation Button
                  GestureDetector(
                    onTap: _runAggregation,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                      decoration: BoxDecoration(
                        color: _theme.accent,
                        borderRadius: BorderRadius.circular(6.0),
                      ),
                      child: Row(
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
                  const SizedBox(width: 8.0),

                  // Save as View
                  GestureDetector(
                    onTap: widget.onSaveAsView == null
                        ? null
                        : () => widget.onSaveAsView!(_pipelineArray(), _pipelineJsonString()),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                      decoration: BoxDecoration(
                        color: CompassColors.warningAmberBg,
                        borderRadius: BorderRadius.circular(6.0),
                        border: Border.all(color: CompassColors.warningAmberBorder, width: 1.0),
                      ),
                      child: Row(
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
                  const SizedBox(width: 8.0),

                  // Export Code
                  GestureDetector(
                    onTap: widget.onExportCode,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                      decoration: BoxDecoration(
                        color: _theme.bgSubtle,
                        borderRadius: BorderRadius.circular(6.0),
                        border: Border.all(color: _theme.border, width: 1.0),
                      ),
                      child: Row(
                        children: [
                          CompassSvg(
                            svgString: CompassSvgIcons.code,
                            size: 13.0,
                            color: _theme.accent,
                          ),
                          const SizedBox(width: 6.0),
                          Text(
                            'Export Code',
                            style: CompassTypography.bodyMedium(color: _theme.textSecondary),
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
        _buildResultsPanel(),
      ],
    );
  }

  Widget _buildModeTab(String modeKey, String title, String badge) {
    final isActive = _activeMode == modeKey;
    return GestureDetector(
      onTap: () => _switchMode(modeKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: isActive ? _theme.bgPanel : const Color(0x00000000),
          borderRadius: BorderRadius.circular(4.0),
          border: isActive ? Border.all(color: _theme.border, width: 1.0) : null,
        ),
        child: Row(
          children: [
            CompassSvg(
              svgString: modeKey == 'visual' ? CompassSvgIcons.layers : CompassSvgIcons.code,
              size: 13.0,
              color: isActive ? _theme.accent : _theme.textMuted,
            ),
            const SizedBox(width: 6.0),
            Text(
              title,
              style: isActive
                  ? CompassTypography.header(color: _theme.textPrimary)
                  : CompassTypography.bodyRegular(color: _theme.textMuted),
            ),
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CompassSvg(
                    svgString: CompassSvgIcons.layers,
                    size: 14.0,
                    color: _theme.accent,
                  ),
                  const SizedBox(width: 8.0),
                  Text(
                    'Visual Pipeline Stages',
                    style: CompassTypography.header(color: _theme.textPrimary),
                  ),
                ],
              ),
              // Quick Stage Add Buttons
              Wrap(
                spacing: 6.0,
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
              ),
            ],
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'AGGREGATION SCRIPT (JSON OR MONGOSH)',
                  style: CompassTypography.monoBold(color: _theme.textMuted, size: 11.0),
                ),
                GestureDetector(
                  onTap: _runAggregation,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
                    decoration: BoxDecoration(
                      color: _theme.accent,
                      borderRadius: BorderRadius.circular(4.0),
                    ),
                    child: Row(
                      children: [
                        CompassSvg(
                          svgString: CompassSvgIcons.play,
                          size: 11.0,
                          color: _theme.onAccent,
                        ),
                        const SizedBox(width: 4.0),
                        Text(
                          'Run Aggregation',
                          style: CompassTypography.header(color: _theme.onAccent),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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

  Widget _buildResultsPanel() {
    final formattedResultsJson = const JsonEncoder.withIndent('  ').convert(
      _results.map((d) => d.data).toList(),
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CompassSvg(
                      svgString: CompassSvgIcons.table,
                      size: 14.0,
                      color: _theme.accent,
                    ),
                    const SizedBox(width: 8.0),
                    Text(
                      'Pipeline Results',
                      style: CompassTypography.header(color: _theme.textPrimary),
                    ),
                    const SizedBox(width: 8.0),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                      decoration: BoxDecoration(
                        color: _theme.bgInput,
                        borderRadius: BorderRadius.circular(10.0),
                        border: Border.all(color: _theme.border, width: 1.0),
                      ),
                      child: Text(
                        '$_totalResultCount docs (${_executionTimeMs.toStringAsFixed(1)} ms)',
                        style: CompassTypography.monoSmall(color: _theme.textMuted),
                      ),
                    ),
                  ],
                ),

                Row(
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
                child: Text(
                  formattedResultsJson,
                  style: CompassTypography.monoRegular(color: _theme.textPrimary, size: 12.0),
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
                    for (int i = 0; i < _results.length; i++)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6.0),
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: _theme.bgPanel,
                          borderRadius: BorderRadius.circular(4.0),
                          border: Border.all(color: _theme.border, width: 1.0),
                        ),
                        child: Text(
                          jsonEncode(_results[i].data),
                          style: CompassTypography.monoRegular(color: _theme.textPrimary, size: 11.0),
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
