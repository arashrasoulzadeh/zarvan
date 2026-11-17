import 'dart:typed_data';

import 'package:flutter/services.dart' show AssetBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:zarvan_flutter/zarvan_flutter.dart'
    show
        ShareOutcome,
        isWeb,
        loadTextAsset,
        measureText,
        platformName,
        shareText;

class _Bundle extends AssetBundle {
  @override
  Future<ByteData> load(String key) async => throw UnimplementedError();
  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      'text of $key';
}

void main() {
  group('helpers so a game needs no Flutter import', () {
    test('loadTextAsset reads a bundled file whole', () async {
      expect(
        await loadTextAsset('assets/a.txt', bundle: _Bundle()),
        'text of assets/a.txt',
      );
    });

    test('isWeb and platformName describe where the game runs', () {
      expect(isWeb, isFalse);
      expect(platformName, isNotEmpty);
    });

    test('shareText uses the sheet when it works', () async {
      final copied = <String>[];
      expect(
        await shareText(
          'x',
          sharer: (_) async {},
          copier: (t) async => copied.add(t),
        ),
        ShareOutcome.shared,
      );
      expect(copied, isEmpty);
    });

    test('shareText copies the text when the sheet throws', () async {
      final copied = <String>[];
      final ok = await shareText(
        'متن',
        sharer: (_) async => throw StateError('no Web Share API'),
        copier: (t) async => copied.add(t),
      );
      expect(ok, ShareOutcome.copied);
      expect(copied, ['متن']);
    });

    test(
      'shareText reports failure, without throwing, when the clipboard is refused too',
      () async {
        final ok = await shareText(
          'x',
          sharer: (_) async => throw StateError('no sheet'),
          copier: (_) async => throw StateError('clipboard denied'),
        );
        expect(ok, ShareOutcome.failed);
      },
    );

    test('measureText grows with the text and wraps at the width', () {
      final short = measureText('ab', fontSize: 20);
      final long = measureText('abababababababab', fontSize: 20);
      expect(long.width, greaterThan(short.width));
      final wrapped = measureText(
        'abababababababab abababababababab',
        fontSize: 20,
        maxWidth: 120,
      );
      expect(wrapped.width, lessThanOrEqualTo(120));
      expect(wrapped.height, greaterThan(short.height));
      expect(measureText('ab', fontSize: 40).height, greaterThan(short.height));
    });
  });
}
