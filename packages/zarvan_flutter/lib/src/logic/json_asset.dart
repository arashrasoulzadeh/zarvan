import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

/// Reads the bundled JSON object at [assetPath] (declared under `assets:` in
/// `pubspec.yaml`). For data files such as a balance table, so a game's own
/// code needs no Flutter import to load them. [bundle] is for tests.
Future<Map<String, dynamic>> loadJsonAsset(
  String assetPath, {
  AssetBundle? bundle,
}) async {
  final raw = await (bundle ?? rootBundle).loadString(assetPath);
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, dynamic>) {
    throw FormatException('$assetPath is not a JSON object');
  }
  return decoded;
}

/// Reads the bundled text file at [assetPath] whole (declared under `assets:`
/// in `pubspec.yaml`), so a game that imports no Flutter itself can load its
/// own data formats. [bundle] is for tests.
Future<String> loadTextAsset(String assetPath, {AssetBundle? bundle}) =>
    (bundle ?? rootBundle).loadString(assetPath);
