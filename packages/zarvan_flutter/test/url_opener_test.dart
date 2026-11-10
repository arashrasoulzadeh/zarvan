import 'package:flutter_test/flutter_test.dart';
import 'package:zarvan_flutter/zarvan_flutter.dart';

void main() {
  test('openUrl hands the parsed address to the launcher', () async {
    Uri? seen;
    final ok = await openUrl(
      'https://example.com/a',
      launcher: (u) async {
        seen = u;
        return true;
      },
    );
    expect(ok, isTrue);
    expect(seen.toString(), 'https://example.com/a');
  });

  test('an address with no scheme is refused without launching', () async {
    var called = false;
    final ok = await openUrl(
      'example.com',
      launcher: (_) async => called = true,
    );
    expect(ok, isFalse);
    expect(called, isFalse);
  });

  test('a launcher that throws gives false, not a crash', () async {
    expect(
      await openUrl('https://x.io', launcher: (_) async => throw StateError('')),
      isFalse,
    );
  });
}
