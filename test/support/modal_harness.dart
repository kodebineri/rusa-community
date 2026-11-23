// Shared test host for modals rendered outside the app shell.
//
// The app has no MaterialApp/Scaffold (see AGENTS.md invariant 1), so a bare
// dialog still needs Directionality + Overlay + MediaQuery + theme + density.

import 'package:flutter/widgets.dart';

import 'package:rusa/theme/compass_density.dart';
import 'package:rusa/theme/compass_theme.dart';
import 'package:rusa/theme/compass_theme_presets.dart';

/// Wraps [child] (normally a `Positioned.fill` modal) in the providers it
/// expects, at [size]. [touch] selects the touch or desktop density profile.
Widget modalHarness({
  required Size size,
  required bool touch,
  required Widget child,
}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Overlay(
      initialEntries: [
        OverlayEntry(
          builder: (context) => CompassDensity.forWidth(
            width: size.width,
            touchDevice: touch,
            child: MediaQuery(
              data: MediaQueryData(size: size),
              child: CompassTheme(
                variant: CompassThemeVariant.defaultVariant,
                child: Stack(children: [child]),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}