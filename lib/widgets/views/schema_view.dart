import 'package:flutter/widgets.dart';
import '../../theme/compass_colors.dart';
import '../../theme/compass_typography.dart';
import '../../icons/compass_svg_icons.dart';
import '../../models/mongo_models.dart';

/// Converted from src/components/SchemaView.tsx
/// Adheres strictly to:
/// 1. Layout & Flexbox (Column, Row, multi-color horizontal distribution bar)
/// 2. Color & Styling (CompassColors, type badges, rounded-full distribution bar)
/// 3. Typography (CompassTypography with JetBrains Mono)
/// 4. Platform Agnosticism (desktop styled schema cards)
/// 5. Icons (CompassSvg instead of generic Icon)
class SchemaView extends StatelessWidget {
  final String dbName;
  final String collName;
  final List<SchemaFieldStat> fields;
  final VoidCallback onAnalyze;

  const SchemaView({
    super.key,
    required this.dbName,
    required this.collName,
    required this.fields,
    required this.onAnalyze,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header Bar
        Container(
          padding: const EdgeInsets.all(14.0),
          decoration: BoxDecoration(
            color: CompassColors.darkBgPanel,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: CompassColors.darkBorder, width: 1.0),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const CompassSvg(
                    svgString: CompassSvgIcons.barChart,
                    size: 16.0,
                    color: CompassColors.greenAccent,
                  ),
                  const SizedBox(width: 8.0),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Schema Analysis', style: CompassTypography.header()),
                      Text(
                        'Analyzed ${fields.length} unique fields in $collName',
                        style: CompassTypography.caption(),
                      ),
                    ],
                  ),
                ],
              ),
              GestureDetector(
                onTap: onAnalyze,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 7.0),
                  decoration: BoxDecoration(
                    color: CompassColors.greenAccent,
                    borderRadius: BorderRadius.circular(6.0),
                  ),
                  child: Row(
                    children: [
                      const CompassSvg(
                        svgString: CompassSvgIcons.rotateCcw,
                        size: 13.0,
                        color: CompassColors.greenNavy,
                      ),
                      const SizedBox(width: 6.0),
                      Text(
                        'Analyze Schema',
                        style: CompassTypography.header(color: CompassColors.greenNavy),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12.0),

        // Field Cards
        for (final field in fields)
          _buildFieldCard(field),
      ],
    );
  }

  Widget _buildFieldCard(SchemaFieldStat field) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: CompassColors.darkBgPanel,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: CompassColors.darkBorder, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Row: Path & Types
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    field.path,
                    style: CompassTypography.monoBold(color: CompassColors.darkTextPrimary, size: 12.0),
                  ),
                  const SizedBox(width: 8.0),
                  Text(
                    '(${field.distinctCount} distinct)',
                    style: CompassTypography.caption(color: CompassColors.darkTextMuted),
                  ),
                ],
              ),
              Row(
                children: [
                  for (final t in field.types)
                    Container(
                      margin: const EdgeInsets.only(left: 4.0),
                      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                      decoration: BoxDecoration(
                        color: _getTypeColor(t.type).withAlpha(30),
                        borderRadius: BorderRadius.circular(4.0),
                        border: Border.all(color: _getTypeColor(t.type).withAlpha(70), width: 1.0),
                      ),
                      child: Text(
                        '${t.type} (${t.percentage}%)',
                        style: CompassTypography.monoSmall(color: _getTypeColor(t.type)),
                      ),
                    ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 8.0),

          // Middle Row: Multi-color Distribution Bar (8px height)
          ClipRRect(
            borderRadius: BorderRadius.circular(4.0),
            child: Container(
              height: 8.0,
              decoration: const BoxDecoration(color: CompassColors.darkBgSubtle),
              child: Row(
                children: [
                  for (final t in field.types)
                    Expanded(
                      flex: t.percentage > 0 ? t.percentage : 1,
                      child: Container(color: _getTypeColor(t.type)),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text('Sample values: ', style: CompassTypography.caption(color: CompassColors.darkTextMuted)),
                  for (final sample in field.sampleValues.take(3))
                    Container(
                      margin: const EdgeInsets.only(right: 6.0),
                      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                      decoration: BoxDecoration(
                        color: CompassColors.darkBgInput,
                        borderRadius: BorderRadius.circular(4.0),
                        border: Border.all(color: CompassColors.darkBorder, width: 1.0),
                      ),
                      child: Text(
                        '$sample',
                        style: CompassTypography.monoSmall(color: CompassColors.darkTextSecondary),
                      ),
                    ),
                ],
              ),
              if (field.min != null || field.max != null)
                Row(
                  children: [
                    Text('min: ${field.min}  ', style: CompassTypography.monoSmall()),
                    Text('max: ${field.max}', style: CompassTypography.monoSmall()),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'ObjectId':
        return CompassColors.greenAccent;
      case 'String':
        return CompassColors.bsonString;
      case 'number':
      case 'Int32':
      case 'Double':
        return CompassColors.bsonNumber;
      case 'Boolean':
        return CompassColors.bsonBoolean;
      case 'Date':
        return CompassColors.bsonDate;
      case 'Array':
        return CompassColors.cyanBadge;
      default:
        return CompassColors.darkTextSecondary;
    }
  }
}
