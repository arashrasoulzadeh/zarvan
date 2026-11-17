import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:share_plus/share_plus.dart';

/// Shares [text] through the system share sheet; when that is not possible (a
/// browser without the Web Share API throws) it copies the text instead.
/// Returns true when the sheet took it, false when it was copied. [sharer] and
/// [copier] are replaceable for tests. A game that imports no Flutter itself
/// can share and copy through this.
Future<bool> shareText(
  String text, {
  Future<void> Function(String text)? sharer,
  Future<void> Function(String text)? copier,
}) async {
  try {
    await (sharer ?? (t) => Share.share(t))(text);
    return true;
  } on Object {
    await (copier ?? (t) => Clipboard.setData(ClipboardData(text: t)))(text);
    return false;
  }
}
