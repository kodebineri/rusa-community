import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rusa/theme/compass_density.dart';

CompassDensity _densityFor(double width, {bool? touchDevice}) {
  final widget = CompassDensity.forWidth(
    width: width,
    touchDevice: touchDevice,
    child: const SizedBox.shrink(),
  );
  return widget as CompassDensity;
}

void main() {
  test('narrow viewports always use the touch profile', () {
    final density = _densityFor(400.0, touchDevice: false);
    expect(density.isTouch, isTrue);
    expect(density.minTapTarget, 44.0);
  });

  test('wide viewports stay dense on non-touch devices', () {
    final density = _densityFor(1280.0, touchDevice: false);
    expect(density.isTouch, isFalse);
    expect(density.minTapTarget, 20.0);
  });

  test('wide viewports use the touch profile on touch tablets', () {
    // An 8-inch tablet in landscape is wider than the breakpoint but still
    // needs finger-sized targets.
    final density = _densityFor(1280.0, touchDevice: true);
    expect(density.isTouch, isTrue);
    expect(density.minTapTarget, 44.0);
    expect(density.rowHeight, 48.0);
  });

  test('touch platforms wait longer before using the docked layout', () {
    expect(CompassDensity.desktopBreakpointFor(false), 768.0);
    expect(CompassDensity.desktopBreakpointFor(true), 1024.0);
  });

  test('the test host is detected as non-touch', () {
    // `flutter test` runs on the host OS (windows/linux/macOS), never a
    // phone/tablet, so the platform check must resolve to the desktop profile.
    expect(CompassDensity.isTouchPrimaryPlatform, isFalse);
    expect(_densityFor(1280.0).isTouch, isFalse);
  });
}
