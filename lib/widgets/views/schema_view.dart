import 'dart:async';

import 'package:flutter/widgets.dart';
import '../../theme/compass_colors.dart';
import '../../theme/compass_theme.dart';
import '../../theme/compass_typography.dart';
import '../../icons/compass_svg_icons.dart';
import '../../models/mongo_models.dart';
import '../../services/mongo_engine.dart';

/// Converted from src/components/SchemaView.tsx
/// Adheres strictly to:
/// 1. Layout & Flexbox (Column, Row, multi-color horizontal distribution bar)
/// 2. Color & Styling (CompassColors, type badges, rounded-full distribution bar)
/// 3. Typography (CompassTypography with JetBrains Mono)
/// 4. Platform Agnosticism (desktop styled schema cards)
/// 5. Icons (CompassSvg instead of generic Icon)
///
/// Like the React reference, this view owns its analysis state: `fields` and
/// `isAnalyzing` live here (not in `main.dart`). Analysis runs automatically
/// on open and whenever `dbName`/`collName` change, and the "Analyze Schema"
/// button re-runs it after a simulated 250 ms delay (the reference's
/// `setTimeout(..., 250)`) so every press shows visible feedback. Unlike the
/// reference the icon does not spin (the app has no animation infrastructure;
/// the label + disabled state carry the feedback instead).
class SchemaView extends StatefulWidget {
  final String dbName;
  final String collName;

  const SchemaView({
    super.key,
    required this.dbName,
    required this.collName,
  });

  @override
  State<SchemaView> createState() => _SchemaViewState();
}

class _SchemaViewState extends State<SchemaView> {
  List<SchemaFieldStat> _fields = [];
  bool _isAnalyzing = false;
  Timer? _analysisTimer;

  @override
  void initState() {
    super.initState();
    _startAnalysis();
  }

