import 'package:flutter/widgets.dart';
import '../theme/compass_colors.dart';
import '../theme/compass_density.dart';
import '../theme/compass_theme.dart';
import '../theme/compass_typography.dart';
import '../icons/compass_svg_icons.dart';
import '../models/mongo_models.dart';
import 'compass_hover.dart';
import 'compass_icon_button.dart';
import 'compass_spinner.dart';

/// Converted from src/components/Sidebar.tsx
/// Adheres strictly to:
/// 1. Layout & Flexbox (256px width, Column, nested Rows/Columns, exact Padding/SizedBox gaps)
/// 2. Color & Styling (exact CompassColors, BorderRadius.circular(6))
/// 3. Typography (CompassTypography)
/// 4. Platform Agnosticism (desktop docked sidebar, collapsible items)
/// 5. Icons (CompassSvg instead of generic Icon)
class CompassSidebar extends StatefulWidget {
  /// Width limits for the docked, resizable desktop sidebar. The touch drawer
  /// keeps its own viewport-relative width and is not resizable.
  static const double minWidth = 180.0;
  static const double maxWidth = 480.0;

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

  /// Called when a database is expanded, so the host can lazily fetch that
  /// database's collection counts (counts are not pre-fetched at connect).
  final Function(String dbName)? onExpandDb;

  /// Controlled width of the docked desktop sidebar. When null the sidebar is
  /// 256 px wide (or the touch drawer width on a phone).
  final double? width;

  /// Called during a resize drag with the new, already-clamped width.
  final ValueChanged<double>? onResize;

  /// Called once when a resize drag ends, so the host can persist the width.
  final ValueChanged<double>? onResizeEnd;

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
    this.onExpandDb,
    this.width,
    this.onResize,
    this.onResizeEnd,
  });

  @override
  State<CompassSidebar> createState() => _CompassSidebarState();
}

class _CompassSidebarState extends State<CompassSidebar> {
  final Map<String, bool> _expandedDbs = {
    'library': true,
    'social_networks': true,
  };

  /// Databases whose collection counts have already been requested, so they are
  /// not fetched again on every rebuild.
  final Set<String> _countsRequested = {};

  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  CompassTheme get _theme => CompassTheme.of(context);

  @override
  void initState() {
    super.initState();
    _requestCountsForExpanded();
  }

  @override
  void didUpdateWidget(covariant CompassSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Collections can appear after the database was expanded; fetch their
    // counts once they exist.
    _requestCountsForExpanded();
  }

  /// Asks the host to lazily fetch counts for every expanded database that has
  /// collections but hasn't been counted yet.
  void _requestCountsForExpanded() {
    if (widget.onExpandDb == null) return;
    for (final db in widget.databases) {
      if ((_expandedDbs[db.name] ?? false) &&
          db.collections.isNotEmpty &&
          _countsRequested.add(db.name)) {
        widget.onExpandDb!(db.name);
      }
    }
  }

