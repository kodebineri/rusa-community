import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../icons/compass_svg_icons.dart';
import '../models/collection_tab.dart';
import '../theme/compass_theme.dart';
import '../theme/compass_typography.dart';

/// Horizontal strip of open collection tabs at the top of the main pane
/// (mirrors MongoDB Compass / a browser tab bar): each collection opened from
/// the sidebar gets its own tab. Clicking a tab activates it, the ✕ closes it,
/// and the freshly activated/appended tab is scrolled into view automatically.
class CollectionTabBar extends StatefulWidget {
  final List<CollectionTab> tabs;
  final int activeIndex;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onClose;

  const CollectionTabBar({
    super.key,
    required this.tabs,
    required this.activeIndex,
    required this.onSelect,
    required this.onClose,
  });

  @override
  State<CollectionTabBar> createState() => _CollectionTabBarState();
}

class _CollectionTabBarState extends State<CollectionTabBar> {
  static const double _tabHeight = 36.0;

  final ScrollController _scrollController = ScrollController();

  /// Attached to whichever tab is currently active so it can be revealed with
  /// [Scrollable.ensureVisible].
  final GlobalKey _activeTabKey = GlobalKey();

  // --- Theme-aware palette ---------------------------------------------------
  // The strip reads the resolved palette from [CompassTheme] (provided at the
  // root by `CompassApp`), so it follows the dark/light toggle without an
  // `isDarkMode` constructor parameter.
  CompassTheme get _theme => CompassTheme.of(context);

  @override
  void didUpdateWidget(covariant CollectionTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final targetChanged = oldWidget.activeIndex != widget.activeIndex;
    final tabsChanged = oldWidget.tabs.length != widget.tabs.length;
    if (!targetChanged && !tabsChanged) return;
    // Wait for the rebuilt tree (the active tab's key moved) before revealing.
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealActiveTab());
  }

  /// Scrolls the active tab into view — but only when it is (partially) out of
  /// view, so switching between visible tabs never jumps the strip around.
  void _revealActiveTab() {
    if (!mounted || widget.activeIndex < 0 || !_scrollController.hasClients) {
      return;
    }
    final tabContext = _activeTabKey.currentContext;
    if (tabContext == null) return;
    final renderObject = tabContext.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;
    final viewport = RenderAbstractViewport.maybeOf(renderObject);
    final position = _scrollController.position;
    if (viewport == null) return;

    // Scroll offset at which the tab's leading edge sits at the viewport's
    // leading edge; the tab is fully visible when that offset is inside the
    // current scroll window.
    final revealOffset = viewport.getOffsetToReveal(renderObject, 0.0).offset;
    final fullyVisible = revealOffset >= position.pixels - 0.5 &&
        (revealOffset + renderObject.size.width) <=
            (position.pixels + position.viewportDimension) + 0.5;
    if (fullyVisible) return;

    Scrollable.ensureVisible(
      tabContext,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      alignment: 0.5,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _tabHeight,
      decoration: BoxDecoration(
        color: _theme.bgPanel,
        border: Border(
          bottom: BorderSide(color: _theme.border, width: 1.0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < widget.tabs.length; i++) _buildTab(i),
                ],
              ),
            ),
          ),

          // Right: open-tab counter (keeps the strip's bottom border line).
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Center(
              child: Text(
                '${widget.tabs.length} open',
                style: CompassTypography.caption(color: _theme.textMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(int index) {
    final tab = widget.tabs[index];
    final isActive = index == widget.activeIndex;

    return GestureDetector(
      key: isActive ? _activeTabKey : null,
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onSelect(index),
      child: Container(
        height: _tabHeight - 1.0, // leave the strip's 1px bottom border visible
        constraints: const BoxConstraints(minWidth: 140.0, maxWidth: 200.0),
        padding: const EdgeInsets.only(left: 12.0, right: 6.0),
        decoration: BoxDecoration(
          color: isActive ? _theme.bgSubtle : const Color(0x00000000),
          border: Border(
            right: BorderSide(color: _theme.border, width: 1.0),
            bottom: BorderSide(
              color: isActive ? _theme.accent : _theme.border,
              width: isActive ? 2.0 : 1.0,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  CompassSvg(
                    svgString: tab.collName.isEmpty ? CompassSvgIcons.database : CompassSvgIcons.table,
                    size: 13.0,
                    color: isActive ? _theme.accent : _theme.textMuted,
                  ),
                  const SizedBox(width: 6.0),
                  Flexible(
                    flex: 3,
                    child: Text(
                      tab.collName.isEmpty ? tab.dbName : tab.collName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: isActive
                          ? CompassTypography.bodyMedium(color: _theme.textPrimary)
                          : CompassTypography.bodyRegular(color: _theme.textSecondary),
                    ),
                  ),
                  if (tab.collName.isNotEmpty) ...[
                    const SizedBox(width: 6.0),
                    Flexible(
                      flex: 2,
                      child: Text(
                        tab.dbName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: CompassTypography.caption(color: _theme.textMuted),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6.0),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => widget.onClose(index),
              child: Container(
                padding: const EdgeInsets.all(5.0),
                child: CompassSvg(
                  svgString: CompassSvgIcons.close,
                  size: 11.0,
                  color: isActive ? _theme.textSecondary : _theme.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
