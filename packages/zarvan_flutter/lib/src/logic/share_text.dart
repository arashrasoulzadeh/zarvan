import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:share_plus/share_plus.dart';

/// What [shareText] managed to do with a text.
enum ShareOutcome {
  /// The system share sheet took it.
  shared,

  /// The sheet was not available, so the text was copied instead.
  copied,

  /// Neither worked (a browser can refuse the clipboard too).
  failed,
}

/// Shares [text] through the system share sheet; when that is not possible (a
/// browser without the Web Share API throws) it copies the text instead, and
/// when that is refused as well it says so. Never throws. [sharer] and [copier]
/// are replaceable for tests. A game that imports no Flutter itself can share
/// and copy through this.
Future<ShareOutcome> shareText(
  String text, {
  Future<void> Function(String text)? sharer,
  Future<void> Function(String text)? copier,
}) async {
  try {
    await (sharer ?? (t) => Share.share(t))(text);
    return ShareOutcome.shared;
  } on Object {
    // Fall through to copying.
  }
  try {
    await (copier ?? (t) => Clipboard.setData(ClipboardData(text: t)))(text);
    return ShareOutcome.copied;
  } on Object {
    return ShareOutcome.failed;
  }
}
