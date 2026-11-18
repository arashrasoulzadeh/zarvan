import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:zarvan_flutter/zarvan_flutter.dart';

void main() {
  test('fillScreen takes the whole screen, with no bars', () {
    final m = ViewportManager(
      const ViewportConfig(
        targetAspectRatio: 9 / 16,
        avoidSystemUi: false,
        fitWorld: true,
        fillScreen: true,
      ),
    );
    final l = m.computeLayout(const ui.Size(1080, 2340), null);
    expect(l.contentRect, const ui.Rect.fromLTWH(0, 0, 1080, 2340));
    expect(l.isLetterboxed, isFalse);
    expect(l.isPillarboxed, isFalse);
  });
}
