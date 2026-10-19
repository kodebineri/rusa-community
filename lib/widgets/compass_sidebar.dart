import 'package:flutter/widgets.dart';
import '../theme/compass_colors.dart';
import '../theme/compass_theme.dart';
import '../theme/compass_typography.dart';
import '../icons/compass_svg_icons.dart';
import '../models/mongo_models.dart';

/// Converted from src/components/Sidebar.tsx
/// Adheres strictly to:
/// 1. Layout & Flexbox (256px width, Column, nested Rows/Columns, exact Padding/SizedBox gaps)
/// 2. Color & Styling (exact CompassColors, BorderRadius.circular(6))
/// 3. Typography (CompassTypography)
/// 4. Platform Agnosticism (desktop docked sidebar, collapsible items)
/// 5. Icons (CompassSvg instead of generic Icon)
class CompassSidebar extends StatefulWidget {
  final List<MongoDatabase> databases;
  final String? selectedDb;
  final String? selectedColl;
  final Function(String dbName, String collName) onSelectCollection;
  final Function(String dbName) onSelectDatabase;
  final VoidCallback onOpenCreateDb;
  final Function(String dbName) onOpenCreateColl;
  final Function(String dbName) onRenameDb;
  final Function(String dbName, String collName, bool isView) onRenameColl;
  final Function(String dbName) onDropDb;
  final Function(String dbName, String collName) onDropColl;
  final VoidCallback onRefresh;

  const CompassSidebar({
    super.key,
    required this.databases,
    required this.selectedDb,
    required this.selectedColl,
    required this.onSelectCollection,
    required this.onSelectDatabase,
    required this.onOpenCreateDb,
    required this.onOpenCreateColl,
    required this.onRenameDb,
    required this.onRenameColl,
    required this.onDropDb,
    required this.onDropColl,
    required this.onRefresh,
  });

  @override
  State<CompassSidebar> createState() => _CompassSidebarState();
}

class _CompassSidebarState extends State<CompassSidebar> {
  final Map<String, bool> _expandedDbs = {
    'library': true,
    'social_networks': true,
  };
  final String _searchQuery = '';

  CompassTheme get _theme => CompassTheme.of(context);

