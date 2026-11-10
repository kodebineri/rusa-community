import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/mongo_models.dart';

/// Everything the app reads from the device store once, at startup.
class StoredPreferences {
  const StoredPreferences({
    required this.eulaAccepted,
    required this.onboardingDone,
    this.themeVariantName,
    this.savedConnections,
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

  /// Connection profiles saved by the user, or `null` when the device has no
  /// stored list yet.
  ///
  /// `null` and an empty list are different: `null` means "first run, use the
  /// built-in sample profiles", while `[]` means the user deleted every saved
  /// connection and the defaults must not reappear.
  final List<ConnectionProfile>? savedConnections;

  /// Whether the welcome tour should cover the app on this launch.
  ///
  /// Either the licence still has to be accepted, or the user explicitly asked
  /// to see the tour again by leaving the "don't show this again" box unticked.
  bool get shouldShowOnboarding => !eulaAccepted || !onboardingDone;
}

/// Tiny wrapper for the values that must survive a restart: EULA acceptance,
/// the welcome tour and the chosen theme ([SharedPreferences]), plus saved
/// connection profiles in the platform's encrypted credential store
/// ([FlutterSecureStorage]).
///
/// It deliberately does **not** cache the [SharedPreferences] instance: widget
/// tests call `SharedPreferences.setMockInitialValues(...)` between runs and a
/// cached instance would ignore the reset.
class AppPreferences {
  AppPreferences({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// Platform keystore/Keychain/Credential Manager - used only for profiles
  /// that contain connection strings and credentials.
  final FlutterSecureStorage _secureStorage;

  /// Key under which first-run EULA acceptance is stored.
  static const String eulaAcceptedKey = 'eula_accepted';

  /// Key under which the welcome tour's "don't show again" choice is stored.
  static const String onboardingDoneKey = 'onboarding_done';

  /// Key under which the chosen theme variant's name is stored.
  static const String themeVariantKey = 'theme_variant';

  /// Key under which the saved connection profiles are stored as JSON.
  ///
  /// The value lives in secure storage, not in [SharedPreferences]. The same
  /// key is read from preferences once, to migrate profiles written by builds
  /// that predate the keystore-backed store.
  static const String savedConnectionsKey = 'saved_connections';

  /// Reads every startup flag in one go.
  Future<StoredPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    final eulaAccepted = prefs.getBool(eulaAcceptedKey) ?? false;
    return StoredPreferences(
      eulaAccepted: eulaAccepted,
      onboardingDone: prefs.getBool(onboardingDoneKey) ?? true,
      themeVariantName: prefs.getString(themeVariantKey),
      savedConnections: _decodeSavedConnections(
        await _readSavedConnections(prefs),
      ),
    );
  }

  /// Reads the profile JSON from the keystore, migrating a legacy
  /// `SharedPreferences` value when no secure value exists yet.
  Future<String?> _readSavedConnections(SharedPreferences prefs) async {
    try {
      final secure = await _secureStorage.read(key: savedConnectionsKey);
      if (secure != null) return secure;
      final legacy = prefs.getString(savedConnectionsKey);
      if (legacy == null) return null;
      await _secureStorage.write(key: savedConnectionsKey, value: legacy);
      await prefs.remove(savedConnectionsKey);
      return legacy;
    } catch (_) {
      // A missing keyring/keystore must not stop the app from starting with
      // the bundled sample profiles and its normal EULA/theme flags.
      return null;
    }
  }

  /// Decodes the stored JSON list; malformed data behaves like a missing key
  /// so the app falls back to the built-in sample profiles instead of crashing.
  List<ConnectionProfile>? _decodeSavedConnections(String? raw) {
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      return [
        for (final item in decoded)
          if (item is Map) ConnectionProfile.fromJson(Map<String, dynamic>.from(item)),
      ];
    } catch (_) {
      return null;
    }
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

  /// Replaces the stored connection list.
  ///
  /// An empty list is written rather than removing the key, so deleting every
  /// saved profile stays deleted on the next launch.
  Future<void> setSavedConnections(List<ConnectionProfile> connections) async {
    try {
      await _secureStorage.write(
        key: savedConnectionsKey,
        value: jsonEncode([
          for (final connection in connections) connection.toJson(),
        ]),
      );
      // Drop any plaintext copy left by a pre-keystore build.
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(savedConnectionsKey);
    } catch (_) {
      // Keep the app usable even if the OS credential store is unavailable.
    }
  }
}

/// Shared singleton, mirroring the `mongoEngine` global style.
final AppPreferences appPreferences = AppPreferences();
