import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:mongodb_compass_flutter/utils/json_syntax_text_controller.dart';
import '../theme/compass_colors.dart';
import '../theme/compass_density.dart';
import '../theme/compass_theme.dart';
import '../theme/compass_typography.dart';
import '../icons/compass_svg_icons.dart';
import '../models/mongo_models.dart';
import 'compass_hover.dart';
import 'compass_icon_button.dart';
import 'compass_text_menu.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Converted from src/components/QueryBar.tsx
/// Adheres strictly to:
/// 1. Layout & Flexbox (exact Row, Column, SizedBox gaps, grid/wrap for options)
/// 2. Color & Styling (exact CompassColors, BorderRadius.circular(6 & 8))
/// 3. Typography (CompassTypography with JetBrains Mono font)
/// 4. Platform Agnosticism (desktop styled query bar)
/// 5. Icons (CompassSvg instead of generic Icon)
class CompassQueryBar extends StatefulWidget {
  final QueryFilterOptions options;
  final Function(QueryFilterOptions updated) onChangeOptions;
  final VoidCallback onExecuteQuery;
  final VoidCallback onResetQuery;
  final VoidCallback onExportToLanguage;
  final double? executionTimeMs;
  final int? totalResultsCount;

  /// Whether the options panel (project / sort / skip / limit) is expanded.
  ///
  /// The state lives in the host so that the overflow action sheet — which
  /// is a *root-level* overlay, see [CompassActionSheet] — can toggle it.
  final bool optionsExpanded;

  /// Toggles the options panel.
  final VoidCallback onToggleOptions;

  /// Opens the host's overflow action sheet.
  ///
  /// The sheet cannot be rendered from inside this widget: it is a
  /// `Positioned.fill` child of the root `Stack` in `main.dart`, so it has
  /// to be hosted there.
  final VoidCallback onOpenOverflow;

  const CompassQueryBar({
    super.key,
    required this.options,
    required this.onChangeOptions,
    required this.onExecuteQuery,
    required this.onResetQuery,
    required this.onExportToLanguage,
    required this.optionsExpanded,
    required this.onToggleOptions,
    required this.onOpenOverflow,
    this.executionTimeMs,
    this.totalResultsCount,
  });

  @override
  State<CompassQueryBar> createState() => _CompassQueryBarState();
}

class _CompassQueryBarState extends State<CompassQueryBar> {
  bool _filterError = false;

  late final JsonSyntaxTextController _filterController;
  late final JsonSyntaxTextController _projectController;
  late final JsonSyntaxTextController _sortController;
  late final TextEditingController _skipController;
  late final TextEditingController _limitController;

  bool _initializedControllers = false;

  final FocusNode _filterFocus = FocusNode(debugLabel: 'query-filter');
  final FocusNode _projectFocus = FocusNode(debugLabel: 'query-project');
  final FocusNode _sortFocus = FocusNode(debugLabel: 'query-sort');
  final FocusNode _skipFocus = FocusNode(debugLabel: 'query-skip');
  final FocusNode _limitFocus = FocusNode(debugLabel: 'query-limit');

  /// Anchors the text context menu to each input box.
  ///
  /// Every field needs its own link: the menu is positioned relative to the
  /// [CompositedTransformTarget] that wraps the box the user is editing.
  late final LayerLink _filterMenuAnchor = LayerLink();
  late final LayerLink _projectMenuAnchor = LayerLink();
  late final LayerLink _sortMenuAnchor = LayerLink();
  late final LayerLink _skipMenuAnchor = LayerLink();
  late final LayerLink _limitMenuAnchor = LayerLink();

