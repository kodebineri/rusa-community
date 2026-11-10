import 'package:flutter/widgets.dart';
import '../../theme/compass_colors.dart';
import '../../theme/compass_theme.dart';
import '../../theme/compass_typography.dart';
import '../../icons/compass_svg_icons.dart';
import '../../models/mongo_models.dart';
import '../compass_icon_button.dart';

/// Converted from src/components/IndexesView.tsx
/// Adheres strictly to:
/// 1. Layout & Flexbox (Column, Row, index table layout)
/// 2. Color & Styling (CompassColors, properties badges, borders)
/// 3. Typography (CompassTypography with JetBrains Mono)
/// 4. Platform Agnosticism (desktop styled indexes manager)
/// 5. Icons (CompassSvg instead of generic Icon)
class IndexesView extends StatelessWidget {
  final String dbName;
  final String collName;
  final List<MongoIndex> indexes;
  final VoidCallback onCreateIndex;
  final Function(String indexName) onDropIndex;

  const IndexesView({
    super.key,
    required this.dbName,
    required this.collName,
    required this.indexes,
    required this.onCreateIndex,
    required this.onDropIndex,
  });

  @override
  Widget build(BuildContext context) {
    final theme = CompassTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
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
                    svgString: CompassSvgIcons.key,
                    size: 16.0,
                    color: theme.accent,
                  ),
                  const SizedBox(width: 8.0),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Indexes', style: CompassTypography.header(color: theme.textPrimary)),
                        Text(
                          'Indexes support efficient execution of queries in MongoDB.',
                          style: CompassTypography.caption(color: theme.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              );
              final createButton = GestureDetector(
                onTap: onCreateIndex,
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
                        svgString: CompassSvgIcons.plus,
                        size: 13.0,
                        color: theme.onAccent,
                      ),
                      const SizedBox(width: 4.0),
                      Text(
                        'Create Index',
                        maxLines: 1,
                        style: CompassTypography.header(color: theme.onAccent),
                      ),
                    ],
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
                      child: createButton,
                    ),
                  ],
                );
              }
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: heading),
                  const SizedBox(width: 12.0),
                  createButton,
                ],
              );
            },
          ),
        ),

        const SizedBox(height: 12.0),

        // Indexes Table
        Container(
          decoration: BoxDecoration(
            color: theme.bgPanel,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: theme.border, width: 1.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row
              Container(
                height: 38.0,
                padding: const EdgeInsets.symmetric(horizontal: 14.0),
                decoration: BoxDecoration(
                  color: theme.bgSubtle,
                  border: Border(
                    bottom: BorderSide(color: theme.border, width: 1.0),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text('INDEX NAME', maxLines: 1, overflow: TextOverflow.ellipsis, style: CompassTypography.monoBold(color: theme.textMuted, size: 10.0)),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text('FIELDS & ORDER', maxLines: 1, overflow: TextOverflow.ellipsis, style: CompassTypography.monoBold(color: theme.textMuted, size: 10.0)),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text('PROPERTIES', maxLines: 1, overflow: TextOverflow.ellipsis, style: CompassTypography.monoBold(color: theme.textMuted, size: 10.0)),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text('SIZE', maxLines: 1, overflow: TextOverflow.ellipsis, style: CompassTypography.monoBold(color: theme.textMuted, size: 10.0)),
                    ),
                    Container(
                      width: 70.0,
                      alignment: Alignment.centerRight,
                      child: Text('ACTIONS', maxLines: 1, overflow: TextOverflow.ellipsis, style: CompassTypography.monoBold(color: theme.textMuted, size: 10.0)),
                    ),
                  ],
                ),
              ),

              // Rows
              for (final idx in indexes)
                Container(
                  height: 42.0,
                  padding: const EdgeInsets.symmetric(horizontal: 14.0),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: theme.border, width: 1.0),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Name
                      Expanded(
                        flex: 2,
                        child: Row(
                          children: [
                            if (idx.name == '_id_') ...[
                              CompassSvg(
                                svgString: CompassSvgIcons.shieldCheck,
                                size: 13.0,
                                color: theme.accent,
                              ),
                              const SizedBox(width: 6.0),
                            ],
                            Flexible(
                              child: Text(
                                idx.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: CompassTypography.monoMedium(color: theme.textPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Fields
                      Expanded(
                        flex: 2,
                        child: Text(
                          idx.keys.toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: CompassTypography.monoMedium(color: theme.accent),
                        ),
                      ),
                      // Properties
                      Expanded(
                        flex: 1,
                        child: Row(
                          children: [
                            if (idx.unique)
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
                                  decoration: BoxDecoration(
                                    color: CompassColors.infoBlueBg,
                                    borderRadius: BorderRadius.circular(4.0),
                                    border: Border.all(color: CompassColors.infoBlueBorder, width: 1.0),
                                  ),
                                  child: Text('Unique', maxLines: 1, overflow: TextOverflow.ellipsis, style: CompassTypography.caption(color: CompassColors.infoBlue)),
                                ),
                              )
                            else
                              Flexible(
                                child: Text('Default', maxLines: 1, overflow: TextOverflow.ellipsis, style: CompassTypography.caption(color: theme.textMuted)),
                              ),
                          ],
                        ),
                      ),
                      // Size
                      Expanded(
                        flex: 1,
                        child: Text(
                          '${idx.sizeKb} KB',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: CompassTypography.monoSmall(color: theme.textMuted),
                        ),
                      ),
                      // Actions
                      Container(
                        width: 70.0,
                        alignment: Alignment.centerRight,
                        child: idx.name == '_id_'
                            ? Text('Protected', maxLines: 1, overflow: TextOverflow.ellipsis, style: CompassTypography.caption(color: theme.textMuted))
                            : CompassIconButton(
                                svgString: CompassSvgIcons.trash,
                                onTap: () => onDropIndex(idx.name),
                                size: 13.0,
                                padding: 4.0,
                                color: CompassColors.errorRed,
                                semanticLabel: 'Drop index ${idx.name}',
                              ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
