import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';

/// Adaptive density metrics for the whole UI.
///
/// The app was ported from a React reference that assumes a mouse: icons are
/// 11-16 px and are packed tightly together. That is perfectly usable with a
/// pointer but hopeless with a finger, so the tree reads its metrics from here
/// instead of hard-coding them at every call site.
///
/// Two profiles ship with the app:
///
/// | Metric           | Desktop | Touch  |
/// |------------------|---------|--------|
/// | `minTapTarget`   | 20 dp   | 44 dp  |
/// | `iconScale`      | 1.0     | 1.15   |
/// | `rowHeight`      | 36 dp   | 48 dp  |
///
/// 44 dp is the smallest target Apple's Human Interface Guidelines accept;
/// Material asks for 48 dp, which 44 is close enough to for a tool this dense.
///
/// Read the metrics anywhere inside the tree:
///   final density = CompassDensity.of(context);
///   final minSize = density.minTapTarget;
///
/// [CompassDensity.of] resolves the nearest ancestor, and falls back to the
/// desktop profile when there is none (e.g. a widget pumped in isolation by a
/// test).
class CompassDensity extends InheritedWidget {
  /// True when the layout is narrow enough to be driven with a finger.
  final bool isTouch;

  /// Smallest edge length of an interactive target, in logical pixels.
  final double minTapTarget;

  /// Multiplier applied to icon glyphs.
  final double iconScale;

  /// Height of a dense list row (document table rows, tab bar, …).
  final double rowHeight;

  const CompassDensity({
    super.key,
    required this.isTouch,
    required this.minTapTarget,
    required this.iconScale,
    required this.rowHeight,
    required super.child,
  });

  /// Desktop metrics: dense and mouse-oriented. The minimum is deliberately
  /// small so the desktop layout keeps the tight spacing it was designed with;
  /// the extra room comes from the invisible padding around each glyph.
  static const CompassDensity desktop = CompassDensity(
    isTouch: false,
    minTapTarget: 20.0,
    iconScale: 1.0,
    rowHeight: 36.0,
    child: SizedBox.shrink(),
  );

  /// Touch metrics: finger-sized targets and slightly larger glyphs.
  static const CompassDensity touch = CompassDensity(
    isTouch: true,
    minTapTarget: 44.0,
    iconScale: 1.15,
    rowHeight: 48.0,
    child: SizedBox.shrink(),
  );

  /// Viewport width below which the layout switches to the touch profile.
  static const double touchBreakpoint = 768.0;

  /// Width at or above which the *docked* desktop layout is used.
  ///
  /// Touch platforms switch later (see [isTouchPrimaryPlatform]): an 8-inch
  /// tablet in portrait is ~800 dp wide, and the docked sidebar plus dense
  /// chrome is a poor fit there, so it keeps the roomier touch layout instead.
  static double desktopBreakpointFor(bool isTouchPlatform) =>
      isTouchPlatform ? 1024.0 : touchBreakpoint;

  /// Whether the running platform's primary input is touch (phones/tablets).
  ///
  /// Android, iOS and Fuchsia are always treated as touch: an 8-inch tablet in
  /// landscape is *wider* than [touchBreakpoint] yet still needs finger-sized
  /// targets, so width alone is not enough. Desktop platforms keep the width
  /// switch, so a narrow desktop window still promotes to the touch profile
  /// while a normal mouse-driven window stays dense.
  ///
  /// This reads `dart:io`'s platform rather than `defaultTargetPlatform`,
  /// because `flutter test` reports the latter as Android — which would force
  /// every desktop-layout test into the touch profile. `dart:io` reports the
  /// actual host (windows/linux/macOS in tests).
  static bool get isTouchPrimaryPlatform =>
      Platform.isAndroid || Platform.isIOS || Platform.isFuchsia;

  /// Wraps [child] in the profile that matches a viewport of [width] logical
  /// pixels.
  ///
  /// [touchDevice] overrides the platform detection (used by tests / previews);
  /// when omitted, [isTouchPrimaryPlatform] decides.
  static Widget forWidth({
    required double width,
    required Widget child,
    bool? touchDevice,
  }) {
    final useTouch = touchDevice ?? isTouchPrimaryPlatform;
    final profile =
        (useTouch || width < touchBreakpoint) ? touch : desktop;
    return CompassDensity(
      isTouch: profile.isTouch,
      minTapTarget: profile.minTapTarget,
      iconScale: profile.iconScale,
      rowHeight: profile.rowHeight,
      child: child,
    );
  }

  /// The nearest [CompassDensity] ancestor, or the desktop profile.
  static CompassDensity of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<CompassDensity>() ??
        desktop;
  }

  @override
  bool updateShouldNotify(CompassDensity oldWidget) =>
      isTouch != oldWidget.isTouch ||
      minTapTarget != oldWidget.minTapTarget ||
      iconScale != oldWidget.iconScale ||
      rowHeight != oldWidget.rowHeight;
}