  void _toggleDb(String dbName) {
    final willExpand = !(_expandedDbs[dbName] ?? false);
    setState(() {
      _expandedDbs[dbName] = willExpand;
      if (willExpand) {
        _countsRequested.remove(dbName);
      }
    });
    if (willExpand) _requestCountsForExpanded();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final density = CompassDensity.of(context);
    final filtered = widget.databases.where((db) {
      if (_searchQuery.trim().isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      if (db.name.toLowerCase().contains(q)) return true;
      return db.collections.keys.any((c) => c.toLowerCase().contains(q));
    }).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    // On a phone the drawer takes most of the screen: the tree of databases
    // and collections needs room for finger-sized action buttons.
    final drawerWidth = density.isTouch
        ? (MediaQuery.maybeOf(context)?.size.width ?? 360.0) * 0.85
        : 256.0;

    final effectiveWidth = (widget.width ?? drawerWidth).clamp(
      density.isTouch ? 0.0 : CompassSidebar.minWidth,
      density.isTouch ? 320.0 : CompassSidebar.maxWidth,
    );

    final sidebar = Container(
      width: effectiveWidth, // CSS w-64, resizable on desktop
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
                          style: CompassTypography.badge(
                              color: _theme.textSecondary),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        CompassIconButton(
                          svgString: CompassSvgIcons.rotateCcw,
                          onTap: widget.onRefresh,
                          size: 14.0,
                          padding: 4.0,
                          color: _theme.textMuted,
                          semanticLabel: 'Refresh databases',
                        ),
                        const SizedBox(width: 4.0),
                        CompassIconButton(
                          svgString: CompassSvgIcons.plus,
                          onTap: widget.onOpenCreateDb,
                          size: 16.0,
                          padding: 4.0,
                          color: _theme.accent,
                          semanticLabel: 'Create database',
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8.0),
                // Search input container
                Container(
                  height: density.isTouch ? 44.0 : 32.0,
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
                        child: EditableText(
                          controller: _searchController,
                          focusNode: FocusNode(),
                          style: CompassTypography.bodyRegular(
                            color: _theme.textPrimary,
                          ),
                          cursorColor: _theme.accent,
                          backgroundCursorColor: _theme.bgInput,
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                            });
                          },
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 6.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final db in filtered) _buildDatabaseItem(db),
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
                      style:
                          CompassTypography.header(color: _theme.textPrimary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    // The touch drawer is temporary and sized from the viewport; only the
    // docked desktop sidebar gets a drag handle on its right edge.
    if (density.isTouch || widget.onResize == null) return sidebar;
    return Stack(
      children: [
        sidebar,
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: CompassSidebarResizeHandle(
            width: effectiveWidth,
            minWidth: CompassSidebar.minWidth,
            maxWidth: CompassSidebar.maxWidth,
            onResize: widget.onResize!,
            onResizeEnd: widget.onResizeEnd,
          ),
        ),
      ],
    );
  }

