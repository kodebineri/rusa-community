import 'package:flutter/widgets.dart';
import '../../icons/compass_svg_icons.dart';
import '../../theme/compass_colors.dart';
import '../../theme/compass_typography.dart';

/// Shared modal primitives for the MongoDB Compass Flutter client.
///
/// The React app renders modals as `fixed inset-0` overlays appended next to
/// the workspace. Flutter has no built-in portal, so every modal is a
/// `Positioned.fill` child of the root `Stack` (see `main.dart`). These helpers
/// keep each dialog visually consistent and avoid leaking Material theming
/// (project constraint #3: no generic Flutter Theme presets / Material 3).
class CompassModalShell extends StatelessWidget {
  final bool isOpen;
  final double maxWidth;
  final List<Widget> children;
  final VoidCallback? onBackdropTap;

  const CompassModalShell({
    super.key,
    required this.isOpen,
    this.maxWidth = 448.0,
    required this.children,
    this.onBackdropTap,
  });

  @override
  Widget build(BuildContext context) {
    if (!isOpen) return const SizedBox.shrink();

    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth - 32.0;
          final width = maxWidth < availableWidth ? maxWidth : availableWidth;
          final maxHeight = constraints.maxHeight - 64.0;

          final card = Container(
            width: width,
            margin: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: CompassColors.darkBgPanel,
              borderRadius: BorderRadius.circular(12.0),
              border: Border.all(color: CompassColors.darkBorder, width: 1.0),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 24.0,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ),
          );

          return Container(
            color: CompassColors.modalOverlay,
            alignment: Alignment.center,
            child: SafeArea(
              child: onBackdropTap == null
                  ? card
                  : GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onBackdropTap,
                      child: GestureDetector(
                        // Absorb taps inside the card so only the backdrop closes.
                        onTap: () {},
                        child: card,
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }
}

/// Modal title row: icon chip + title/subtitle + close button.
class CompassModalHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String iconSvg;
  final Color iconColor;
  final Color iconBg;
  final Color iconBorder;
  final VoidCallback onClose;

  const CompassModalHeader({
    super.key,
    required this.title,
    this.subtitle,
    required this.iconSvg,
    this.iconColor = CompassColors.greenAccent,
    this.iconBg = CompassColors.greenBadgeBg,
    this.iconBorder = CompassColors.greenBadgeBorder,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 12.0),
      margin: const EdgeInsets.only(bottom: 4.0),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: CompassColors.darkBorder, width: 1.0),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32.0,
            height: 32.0,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: iconBorder, width: 1.0),
            ),
            alignment: Alignment.center,
            child: CompassSvg(svgString: iconSvg, size: 16.0, color: iconColor),
          ),
          const SizedBox(width: 10.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: CompassTypography.header(color: CompassColors.darkTextPrimary)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2.0),
                  Text(subtitle!, style: CompassTypography.caption(color: CompassColors.darkTextMuted)),
                ],
              ],
            ),
          ),
          GestureDetector(
            onTap: onClose,
            child: Container(
              padding: const EdgeInsets.all(4.0),
              child: const CompassSvg(
                svgString: CompassSvgIcons.close,
                size: 14.0,
                color: CompassColors.darkTextMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Label + optional trailing hint, matching the React `<label>` blocks.
class CompassFieldLabel extends StatelessWidget {
  final String label;
  final String? hint;
  final Widget? trailing;

  const CompassFieldLabel({super.key, required this.label, this.hint, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(label, style: CompassTypography.bodyMedium(color: CompassColors.darkTextSecondary)),
              if (trailing != null) trailing!,
            ],
          ),
          if (hint != null)
            Text(hint!, style: CompassTypography.caption(color: CompassColors.darkTextMuted)),
        ],
      ),
    );
  }
}

