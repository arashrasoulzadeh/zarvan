/// A tiny string key-value store: where a game keeps its save blobs.
///
/// An interface so game code stays free of platform packages (the
/// Flutter implementation is `PreferencesKeyValueStore`) and tests can use
/// [MemoryKeyValueStore]. Strings, not maps, so the caller owns the format
/// and can keep a corrupt copy aside instead of losing it.
abstract class KeyValueStore {
  /// The string stored under [key], or null.
  Future<String?> getString(String key);

  /// Stores [value] under [key], replacing any previous one.
  Future<void> setString(String key, String value);

  /// Removes [key]; does nothing if it is absent.
  Future<void> remove(String key);
}

/// A [KeyValueStore] in memory, for tests and previews.
class MemoryKeyValueStore implements KeyValueStore {
  MemoryKeyValueStore([Map<String, String>? initial]) : values = {...?initial};

  /// The stored entries; tests may read and write it directly.
  final Map<String, String> values;

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> setString(String key, String value) async => values[key] = value;

  @override
  Future<void> remove(String key) async => values.remove(key);
}
