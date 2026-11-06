import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../icons/compass_svg_icons.dart';
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
    CompassThemeVariant.dracula,
    CompassThemeVariant.materialLight,
  ];

  @override
  State<OnboardingModal> createState() => _OnboardingModalState();
}

class _OnboardingModalState extends State<OnboardingModal> {
  /// Asset path of the licence text, relative to `pubspec.yaml`.
  static const String _eulaAssetPath = 'EULA.md';

  /// 0 welcome · 1 sample data · 2 theme · 3 terms.
  static const int _lastSlide = 3;

  int _index = 0;
  late bool _dontShowAgain;

  /// Licence markdown, loaded lazily for the terms slide.
  String? _eulaMarkdown;
  String? _eulaError;
  bool _eulaRequested = false;

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
    }
  }

  bool get _isLastSlide => _index == _lastSlide;

  void _goTo(int index) {
    setState(() => _index = index.clamp(0, _lastSlide));
    if (_index == _lastSlide) _loadEula();
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

  @override
  Widget build(BuildContext context) {
    if (!widget.isOpen) return const SizedBox.shrink();

    final theme = CompassTheme.of(context);

    return Positioned.fill(
      child: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent) return KeyEventResult.ignored;
          final key = event.logicalKey;
          final isForward = key == LogicalKeyboardKey.arrowRight ||
              key == LogicalKeyboardKey.enter ||
              key == LogicalKeyboardKey.numpadEnter;
          // Enter / → advance, but never past the licence slide: accepting the
          // EULA must be a deliberate click on "I Accept".
          if (isForward && !_isLastSlide) {
            _next();
            return KeyEventResult.handled;
          }
          if (key == LogicalKeyboardKey.arrowLeft && _index > 0) {
            _back();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          // Absorb taps on empty areas so the shell behind the tour cannot be
          // clicked through (the tour's own controls are hit-tested first).
          behavior: HitTestBehavior.opaque,
          onTap: () {},
          child: Container(
            color: theme.bgApp,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildTopBar(theme),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24.0, vertical: 8.0),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 640.0),
                          child: _buildSlide(theme),
                        ),
                      ),
                    ),
                  ),
                  _buildFooter(theme),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Chrome ----------------------------------------------------------------

  Widget _buildTopBar(CompassTheme theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24.0, 16.0, 16.0, 0.0),
      child: Row(
        children: [
          Text(
            'Step ${_index + 1} of ${_lastSlide + 1}',
            style: CompassTypography.caption(color: theme.textMuted),
          ),
          const Spacer(),
          // Skipping only fast-forwards the tour; the licence slide is still
          // the only way out (there is no dismissal).
          if (!_isLastSlide)
            CompassSecondaryButton(
              label: 'Skip',
              onTap: () => _goTo(_lastSlide),
            ),
        ],
      ),
    );
  }

  Widget _buildFooter(CompassTheme theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24.0, 8.0, 24.0, 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isLastSlide) ...[
            _buildDontShowAgainRow(theme),
            const SizedBox(height: 12.0),
          ],
          Row(
            children: [
              _buildDots(theme),
              const Spacer(),
              if (_index > 0) ...[
                CompassSecondaryButton(label: 'Back', onTap: _back),
                const SizedBox(width: 8.0),
              ],
              if (!_isLastSlide)
                CompassPrimaryButton(label: 'Next', onTap: _next)
              else
                CompassPrimaryButton(
                  label: widget.needsEulaConsent ? 'I Accept' : 'Done',
                  onTap: () => widget.onFinish(dontShowAgain: _dontShowAgain),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDots(CompassTheme theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i <= _lastSlide; i++)
          Container(
            width: 8.0,
            height: 8.0,
            margin: const EdgeInsets.only(right: 6.0),
            decoration: BoxDecoration(
              color: i == _index ? theme.accent : theme.border,
              shape: BoxShape.circle,
            ),
          ),
      ],
    );
  }

  Widget _buildDontShowAgainRow(CompassTheme theme) {
    final density = CompassDensity.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: density.minTapTarget),
      child: CompassHover(
        onTap: () => setState(() => _dontShowAgain = !_dontShowAgain),
        semanticLabel: 'Don\'t show this again in the future',
        builder: (hovered) => Row(
          children: [
            Container(
              width: 16.0,
              height: 16.0,
              decoration: BoxDecoration(
                color: _dontShowAgain ? theme.accent : theme.bgInput,
                borderRadius: BorderRadius.circular(3.0),
                border: Border.all(
                  color: _dontShowAgain
                      ? theme.accent
                      : (hovered ? theme.borderHover : theme.border),
                  width: 1.0,
                ),
              ),
              alignment: Alignment.center,
              child: _dontShowAgain
                  ? CompassSvg(
                      svgString: CompassSvgIcons.check,
                      size: 11.0,
                      color: theme.onAccent,
                    )
                  : null,
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: Text(
                "Don't show this again in the future",
                style:
                    CompassTypography.bodyRegular(color: theme.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Slides ----------------------------------------------------------------

  Widget _buildSlide(CompassTheme theme) {
    switch (_index) {
      case 0:
        return _welcomeSlide(theme);
      case 1:
        return _sampleDataSlide(theme);
      case 2:
        return _themeSlide(theme);
      default:
        return _termsSlide(theme);
    }
  }

  Widget _welcomeSlide(CompassTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
            child: Text('Hello, I am',
                style: CompassTypography.title(color: theme.textPrimary)
                    .copyWith(fontSize: 32))),
        const SizedBox(height: 48.0),
        Center(
          child: CompassSvg(
            svgString: CompassSvgIcons.rusa,
            size: 96.0,
            color: theme.brandMark,
          ),
        ),
        const SizedBox(height: 24.0),
        Center(
          child: Text(
            'r u s a',
            style: CompassTypography.title(color: theme.textPrimary)
                .copyWith(fontSize: 30.0, letterSpacing: 2.0),
          ),
        ),
        const SizedBox(height: 8.0),
        Center(
          child: Text(
            'a MongoDB database client',
            style: CompassTypography.bodyMedium(color: theme.textSecondary)
                .copyWith(fontSize: 14.0),
          ),
        ),
        const SizedBox(height: 28.0),
        Text(
          'Browse and query a MongoDB database without leaving your desktop: '
          'documents in tree, JSON and table views, a real aggregation '
          'pipeline builder, schema analysis, indexes and a built-in '
          'Shell.',
          textAlign: TextAlign.center,
          style: CompassTypography.bodyRegular(color: theme.textSecondary)
              .copyWith(height: 1.6),
        ),
        const SizedBox(height: 24.0),
        Text(
          'Not affiliated with, endorsed by, or sponsored by MongoDB, Inc.',
          textAlign: TextAlign.center,
          style: CompassTypography.caption(color: theme.textMuted),
        ),
        const SizedBox(height: 24.0),
      ],
    );
  }

  Widget _sampleDataSlide(CompassTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16.0),
        _slideTitle(theme, 'Sample data is already here'),
        const SizedBox(height: 10.0),
        Text(
          "You don't need to connect to a real database to try Rusa. Two "
          'sample databases ship with the app and are already loaded:',
          style: CompassTypography.bodyRegular(color: theme.textSecondary)
              .copyWith(height: 1.5),
        ),
        const SizedBox(height: 20.0),
        _sampleDbCard(
          theme,
          name: 'library',
          collections: 'books · publishers · genres',
        ),
        const SizedBox(height: 10.0),
        _sampleDbCard(
          theme,
          name: 'social_networks',
          collections: 'users · posts · comments',
        ),
        const SizedBox(height: 20.0),
        Row(
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
                'Point Rusa at a real MongoDB server whenever you like — '
                'use Connect in the header.',
                style: CompassTypography.caption(color: theme.textMuted)
                    .copyWith(height: 1.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16.0),
      ],
    );
  }

  Widget _themeSlide(CompassTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16.0),
        _slideTitle(theme, 'Pick a look'),
        const SizedBox(height: 10.0),
        Text(
          'Choose a theme to start with. It is remembered next time, and you '
          'can switch between all six variants from the ⋮ menu.',
          style: CompassTypography.bodyRegular(color: theme.textSecondary)
              .copyWith(height: 1.5),
        ),
        const SizedBox(height: 24.0),
        Wrap(
          spacing: 16.0,
          runSpacing: 16.0,
          alignment: WrapAlignment.center,
          children: [
            for (final variant in OnboardingModal.previewVariants)
              _themePreviewCard(theme, variant),
          ],
        ),
        const SizedBox(height: 16.0),
      ],
    );
  }

  Widget _termsSlide(CompassTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16.0),
        _slideTitle(theme, 'Terms of use'),
        const SizedBox(height: 10.0),
        Text(
          widget.needsEulaConsent
              ? 'Please review and accept the End User License Agreement to '
                  'use Rusa.'
              : 'You already accepted the End User License Agreement. You can '
                  'review it below.',
          style: CompassTypography.bodyRegular(color: theme.textSecondary)
              .copyWith(height: 1.5),
        ),
        const SizedBox(height: 16.0),
        if (_eulaError != null)
          CompassErrorBanner(message: _eulaError!)
        else if (_eulaMarkdown == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0),
            child: Text(
              'Loading license text...',
              textAlign: TextAlign.center,
              style: CompassTypography.bodyRegular(color: theme.textMuted),
            ),
          )
        else
          CompassMarkdownView(markdown: _eulaMarkdown!),
        const SizedBox(height: 16.0),
      ],
    );
  }

  // --- Small pieces ----------------------------------------------------------

  Widget _slideTitle(CompassTheme theme, String text) {
    return Text(
      text,
      style: CompassTypography.title(color: theme.textPrimary)
          .copyWith(fontSize: 22.0),
    );
  }

  Widget _sampleDbCard(CompassTheme theme,
      {required String name, required String collections}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: theme.bgSubtle,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: theme.border, width: 1.0),
      ),
      child: Row(
        children: [
          CompassSvg(
            svgString: CompassSvgIcons.database,
            size: 16.0,
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
        ],
      ),
    );
  }

  Widget _themePreviewCard(CompassTheme theme, CompassThemeVariant variant) {
    final palette = variant.palette;
    final selected = theme.variant == variant;
    final density = CompassDensity.of(context);

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: density.minTapTarget),
      child: CompassHover(
        onTap: () => widget.onSelectTheme(variant),
        semanticLabel: '${variant.label} theme',
        builder: (hovered) => Container(
          width: 224.0,
          padding: const EdgeInsets.all(10.0),
          decoration: BoxDecoration(
            color: theme.bgSubtle,
            borderRadius: BorderRadius.circular(10.0),
            border: Border.all(
              color: selected
                  ? theme.accent
                  : (hovered ? theme.borderHover : theme.border),
              width: selected ? 2.0 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Miniature of the variant: app background, panel, accent bar.
              Container(
                height: 96.0,
                padding: const EdgeInsets.all(10.0),
                decoration: BoxDecoration(
                  color: palette.bgApp,
                  borderRadius: BorderRadius.circular(6.0),
                  border: Border.all(color: palette.border, width: 1.0),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Accent bar, then two "text" lines, then a panel box —
                    // enough to read the variant's palette at a glance.
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        height: 8.0,
                        width: 90.0,
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
                        width: 110.0,
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
                      style: CompassTypography.bodyMedium(
                          color: theme.textPrimary),
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
      ),
    );
  }
}