/// Editable single- or multi-line text input built on [EditableText].
///
/// [EditableText] is used instead of Material's `TextField` so the app does not
/// depend on a `Material`/`MaterialApp` ancestor or MD3 theming.
class CompassInput extends StatefulWidget {
  final TextEditingController controller;
  final String placeholder;
  final bool autofocus;
  final int maxLines;
  final bool minLinesAuto;
  final int? minLines;
  final bool mono;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  const CompassInput({
    super.key,
    required this.controller,
    this.placeholder = '',
    this.autofocus = false,
    this.maxLines = 1,
    this.minLinesAuto = true,
    this.minLines,
    this.mono = true,
    this.obscureText = false,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  State<CompassInput> createState() => _CompassInputState();
}

class _CompassInputState extends State<CompassInput> {
  late final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle style = widget.mono
        ? CompassTypography.monoRegular(color: CompassColors.darkTextPrimary, size: 12.0)
        : CompassTypography.bodyMedium(color: CompassColors.darkTextPrimary);

    final int resolvedMinLines =
        widget.minLines ?? (widget.minLinesAuto && widget.maxLines > 1 ? widget.maxLines : 1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: CompassColors.darkBgInput,
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(color: CompassColors.darkBorder, width: 1.0),
      ),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: widget.controller,
        builder: (context, value, _) {
          return Stack(
            alignment: Alignment.topLeft,
            children: [
              if (value.text.isEmpty && widget.placeholder.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 1.0),
                  child: Text(
                    widget.placeholder,
                    style: style.copyWith(color: CompassColors.darkTextMuted),
                  ),
                ),
              EditableText(
                controller: widget.controller,
                focusNode: _focusNode,
                autofocus: widget.autofocus,
                style: style,
                cursorColor: CompassColors.greenAccent,
                backgroundCursorColor: CompassColors.darkBgInput,
                selectionColor: CompassColors.greenBadgeBg,
                maxLines: widget.maxLines,
                minLines: resolvedMinLines,
                obscureText: widget.obscureText,
                onChanged: widget.onChanged,
                onSubmitted: widget.onSubmitted,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Primary (green) action button.
class CompassPrimaryButton extends StatelessWidget {
  final String label;
  final String? iconSvg;
  final VoidCallback? onTap;
  final bool fullWidth;

  const CompassPrimaryButton({
    super.key,
    required this.label,
    this.iconSvg,
    required this.onTap,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: onTap == null ? const Color(0x1A00ED64) : CompassColors.greenAccent,
          borderRadius: BorderRadius.circular(6.0),
        ),
        child: Row(
          mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (iconSvg != null) ...[
              CompassSvg(
                svgString: iconSvg!,
                size: 13.0,
                color: onTap == null ? CompassColors.darkTextMuted : CompassColors.greenNavy,
              ),
              const SizedBox(width: 6.0),
            ],
            Text(
              label,
              style: CompassTypography.header(
                color: onTap == null ? CompassColors.darkTextMuted : CompassColors.greenNavy,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Secondary (subtle) action button.
class CompassSecondaryButton extends StatelessWidget {
  final String label;
  final String? iconSvg;
  final VoidCallback? onTap;

  const CompassSecondaryButton({
    super.key,
    required this.label,
    this.iconSvg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: CompassColors.darkBgSubtle,
          borderRadius: BorderRadius.circular(6.0),
          border: Border.all(color: CompassColors.darkBorder, width: 1.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (iconSvg != null) ...[
              CompassSvg(svgString: iconSvg!, size: 13.0, color: CompassColors.darkTextSecondary),
              const SizedBox(width: 6.0),
            ],
            Text(label, style: CompassTypography.bodyMedium(color: CompassColors.darkTextSecondary)),
          ],
        ),
      ),
    );
  }
}

/// Destructive (red) action button, optionally disabled until confirmed.
class CompassDangerButton extends StatelessWidget {
  final String label;
  final String? iconSvg;
  final VoidCallback? onTap;

  const CompassDangerButton({super.key, required this.label, this.iconSvg, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: enabled ? CompassColors.errorRed : const Color(0x4DF43F5E),
          borderRadius: BorderRadius.circular(6.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (iconSvg != null) ...[
              const CompassSvg(svgString: CompassSvgIcons.trash, size: 13.0, color: Color(0xFFFFFFFF)),
              const SizedBox(width: 6.0),
            ],
            Text(
              label,
              style: CompassTypography.header(
                color: enabled ? const Color(0xFFFFFFFF) : const Color(0x80FFFFFF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rose error banner used across the forms.
class CompassErrorBanner extends StatelessWidget {
  final String message;
  const CompassErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: CompassColors.errorRedBg,
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(color: CompassColors.errorRedBorder, width: 1.0),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CompassSvg(svgString: CompassSvgIcons.activity, size: 13.0, color: CompassColors.errorRed),
          const SizedBox(width: 6.0),
          Expanded(
            child: Text(message, style: CompassTypography.caption(color: CompassColors.errorRed)),
          ),
        ],
      ),
    );
  }
}

/// Row of right-aligned footer actions separated by a top border.
class CompassModalFooter extends StatelessWidget {
  final List<Widget> children;
  const CompassModalFooter({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 12.0),
      margin: const EdgeInsets.only(top: 4.0),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: CompassColors.darkBorder, width: 1.0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 8.0),
            children[i],
          ],
        ],
      ),
    );
  }
}
