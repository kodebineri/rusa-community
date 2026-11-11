import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../icons/compass_svg_icons.dart';
import '../../theme/compass_colors.dart';
import '../../theme/compass_density.dart';
import '../../theme/compass_theme.dart';
import '../../theme/compass_theme_presets.dart';
import '../../theme/compass_typography.dart';
import '../compass_hover.dart';
import '../compass_markdown_view.dart';
import 'compass_modal.dart';

/// First-run welcome tour: a full-window slideshow shown *above* everything
/// else (it is the topmost child of the root `Stack` in `main.dart`).
///
/// Order: welcome → sample data → theme → terms. The last slide is the EULA
/// acceptance step, so the tour owns first-run consent: the **Skip** button
/// jumps *to* that slide, it never skips past it. There is no close button and
/// no backdrop dismissal.
///
/// The tour is also reusable as a plain walkthrough (header `⋮` → **Show
/// Welcome Screen**): when [needsEulaConsent] is false the licence has already
/// been accepted, so the last slide ends in **Done** instead of re-asking.
///
/// Design language (mirrors the reference `OnboardingPage`): a minimal top
/// header with the brand chip and an `n / N` step counter, a single centered
/// column of slides led by a rounded icon tile, and a quiet bottom bar with a
/// text **Back**, the dots, and one filled primary action.
///
/// Unlike the modals it is not a [CompassModalShell] — it covers the whole
/// window (status/nav insets included via [SafeArea]) and renders
/// `SizedBox.shrink()` while [isOpen] is false, mirroring the "closed modals
/// are not mounted" rule (invariant 5).
class OnboardingModal extends StatefulWidget {
  final bool isOpen;

  /// Whether the licence still has to be accepted (first run). When false the
  /// last slide is read-only and its primary action reads **Done**.
  final bool needsEulaConsent;

  /// Initial value of the "don't show this again" box — the choice the user
  /// made last time, if any.
  final bool initialDontShowAgain;

  /// Applies (and persists) a theme picked on the preview slide.
  final ValueChanged<CompassThemeVariant> onSelectTheme;

  /// Finishes the tour: persists consent (first run only) and [dontShowAgain],
  /// then reveals the shell.
  final void Function({required bool dontShowAgain}) onFinish;

  const OnboardingModal({
    super.key,
    required this.isOpen,
    required this.needsEulaConsent,
    required this.initialDontShowAgain,
    required this.onSelectTheme,
    required this.onFinish,
  });

  /// The two variants previewed on the theme slide (one dark, one light). All
  /// six remain available from the header menu.
  static const List<CompassThemeVariant> previewVariants = [
    CompassThemeVariant.rainForestNight,
    CompassThemeVariant.sunnyRainForest,
  ];

  @override
  State<OnboardingModal> createState() => _OnboardingModalState();
}

class _OnboardingModalState extends State<OnboardingModal> {
  /// Asset path of the licence text, relative to `pubspec.yaml`.
  static const String _eulaAssetPath = 'EULA.md';

  /// 0 welcome · 1 sample data · 2 theme · 3 terms.
  static const int _lastSlide = 3;

  /// Width of the centered slide column (`max-w-md` in the reference).
  static const double _contentMaxWidth = 448.0;

  int _index = 0;
  late bool _dontShowAgain;

  /// Whether the user has ticked the licence acceptance box. The primary
  /// action stays disabled until they do (first run only).
  bool _acceptedEula = false;

  /// Licence markdown, loaded lazily for the terms slide.
  String? _eulaMarkdown;
  String? _eulaError;
  bool _eulaRequested = false;