  @override
  void didUpdateWidget(covariant SchemaView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dbName != widget.dbName ||
        oldWidget.collName != widget.collName) {
      // No setState here: didUpdateWidget runs during the build phase and is
      // always followed by a build, which picks up the new `_isAnalyzing`.
      _startAnalysis();
    }
  }

  @override
  void dispose() {
    _analysisTimer?.cancel();
    super.dispose();
  }

  /// Port of `analyze()` in src/components/SchemaView.tsx: flip to the
  /// analyzing state, then recompute the stats after the reference's 250 ms
  /// delay. Called from lifecycle hooks (which are followed by a build, so no
  /// setState) and from the button via `setState(_startAnalysis)`.
  void _startAnalysis() {
    _analysisTimer?.cancel();
    _isAnalyzing = true;
    _analysisTimer = Timer(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() {
        _fields = mongoEngine.analyzeSchema(widget.dbName, widget.collName);
        _isAnalyzing = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = CompassTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header Bar
        Container(
          padding: const EdgeInsets.all(14.0),
          decoration: BoxDecoration(
            color: theme.bgPanel,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: theme.border, width: 1.0),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 620.0;
              final heading = Row(
                children: [
                  CompassSvg(
                    svgString: CompassSvgIcons.barChart,
                    size: 16.0,
                    color: theme.accent,
                  ),
                  const SizedBox(width: 8.0),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Schema Analysis',
                          style: CompassTypography.header(color: theme.textPrimary),
                        ),
                        Text(
                          'Analyzed ${_fields.length} unique fields in ${widget.collName}',
                          style: CompassTypography.caption(color: theme.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              );
              // Disabled while an analysis runs (reference: disabled={isAnalyzing}
              // with disabled:opacity-50), label toggles to "Analyzing...".
              final analyzeButton = GestureDetector(
                onTap: _isAnalyzing ? null : () => setState(_startAnalysis),
                child: Opacity(
                  opacity: _isAnalyzing ? 0.5 : 1.0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 7.0),
                    decoration: BoxDecoration(
                      color: theme.accent,
                      borderRadius: BorderRadius.circular(6.0),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CompassSvg(
                          svgString: CompassSvgIcons.rotateCcw,
                          size: 13.0,
                          color: theme.onAccent,
                        ),
                        const SizedBox(width: 6.0),
                        Text(
                          _isAnalyzing ? 'Analyzing...' : 'Analyze Schema',
                          maxLines: 1,
                          style: CompassTypography.header(color: theme.onAccent),
                        ),
                      ],
                    ),
                  ),
                ),
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    heading,
                    const SizedBox(height: 10.0),
                    Align(
                      alignment: Alignment.centerRight,
                      child: analyzeButton,
                    ),
                  ],
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: heading),
                  const SizedBox(width: 12.0),
                  analyzeButton,
                ],
              );
            },
          ),
        ),

        const SizedBox(height: 12.0),

        // Field Cards
        for (final field in _fields)
          _buildFieldCard(theme, field),
      ],
    );
  }

  Widget _buildFieldCard(CompassTheme theme, SchemaFieldStat field) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: theme.bgPanel,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: theme.border, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Row: Path & Types
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520.0;
              final path = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      field.path,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CompassTypography.monoBold(color: theme.textPrimary, size: 12.0),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  Text(
                    '(${field.distinctCount} distinct)',
                    style: CompassTypography.caption(color: theme.textMuted),
                  ),
                ],
              );
              final types = Wrap(
                spacing: 4.0,
                runSpacing: 4.0,
                children: [
                  for (final t in field.types)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                      decoration: BoxDecoration(
                        color: _getTypeColor(t.type, theme).withAlpha(30),
                        borderRadius: BorderRadius.circular(4.0),
                        border: Border.all(
                          color: _getTypeColor(t.type, theme).withAlpha(70),
                          width: 1.0,
                        ),
                      ),
                      child: Text(
                        '${t.type} (${t.percentage}%)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: CompassTypography.monoSmall(color: _getTypeColor(t.type, theme)),
                      ),
                    ),
                ],
              );
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    path,
                    const SizedBox(height: 6.0),
                    types,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: path),
                  const SizedBox(width: 8.0),
                  Flexible(child: types),
                ],
              );
            },
          ),

          const SizedBox(height: 8.0),

          // Middle Row: Multi-color Distribution Bar (8px height)
          ClipRRect(
            borderRadius: BorderRadius.circular(4.0),
            child: Container(
              height: 8.0,
              decoration: BoxDecoration(color: theme.bgSubtle),
              child: Row(
                children: [
                  for (final t in field.types)
                    Expanded(
                      flex: t.percentage > 0 ? t.percentage : 1,
                      child: Container(color: _getTypeColor(t.type, theme)),
                    ),
                  if (field.missingPercentage > 0)
                    Expanded(
                      flex: field.missingPercentage,
                      child: Container(color: CompassColors.errorRed.withAlpha(150)),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8.0),

          // Bottom Row: Sample Values
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 520.0;
              final chipMaxWidth =
                  constraints.maxWidth < 160.0 ? constraints.maxWidth : 160.0;
              final samples = Wrap(
                spacing: 6.0,
                runSpacing: 4.0,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Sample values: ',
                    style: CompassTypography.caption(color: theme.textMuted),
                  ),
                  for (final sample in field.sampleValues.take(3))
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: chipMaxWidth),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                        decoration: BoxDecoration(
                          color: theme.bgInput,
                          borderRadius: BorderRadius.circular(4.0),
                          border: Border.all(color: theme.border, width: 1.0),
                        ),
                        child: Text(
                          '$sample',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: CompassTypography.monoSmall(color: theme.textSecondary),
                        ),
                      ),
                    ),
                ],
              );
              final range = field.min != null || field.max != null
                  ? Text(
                      'min: ${field.min}  max: ${field.max}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CompassTypography.monoSmall(color: theme.textSecondary),
                    )
                  : null;
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    samples,
                    if (range != null) ...[
                      const SizedBox(height: 4.0),
                      range,
                    ],
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: samples),
                  if (range != null) ...[
                    const SizedBox(width: 12.0),
                    Flexible(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: range,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Color _getTypeColor(String type, CompassTheme theme) {
    switch (type) {
      case 'ObjectId':
        return theme.accent;
      case 'String':
        return theme.bsonString;
      case 'number':
      case 'Int32':
      case 'Double':
        return theme.bsonNumber;
      case 'Boolean':
        return theme.bsonBoolean;
      case 'Date':
        return theme.bsonDate;
      case 'Array':
        return CompassColors.cyanBadge;
      default:
        return theme.textSecondary;
    }
  }
}
