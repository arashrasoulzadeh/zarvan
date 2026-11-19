import 'package:flutter_test/flutter_test.dart';
import 'package:zarvan_idle/zarvan_idle.dart';

Gear g(double bonus, {GearRarity r = GearRarity.common, String slot = 'weapon', String stat = 'attack'}) =>
    Gear(slot: slot, name: 'n$bonus', stat: stat, bonus: bonus, rarity: r);

void main() {
  test('a replaced worn item goes to the bag; a worse drop does not replace', () {
    final p = HeroProgress();
    expect(p.equipIfBetter(g(0.1)), isTrue);
    expect(p.bag, isEmpty);
    expect(p.equipIfBetter(g(0.2)), isTrue);
    expect(p.bag.single.bonus, 0.1);
    expect(p.equipIfBetter(g(0.05)), isFalse);
    expect(p.addToBag(g(0.05)), isTrue);
    expect(p.bag.length, 2);
  });

  test('compareToWorn is the bonus difference, full value for an empty slot', () {
    final p = HeroProgress()..equipIfBetter(g(0.1));
    expect(p.compareToWorn(g(0.25)), closeTo(0.15, 1e-9));
    expect(p.compareToWorn(g(0.04)), closeTo(-0.06, 1e-9));
    expect(p.compareToWorn(g(0.3, slot: 'armor', stat: 'hp')), 0.3);
  });

  test('equipFromBag swaps with the worn item and rejects bad indexes', () {
    final p = HeroProgress()..equipIfBetter(g(0.1));
    p.addToBag(g(0.04));
    expect(p.equipFromBag(5), isFalse);
    expect(p.equipFromBag(-1), isFalse);
    expect(p.equipFromBag(0), isTrue);
    expect(p.gear['weapon']!.bonus, 0.04);
    expect(p.bag.single.bonus, 0.1);
  });

  test('the bag holds at most bagCapacity items', () {
    final p = HeroProgress();
    for (var i = 0; i < HeroProgress.bagCapacity; i++) {
      expect(p.addToBag(g(0.01)), isTrue);
    }
    expect(p.addToBag(g(0.01)), isFalse);
    expect(p.bag.length, HeroProgress.bagCapacity);
  });

  test('merge needs three of one kind, takes the best, averages and boosts', () {
    final p = HeroProgress();
    final like = g(0.06);
    expect(p.mergeBag(like), isNull);
    for (final b in [0.06, 0.06, 0.03, 0.09]) {
      p.addToBag(g(b));
    }
    p.addToBag(g(0.06, slot: 'armor', stat: 'hp'));
    expect(p.mergeablePairs(like), 1);
    final m = p.mergeBag(like)!;
    expect(m.rarity, GearRarity.rare);
    expect(m.bonus, closeTo((0.09 + 0.06 + 0.06) / 3 * 2.0, 1e-9));
    expect(p.bag.length, 3); // 0.03 left, the armor item, and the merged one
    expect(p.bag.where((x) => x.rarity == GearRarity.common && x.slot == 'weapon').single.bonus, 0.03);
  });

  test('epic cannot merge; rare merges into epic', () {
    final p = HeroProgress();
    for (var i = 0; i < 3; i++) {
      p.addToBag(g(0.2, r: GearRarity.epic));
      p.addToBag(g(0.1, r: GearRarity.rare));
    }
    expect(p.mergeBag(g(0.2, r: GearRarity.epic)), isNull);
    final m = p.mergeBag(g(0.1, r: GearRarity.rare))!;
    expect(m.rarity, GearRarity.epic);
    expect(m.bonus, closeTo(0.18, 1e-9));
  });

  test('the bag survives JSON; an old save without one loads empty', () {
    final p = HeroProgress()..addToBag(g(0.07, r: GearRarity.rare));
    final back = HeroProgress.fromJson(p.toJson());
    expect(back.bag.single.rarity, GearRarity.rare);
    expect(back.bag.single.bonus, 0.07);
    final json = HeroProgress().toJson();
    expect(json.containsKey('bag'), isFalse);
    expect(HeroProgress.fromJson(json).bag, isEmpty);
  });
}
