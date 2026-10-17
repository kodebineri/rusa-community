import 'dart:convert';

import 'package:flutter/widgets.dart';
import '../theme/compass_colors.dart';
import '../theme/compass_typography.dart';
import '../icons/compass_svg_icons.dart';
import '../models/mongo_models.dart';

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

  const CompassQueryBar({
    super.key,
    required this.options,
    required this.onChangeOptions,
    required this.onExecuteQuery,
    required this.onResetQuery,
    required this.onExportToLanguage,
    this.executionTimeMs,
    this.totalResultsCount,
  });

  @override
  State<CompassQueryBar> createState() => _CompassQueryBarState();
}

class _CompassQueryBarState extends State<CompassQueryBar> {
  bool _isOptionsExpanded = false;
  bool _filterError = false;

  late final TextEditingController _filterController;
  late final TextEditingController _projectController;
  late final TextEditingController _sortController;
  late final TextEditingController _skipController;
  late final TextEditingController _limitController;

  final FocusNode _filterFocus = FocusNode(debugLabel: 'query-filter');
  final FocusNode _projectFocus = FocusNode(debugLabel: 'query-project');
  final FocusNode _sortFocus = FocusNode(debugLabel: 'query-sort');
  final FocusNode _skipFocus = FocusNode(debugLabel: 'query-skip');
  final FocusNode _limitFocus = FocusNode(debugLabel: 'query-limit');

