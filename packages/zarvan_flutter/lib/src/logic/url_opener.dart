import 'package:url_launcher/url_launcher.dart';

/// Opens [url] outside the game (the phone's browser or the matching app), so
/// a game that imports no Flutter itself can still link to a web page.
///
/// [launcher] exists so tests need no platform channel. Never throws: a bad
/// address or a phone with no handler returns false instead of stopping a game.
Future<bool> openUrl(
  String url, {
  Future<bool> Function(Uri uri)? launcher,
}) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) return false;
  try {
    return await (launcher ?? _external)(uri);
  } catch (_) {
    return false;
  }
}

Future<bool> _external(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);
