import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../icons/compass_svg_icons.dart';
import '../theme/compass_density.dart';
import '../theme/compass_theme.dart';
import '../theme/compass_typography.dart';
import 'compass_hover.dart';

/// The Material-free replacement for Flutter's text selection toolbar.
///
/// Flutter ships `AdaptiveTextSelectionToolbar` in `package:flutter/material.dart`.
/// It needs `MaterialLocalizations` (and therefore a `MaterialApp`) and this app
/// has neither, so the menu is assembled by hand: a themed panel with one row
/// per action.
///
/// Without this the app has **no** copy / paste at all: a bare `EditableText`
/// with neither `selectionControls` nor `contextMenuBuilder` disposes its
/// selection overlay, so a long press does nothing and there is no toolbar.
/// On a phone that makes every text field (filter, connection form, document
/// JSON, mongosh prompt) painful to use.
///
/// Wire it up with [compassTextContextMenuBuilderFor].
class CompassTextContextMenu extends StatelessWidget {
  /// Touch metrics for the menu rows.
  ///
  /// The menu lives in the root overlay, which sits above the app's
  /// [CompassDensity] provider, so the profile has to be handed down.
  final CompassDensity density;

  final VoidCallback onCut;
  final VoidCallback onCopy;
  final VoidCallback onPaste;
  final VoidCallback onSelectAll;
  final bool canCut;
  final bool canCopy;
  final bool canPaste;

  const CompassTextContextMenu({
    super.key,
    required this.density,
    required this.onCut,
    required this.onCopy,
    required this.onPaste,
    required this.onSelectAll,
    this.canCut = true,
    this.canCopy = true,
    this.canPaste = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = CompassTheme.of(context);

    return GestureDetector(
      // Tapping the panel (but not a row) closes the menu.
      behavior: HitTestBehavior.opaque,
      onTap: ContextMenuController.removeAny,
      child: Container(
        constraints: const BoxConstraints(minWidth: 168.0),
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        decoration: BoxDecoration(
          color: theme.bgPanel,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: theme.border, width: 1.0),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 16.0,
              offset: Offset(0.0, 6.0),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildRow(
              theme,
              label: 'Cut',
              svg: CompassSvgIcons.cut,
              enabled: canCut,
              onTap: onCut,
            ),
            _buildRow(
              theme,
              label: 'Copy',
              svg: CompassSvgIcons.copy,
              enabled: canCopy,
              onTap: onCopy,
            ),
            _buildRow(
              theme,
              label: 'Paste',
              svg: CompassSvgIcons.paste,
              enabled: canPaste,
              onTap: onPaste,
            ),
            Container(height: 1.0, color: theme.border),
            _buildRow(
              theme,
              label: 'Select all',
              svg: CompassSvgIcons.selectAll,
              enabled: true,
              onTap: onSelectAll,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(
    CompassTheme theme, {
    required String label,
    required String svg,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    final Color color = enabled ? theme.textPrimary : theme.textMuted;

    return CompassHover(
      onTap: enabled ? onTap : null,
      semanticLabel: label,
      builder: (hovered) => Container(
        constraints: BoxConstraints(minHeight: density.minTapTarget),
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
        color: hovered && enabled ? theme.bgHover : null,
        child: Row(
          children: [
            CompassSvg(svgString: svg, size: 14.0, color: color),
            const SizedBox(width: 10.0),
            Text(label, style: CompassTypography.bodyMedium(color: color)),
          ],
        ),
      ),
    );
  }
}

/// Builds the context menu for a bare [EditableText], anchored to the field.
///
/// The field has to be wrapped in a [CompositedTransformTarget] and the same
/// [LayerLink] handed to this builder:
///
/// ```dart
/// CompositedTransformTarget(
///   link: _anchorLink,
///   child: EditableText(
///     …
///     contextMenuBuilder: compassTextContextMenuBuilderFor(
///       _anchorLink,
///       density: CompassDensity.of(context),
///     ),
///   ),
/// )
/// ```
///
/// The target is not optional cosmetics: Flutter inserts the menu into the
/// root overlay and cancels out the field's own position, so an unanchored
/// menu opens in the top-left corner of the window instead of next to the
/// text the user is editing.
///
/// The menu closes itself after every action, and the actions are disabled
/// when they would do nothing (no selection → no cut/copy).
EditableTextContextMenuBuilder compassTextContextMenuBuilderFor(
  LayerLink anchorLink, {
  required CompassDensity density,
}) {
  return (BuildContext context, EditableTextState editableTextState) {
    // ignore: avoid_print
    print('PROBE-MENU builder called sel=${editableTextState.textEditingValue.selection}');
    final TextEditingValue value = editableTextState.textEditingValue;
    final bool hasSelection =
        value.selection.isValid && !value.selection.isCollapsed;

    void close() => ContextMenuController.removeAny();

    final Widget menu = CompassTextContextMenu(
      density: density,
      canCut: hasSelection && !editableTextState.widget.readOnly,
      canCopy: hasSelection,
      onCut: () {
        editableTextState.cutSelection(SelectionChangedCause.toolbar);
        close();
      },
      onCopy: () {
        editableTextState.copySelection(SelectionChangedCause.toolbar);
        close();
      },
      onPaste: () {
        editableTextState.pasteText(SelectionChangedCause.toolbar);
        close();
      },
      onSelectAll: () {
        editableTextState.selectAll(SelectionChangedCause.toolbar);
        close();
      },
    );

    // Open the menu under the field, or over it when the field sits close to
    // the bottom of the window (the mongosh prompt always does).
    final Rect field = _fieldRect(editableTextState.context);
    final double screenHeight =
        MediaQuery.maybeOf(context)?.size.height ?? double.infinity;
    final bool below =
        field.bottom + _estimatedMenuHeight(density) <= screenHeight;

    return CompositedTransformFollower(
      link: anchorLink,
      showWhenUnlinked: false,
      targetAnchor: below ? Alignment.bottomLeft : Alignment.topLeft,
      followerAnchor: below ? Alignment.topLeft : Alignment.bottomLeft,
      offset: below ? const Offset(0.0, 4.0) : const Offset(0.0, -4.0),
      child: menu,
    );
  };
}

/// The global rectangle of the text field the menu belongs to.
///
/// The menu is anchored to the field's [CompositedTransformTarget], but the
/// target is not reachable from here — the field's own render box is close
/// enough to tell whether the menu fits below it.
Rect _fieldRect(BuildContext fieldContext) {
  final RenderObject? object = fieldContext.findRenderObject();
  if (object is RenderBox && object.attached && object.hasSize) {
    return object.localToGlobal(Offset.zero) & object.size;
  }
  return Rect.zero;
}

/// Rough height of the menu, used to decide whether it fits below the field.
///
/// Four rows (cut / copy / paste / select all) plus the panel's padding.
double _estimatedMenuHeight(CompassDensity density) {
  final double row =
      density.minTapTarget > 28.0 ? density.minTapTarget : 28.0;
  return row * 4.0 + 10.0;
}

/// Closes the context menu when the user taps outside the text field.
///
/// Flutter's own handler closes the selection toolbar by dropping the field's
/// focus — but it deliberately keeps the focus on touch devices so that the
/// soft keyboard stays open, which would leave the menu floating over the
/// app. Mouse-like pointers keep the framework's behaviour (the field is
/// unfocused).
///
/// Pass it to [EditableText.onTapOutside].
void compassHandleTapOutside(PointerDownEvent event, FocusNode focusNode) {
  ContextMenuController.removeAny();
  if (event.kind != PointerDeviceKind.touch) {
    focusNode.unfocus();
  }
}