  @override
  void initState() {
    super.initState();
    _skipController =
        TextEditingController(text: widget.options.skip.toString());
    _limitController =
        TextEditingController(text: widget.options.limit.toString());
    // When the numeric fields lose focus, snap the text back to the committed
    // value so an empty/partial entry doesn't linger.
    _skipFocus.addListener(() {
      if (!_skipFocus.hasFocus) {
        _commitSkip();
        _sync(_skipController, widget.options.skip.toString());
      }
    });
    _limitFocus.addListener(() {
      if (!_limitFocus.hasFocus) {
        _commitLimit();
        _sync(_limitController, widget.options.limit.toString());
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final theme = CompassTheme.of(context);

    if (!_initializedControllers) {
      _filterController = JsonSyntaxTextController(
        text: widget.options.filter,
        theme: theme,
      );
      _projectController = JsonSyntaxTextController(
        text: widget.options.project,
        theme: theme,
      );
      _sortController = JsonSyntaxTextController(
        text: widget.options.sort,
        theme: theme,
      );
      _initializedControllers = true;
    } else {
      // Keep theme up-to-date if application dynamic theme changes
      _filterController.theme = theme;
      _projectController.theme = theme;
      _sortController.theme = theme;
    }
  }

  @override
  void didUpdateWidget(covariant CompassQueryBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync external changes (Reset, pagination, collection switch) back into the
    // text fields without disturbing the field currently being typed in.
    if (widget.options.filter != oldWidget.options.filter) {
      _sync(_filterController, widget.options.filter);
      if (widget.options.filter.trim().isEmpty && _filterError) {
        _filterError = false;
      }
    }
    if (widget.options.project != oldWidget.options.project) {
      _sync(_projectController, widget.options.project);
    }
    if (widget.options.sort != oldWidget.options.sort) {
      _sync(_sortController, widget.options.sort);
    }
    if (widget.options.skip != oldWidget.options.skip) {
      _syncIfUnfocused(
          _skipController, _skipFocus, widget.options.skip.toString());
    }
    if (widget.options.limit != oldWidget.options.limit) {
      _syncIfUnfocused(
          _limitController, _limitFocus, widget.options.limit.toString());
    }
  }

  @override
  void dispose() {
    _filterController.dispose();
    _projectController.dispose();
    _sortController.dispose();
    _skipController.dispose();
    _limitController.dispose();
    _filterFocus.dispose();
    _projectFocus.dispose();
    _sortFocus.dispose();
    _skipFocus.dispose();
    _limitFocus.dispose();
    super.dispose();
  }

  void _sync(TextEditingController controller, String value) {
    if (controller.text == value) return;
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  /// Like [_sync] but leaves a field the user is actively editing untouched.
  void _syncIfUnfocused(
      TextEditingController controller, FocusNode focus, String value) {
    if (focus.hasFocus) return;
    _sync(controller, value);
  }

  void _handleFilterChange(String value) {
    if (!mounted) return;
    if (value.isEmpty) {
      if (_filterError) setState(() => _filterError = false);
      widget.onChangeOptions(widget.options.copyWith(filter: ''));
      return;
    }
    if (value.trim().isEmpty) {
      if (_filterError) setState(() => _filterError = false);
      return;
    }
    var isValid = true;
    try {
      final cleaned = value
          .replaceAllMapped(
            RegExp(r'([{,]\s*)([a-zA-Z0-9_$.]+)\s*:'),
            (m) => '${m[1]}"${m[2]}":',
          )
          .replaceAll("'", '"');
      jsonDecode(cleaned);
    } catch (_) {
      isValid = false;
    }
    if (_filterError != !isValid) {
      setState(() => _filterError = !isValid);
    }
  }

  void _executeWithCurrentFilter() {
    // Commit all query options (do not execute on type)
    _commitSkip();
    _commitLimit();
    widget.onChangeOptions(widget.options.copyWith(
      filter: _filterController.text,
      project: _projectController.text,
      sort: _sortController.text,
      skip: _skipController.text.trim().isEmpty
          ? 0
          : (int.tryParse(_skipController.text.trim()) ?? widget.options.skip)
              .clamp(0, 1000000000),
      limit: _limitController.text.trim().isEmpty
          ? 20
          : ((int.tryParse(_limitController.text.trim()) ?? widget.options.limit)
                  < 1
              ? 1
              : (int.tryParse(_limitController.text.trim()) ?? widget.options.limit)),
    ));
    widget.onExecuteQuery();
  }

  void _commitSkip() {
    final text = _skipController.text;
    if (text.trim().isEmpty) {
      if (widget.options.skip != 0) {
        widget.onChangeOptions(widget.options.copyWith(skip: 0));
      }
      return;
    }
    final parsed = int.tryParse(text.trim());
    if (parsed == null) {
      _sync(_skipController, widget.options.skip.toString());
      return;
    }
    final committed = parsed < 0 ? 0 : parsed;
    if (committed != widget.options.skip) {
      widget.onChangeOptions(widget.options.copyWith(skip: committed));
    } else {
      _sync(_skipController, committed.toString());
    }
  }

  void _commitLimit() {
    final text = _limitController.text;
    if (text.trim().isEmpty) {
      if (widget.options.limit != 20) {
        widget.onChangeOptions(widget.options.copyWith(limit: 20));
      } else {
        _sync(_limitController, '20');
      }
      return;
    }
    final parsed = int.tryParse(text.trim());
    if (parsed == null) {
      _sync(_limitController, widget.options.limit.toString());
      return;
    }
    final committed = parsed < 1 ? 1 : parsed;
    if (committed != widget.options.limit) {
      widget.onChangeOptions(widget.options.copyWith(limit: committed));
    } else {
      _sync(_limitController, committed.toString());
    }
  }

  void _handleSkipChange(String value) {
    // Do not execute on type; commit only on blur or explicit actions
  }

  void _handleLimitChange(String value) {
    // Do not execute on type; commit only on blur or explicit actions
  }

  @override
  Widget build(BuildContext context) {
    final theme = CompassTheme.of(context);
    final density = CompassDensity.of(context);

    // Keyboard hints are pointless without a keyboard, and the stats ribbon
    // is the one row that cannot shrink.
    final windowWidth = MediaQuery.maybeOf(context)?.size.width ?? 1440.0;
    final showKeyboardHint = windowWidth >= 900.0 && !density.isTouch;

    // On very small phones, collapse everything except filter + Find into an
    // overflow sheet to reclaim vertical space.
    final isTiny = density.isTouch && windowWidth < 440.0;

    return Container(
      decoration: BoxDecoration(
        color: theme.bgPanel,
        border: Border(
          bottom: BorderSide(color: theme.border, width: 1.0),
        ),
      ),
      padding:
          EdgeInsets.symmetric(horizontal: 16.0, vertical: isTiny ? 6.0 : 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Primary Query Row
          LayoutBuilder(
            builder: (context, constraints) {
              if (isTiny) {
                // One row: filter + Find + overflow. Everything else lives
                // in the host's action sheet.
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: _buildFilterInput(theme, compact: true)),
                        const SizedBox(width: 6.0),
                        _buildFindButtonCompact(theme, density,
                            onTap: _executeWithCurrentFilter),
                        const SizedBox(width: 4.0),
                        SizedBox(
                          width: density.minTapTarget,
                          height: density.minTapTarget,
                          child: Semantics(
                            button: true,
                            label: 'More query actions',
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: widget.onOpenOverflow,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: theme.bgSubtle,
                                  borderRadius: BorderRadius.circular(8.0),
                                  border: Border.all(
                                      color: theme.border, width: 1.0),
                                ),
                                alignment: Alignment.center,
                                child: CompassSvg(
                                  svgString: CompassSvgIcons.moreVertical,
                                  size: 14.0,
                                  color: theme.textMuted,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (widget.optionsExpanded) ...[
                      const SizedBox(height: 6.0),
                      _buildOptionsPanel(theme, density),
                    ],
                  ],
                );
              }
              final stackActions =
                  density.isTouch || constraints.maxWidth < 640.0;
              if (stackActions) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildFilterInput(theme),
                    const SizedBox(height: 8.0),
                    Wrap(
                      alignment: WrapAlignment.end,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: [
                        _buildOptionsButton(theme, density),
                        _buildResetButton(theme),
                        _buildShowCodeButton(theme, density),
                        _buildFindButton(theme, density,
                            onTap: _executeWithCurrentFilter),
                      ],
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  // Main Filter Input
                  Expanded(child: _buildFilterInput(theme)),

                  const SizedBox(width: 8.0),

                  // Options Toggle Button
                  _buildOptionsButton(theme, density),

                  const SizedBox(width: 6.0),

                  // Reset Button
                  _buildResetButton(theme),

                  const SizedBox(width: 6.0),

                  // Export to Language
                  _buildShowCodeButton(theme, density),

                  const SizedBox(width: 8.0),

                  // Find Button (Primary)
                  _buildFindButton(theme, density,
                      onTap: _executeWithCurrentFilter),
                ],
              );
            },
          ),

          // Expanded Query Options Panel
          if (!isTiny && widget.optionsExpanded) ...[
            const SizedBox(height: 10.0),
            _buildOptionsPanel(theme, density),
          ],

          // Query Stats Ribbon
          if (!isTiny &&
              (widget.totalResultsCount != null ||
                  widget.executionTimeMs != null)) ...[
            const SizedBox(height: 6.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('Matches: ',
                        style: CompassTypography.monoSmall(
                            color: theme.textSecondary)),
                    Text(
                      '${widget.totalResultsCount ?? 0}',
                      style: CompassTypography.monoBold(
                          color: theme.textPrimary, size: 11.0),
                    ),
                    const SizedBox(width: 8.0),
                    Text('·',
                        style: CompassTypography.monoSmall(
                            color: theme.textMuted)),
                    const SizedBox(width: 8.0),
                    Text('Time: ',
                        style: CompassTypography.monoSmall(
                            color: theme.textSecondary)),
                    Text(
                      '${widget.executionTimeMs ?? 0.8}ms',
                      style: CompassTypography.monoBold(
                          color: theme.accent, size: 11.0),
                    ),
                  ],
                ),
                // The "press Enter" hint is a keyboard affordance; on touch
                // there is no Enter key to press.
                if (showKeyboardHint)
                  Text(
                    'Tip: Press Enter to find',
                    style: CompassTypography.caption(color: theme.textMuted),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOptionField({
    required CompassTheme theme,
    required String title,
    String? subtitle,
    required String placeholder,
    required TextEditingController controller,
    required FocusNode focusNode,
    required ValueChanged<String> onChanged,
    required LayerLink anchorLink,
    TextInputType keyboardType = TextInputType.text,
    ValueChanged<String>? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: CompassTypography.monoBold(
                  color: theme.textMuted, size: 10.0),
            ),
            if (subtitle != null)
              Text(
                subtitle,
                style: CompassTypography.caption(color: theme.textMuted),
              ),
          ],
        ),
        const SizedBox(height: 4.0),
        CompositedTransformTarget(
          link: anchorLink,
          child: Container(
            height: 30.0,
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            decoration: BoxDecoration(
              color: theme.bgInput,
              borderRadius: BorderRadius.circular(4.0),
              border: Border.all(color: theme.border, width: 1.0),
            ),
            alignment: Alignment.centerLeft,
            child: _buildEditable(
              theme: theme,
              controller: controller,
              focusNode: focusNode,
              placeholder: placeholder,
              onChanged: onChanged,
              onSubmitted: (v) {
                if (onSubmitted != null) {
                  onSubmitted(v);
                } else {
                  _executeWithCurrentFilter();
                }
              },
              keyboardType: keyboardType,
              fontSize: 11.0,
              anchorLink: anchorLink,
            ),
          ),
        ),
      ],
    );
  }

  TextSelectionControls getPlatformSelectionControls() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return cupertinoTextSelectionControls;
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return desktopTextSelectionControls;
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      default:
        return materialTextSelectionControls;
    }
  }

