/// App identity shown in the UI — currently the version badge in `AboutModal`.
///
/// Flutter does not expose `pubspec.yaml` to Dart at runtime, so the value has
/// to be duplicated here. To stop it drifting, `test/widget_test.dart` reads
/// `pubspec.yaml` and asserts [version] / [buildNumber] match its `version:`
/// field — a mismatch fails the suite, so bumping the pubspec version is a
/// deliberate two-line change.
///
/// (The alternative, `package_info_plus`, would read the platform's build-time
/// version for real, but pulls in a platform plugin and makes the value async.)
class AppInfo {
  const AppInfo._();

  /// Semantic version — the part before `+` in pubspec's `version:`.
  static const String version = '1.0.0';

  /// Build number — the part after `+` in pubspec's `version:`.
  static const String buildNumber = '1';

  /// The complete `version:` string from `pubspec.yaml` (`<version>+<build>`).
  static const String fullVersion = '$version+$buildNumber';
}
