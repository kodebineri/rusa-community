import 'package:shared_preferences/shared_preferences.dart';

/// Tiny wrapper over [SharedPreferences] for flags that must survive a restart
/// (currently only EULA acceptance).
///
/// It deliberately does **not** cache the [SharedPreferences] instance: widget
/// tests call `SharedPreferences.setMockInitialValues(...)` between runs and a
/// cached instance would ignore the reset.
class AppPreferences {
  /// Key under which first-run EULA acceptance is stored.
  static const String eulaAcceptedKey = 'eula_accepted';

  /// Whether the user has accepted the EULA on this device.
  Future<bool> hasAcceptedEula() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(eulaAcceptedKey) ?? false;
  }

  /// Records (or clears) EULA acceptance.
  Future<void> setEulaAccepted(bool accepted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(eulaAcceptedKey, accepted);
  }
}

/// Shared singleton, mirroring the `mongoEngine` global style.
final AppPreferences appPreferences = AppPreferences();