  /// Material-free single-line editable text with placeholder overlay.
  ///
  /// The placeholder is always in the tree (only its visibility toggles) so the
  /// [EditableText] element keeps its slot and never loses its text-input
  /// connection when the field transitions between empty and non-empty.
  Widget _buildEditable({
    required CompassTheme theme,
    required TextEditingController controller,
    required FocusNode focusNode,
    required String placeholder,
    required ValueChanged<String> onChanged,
    required LayerLink anchorLink,
    ValueChanged<String>? onSubmitted,
    TextInputType keyboardType = TextInputType.text,
    double fontSize = 11.0,
    String indentString = '    ', // 4 spaces (or '\t' for tab)
  }) {
    final style =
        CompassTypography.monoRegular(color: theme.textPrimary, size: fontSize)
            .copyWith(fontFamily: 'JetBrains Mono');
    final CompassDensity density = CompassDensity.of(context);

    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return Stack(
          alignment: Alignment.centerLeft,
          children: [
            Visibility(
              visible: value.text.isEmpty,
              maintainState: true,
              maintainAnimation: true,
              maintainSize: true,
              child: Text(
                placeholder,
                style: style.copyWith(color: theme.textMuted),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Focus(
              onKeyEvent: (FocusNode node, KeyEvent event) {
                if (event is KeyDownEvent &&
                    (event.logicalKey == LogicalKeyboardKey.enter ||
                        event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
                  // If enter was pressed between matching brackets, format and consume key
                  if (_handleEnterFormatting(controller, indentString)) {
                    onChanged(controller.text);
                    return KeyEventResult.handled;
                  }
                }
                return KeyEventResult.ignored;
              },
              child: EditableText(
                controller: controller,
                focusNode: focusNode,
                style: style,
                cursorColor: theme.accent,
                selectionColor: theme.accent.withOpacity(0.4),
                selectionControls: getPlatformSelectionControls(),
                backgroundCursorColor: theme.bgInput,
                keyboardType: TextInputType.multiline,
                maxLines: null,
                minLines: 1,
                onChanged: (text) {
                  _handleAutoClosePairs(controller);
                  onChanged(controller.text);
                },
                onSubmitted: onSubmitted,
                onTapOutside: (event) =>
                    compassHandleTapOutside(event, focusNode),
                contextMenuBuilder: (BuildContext context,
                    EditableTextState editableTextState) {
                  return compassTextContextMenuBuilderFor(anchorLink,
                      density: density)(context, editableTextState);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  /// The expanded query options panel (project / sort / skip / limit).
  ///
  /// On a phone the four fields are stacked: side by side they would each be
  /// ~80 px wide, which is unusable for a JSON payload.
  Widget _buildOptionsPanel(CompassTheme theme, CompassDensity density) {
    final projectField = _buildOptionField(
      theme: theme,
      title: 'PROJECT',
      subtitle: '1 or 0',
      placeholder: "{ title: 1, year: 1, _id: 0 }",
      controller: _projectController,
      focusNode: _projectFocus,
      onChanged: (v) {},
      onSubmitted: (_) => _executeWithCurrentFilter(),
      anchorLink: _projectMenuAnchor,
    );

    final sortField = _buildOptionField(
      theme: theme,
      title: 'SORT',
      subtitle: '1 (asc) / -1 (desc)',
      placeholder: "{ year: -1, rating: -1 }",
      controller: _sortController,
      focusNode: _sortFocus,
      onChanged: (v) {},
      onSubmitted: (_) => _executeWithCurrentFilter(),
      anchorLink: _sortMenuAnchor,
    );

    final skipField = _buildOptionField(
      theme: theme,
      title: 'SKIP',
      placeholder: "0",
      controller: _skipController,
      focusNode: _skipFocus,
      keyboardType: TextInputType.number,
      onChanged: _handleSkipChange,
      onSubmitted: (_) {
        _commitSkip();
        _executeWithCurrentFilter();
      },
      anchorLink: _skipMenuAnchor,
    );

    final limitField = _buildOptionField(
      theme: theme,
      title: 'LIMIT',
      placeholder: "20",
      controller: _limitController,
      focusNode: _limitFocus,
      keyboardType: TextInputType.number,
      onChanged: _handleLimitChange,
      onSubmitted: (_) {
        _commitLimit();
        _executeWithCurrentFilter();
      },
      anchorLink: _limitMenuAnchor,
    );

    return Container(
      padding: const EdgeInsets.only(top: 10.0),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.border, width: 1.0),
        ),
      ),
      child: density.isTouch
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                projectField,
                const SizedBox(height: 8.0),
                sortField,
                const SizedBox(height: 8.0),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: skipField),
                    const SizedBox(width: 8.0),
                    Expanded(child: limitField),
                  ],
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: projectField),
                const SizedBox(width: 8.0),
                Expanded(flex: 2, child: sortField),
                const SizedBox(width: 8.0),
                Expanded(flex: 1, child: skipField),
                const SizedBox(width: 8.0),
                Expanded(flex: 1, child: limitField),
              ],
            ),
    );
  }

  Widget _buildFindButtonCompact(CompassTheme theme, CompassDensity density,
      {VoidCallback? onTap}) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: density.minTapTarget),
      child: CompassHover(
        onTap: onTap ?? widget.onExecuteQuery,
        semanticLabel: 'Run query',
        builder: (hovered) => Container(
          height: 34.0,
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          decoration: BoxDecoration(
            color: hovered ? theme.accentHover : theme.accent,
            borderRadius: BorderRadius.circular(8.0),
          ),
          alignment: Alignment.center,
          child: Text(
            'Find',
            style: CompassTypography.header(color: theme.onAccent),
          ),
        ),
      ),
    );
  }

  /// The filter input box of the query bar.
  Widget _buildFilterInput(CompassTheme theme, {bool compact = false}) {
    return CompositedTransformTarget(
      link: _filterMenuAnchor,
      child: Container(
        constraints: BoxConstraints(minHeight: compact ? 34.0 : 36.0),
        decoration: BoxDecoration(
          color: theme.bgInput,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: theme.border, width: 1.0),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: CompassSvg(
                svgString: CompassSvgIcons.search,
                size: 14.0,
                color: theme.textMuted,
              ),
            ),
            const SizedBox(width: 6.0),
            Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Text(
                'FILTER',
                style: CompassTypography.monoBold(
                  color: theme.accent,
                  size: 11.0,
                ),
              ),
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: _buildEditable(
                theme: theme,
                controller: _filterController,
                focusNode: _filterFocus,
                placeholder: "{ field: 'value', year: { \$gte: 1990 } }",
                onChanged: _handleFilterChange,
                onSubmitted: (value) {
                  _executeWithCurrentFilter();
                },
                fontSize: 12.0,
                anchorLink: _filterMenuAnchor,
              ),
            ),
            if (_filterError)
              const CompassSvg(
                svgString: CompassSvgIcons.activity,
                size: 14.0,
                color: CompassColors.warningAmber,
              )
            else if (widget.options.filter.trim().isNotEmpty)
              CompassSvg(
                svgString: CompassSvgIcons.check,
                size: 14.0,
                color: theme.accent,
              ),
          ],
        ),
      ),
    );
  }

  /// Toggles the expanded query options panel.
  Widget _buildOptionsButton(CompassTheme theme, CompassDensity density) {
    final expanded = widget.optionsExpanded;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: density.minTapTarget),
      child: CompassHover(
        onTap: widget.onToggleOptions,
        semanticLabel: 'Query options',
        builder: (hovered) => Container(
          height: 36.0,
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          decoration: BoxDecoration(
            color: expanded
                ? theme.greenBadgeBg
                : (hovered ? theme.bgHover : theme.bgSubtle),
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(
              color: expanded
                  ? theme.greenBadgeBorder
                  : (hovered ? theme.borderHover : theme.border),
              width: 1.0,
            ),
          ),
          child: Row(
            children: [
              CompassSvg(
                svgString: CompassSvgIcons.sliders,
                size: 14.0,
                color: expanded ? theme.accent : theme.textSecondary,
              ),
              const SizedBox(width: 6.0),
              Text(
                'Options',
                style: CompassTypography.bodyMedium(
                  color: expanded ? theme.accent : theme.textSecondary,
                ),
              ),
              const SizedBox(width: 4.0),
              CompassSvg(
                svgString: expanded
                    ? CompassSvgIcons.chevronUp
                    : CompassSvgIcons.chevronDown,
                size: 12.0,
                color: theme.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Clears the current filter / sort / projection.
  Widget _buildResetButton(CompassTheme theme) {
    return CompassIconButton(
      svgString: CompassSvgIcons.rotateCcw,
      onTap: widget.onResetQuery,
      size: 14.0,
      padding: 4.0,
      boxSize: 36.0,
      borderRadius: 8.0,
      background: theme.bgSubtle,
      borderColor: theme.border,
      color: theme.textMuted,
      semanticLabel: 'Reset query',
    );
  }

  /// Opens the "export query to language" modal.
  Widget _buildShowCodeButton(CompassTheme theme, CompassDensity density) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: density.minTapTarget),
      child: CompassHover(
        onTap: widget.onExportToLanguage,
        semanticLabel: 'Show generated code',
        builder: (hovered) => Container(
          height: 36.0,
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          decoration: BoxDecoration(
            color: hovered ? theme.bgHover : theme.bgSubtle,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(
              color: hovered ? theme.borderHover : theme.border,
              width: 1.0,
            ),
          ),
          child: Row(
            children: [
              CompassSvg(
                svgString: CompassSvgIcons.code,
                size: 14.0,
                color: theme.accent,
              ),
              const SizedBox(width: 6.0),
              Text(
                'Show Code',
                style: CompassTypography.bodyMedium(
                  color: theme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Runs the query.
  Widget _buildFindButton(CompassTheme theme, CompassDensity density,
      {VoidCallback? onTap}) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: density.minTapTarget),
      child: CompassHover(
        onTap: onTap ?? widget.onExecuteQuery,
        semanticLabel: 'Run query',
        builder: (hovered) => Container(
          height: 36.0,
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          decoration: BoxDecoration(
            color: hovered ? theme.accentHover : theme.accent,
            borderRadius: BorderRadius.circular(8.0),
            boxShadow: [
              BoxShadow(
                color: theme.accent.withValues(alpha: 0.2),
                blurRadius: 4.0,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            'Find',
            style: CompassTypography.header(color: theme.onAccent),
          ),
        ),
      ),
    );
  }

  // Map of opening to closing pairs
  final Map<String, String> _bracketPairs = const {
    '(': ')',
    '[': ']',
    '{': '}',
    '"': '"',
    "'": "'",
  };

  TextEditingValue? _previousValue;

  void _handleAutoClosePairs(TextEditingController controller) {
    final current = controller.value;
    final previous = _previousValue ?? current;
    _previousValue = current;

    // Ensure change was an insertion at a single point or selection replacement
    if (current.text.length <= previous.text.length) return;

    final selection = current.selection;
    if (!selection.isCollapsed || selection.start <= 0) return;

    final typedCharIndex = selection.start - 1;
    final typedChar = current.text[typedCharIndex];

    // Case 1: Typing an opening bracket
    if (_bracketPairs.containsKey(typedChar)) {
      final closePair = _bracketPairs[typedChar]!;

      // Check if the user is typing over an existing identical closing bracket
      if (typedChar == closePair &&
          typedCharIndex + 1 < current.text.length &&
          current.text[typedCharIndex + 1] == closePair) {
        // Over-type existing closing quote/bracket
        final newText =
            current.text.replaceRange(typedCharIndex, typedCharIndex + 1, '');
        controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: typedCharIndex + 1),
        );
        _previousValue = controller.value;
        return;
      }

      // Insert the closing pair right after the cursor
      final newText = current.text.substring(0, selection.start) +
          closePair +
          current.text.substring(selection.start);

      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start),
      );
      _previousValue = controller.value;
      return;
    }

    // Case 2: User typed a closing bracket that already exists right after cursor
    if (_bracketPairs.containsValue(typedChar)) {
      if (selection.start < current.text.length &&
          current.text[selection.start] == typedChar) {
        // Skip over existing closing bracket instead of duplicating it
        final newText = current.text.substring(0, typedCharIndex) +
            current.text.substring(selection.start);

        controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: selection.start),
        );
        _previousValue = controller.value;
      }
    }
  }

  final Map<String, String> _matchingPairs = const {
    '(': ')',
    '[': ']',
    '{': '}',
  };

  bool _handleEnterFormatting(TextEditingController controller, String indent) {
    final value = controller.value;
    final selection = value.selection;

    if (!selection.isCollapsed ||
        selection.start <= 0 ||
        selection.start >= value.text.length) {
      return false;
    }

    final charBefore = value.text[selection.start - 1];
    final charAfter = value.text[selection.start];

    // Check if cursor is directly between a matching pair (e.g., {|} or [|] or (|))
    if (_matchingPairs.containsKey(charBefore) &&
        _matchingPairs[charBefore] == charAfter) {
      // Detect existing line indentation leading up to charBefore
      final textBeforeCursor = value.text.substring(0, selection.start - 1);
      final lastNewlineIndex = textBeforeCursor.lastIndexOf('\n');
      final currentLine = lastNewlineIndex == -1
          ? textBeforeCursor
          : textBeforeCursor.substring(lastNewlineIndex + 1);

      final baseIndent = RegExp(r'^\s*').stringMatch(currentLine) ?? '';
      final innerIndent = baseIndent + indent;

      // Construct expanded block:
      // {
      //   | <- cursor here
      // }
      final prefix =
          value.text.substring(0, selection.start) + '\n' + innerIndent;
      final suffix = '\n' + baseIndent + value.text.substring(selection.start);

      final newText = prefix + suffix;
      final cursorOffset = prefix.length;

      controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: cursorOffset),
      );

      return true; // Key event handled
    }

    return false;
  }
}
