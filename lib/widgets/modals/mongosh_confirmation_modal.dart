import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../../icons/compass_svg_icons.dart';
import '../../theme/compass_colors.dart';
import '../../theme/compass_theme.dart';
import '../../theme/compass_typography.dart';

/// Details of a risky mongosh operation awaiting confirmation.
/// Mirrors `RiskyOperationDetails` from MongoshConfirmationModal.tsx.
class RiskyOperationDetails {
  final String type; // dropDatabase | dropCollection | deleteMany | deleteOne | updateMany | updateOne
  final String title;
  final String command;
  final String dbName;
  final String? collName;
  final String description;
  final String impact;
  final String? filterPreview;
  final String? updatePreview;

  const RiskyOperationDetails({
    required this.type,
    required this.title,
    required this.command,
    required this.dbName,
    this.collName,
    required this.description,
    required this.impact,
    this.filterPreview,
    this.updatePreview,
  });

  bool get isDestructive =>
      type == 'dropDatabase' ||
      type == 'dropCollection' ||
      type == 'deleteMany' ||
      type == 'deleteOne';

  String get typeLabel {
    switch (type) {
      case 'dropDatabase':
        return 'DROP DATABASE';
      case 'dropCollection':
        return 'DROP COLLECTION';
      case 'deleteMany':
        return 'DELETE MANY';
      case 'deleteOne':
        return 'DELETE ONE';
      case 'updateMany':
        return 'UPDATE MANY';
      case 'updateOne':
        return 'UPDATE ONE';
      default:
        return type.toUpperCase();
    }
  }
}

enum _RiskyAction { cancel, confirm }

/// Converted from src/components/MongoshConfirmationModal.tsx
///
/// A defensive confirmation dialog for destructive terminal commands. Cancel is
/// selected by default and Enter/Space cannot confirm until a short debounce has
/// elapsed, matching the React guard-rails.
class MongoshConfirmationModal extends StatefulWidget {
  final bool isOpen;
  final RiskyOperationDetails? operation;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const MongoshConfirmationModal({
    super.key,
    required this.isOpen,
    required this.operation,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<MongoshConfirmationModal> createState() => _MongoshConfirmationModalState();
}

class _MongoshConfirmationModalState extends State<MongoshConfirmationModal> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'mongosh-confirm');
  _RiskyAction _selectedAction = _RiskyAction.cancel;
  bool _canConfirmDestructive = false;

  CompassTheme get _theme => CompassTheme.of(context);

  static const Color _cardBg = Color(0xFF12181F);
  static const Color _panelBg = Color(0xFF0A0E13);
  static const Color _terminalBg = Color(0xFF080B0E);
  static const Color _inactiveBg = Color(0xFF0E141B);