  Widget _buildDatabaseItem(MongoDatabase db) {
    final isExpanded = _expandedDbs[db.name] ?? false;
    final isSelected =
        widget.selectedDb == db.name && widget.selectedColl == null;
    final collections = db.collections.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Padding(
      padding: const EdgeInsets.only(bottom: 2.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Database Row
          CompassHover(
            onTap: () {
              widget.onSelectDatabase(db.name);
              if (!isExpanded) _toggleDb(db.name);
            },
            builder: (hovered) => Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
              decoration: BoxDecoration(
                color: isSelected
                    ? _theme.bgSubtle
                    : (hovered ? _theme.bgHover : const Color(0x00000000)),
                borderRadius: BorderRadius.circular(6.0),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        CompassIconButton(
                          svgString: isExpanded
                              ? CompassSvgIcons.chevronDown
                              : CompassSvgIcons.chevronRight,
                          onTap: () => _toggleDb(db.name),
                          size: 13.0,
                          padding: 0.0,
                          color: _theme.textMuted,
                          semanticLabel: isExpanded
                              ? 'Collapse ${db.name}'
                              : 'Expand ${db.name}',
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
                                ? CompassTypography.header(
                                    color: _theme.textPrimary)
                                : CompassTypography.bodyMedium(
                                    color: _theme.textSecondary),
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
                      CompassIconButton(
                        svgString: CompassSvgIcons.plus,
                        onTap: () => widget.onOpenCreateColl(db.name),
                        size: 13.0,
                        padding: 0.0,
                        color: _theme.textMuted,
                        semanticLabel: 'Create collection in ${db.name}',
                      ),
                      const SizedBox(width: 6.0),
                      CompassIconButton(
                        svgString: CompassSvgIcons.pencil,
                        onTap: () => widget.onRenameDb(db.name),
                        size: 12.0,
                        padding: 0.0,
                        color: _theme.textMuted,
                        semanticLabel: 'Rename ${db.name}',
                      ),
                      const SizedBox(width: 6.0),
                      CompassIconButton(
                        svgString: CompassSvgIcons.trash,
                        onTap: () => widget.onDropDb(db.name),
                        size: 13.0,
                        padding: 0.0,
                        color: _theme.textMuted,
                        semanticLabel: 'Drop ${db.name}',
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
                      padding: const EdgeInsets.symmetric(
                          vertical: 4.0, horizontal: 8.0),
                      child: Text(
                        'No collections',
                        style:
                            CompassTypography.caption(color: _theme.textMuted),
                      ),
                    )
                  else
                    for (final coll in collections)
                      _buildCollectionItem(db.name, coll),

                  // Inline "+ Create Collection" link
                  GestureDetector(
                    onTap: () => widget.onOpenCreateColl(db.name),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8.0, vertical: 4.0),
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
                              style: CompassTypography.caption(
                                  color: _theme.textMuted),
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

  /// Trailing document count for a collection row.
  ///
  /// Shows the server count once known, the mirror length for the bundled
  /// sample data, a spinner while the collection is being opened, and a neutral
  /// dash before the count has been fetched (never a misleading "0").
  Widget _buildCollectionCount(MongoCollection coll) {
    if (coll.isLoading) {
      return CompassSpinner(size: 11.0, color: _theme.textMuted);
    }
    final int? count = coll.documentCount ??
        (coll.documents.isNotEmpty ? coll.documents.length : null);
    return Text(
      count?.toString() ?? '—',
      style: CompassTypography.monoSmall(color: _theme.textMuted),
    );
  }

  Widget _buildCollectionItem(String dbName, MongoCollection coll) {
    final isSelected =
        widget.selectedDb == dbName && widget.selectedColl == coll.name;

    return CompassHover(
      onTap: () => widget.onSelectCollection(dbName, coll.name),
      builder: (hovered) => Container(
        margin: const EdgeInsets.only(bottom: 2.0),
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
        decoration: BoxDecoration(
          color: isSelected
              ? _theme.greenBadgeBg
              : (hovered ? _theme.bgHover : const Color(0x00000000)),
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
                    svgString: coll.isView
                        ? CompassSvgIcons.eye
                        : CompassSvgIcons.table,
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
                          : CompassTypography.bodyRegular(
                              color: _theme.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4.0),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildCollectionCount(coll),
                const SizedBox(width: 6.0),
                CompassIconButton(
                  svgString: CompassSvgIcons.pencil,
                  onTap: () => widget.onRenameColl(dbName, coll.name, coll.isView),
                  size: 11.0,
                  padding: 0.0,
                  color: _theme.textMuted,
                  semanticLabel: 'Rename ${coll.name}',
                ),
                const SizedBox(width: 4.0),
                CompassIconButton(
                  svgString: CompassSvgIcons.trash,
                  onTap: () => widget.onDropColl(dbName, coll.name),
                  size: 12.0,
                  padding: 0.0,
                  color: _theme.textMuted,
                  semanticLabel: 'Drop ${coll.name}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Thin grip on the right edge of the docked sidebar. Pointer drags resize the
/// sidebar through the host's controlled [width]; [onResizeEnd] lets the host
/// persist the final value without writing preferences on every drag frame.
class CompassSidebarResizeHandle extends StatefulWidget {
  const CompassSidebarResizeHandle({
    super.key,
    required this.width,
    required this.minWidth,
    required this.maxWidth,
    required this.onResize,
    this.onResizeEnd,
  });

  final double width;
  final double minWidth;
  final double maxWidth;
  final ValueChanged<double> onResize;
  final ValueChanged<double>? onResizeEnd;

  @override
  State<CompassSidebarResizeHandle> createState() =>
      _CompassSidebarResizeHandleState();
}

class _CompassSidebarResizeHandleState
    extends State<CompassSidebarResizeHandle> {
  double _dragStartX = 0.0;
  double _dragStartWidth = 0.0;
  double _lastWidth = 0.0;
  bool _hovered = false;
  bool _resizing = false;

  void _endDrag() {
    if (!_resizing) return;
    setState(() => _resizing = false);
    // The final pointer move may not have produced a new build yet, so persist
    // the width from the gesture rather than a possibly stale widget.width.
    widget.onResizeEnd?.call(_lastWidth);
  }

  @override
  Widget build(BuildContext context) {
    final theme = CompassTheme.of(context);
    final active = _hovered || _resizing;

    return Semantics(
      label: 'Resize sidebar',
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeLeftRight,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (details) {
            _dragStartX = details.globalPosition.dx;
            _dragStartWidth = widget.width;
            _lastWidth = widget.width;
            setState(() => _resizing = true);
          },
          onHorizontalDragUpdate: (details) {
            final next = _dragStartWidth +
                (details.globalPosition.dx - _dragStartX);
            _lastWidth = next.clamp(widget.minWidth, widget.maxWidth);
            widget.onResize(_lastWidth);
          },
          onHorizontalDragEnd: (_) => _endDrag(),
          onHorizontalDragCancel: _endDrag,
          child: SizedBox(
            width: 6.0,
            child: Center(
              child: Container(
                width: active ? 3.0 : 1.0,
                color: _resizing
                    ? theme.accent
                    : (active ? theme.borderHover : const Color(0x00000000)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
