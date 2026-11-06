import 'package:shared_preferences/shared_preferences.dart';

/// Everything the app reads from the device store once, at startup.
class StoredPreferences {
  const StoredPreferences({
    required this.eulaAccepted,
    required this.onboardingDone,
    this.themeVariantName,
  });

  /// Whether the EULA has been accepted on this device.
  final bool eulaAccepted;

  /// Whether the welcome tour should stay hidden.
  ///
  /// Absent means "yes, done": an install that predates the tour must not
  /// suddenly show it, and a first-time user sees the tour anyway (consent is
  /// missing) with the "don't show this again" box already ticked.
  final bool onboardingDone;

  /// `CompassThemeVariant.name` of the last theme the user picked, or `null`
  /// when they never picked one.
  final String? themeVariantName;

  /// Whether the welcome tour should cover the app on this launch.
  ///
  /// Either the licence still has to be accepted, or the user explicitly asked
  /// to see the tour again by leaving the "don't show this again" box unticked.
  bool get shouldShowOnboarding => !eulaAccepted || !onboardingDone;
}

/// Tiny wrapper over [SharedPreferences] for the flags that must survive a
/// restart: EULA acceptance, the welcome tour, and the chosen theme.
///
/// It deliberately does **not** cache the [SharedPreferences] instance: widget
/// tests call `SharedPreferences.setMockInitialValues(...)` between runs and a
/// cached instance would ignore the reset.
class AppPreferences {
  /// Key under which first-run EULA acceptance is stored.
  static const String eulaAcceptedKey = 'eula_accepted';

  /// Key under which the welcome tour's "don't show again" choice is stored.
  static const String onboardingDoneKey = 'onboarding_done';

  /// Key under which the chosen theme variant's name is stored.
  static const String themeVariantKey = 'theme_variant';

  /// Reads every startup flag in one go.
  Future<StoredPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    final eulaAccepted = prefs.getBool(eulaAcceptedKey) ?? false;
    return StoredPreferences(
      eulaAccepted: eulaAccepted,
      onboardingDone: prefs.getBool(onboardingDoneKey) ?? true,
      themeVariantName: prefs.getString(themeVariantKey),
    );
  }

  /// Records (or clears) EULA acceptance.
  Future<void> setEulaAccepted(bool accepted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(eulaAcceptedKey, accepted);
  }

  /// Records whether the welcome tour should stop showing automatically.
  Future<void> setOnboardingDone(bool done) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(onboardingDoneKey, done);
  }

  /// Stores the chosen theme by `CompassThemeVariant.name`; `null` clears it.
  Future<void> setThemeVariant(String? variantName) async {
    final prefs = await SharedPreferences.getInstance();
    if (variantName == null) {
      await prefs.remove(themeVariantKey);
    } else {
      await prefs.setString(themeVariantKey, variantName);
    }
  }
}

/// Shared singleton, mirroring the `mongoEngine` global style.
final AppPreferences appPreferences = AppPreferences();
