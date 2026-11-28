import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../theme/compass_density.dart';
import '../theme/compass_theme.dart';
import 'compass_text_menu.dart';

/// A material-free [EditableText] with working selection gestures.
///
/// Flutter 3.50 no longer puts tap / drag / long-press / right-click handlers on
/// [EditableText] itself: those come from
/// [TextSelectionGestureDetectorBuilder], which `TextField` and `SelectableText`
/// wrap around it. Without that builder a bare editable field shows an I-beam
/// cursor but right-clicking it does nothing and the custom copy menu never
/// opens. This widget supplies the builder, the menu anchor and tap-outside
/// dismissal so every Rusa input behaves like a real text field while the app
/// stays free of Material ancestors.
///
/// The caller still owns the [CompositedTransformTarget] (usually the field's
/// border container) and must pass the same [LayerLink] as [anchorLink] so the
/// menu opens beside the selected text instead of in the window corner.
class CompassEditableText extends StatefulWidget {
  const CompassEditableText({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.anchorLink,
    required this.style,
    required this.cursorColor,
    required this.backgroundCursorColor,
    this.selectionColor,
    this.selectionControls,
    this.maxLines,
    this.minLines = 1,
    this.obscureText = false,
    this.showCursor = true,
    this.autofocus = false,
    this.textAlign = TextAlign.start,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.onEditingComplete,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final LayerLink anchorLink;

  final TextStyle style;
  final Color cursorColor;
  final Color backgroundCursorColor;

  /// Highlight behind selected text. Defaults to a clearly visible accent tint
  /// so every field paints a highlight even if the caller forgets to pass one.
  final Color? selectionColor;
  final TextSelectionControls? selectionControls;

  final int? maxLines;
  final int minLines;
  final bool obscureText;
  final bool showCursor;
  final bool autofocus;
  final TextAlign textAlign;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;

  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onEditingComplete;

  @override
  State<CompassEditableText> createState() => _CompassEditableTextState();
}

class _CompassEditableTextState extends State<CompassEditableText>
    implements TextSelectionGestureDetectorBuilderDelegate {
  final GlobalKey<EditableTextState> _editableTextKey =
      GlobalKey<EditableTextState>();
  late final TextSelectionGestureDetectorBuilder _gestureBuilder;

  bool _showSelectionHandles = false;

  @override
  GlobalKey<EditableTextState> get editableTextKey => _editableTextKey;

  @override
  bool get forcePressEnabled => false;

  @override
  bool get selectionEnabled => true;

  @override
  void initState() {
    super.initState();
    _gestureBuilder = TextSelectionGestureDetectorBuilder(delegate: this);
    widget.controller.addListener(_handleValueChanged);
    widget.focusNode.addListener(_handleFocusChanged);
  }

  @override
  void didUpdateWidget(covariant CompassEditableText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleValueChanged);
      widget.controller.addListener(_handleValueChanged);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_handleFocusChanged);
      widget.focusNode.addListener(_handleFocusChanged);
    }
    _syncSelectionHandles();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleValueChanged);
    widget.focusNode.removeListener(_handleFocusChanged);
    super.dispose();
  }

  void _handleValueChanged() => _syncSelectionHandles();

  void _handleFocusChanged() => _syncSelectionHandles();

  /// Handles belong to a non-empty selection; a focused collapsed selection
  /// only needs its caret. Mirrors `TextField`'s own bookkeeping.
  void _syncSelectionHandles() {
    final bool next =
        !widget.focusNode.hasFocus || !widget.controller.selection.isCollapsed;
    if (next != _showSelectionHandles && mounted) {
      setState(() => _showSelectionHandles = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final CompassDensity density = CompassDensity.of(context);
    final CompassTheme theme = CompassTheme.of(context);
    final Color highlight =
        widget.selectionColor ?? theme.accent.withValues(alpha: 0.35);

    return _gestureBuilder.buildGestureDetector(
      behavior: HitTestBehavior.translucent,
      child: EditableText(
        key: _editableTextKey,
        controller: widget.controller,
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        style: widget.style,
        textAlign: widget.textAlign,
        cursorColor: widget.cursorColor,
        backgroundCursorColor: widget.backgroundCursorColor,
        selectionColor: highlight,
        selectionControls: widget.selectionControls,
        maxLines: widget.maxLines,
        minLines: widget.minLines,
        obscureText: widget.obscureText,
        showCursor: widget.showCursor,
        showSelectionHandles: _showSelectionHandles,
        keyboardType: widget.keyboardType ?? TextInputType.text,
        textInputAction: widget.textInputAction,
        inputFormatters: widget.inputFormatters,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        onEditingComplete: widget.onEditingComplete,
        // The builder above owns the pointer gestures, so the editable must
        // not compete for the same pointer (this is what TextField does).
        rendererIgnoresPointer: true,
        onTapOutside: (event) =>
            compassHandleTapOutside(event, widget.focusNode),
        contextMenuBuilder:
            compassTextContextMenuBuilderFor(widget.anchorLink, density: density),
      ),
    );
  }
}
