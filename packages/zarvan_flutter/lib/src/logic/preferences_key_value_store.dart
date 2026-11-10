import 'package:shared_preferences/shared_preferences.dart';
import 'package:zarvan_core/zarvan_core.dart';

/// A [KeyValueStore] on `shared_preferences`: Android, iOS, web and desktop.
/// What a game's save data lives in; game code only sees [KeyValueStore].
class PreferencesKeyValueStore implements KeyValueStore {
  PreferencesKeyValueStore._(this._prefs);

  final SharedPreferences _prefs;

  /// Opens the platform store.
  static Future<PreferencesKeyValueStore> open() async =>
      PreferencesKeyValueStore._(await SharedPreferences.getInstance());

  @override
  Future<String?> getString(String key) async => _prefs.getString(key);

  @override
  Future<void> setString(String key, String value) async {
    await _prefs.setString(key, value);
  }

  @override
  Future<void> remove(String key) async {
    await _prefs.remove(key);
  }
}