  final ScrollController _bodyScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _dontShowAgain = widget.initialDontShowAgain;
  }

  @override
  void didUpdateWidget(OnboardingModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-opened from the menu (or re-shown after a restart): always start from
    // the first slide with the stored preference. No setState — a rebuild is
    // already in flight.
    if (widget.isOpen && !oldWidget.isOpen) {
      _index = 0;
      _dontShowAgain = widget.initialDontShowAgain;
      _acceptedEula = false;
    }
  }

  @override
  void dispose() {
    _bodyScroll.dispose();
    super.dispose();
  }

  bool get _isLastSlide => _index == _lastSlide;

  /// The tour can only be finished once the licence is accepted (first run).
  bool get _canFinish => !widget.needsEulaConsent || _acceptedEula;

  void _goTo(int index) {
    setState(() => _index = index.clamp(0, _lastSlide));
    if (_index == _lastSlide) _loadEula();
    if (_bodyScroll.hasClients) _bodyScroll.jumpTo(0);
  }

  void _next() => _goTo(_index + 1);

  void _back() => _goTo(_index - 1);

  Future<void> _loadEula() async {
    if (_eulaRequested) return;
    _eulaRequested = true;
    try {
      final text = await rootBundle.loadString(_eulaAssetPath);
      if (!mounted) return;
      setState(() => _eulaMarkdown = text);
    } catch (_) {
      if (!mounted) return;
      setState(() =>
          _eulaError = 'Could not load the license text ($_eulaAssetPath).');
    }
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    // Enter never finishes the tour: accepting the licence must be a deliberate
    // click (or Tab + Enter) on the primary button.
    if (key == LogicalKeyboardKey.arrowRight && !_isLastSlide) {
      _next();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft && _index > 0) {
      _back();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isOpen) return const SizedBox.shrink();

    final theme = CompassTheme.of(context);
    final windowWidth = MediaQuery.maybeOf(context)?.size.width ?? 900.0;
    final horizontal = windowWidth >= 600.0 ? 40.0 : 24.0;

    return Positioned.fill(
      child: GestureDetector(
        // Absorb taps on empty areas so the shell behind the tour cannot be
        // clicked through (the tour's own controls are hit-tested first).
        behavior: HitTestBehavior.opaque,
        onTap: () {},
        child: Focus(
          autofocus: true,
          onKeyEvent: _handleKey,
          child: Container(
            color: theme.bgApp,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(theme, horizontal),
                  Expanded(
                    // `Center` shrink-wraps when the height is unbounded, so
                    // `ConstrainedBox(minHeight: viewport)` makes it fill the
                    // body and center the slide — with no intrinsic measurement
                    // (which under-reports wrapped text and caused the terms
                    // slide to overflow).
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          controller: _bodyScroll,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: _contentMaxWidth + horizontal * 2,
                                ),
                                child: Padding(
                                  padding: EdgeInsets.fromLTRB(
                                      horizontal, 8.0, horizontal, 24.0),
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 150),
                                    child: KeyedSubtree(
                                      key: ValueKey<int>(_index),
                                      child: _buildSlide(
                                          theme, constraints.maxHeight),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  _buildFooter(theme, horizontal),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Chrome ----------------------------------------------------------------

  Widget _buildHeader(CompassTheme theme, double horizontal) {
    return Container(
      height: 56.0,
      padding: EdgeInsets.symmetric(horizontal: horizontal),
      child: Row(
        children: [
          _brandTile(size: 24.0),
          const SizedBox(width: 10.0),
          Text(
            'r u s a',
            style: CompassTypography.title(color: theme.textPrimary)
                .copyWith(fontSize: 11.0),
          ),
          const Spacer(),
          Text(
            '${_index + 1} / ${_lastSlide + 1}',
            style: CompassTypography.monoSmall(color: theme.textMuted),
          ),
          // Skipping only fast-forwards the tour; the licence slide is still
          // the only way out (there is no dismissal).
          if (!_isLastSlide) ...[
            const SizedBox(width: 4.0),
            _navTextButton(
              theme,
              label: 'Skip',
              onTap: () => _goTo(_lastSlide),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter(CompassTheme theme, double horizontal) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: horizontal, vertical: 12.0),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
          // A Stack keeps the dots centered while Back / the primary action
          // keep their natural widths (an `Expanded` slot squeezed the
          // "Continue" label on narrow windows).
          child: Stack(
            alignment: Alignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _index > 0
                      ? _navTextButton(
                          theme,
                          label: 'Back',
                          icon: CompassSvgIcons.chevronLeft,
                          onTap: _back,
                        )
                      : const SizedBox.shrink(),
                  _isLastSlide
                      ? CompassPrimaryButton(
                          label: 'Done',
                          iconSvg: CompassSvgIcons.check,
                          onTap: _canFinish
                              ? () =>
                                  widget.onFinish(dontShowAgain: _dontShowAgain)
                              : null,
                        )
                      : CompassPrimaryButton(label: 'Next', onTap: _next),
                ],
              ),
              _buildDots(theme),
            ],
          ),
        ),
      ),
    );
  }

  /// Quiet, borderless text button (the reference's Back / Skip styling).
  Widget _navTextButton(
    CompassTheme theme, {
    required String label,
    String? icon,
    required VoidCallback onTap,
  }) {
    final density = CompassDensity.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: density.minTapTarget),
      child: CompassHover(
        onTap: onTap,
        semanticLabel: label,
        builder: (hovered) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
          decoration: BoxDecoration(
            color: hovered ? theme.bgSubtle : const Color(0x00000000),
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                CompassSvg(
                  svgString: icon,
                  size: 13.0,
                  color: theme.textSecondary,
                ),
                const SizedBox(width: 6.0),
              ],
              Text(
                label,
                style: CompassTypography.bodyMedium(color: theme.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDots(CompassTheme theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i <= _lastSlide; i++)
          Container(
            width: i == _index ? 10.0 : 8.0,
            height: i == _index ? 10.0 : 8.0,
            margin: const EdgeInsets.symmetric(horizontal: 4.0),
            decoration: BoxDecoration(
              color: i == _index ? theme.accent : theme.bgSubtle,
              shape: BoxShape.circle,
              border: Border.all(
                color: i == _index ? theme.accent : theme.borderHover,
              ),
              boxShadow: i == _index
                  ? [
                      BoxShadow(
                        color: theme.accent.withValues(alpha: 0.30),
                        blurRadius: 0.0,
                        spreadRadius: 2.0,
                      ),
                    ]
                  : null,
            ),
          ),
      ],
    );
  }

  // --- Slides ----------------------------------------------------------------

  Widget _buildSlide(CompassTheme theme, double viewportHeight) {
    switch (_index) {
      case 0:
        return _welcomeSlide(theme);
      case 1:
        return _sampleDataSlide(theme);
      case 2:
        return _themeSlide(theme);
      default:
        // The terms slide fills the body so the licence can flex and the
        // acceptance controls stay visible. `viewportHeight` is the body's
        // height; subtract the body padding (8 top + 24 bottom).
        return SizedBox(
          height: (viewportHeight - 32.0).clamp(0.0, double.infinity),
          child: _termsSlide(theme),
        );
    }
  }

  Widget _welcomeSlide(CompassTheme theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8.0),
        Text(
          'hello, I am',
          style: CompassTypography.title(color: theme.accent)
              .copyWith(fontSize: 24.0, letterSpacing: 6),
        ),
        const SizedBox(height: 24.0),
        _brandTile(size: 64.0),
        const SizedBox(height: 8.0),
        Text(
          'r u s a',
          textAlign: TextAlign.center,
          style: CompassTypography.title(color: theme.textPrimary)
              .copyWith(fontSize: 28.0, letterSpacing: 2.0),
        ),
        const SizedBox(height: 8.0),
        Text(
          'a MongoDB database client',
          textAlign: TextAlign.center,
          style: CompassTypography.bodyMedium(color: theme.textSecondary)
              .copyWith(fontSize: 13.0),
        ),
        const SizedBox(height: 20.0),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380.0),
          child: Text(
            'Browse and query a MongoDB database without leaving your desktop: '
            'documents in tree, JSON and table views, a real aggregation '
            'pipeline builder, schema analysis, indexes and a built-in Shell.',
            textAlign: TextAlign.center,
            style: CompassTypography.bodyRegular(color: theme.textSecondary)
                .copyWith(height: 1.6),
          ),
        ),
        const SizedBox(height: 20.0),
        Text(
          'Not affiliated with, endorsed by, or sponsored by MongoDB, Inc.',
          textAlign: TextAlign.center,
          style: CompassTypography.caption(color: theme.textMuted),
        ),
        const SizedBox(height: 8.0),
      ],
    );
  }

  Widget _sampleDataSlide(CompassTheme theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8.0),
        Center(child: _iconTile(theme, CompassSvgIcons.database, theme.accent)),
        const SizedBox(height: 20.0),
        _heading(
          theme,
          'Sample data is already here',
          "You don't need to connect to a real database to try Rusa.",
        ),
        const SizedBox(height: 20.0),
        _box(theme, children: [
          _boxLabel(theme, 'BUNDLED DATASETS'),
          const SizedBox(height: 10.0),
          _datasetRow(
            theme,
            name: 'library',
            collections: 'books · publishers · genres',
          ),
          const SizedBox(height: 8.0),
          _datasetRow(
            theme,
            name: 'social_networks',
            collections: 'users · posts · comments',
          ),
        ]),
        const SizedBox(height: 16.0),
        _hint(
          theme,
          'Point Rusa at a real MongoDB server whenever you like — use '
          'Connect in the header.',
        ),
        const SizedBox(height: 8.0),
      ],
    );
  }

  Widget _themeSlide(CompassTheme theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8.0),
        Center(
          child: _iconTile(
            theme,
            CompassSvgIcons.sun,
            CompassColors.warningAmber,
          ),
        ),
        const SizedBox(height: 20.0),
        _heading(
          theme,
          'Pick a look',
          'Choose a theme to start with. It is remembered next time, and you '
              'can switch between all eight variants from the ⋮ menu.',
        ),
        const SizedBox(height: 20.0),
        Row(
          children: [
            Expanded(
              child:
                  _themePreviewCard(theme, OnboardingModal.previewVariants[0]),
            ),
            const SizedBox(width: 12.0),
            Expanded(
              child:
                  _themePreviewCard(theme, OnboardingModal.previewVariants[1]),
            ),
          ],
        ),
        const SizedBox(height: 8.0),
      ],
    );
  }

  Widget _termsSlide(CompassTheme theme) {
    return Column(
      // Fill the body so the licence can flex: the acceptance controls stay
      // visible while the (long) licence scrolls in its own box.
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8.0),
        Center(
          child: _iconTile(theme, CompassSvgIcons.shieldCheck, theme.accent),
        ),
        const SizedBox(height: 20.0),
        _heading(
          theme,
          'Accept License Agreement',
          'Please review and accept the End User License Agreement (EULA).',
        ),
        const SizedBox(height: 16.0),
        Expanded(child: _eulaBox(theme)),
        const SizedBox(height: 12.0),
        if (widget.needsEulaConsent) ...[
          _checkboxRow(
            theme,
            checked: _acceptedEula,
            label: 'I accept the End User License Agreement (EULA).',
            onTap: () => setState(() => _acceptedEula = !_acceptedEula),
          ),
          if (!_acceptedEula)
            Padding(
              padding: const EdgeInsets.only(top: 8.0, left: 2.0),
              child: Text(
                'Tick the box above to continue.',
                style: CompassTypography.caption(color: theme.textMuted),
              ),
            ),
          const SizedBox(height: 8.0),
        ],
        _checkboxRow(
          theme,
          checked: _dontShowAgain,
          label: "Don't show this again in the future",
          onTap: () => setState(() => _dontShowAgain = !_dontShowAgain),
        ),
        const SizedBox(height: 8.0),
      ],
    );
  }

  /// The full licence in a bordered box that scrolls on its own, so the
  /// acceptance controls below it are always visible.
  Widget _eulaBox(CompassTheme theme) {
    return Container(
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: theme.bgSubtle,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_eulaError != null)
            Text(
              _eulaError!,
              style: CompassTypography.caption(color: CompassColors.errorRed),
            )
          else if (_eulaMarkdown == null)
            Text(
              'Loading license text...',
              style: CompassTypography.caption(color: theme.textMuted),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                child: CompassMarkdownView(markdown: _eulaMarkdown!),
              ),
            ),
        ],
      ),
    );
  }

  /// Bordered checkbox row (the reference's acceptance / preference control).
  Widget _checkboxRow(
    CompassTheme theme, {
    required bool checked,
    required String label,
    required VoidCallback onTap,
  }) {
    final density = CompassDensity.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: density.minTapTarget),
      child: CompassHover(
        onTap: onTap,
        semanticLabel: label,
        builder: (hovered) => Container(
          padding: const EdgeInsets.all(12.0),
          decoration: _rowDecoration(
            theme,
            selected: checked,
            hovered: hovered,
          ),
          child: Row(
            children: [
              Container(
                width: 16.0,
                height: 16.0,
                decoration: BoxDecoration(
                  color: checked ? theme.accent : theme.bgInput,
                  borderRadius: BorderRadius.circular(4.0),
                  border: Border.all(
                    color: checked
                        ? theme.accent
                        : (hovered ? theme.borderHover : theme.border),
                  ),
                ),
                alignment: Alignment.center,
                child: checked
                    ? CompassSvg(
                        svgString: CompassSvgIcons.check,
                        size: 11.0,
                        color: theme.onAccent,
                      )
                    : null,
              ),
              const SizedBox(width: 10.0),
              Expanded(
                child: Text(
                  label,
                  style:
                      CompassTypography.bodyRegular(color: theme.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Shared pieces ---------------------------------------------------------

  /// The brand mark on its emerald gradient chip (header + welcome slide).
  Widget _brandTile({required double size}) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      child: CompassSvg(
        svgString: CompassSvgIcons.rusa,
        size: size * 0.56,
        color: const Color(0xFFFFFFFF),
      ),
    );
  }

  /// 48 px rounded icon tile that leads each slide.
  Widget _iconTile(CompassTheme theme, String svg, Color color) {
    return Container(
      width: 48.0,
      height: 48.0,
      decoration: BoxDecoration(
        color: theme.bgSubtle,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: theme.border),
      ),
      alignment: Alignment.center,
      child: CompassSvg(svgString: svg, size: 24.0, color: color),
    );
  }

  Widget _heading(CompassTheme theme, String title, String subtitle) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: CompassTypography.title(color: theme.textPrimary)
              .copyWith(fontSize: 20.0),
        ),
        const SizedBox(height: 6.0),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360.0),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: CompassTypography.bodyRegular(color: theme.textSecondary)
                .copyWith(height: 1.5),
          ),
        ),
      ],
    );
  }

  /// Soft bordered panel used for grouped information.
  Widget _box(CompassTheme theme, {required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: theme.bgSubtle,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _boxLabel(CompassTheme theme, String text) {
    return Text(
      text,
      style: CompassTypography.monoSmall(color: theme.textMuted)
          .copyWith(fontSize: 10.0, letterSpacing: 1.0),
    );
  }

  Widget _datasetRow(
    CompassTheme theme, {
    required String name,
    required String collections,
  }) {
    return Row(
      children: [
        CompassSvg(
          svgString: CompassSvgIcons.database,
          size: 15.0,
          color: theme.accent,
        ),
        const SizedBox(width: 10.0),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: CompassTypography.monoMedium(color: theme.textPrimary),
              ),
              const SizedBox(height: 2.0),
              Text(
                collections,
                style: CompassTypography.caption(color: theme.textMuted),
              ),
            ],
          ),
        ),
        CompassSvg(
          svgString: CompassSvgIcons.check,
          size: 13.0,
          color: theme.accent,
        ),
      ],
    );
  }

  Widget _hint(CompassTheme theme, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CompassSvg(
          svgString: CompassSvgIcons.zap,
          size: 14.0,
          color: theme.accent,
        ),
        const SizedBox(width: 8.0),
        Expanded(
          child: Text(
            text,
            style: CompassTypography.caption(color: theme.textMuted)
                .copyWith(height: 1.5),
          ),
        ),
      ],
    );
  }

  /// Shared card treatment: selected = accent border + tint + soft ring.
  BoxDecoration _rowDecoration(
    CompassTheme theme, {
    required bool selected,
    required bool hovered,
    bool subtle = false,
  }) {
    return BoxDecoration(
      color: selected
          ? theme.accent.withValues(alpha: 0.07)
          : (hovered
              ? theme.bgHover
              : (subtle ? theme.bgSubtle : theme.bgPanel)),
      borderRadius: BorderRadius.circular(12.0),
      border: Border.all(
        color: selected ? theme.accent : theme.border,
        width: selected ? 1.5 : 1.0,
      ),
      boxShadow: selected
          ? [
              BoxShadow(
                color: theme.accent.withValues(alpha: 0.20),
                blurRadius: 0.0,
                spreadRadius: 1.0,
              ),
            ]
          : null,
    );
  }

  Widget _themePreviewCard(CompassTheme theme, CompassThemeVariant variant) {
    final palette = variant.palette;
    final selected = theme.variant == variant;

    return CompassHover(
      onTap: () => widget.onSelectTheme(variant),
      semanticLabel: '${variant.label} theme',
      builder: (hovered) => Container(
        padding: const EdgeInsets.all(10.0),
        decoration: _rowDecoration(
          theme,
          selected: selected,
          hovered: hovered,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Miniature of the variant: app background, accent bar, panel box.
            Container(
              height: 88.0,
              padding: const EdgeInsets.all(10.0),
              decoration: BoxDecoration(
                color: palette.bgApp,
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(color: palette.border, width: 1.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      height: 8.0,
                      width: 84.0,
                      decoration: BoxDecoration(
                        color: palette.accent,
                        borderRadius: BorderRadius.circular(4.0),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  Container(
                    height: 6.0,
                    decoration: BoxDecoration(
                      color: palette.textPrimary,
                      borderRadius: BorderRadius.circular(3.0),
                    ),
                  ),
                  const SizedBox(height: 6.0),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      height: 6.0,
                      width: 96.0,
                      decoration: BoxDecoration(
                        color: palette.textMuted,
                        borderRadius: BorderRadius.circular(3.0),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    height: 16.0,
                    decoration: BoxDecoration(
                      color: palette.bgSubtle,
                      borderRadius: BorderRadius.circular(4.0),
                      border: Border.all(color: palette.border, width: 1.0),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10.0),
            Row(
              children: [
                Expanded(
                  child: Text(
                    variant.label,
                    style:
                        CompassTypography.bodyMedium(color: theme.textPrimary),
                  ),
                ),
                if (selected)
                  CompassSvg(
                    svgString: CompassSvgIcons.check,
                    size: 14.0,
                    color: theme.accent,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