  void _toggleDb(String dbName) {
    setState(() {
      _expandedDbs[dbName] = !(_expandedDbs[dbName] ?? false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.databases.where((db) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      if (db.name.toLowerCase().contains(q)) return true;
      return db.collections.keys.any((c) => c.toLowerCase().contains(q));
    }).toList();

    return Container(
      width: 256.0, // CSS w-64
      decoration: BoxDecoration(
        color: _theme.bgSidebar,
        border: Border(
          right: BorderSide(
            color: _theme.border,
            width: 1.0,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: "DATABASES", Actions, Search Input
          Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: _theme.border, width: 1.0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CompassSvg(
                          svgString: CompassSvgIcons.layers,
                          size: 14.0,
                          color: _theme.accent,
                        ),
                        const SizedBox(width: 6.0),
                        Text(
                          'DATABASES',
                          style: CompassTypography.badge(color: _theme.textSecondary),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: widget.onRefresh,
                          child: Container(
                            padding: const EdgeInsets.all(4.0),
                            child: CompassSvg(
                              svgString: CompassSvgIcons.rotateCcw,
                              size: 14.0,
                              color: _theme.textMuted,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4.0),
                        GestureDetector(
                          onTap: widget.onOpenCreateDb,
                          child: Container(
                            padding: const EdgeInsets.all(4.0),
                            child: CompassSvg(
                              svgString: CompassSvgIcons.plus,
                              size: 16.0,
                              color: _theme.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8.0),
                // Search input container
                Container(
                  height: 32.0,
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  decoration: BoxDecoration(
                    color: _theme.bgInput,
                    borderRadius: BorderRadius.circular(6.0),
                    border: Border.all(color: _theme.border, width: 1.0),
                  ),
                  child: Row(
                    children: [
                      CompassSvg(
                        svgString: CompassSvgIcons.search,
                        size: 13.0,
                        color: _theme.textMuted,
                      ),
                      const SizedBox(width: 8.0),
                      Expanded(
                        child: Text(
                          _searchQuery.isEmpty ? 'Filter databases...' : _searchQuery,
                          style: CompassTypography.bodyRegular(
                            color: _searchQuery.isEmpty
                                ? _theme.textMuted
                                : _theme.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Scrollable Database Tree
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final db in filtered)
                    _buildDatabaseItem(db),
                ],
              ),
            ),
          ),

          // Footer: Create Database action
          Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: _theme.bgPanel,
              border: Border(
                top: BorderSide(color: _theme.border, width: 1.0),
              ),
            ),
            child: GestureDetector(
              onTap: widget.onOpenCreateDb,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                decoration: BoxDecoration(
                  color: _theme.bgSubtle,
                  borderRadius: BorderRadius.circular(6.0),
                  border: Border.all(color: _theme.border, width: 1.0),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CompassSvg(
                      svgString: CompassSvgIcons.plus,
                      size: 14.0,
                      color: _theme.accent,
                    ),
                    const SizedBox(width: 6.0),
                    Text(
                      'Create Database',
                      style: CompassTypography.header(color: _theme.textPrimary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatabaseItem(MongoDatabase db) {
    final isExpanded = _expandedDbs[db.name] ?? false;
    final isSelected = widget.selectedDb == db.name && widget.selectedColl == null;
    final collections = db.collections.values.toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 2.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Database Row
          GestureDetector(
            onTap: () {
              widget.onSelectDatabase(db.name);
              if (!isExpanded) _toggleDb(db.name);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
              decoration: BoxDecoration(
                color: isSelected ? _theme.bgSubtle : const Color(0x00000000),
                borderRadius: BorderRadius.circular(6.0),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () => _toggleDb(db.name),
                          child: CompassSvg(
                            svgString: isExpanded ? CompassSvgIcons.chevronDown : CompassSvgIcons.chevronRight,
                            size: 13.0,
                            color: _theme.textMuted,
                          ),
                        ),
                        const SizedBox(width: 6.0),
                        CompassSvg(
                          svgString: CompassSvgIcons.database,
                          size: 14.0,
                          color: _theme.accent,
                        ),
                        const SizedBox(width: 6.0),
                        Expanded(
                          child: Text(
                            db.name,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: isSelected
                                ? CompassTypography.header(color: _theme.textPrimary)
                                : CompassTypography.bodyMedium(color: _theme.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4.0),
                  // Db Action buttons
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => widget.onOpenCreateColl(db.name),
                        child: CompassSvg(
                          svgString: CompassSvgIcons.plus,
                          size: 13.0,
                          color: _theme.textMuted,
                        ),
                      ),
                      const SizedBox(width: 6.0),
                      GestureDetector(
                        onTap: () => widget.onRenameDb(db.name),
                        child: CompassSvg(
                          svgString: CompassSvgIcons.pencil,
                          size: 12.0,
                          color: _theme.textMuted,
                        ),
                      ),
                      const SizedBox(width: 6.0),
                      GestureDetector(
                        onTap: () => widget.onDropDb(db.name),
                        child: CompassSvg(
                          svgString: CompassSvgIcons.trash,
                          size: 13.0,
                          color: _theme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Subtree: Collections List
          if (isExpanded)
            Container(
              margin: const EdgeInsets.only(left: 16.0),
              padding: const EdgeInsets.only(left: 8.0, top: 2.0),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: _theme.border, width: 1.0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (collections.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                      child: Text(
                        'No collections',
                        style: CompassTypography.caption(color: _theme.textMuted),
                      ),
                    )
                  else
                    for (final coll in collections)
                      _buildCollectionItem(db.name, coll),

                  // Inline "+ Create Collection" link
                  GestureDetector(
                    onTap: () => widget.onOpenCreateColl(db.name),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                      child: Row(
                        children: [
                          CompassSvg(
                            svgString: CompassSvgIcons.plus,
                            size: 11.0,
                            color: _theme.textMuted,
                          ),
                          const SizedBox(width: 6.0),
                          Expanded(
                            child: Text(
                              'Create Collection',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: CompassTypography.caption(color: _theme.textMuted),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCollectionItem(String dbName, MongoCollection coll) {
    final isSelected = widget.selectedDb == dbName && widget.selectedColl == coll.name;

    return GestureDetector(
      onTap: () => widget.onSelectCollection(dbName, coll.name),
      child: Container(
        margin: const EdgeInsets.only(bottom: 2.0),
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
        decoration: BoxDecoration(
          color: isSelected ? _theme.greenBadgeBg : const Color(0x00000000),
          borderRadius: BorderRadius.circular(6.0),
          border: isSelected
              ? Border.all(color: _theme.greenBadgeBorder, width: 1.0)
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  CompassSvg(
                    svgString: coll.isView ? CompassSvgIcons.eye : CompassSvgIcons.table,
                    size: 13.0,
                    color: coll.isView
                        ? CompassColors.warningAmber
                        : (isSelected ? _theme.accent : _theme.textMuted),
                  ),
                  const SizedBox(width: 6.0),
                  Expanded(
                    child: Text(
                      coll.name,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: isSelected
                          ? CompassTypography.bodyMedium(color: _theme.accent)
                          : CompassTypography.bodyRegular(color: _theme.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4.0),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${coll.documents.length}',
                  style: CompassTypography.monoSmall(color: _theme.textMuted),
                ),
                const SizedBox(width: 6.0),
                GestureDetector(
                  onTap: () => widget.onRenameColl(dbName, coll.name, coll.isView),
                  child: CompassSvg(
                    svgString: CompassSvgIcons.pencil,
                    size: 11.0,
                    color: _theme.textMuted,
                  ),
                ),
                const SizedBox(width: 4.0),
                GestureDetector(
                  onTap: () => widget.onDropColl(dbName, coll.name),
                  child: CompassSvg(
                    svgString: CompassSvgIcons.trash,
                    size: 12.0,
                    color: _theme.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
