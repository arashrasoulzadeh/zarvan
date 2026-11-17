import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;

/// Whether the game runs in a browser, so a game that imports no Flutter
/// itself can choose what to offer (no ads there, for example).
bool get isWeb => kIsWeb;

/// The platform's name (`android`, `iOS`, `macOS`, `windows`, `linux`,
/// `fuchsia`), for analytics dimensions and the like.
String get platformName => defaultTargetPlatform.name;
