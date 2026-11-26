import 'package:flutter/widgets.dart';

import '../theme/compass_density.dart';
import '../theme/compass_theme.dart';
import 'compass_text_menu.dart';

/// A read-only value the user can highlight and copy.
///
/// The document views used to render their values with plain [Text] widgets,
/// which Flutter never makes selectable. A bare, read-only [EditableText] gives
/// the I-beam cursor and paints a selection, but it does **not** install the
/// tap/drag/long-press handlers that turn gestures into a selection -- those
/// come from [TextSelectionGestureDetectorBuilder], which `SelectableText` and
/// `TextField` wrap around it. This widget supplies that builder itself so the
/// app stays Material-free while gaining real gesture selection.
class CompassSelectableText extends StatefulWidget {
  /// Creates a selectable run of text with a single style.
  const CompassSelectableText(
    this.text, {
    super.key,
    required this.style,
    this.maxLines = 1,
    this.textAlign = TextAlign.start,
    this.selectionColor,
  }) : textSpan = null;

  /// Creates a selectable run with mixed styles (for example, syntax-coloured
  /// JSON). The controller keeps the span's plain text for selection offsets.
  const CompassSelectableText.rich(
    TextSpan this.textSpan, {
    super.key,
    required this.style,
    this.maxLines = 1,
    this.textAlign = TextAlign.start,
    this.selectionColor,
  }) : text = '';

  final String text;
  final TextSpan? textSpan;
  final TextStyle style;

  /// `null` grows to as many lines as the text needs (the JSON card body).
  final int? maxLines;
  final TextAlign textAlign;
  final Color? selectionColor;

  @override
  State<CompassSelectableText> createState() => _CompassSelectableTextState();
}

/// Keeps a prebuilt [TextSpan] as the rendered text while the controller's
/// plain value stays in sync for selection and copying.
class _SpanTextController extends TextEditingController {
  _SpanTextController(TextSpan span)
      : _span = span,
        super(text: span.toPlainText(includeSemanticsLabels: false));

  TextSpan _span;

  /// Rebuilds the span when the document value (or its theme) changes.
  /// The selection is left alone when the plain text is unchanged, so a parent
  /// rebuild cannot clear a highlight the user is dragging out.
  void updateSpan(TextSpan next) {
    _span = next;
    final String plain = next.toPlainText(includeSemanticsLabels: false);
    if (value.text != plain) {
      value = TextEditingValue(
        text: plain,
        selection: const TextSelection.collapsed(offset: 0),
      );
    } else {
      notifyListeners();
    }
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    return _span;
  }
}

class _CompassSelectableTextState extends State<CompassSelectableText>
    implements TextSelectionGestureDetectorBuilderDelegate {
  final LayerLink _menuAnchor = LayerLink();
  final FocusNode _focusNode = FocusNode(skipTraversal: true);
  final GlobalKey<EditableTextState> _editableTextKey = GlobalKey<EditableTextState>();

  late TextEditingController _controller = _createController();
  late final TextSelectionGestureDetectorBuilder _selectionGestureDetectorBuilder;

  bool _showSelectionHandles = false;

  // TextSelectionGestureDetectorBuilderDelegate.
  @override
  GlobalKey<EditableTextState> get editableTextKey => _editableTextKey;

  @override
  bool get forcePressEnabled => false;

  @override
  bool get selectionEnabled => true;

  TextEditingController _createController() => widget.textSpan == null
      ? TextEditingController(text: widget.text)
      : _SpanTextController(widget.textSpan!);

  @override
  void initState() {
    super.initState();
    _selectionGestureDetectorBuilder = TextSelectionGestureDetectorBuilder(delegate: this);
    _controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(covariant CompassSelectableText oldWidget) {
    super.didUpdateWidget(oldWidget);
    final TextSpan? nextSpan = widget.textSpan;
    final bool switchedToRich = nextSpan != null && oldWidget.textSpan == null;
    final bool switchedToPlain = nextSpan == null && oldWidget.textSpan != null;

    if (switchedToRich || switchedToPlain) {
      _controller.removeListener(_handleControllerChanged);
      _controller.dispose();
      _controller = _createController();
      _controller.addListener(_handleControllerChanged);
    } else if (nextSpan != null) {
      (_controller as _SpanTextController).updateSpan(nextSpan);
    } else if (oldWidget.text != widget.text) {
      _controller.value = TextEditingValue(
        text: widget.text,
        selection: const TextSelection.collapsed(offset: 0),
      );
    }
  }

  void _handleControllerChanged() {
    final bool showHandles =
        !_focusNode.hasFocus || !_controller.selection.isCollapsed;
    if (showHandles != _showSelectionHandles && mounted) {
      setState(() => _showSelectionHandles = showHandles);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CompassDensity density = CompassDensity.of(context);
    final CompassTheme theme = CompassTheme.of(context);

    final Widget child = CompositedTransformTarget(
      link: _menuAnchor,
      child: EditableText(
        key: _editableTextKey,
        controller: _controller,
        focusNode: _focusNode,
        style: widget.style,
        textAlign: widget.textAlign,
        maxLines: widget.maxLines,
        readOnly: true,
        showCursor: false,
        showSelectionHandles: _showSelectionHandles,
        enableInteractiveSelection: true,
        // The outer gesture detector owns selection gestures; the editable's
        // own recognizers must not compete for the same pointer (this is what
        // SelectableText does with rendererIgnoresPointer).
        rendererIgnoresPointer: true,
        cursorColor: theme.accent,
        backgroundCursorColor: theme.bgInput,
        selectionColor:
            widget.selectionColor ?? theme.accent.withValues(alpha: 0.35),
        contextMenuBuilder: compassTextContextMenuBuilderFor(
          _menuAnchor,
          density: density,
        ),
        onTapOutside: (event) => compassHandleTapOutside(event, _focusNode),
      ),
    );

    return _selectionGestureDetectorBuilder.buildGestureDetector(
      behavior: HitTestBehavior.translucent,
      child: child,
    );
  }
}