  @override
  void initState() {
    super.initState();
    _filterController = TextEditingController(text: widget.options.filter);
    _projectController = TextEditingController(text: widget.options.project);
    _sortController = TextEditingController(text: widget.options.sort);
    _skipController =
        TextEditingController(text: widget.options.skip.toString());
    _limitController =
        TextEditingController(text: widget.options.limit.toString());
    // When the numeric fields lose focus, snap the text back to the committed
    // value so an empty/partial entry doesn't linger.
    _skipFocus.addListener(() {
      if (!_skipFocus.hasFocus) {
        _sync(_skipController, widget.options.skip.toString());
      }
    });
    _limitFocus.addListener(() {
      if (!_limitFocus.hasFocus) {
        _sync(_limitController, widget.options.limit.toString());
      }
    });
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
    widget.onChangeOptions(widget.options.copyWith(filter: value));
    if (!mounted) return;
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

  void _handleSkipChange(String value) {
    // Allow the field to be momentarily empty while typing; only commit numbers.
    if (value.trim().isEmpty) return;
    final parsed = int.tryParse(value.trim());
    if (parsed == null) return;
    widget.onChangeOptions(
        widget.options.copyWith(skip: parsed < 0 ? 0 : parsed));
  }

  void _handleLimitChange(String value) {
    if (value.trim().isEmpty) return;
    final parsed = int.tryParse(value.trim());
    if (parsed == null) return;
    widget.onChangeOptions(
        widget.options.copyWith(limit: parsed < 1 ? 1 : parsed));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: CompassColors.darkBgPanel,
        border: Border(
          bottom: BorderSide(color: CompassColors.darkBorder, width: 1.0),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Primary Query Row
          Row(
            children: [
              // Main Filter Input
              Expanded(
                child: Container(
                  height: 36.0,
                  decoration: BoxDecoration(
                    color: CompassColors.darkBgInput,
                    borderRadius: BorderRadius.circular(8.0),
                    border:
                        Border.all(color: CompassColors.darkBorder, width: 1.0),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: Row(
                    children: [
                      const CompassSvg(
                        svgString: CompassSvgIcons.search,
                        size: 14.0,
                        color: CompassColors.darkTextMuted,
                      ),
                      const SizedBox(width: 6.0),
                      Text(
                        'FILTER',
                        style: CompassTypography.monoBold(
                          color: CompassColors.greenAccent,
                          size: 11.0,
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      Expanded(
                        child: _buildEditable(
                          controller: _filterController,
                          focusNode: _filterFocus,
                          placeholder:
                              "{ field: 'value', year: { \$gte: 1990 } }",
                          onChanged: _handleFilterChange,
                          onSubmitted: (_) => widget.onExecuteQuery(),
                          fontSize: 12.0,
                        ),
                      ),
                      if (_filterError)
                        const CompassSvg(
                          svgString: CompassSvgIcons.activity,
                          size: 14.0,
                          color: CompassColors.warningAmber,
                        )
                      else if (widget.options.filter.trim().isNotEmpty)
                        const CompassSvg(
                          svgString: CompassSvgIcons.check,
                          size: 14.0,
                          color: CompassColors.greenAccent,
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 8.0),

              // Options Toggle Button
              GestureDetector(
                onTap: () {
                  setState(() {
                    _isOptionsExpanded = !_isOptionsExpanded;
                  });
                },
                child: Container(
                  height: 36.0,
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  decoration: BoxDecoration(
                    color: _isOptionsExpanded
                        ? CompassColors.greenBadgeBg
                        : CompassColors.darkBgSubtle,
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(
                      color: _isOptionsExpanded
                          ? CompassColors.greenBadgeBorder
                          : CompassColors.darkBorder,
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      CompassSvg(
                        svgString: CompassSvgIcons.sliders,
                        size: 14.0,
                        color: _isOptionsExpanded
                            ? CompassColors.greenAccent
                            : CompassColors.darkTextSecondary,
                      ),
                      const SizedBox(width: 6.0),
                      Text(
                        'Options',
                        style: CompassTypography.bodyMedium(
                          color: _isOptionsExpanded
                              ? CompassColors.greenAccent
                              : CompassColors.darkTextSecondary,
                        ),
                      ),
                      const SizedBox(width: 4.0),
                      CompassSvg(
                        svgString: _isOptionsExpanded
                            ? CompassSvgIcons.chevronUp
                            : CompassSvgIcons.chevronDown,
                        size: 12.0,
                        color: CompassColors.darkTextMuted,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 6.0),

              // Reset Button
              GestureDetector(
                onTap: widget.onResetQuery,
                child: Container(
                  height: 36.0,
                  width: 36.0,
                  decoration: BoxDecoration(
                    color: CompassColors.darkBgSubtle,
                    borderRadius: BorderRadius.circular(8.0),
                    border:
                        Border.all(color: CompassColors.darkBorder, width: 1.0),
                  ),
                  alignment: Alignment.center,
                  child: const CompassSvg(
                    svgString: CompassSvgIcons.rotateCcw,
                    size: 14.0,
                    color: CompassColors.darkTextMuted,
                  ),
                ),
              ),

              const SizedBox(width: 6.0),

              // Export to Language
              GestureDetector(
                onTap: widget.onExportToLanguage,
                child: Container(
                  height: 36.0,
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  decoration: BoxDecoration(
                    color: CompassColors.darkBgSubtle,
                    borderRadius: BorderRadius.circular(8.0),
                    border:
                        Border.all(color: CompassColors.darkBorder, width: 1.0),
                  ),
                  child: Row(
                    children: [
                      const CompassSvg(
                        svgString: CompassSvgIcons.code,
                        size: 14.0,
                        color: CompassColors.greenAccent,
                      ),
                      const SizedBox(width: 6.0),
                      Text(
                        'Show Code',
                        style: CompassTypography.bodyMedium(
                          color: CompassColors.darkTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 8.0),

              // Find Button (Primary)
              GestureDetector(
                onTap: widget.onExecuteQuery,
                child: Container(
                  height: 36.0,
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  decoration: BoxDecoration(
                    color: CompassColors.greenAccent,
                    borderRadius: BorderRadius.circular(8.0),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x3300ED64),
                        blurRadius: 4.0,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Find',
                    style: CompassTypography.header(
                        color: CompassColors.greenNavy),
                  ),
                ),
              ),
            ],
          ),

          // Expanded Query Options Panel
          if (_isOptionsExpanded) ...[
            const SizedBox(height: 10.0),
            Container(
              padding: const EdgeInsets.only(top: 10.0),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: CompassColors.darkBorder, width: 1.0),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // PROJECT
                  Expanded(
                    flex: 2,
                    child: _buildOptionField(
                      title: 'PROJECT',
                      subtitle: '1 or 0',
                      placeholder: "{ title: 1, year: 1, _id: 0 }",
                      controller: _projectController,
                      focusNode: _projectFocus,
                      onChanged: (v) => widget
                          .onChangeOptions(widget.options.copyWith(project: v)),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  // SORT
                  Expanded(
                    flex: 2,
                    child: _buildOptionField(
                      title: 'SORT',
                      subtitle: '1 (asc) / -1 (desc)',
                      placeholder: "{ year: -1, rating: -1 }",
                      controller: _sortController,
                      focusNode: _sortFocus,
                      onChanged: (v) => widget
                          .onChangeOptions(widget.options.copyWith(sort: v)),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  // SKIP
                  Expanded(
                    flex: 1,
                    child: _buildOptionField(
                      title: 'SKIP',
                      placeholder: "0",
                      controller: _skipController,
                      focusNode: _skipFocus,
                      keyboardType: TextInputType.number,
                      onChanged: _handleSkipChange,
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  // LIMIT
                  Expanded(
                    flex: 1,
                    child: _buildOptionField(
                      title: 'LIMIT',
                      placeholder: "20",
                      controller: _limitController,
                      focusNode: _limitFocus,
                      keyboardType: TextInputType.number,
                      onChanged: _handleLimitChange,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Query Stats Ribbon
          if (widget.totalResultsCount != null ||
              widget.executionTimeMs != null) ...[
            const SizedBox(height: 6.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text('Matches: ', style: CompassTypography.monoSmall()),
                    Text(
                      '${widget.totalResultsCount ?? 0}',
                      style: CompassTypography.monoBold(
                          color: CompassColors.darkTextPrimary, size: 11.0),
                    ),
                    const SizedBox(width: 8.0),
                    Text('·', style: CompassTypography.monoSmall()),
                    const SizedBox(width: 8.0),
                    Text('Time: ', style: CompassTypography.monoSmall()),
                    Text(
                      '${widget.executionTimeMs ?? 0.8}ms',
                      style: CompassTypography.monoBold(
                          color: CompassColors.greenAccent, size: 11.0),
                    ),
                  ],
                ),
                Text(
                  'Tip: Press Enter to find',
                  style: CompassTypography.caption(
                      color: CompassColors.darkTextMuted),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOptionField({
    required String title,
    String? subtitle,
    required String placeholder,
    required TextEditingController controller,
    required FocusNode focusNode,
    required ValueChanged<String> onChanged,
    TextInputType keyboardType = TextInputType.text,
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
                  color: CompassColors.darkTextMuted, size: 10.0),
            ),
            if (subtitle != null)
              Text(
                subtitle,
                style: CompassTypography.caption(
                    color: CompassColors.darkTextMuted),
              ),
          ],
        ),
        const SizedBox(height: 4.0),
        Container(
          height: 30.0,
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          decoration: BoxDecoration(
            color: CompassColors.darkBgInput,
            borderRadius: BorderRadius.circular(4.0),
            border: Border.all(color: CompassColors.darkBorder, width: 1.0),
          ),
          alignment: Alignment.centerLeft,
          child: _buildEditable(
            controller: controller,
            focusNode: focusNode,
            placeholder: placeholder,
            onChanged: onChanged,
            keyboardType: keyboardType,
            fontSize: 11.0,
          ),
        ),
      ],
    );
  }

  /// Material-free single-line editable text with placeholder overlay.
  ///
  /// The placeholder is always in the tree (only its visibility toggles) so the
  /// [EditableText] element keeps its slot and never loses its text-input
  /// connection when the field transitions between empty and non-empty.
  Widget _buildEditable({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String placeholder,
    required ValueChanged<String> onChanged,
    ValueChanged<String>? onSubmitted,
    TextInputType keyboardType = TextInputType.text,
    double fontSize = 11.0,
  }) {
    final style = CompassTypography.monoRegular(
        color: CompassColors.darkTextPrimary, size: fontSize);
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
                style: style.copyWith(color: CompassColors.darkTextMuted),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            EditableText(
              controller: controller,
              focusNode: focusNode,
              style: style,
              cursorColor: CompassColors.greenAccent,
              backgroundCursorColor: CompassColors.darkBgInput,
              keyboardType: keyboardType,
              maxLines: 1,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
            ),
          ],
        );
      },
    );
  }
}
