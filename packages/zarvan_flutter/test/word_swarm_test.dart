import 'package:flutter_test/flutter_test.dart';
import 'package:zarvan_core/zarvan_core.dart';
import 'package:zarvan_flutter/zarvan_flutter.dart';

void main() {
  WordSwarm make(World w) {
    registerCoreComponents(w);
    registerFlutterComponents(w);
    return WordSwarm(
      w,
      ['شب', 'فراق', 'عشق', 'یار'],
      width: 360,
      height: 640,
      fontFamily: 'x',
      color: 0xFFFFFFFF,
      accentColor: 0xFFE3C477,
      rtl: true,
    );
  }

  test('one word per cell of a grid over the screen', () {
    final w = World(width: 360, height: 640);
    final s = make(w);
    expect(s.length, 3 * 16, reason: '3 columns, 640 / 40 = 16 rows');
    expect(w.componentsOf<Text>().length, s.length);
  });

  test('nothing shows at 0, every word is settled inside the screen at 1', () {
    final w = World(width: 360, height: 640);
    final s = make(w);
    s.apply(0);
    expect(s.nodes.every((n) => n.text!.alpha == 0), isTrue);
    s.apply(1);
    for (final n in s.nodes) {
      expect(n.text!.alpha, 1);
      expect(n.text!.textScale, closeTo(1, 1e-9));
      expect(n.pos.x, inInclusiveRange(0, 360));
      expect(n.pos.y, inInclusiveRange(0, 640));
    }
  });

  test('in between the words are swirling in: some seen, some still away', () {
    final w = World(width: 360, height: 640);
    final s = make(w);
    s.apply(0.4);
    final shown = s.nodes.where((n) => n.text!.alpha > 0).length;
    expect(shown, greaterThan(0));
    expect(shown, lessThan(s.length));
    final away = s.nodes.where(
      (n) => n.pos.x < -10 || n.pos.x > 370 || n.pos.y < -10 || n.pos.y > 650,
    );
    expect(away, isNotEmpty, reason: 'the late ones are still off the page');
  });

  test('dispose removes the words from the world', () {
    final w = World(width: 360, height: 640);
    final s = make(w);
    s.dispose();
    expect(w.componentsOf<Text>().length, 0);
    expect(s.length, 0);
  });
}
