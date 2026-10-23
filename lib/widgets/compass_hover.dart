import 'package:flutter/widgets.dart';

/// Adds pointer hover feedback to any control.
///
/// The app is built without Material widgets, so there is no `InkWell` or
/// `Ink` to lean on and hover states have to be opted into per control. Before
/// this existed the desktop build had **no** hover feedback at all: buttons
/// looked identical whether the pointer was on them or not.
///
/// The [builder] receives the current hover state so the control can repaint
/// itself — a button with its own fill swaps that fill, a bare icon shows a
/// hover surface.
///
/// [onTap] turns the control into a button: the pointer cursor becomes a
/// hand and the whole child area becomes tappable.
class CompassHover extends StatefulWidget {
  final Widget Function(bool isHovered) builder;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? semanticLabel;

  const CompassHover({
    super.key,
    required this.builder,
    this.onTap,
    this.onLongPress,
    this.semanticLabel,
  });

  @override
  State<CompassHover> createState() => _CompassHoverState();
}

class _CompassHoverState extends State<CompassHover> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    Widget result = MouseRegion(
      cursor:
          widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: widget.builder(_hovered),
    );

    if (widget.onTap != null || widget.onLongPress != null) {
      result = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: result,
      );
    }

    if (widget.semanticLabel != null) {
      result = Semantics(
        button: true,
        enabled: widget.onTap != null,
        label: widget.semanticLabel,
        child: result,
      );
    }

    return result;
  }
}
