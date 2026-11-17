import 'package:flutter_test/flutter_test.dart';
import 'package:zarvan_idle/zarvan_idle.dart';

const _cheap = HeroUpgrade(id: 'c', label: 'C', stat: 'attack', baseCost: 5);
const _dear = HeroUpgrade(id: 'd', label: 'D', stat: 'hp', baseCost: 50);

void main() {
  test('buy ticks at the interval and only when enabled', () {
    final a = WaveAutomation(autoBuy: true, buyIntervalSeconds: 1);
    expect(a.buyDue(0.6), isFalse);
    expect(a.buyDue(0.6), isTrue);
    expect(a.buyDue(0.6), isFalse);
    expect(WaveAutomation().buyDue(10), isFalse);
  });

  test('purchase picks the cheapest affordable, null when none', () {
    final a = WaveAutomation(autoBuy: true);
    expect(a.pickPurchase(HeroProgress(coins: 100), [_dear, _cheap]), _cheap);
    expect(a.pickPurchase(HeroProgress(coins: 4), [_dear, _cheap]), isNull);
    final p = HeroProgress(coins: 1000);
    for (var i = 0; i < _cheap.maxLevel; i++) {
      p.buy(_cheap);
    }
    expect(a.pickPurchase(p, [_cheap]), isNull);
  });

  test('casts: strike always, heal and guard only when hurt, nothing when off', () {
    const strike = HeroSkill(id: 's', label: 's', kind: SkillKind.strike);
    const heal = HeroSkill(id: 'h', label: 'h', kind: SkillKind.heal);
    const guard = HeroSkill(id: 'g', label: 'g', kind: SkillKind.guard);
    final a = WaveAutomation(autoCast: true);
    expect(a.wantsCast(strike, 1), isTrue);
    expect(a.wantsCast(heal, 0.9), isFalse);
    expect(a.wantsCast(heal, 0.4), isTrue);
    expect(a.wantsCast(guard, 0.8), isFalse);
    expect(a.wantsCast(guard, 0.6), isTrue);
    expect(WaveAutomation().wantsCast(strike, 0.1), isFalse);
  });

  test('ending waits the delay, prefers ascend on a win, resets mid-fight', () {
    final a = WaveAutomation(autoRetry: true, autoAscend: true, endingDelaySeconds: 1);
    AutoEnding tick(double dt, {bool finished = true, bool won = false, bool canAscend = true}) =>
        a.endingDue(dt, finished: finished, won: won, canAscend: canAscend);
    expect(tick(0.5), AutoEnding.none);
    expect(tick(0.6), AutoEnding.retry);
    expect(tick(0.5, finished: false), AutoEnding.none);
    expect(tick(0.5, won: true), AutoEnding.none);
    expect(tick(0.6, won: true), AutoEnding.ascend);
    expect(tick(1.1, won: true, canAscend: false), AutoEnding.retry);
  });

  test('ascend-only does not retry a loss; neither toggle does nothing', () {
    final a = WaveAutomation(autoAscend: true, endingDelaySeconds: 0);
    expect(a.endingDue(1, finished: true, won: false, canAscend: true), AutoEnding.none);
    expect(WaveAutomation().endingDue(1, finished: true, won: true, canAscend: true), AutoEnding.none);
  });

  test('round-trips through JSON', () {
    final a = WaveAutomation(autoBuy: true, autoRetry: true, healBelow: 0.3);
    expect(WaveAutomation.fromJson(a.toJson()).toJson(), a.toJson());
  });
}