  @override
  void didUpdateWidget(covariant MongoshConfirmationModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen && !oldWidget.isOpen) {
      _selectedAction = _RiskyAction.cancel;
      _canConfirmDestructive = false;
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && widget.isOpen) setState(() => _canConfirmDestructive = true);
      });
      Future.delayed(const Duration(milliseconds: 40), () {
        if (mounted && widget.isOpen) _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _executeSelection() {
    if (_selectedAction == _RiskyAction.cancel) {
      widget.onCancel();
    } else if (_canConfirmDestructive) {
      widget.onConfirm();
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.keyC ||
        key == LogicalKeyboardKey.keyN) {
      widget.onCancel();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyY) {
      setState(() => _selectedAction = _RiskyAction.confirm);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowUp) {
      setState(() => _selectedAction = _RiskyAction.cancel);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.arrowDown) {
      setState(() => _selectedAction = _RiskyAction.confirm);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.tab) {
      setState(() {
        _selectedAction = _selectedAction == _RiskyAction.cancel
            ? _RiskyAction.confirm
            : _RiskyAction.cancel;
      });
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space) {
      _executeSelection();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final op = widget.operation;
    if (!widget.isOpen || op == null) return const SizedBox.shrink();

    final destructive = op.isDestructive;
    final accent = destructive ? CompassColors.errorRed : CompassColors.warningAmber;

    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = 512.0 < constraints.maxWidth - 32.0 ? 512.0 : constraints.maxWidth - 32.0;
          final maxHeight = constraints.maxHeight - 64.0;

          final card = Container(
            width: width,
            margin: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: _theme.border, width: 1.0),
              boxShadow: const [
                BoxShadow(color: Color(0x99000000), blurRadius: 24.0, offset: Offset(0, 8)),
              ],
            ),
            padding: const EdgeInsets.all(20.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _buildContent(op, destructive, accent),
                ),
              ),
            ),
          );

          return Focus(
            focusNode: _focusNode,
            autofocus: true,
            onKeyEvent: _onKey,
            child: Container(
              color: const Color(0xCC000000),
              alignment: Alignment.center,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onCancel,
                child: GestureDetector(onTap: () {}, child: card),
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildContent(RiskyOperationDetails op, bool destructive, Color accent) {
    return [
      // Header
      Container(
        padding: const EdgeInsets.only(bottom: 12.0),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: _theme.border, width: 1.0)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10.0),
              decoration: BoxDecoration(
                color: destructive ? CompassColors.errorRedBg : CompassColors.warningAmberBg,
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(
                  color: destructive ? CompassColors.errorRedBorder : CompassColors.warningAmberBorder,
                  width: 1.0,
                ),
              ),
              child: CompassSvg(svgString: CompassSvgIcons.activity, size: 18.0, color: accent),
            ),
            const SizedBox(width: 12.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Risky Database Operation',
                        style: CompassTypography.header(color: const Color(0xFFFFFFFF)),
                      ),
                      const SizedBox(width: 8.0),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                        decoration: BoxDecoration(
                          color: destructive ? CompassColors.errorRedBg : CompassColors.warningAmberBg,
                          borderRadius: BorderRadius.circular(4.0),
                          border: Border.all(
                            color: destructive ? CompassColors.errorRedBorder : CompassColors.warningAmberBorder,
                            width: 1.0,
                          ),
                        ),
                        child: Text(op.typeLabel, style: CompassTypography.badge(color: accent)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2.0),
                  Text(
                    'mongosh requested execution of a data-altering command',
                    style: CompassTypography.caption(color: _theme.textMuted),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: widget.onCancel,
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: CompassSvg(
                  svgString: CompassSvgIcons.close,
                  size: 14.0,
                  color: _theme.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14.0),

      // Target context strip
      Row(
        children: [
          Expanded(child: _contextCard('DATABASE', op.dbName, CompassSvgIcons.database)),
          const SizedBox(width: 8.0),
          Expanded(
            child: _contextCard(
              'TARGET',
              op.collName ?? '(All collections in DB)',
              CompassSvgIcons.table,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12.0),

      // Command preview
      Row(
        children: [
          CompassSvg(svgString: CompassSvgIcons.terminal, size: 13.0, color: _theme.accent),
          const SizedBox(width: 6.0),
          Text('COMMAND TO EXECUTE', style: CompassTypography.monoSmall(color: _theme.textMuted)),
        ],
      ),
      const SizedBox(height: 6.0),
      Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: _terminalBg,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: const Color(0xFF283946), width: 1.0),
        ),
        child: Text(
          op.command,
          style: CompassTypography.monoSmall(color: const Color(0xFFFCD34D)),
        ),
      ),
      const SizedBox(height: 12.0),

      // Warning callout
      Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: destructive ? CompassColors.errorRedBg : CompassColors.warningAmberBg,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(
            color: destructive ? CompassColors.errorRedBorder : CompassColors.warningAmberBorder,
            width: 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CompassSvg(svgString: CompassSvgIcons.shieldCheck, size: 15.0, color: accent),
                const SizedBox(width: 6.0),
                Expanded(child: Text(op.description, style: CompassTypography.bodyMedium(color: accent))),
              ],
            ),
            const SizedBox(height: 4.0),
            Padding(
              padding: const EdgeInsets.only(left: 21.0),
              child: Text(op.impact, style: CompassTypography.caption(color: accent)),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12.0),

      Text('SELECT ACTION:', style: CompassTypography.monoSmall(color: _theme.textMuted)),
      const SizedBox(height: 8.0),
      _actionCard(
        label: 'Cancel Operation',
        tag: 'SAFE / RECOMMENDED',
        description: 'Abort execution and keep all database records untouched.',
        selected: _selectedAction == _RiskyAction.cancel,
        isCancel: true,
      ),
      const SizedBox(height: 8.0),
      _actionCard(
        label: 'Confirm & Execute Command',
        tag: 'IRREVERSIBLE',
        description: 'Proceed with data modification or deletion.',
        selected: _selectedAction == _RiskyAction.confirm,
        isCancel: false,
      ),
      const SizedBox(height: 14.0),

      // Footer actions
      Container(
        padding: const EdgeInsets.only(top: 12.0),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: _theme.border, width: 1.0)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _footerButton(
              label: 'Cancel Operation',
              hint: '(Esc / N)',
              selected: _selectedAction == _RiskyAction.cancel,
              isCancel: true,
              onTap: widget.onCancel,
              onSelect: () => setState(() => _selectedAction = _RiskyAction.cancel),
            ),
            const SizedBox(width: 10.0),
            _footerButton(
              label: 'Confirm & Execute',
              hint: '(Y)',
              selected: _selectedAction == _RiskyAction.confirm,
              isCancel: false,
              onTap: _canConfirmDestructive ? widget.onConfirm : null,
              onSelect: () => setState(() => _selectedAction = _RiskyAction.confirm),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _contextCard(String label, String value, String iconSvg) {
    return Container(
      padding: const EdgeInsets.all(10.0),
      decoration: BoxDecoration(
        color: _panelBg,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: _theme.border, width: 1.0),
      ),
      child: Row(
        children: [
          CompassSvg(svgString: iconSvg, size: 14.0, color: _theme.accent),
          const SizedBox(width: 8.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: CompassTypography.badge(color: _theme.textMuted)),
                const SizedBox(height: 2.0),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: CompassTypography.monoMedium(color: const Color(0xFFFFFFFF)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionCard({
    required String label,
    required String tag,
    required String description,
    required bool selected,
    required bool isCancel,
  }) {
    final accent = isCancel ? _theme.accent : CompassColors.errorRed;
    return GestureDetector(
      onTap: () => setState(
        () => _selectedAction = isCancel ? _RiskyAction.cancel : _RiskyAction.confirm,
      ),
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: selected ? (isCancel ? _theme.greenBadgeBg : CompassColors.errorRedBg) : _inactiveBg,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(
            color: selected ? accent : _theme.border,
            width: selected ? 2.0 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20.0,
              height: 20.0,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? accent : const Color(0x00000000),
                border: Border.all(color: selected ? accent : _theme.textMuted, width: 2.0),
              ),
              alignment: Alignment.center,
              child: selected
                  ? CompassSvg(
                      svgString: CompassSvgIcons.check,
                      size: 11.0,
                      color: isCancel ? _theme.onAccent : const Color(0xFFFFFFFF),
                    )
                  : null,
            ),
            const SizedBox(width: 12.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(label, style: CompassTypography.bodyMedium(color: const Color(0xFFFFFFFF))),
                      const SizedBox(width: 8.0),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 2.0),
                        decoration: BoxDecoration(
                          color: isCancel ? _theme.greenBadgeBg : CompassColors.errorRedBg,
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                        child: Text(tag, style: CompassTypography.badge(color: accent)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2.0),
                  Text(description, style: CompassTypography.caption(color: _theme.textMuted)),
                ],
              ),
            ),
            CompassSvg(
              svgString: isCancel ? CompassSvgIcons.shieldCheck : CompassSvgIcons.activity,
              size: 15.0,
              color: selected ? accent : _theme.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Widget _footerButton({
    required String label,
    required String hint,
    required bool selected,
    required bool isCancel,
    required VoidCallback? onTap,
    required VoidCallback onSelect,
  }) {
    final accent = isCancel ? const Color(0xFF059669) : CompassColors.errorRed;
    return GestureDetector(
      onTap: () {
        onSelect();
        onTap?.call();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        decoration: BoxDecoration(
          color: selected ? accent : _inactiveBg,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(
            color: selected ? accent : _theme.border,
            width: 2.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CompassSvg(
              svgString: isCancel ? CompassSvgIcons.check : CompassSvgIcons.activity,
              size: 14.0,
              color: const Color(0xFFFFFFFF),
            ),
            const SizedBox(width: 6.0),
            Text(label, style: CompassTypography.header(color: const Color(0xFFFFFFFF))),
            const SizedBox(width: 6.0),
            Text(hint, style: CompassTypography.badge(color: const Color(0xB3FFFFFF))),
          ],
        ),
      ),
    );
  }
}
