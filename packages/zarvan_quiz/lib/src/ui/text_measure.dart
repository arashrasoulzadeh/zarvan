import 'dart:ui' show Size;

import 'package:flutter/painting.dart'
    show TextAlign, TextDirection, TextPainter, TextSpan, TextStyle;

/// How big the engine will draw a piece of text, so a screen can stack
/// things under a poem of any length. Uses the same text layout as the
/// engine's renderer (same size, typeface, direction and wrap width).
Size measureText(
  String text, {
  required double fontSize,
  String? fontFamily,
  bool rtl = false,
  double? maxWidth,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontSize: fontSize,
        fontFamily: fontFamily ?? 'packages/zarvan_flutter/EngineDefault',
      ),
    ),
    textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
    textAlign: TextAlign.center,
  )..layout(maxWidth: maxWidth ?? double.infinity);
  final size = Size(painter.width, painter.height);
  painter.dispose();
  return size;
}
