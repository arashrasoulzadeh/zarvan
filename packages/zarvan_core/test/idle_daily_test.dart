import 'package:test/test.dart';
import 'package:zarvan_core/zarvan_core.dart';
import 'package:zarvan_core/zarvan_core_idle.dart';

Rewards coins(int n) => {'coins': BigNumber.from(n)};

LoginStreak streak() => LoginStreak(rewards: [coins(10), coins(20), coins(50)]);

DailyQuests quests({int perDay = 2, int seed = 7}) => DailyQuests(
  perDay: perDay,
  seed: seed,
  pool: [
    for (var i = 0; i < 6; i++)
      DailyQuest(id: 'q$i', event: 'e${i % 2}', target: 3, reward: coins(i + 1)),
  ],
);

void main() {
  group('login streak', () {
    test('first claim starts at 1; same day twice is a no-op', () {
      final s = streak();
      final a = s.claim(DateTime(2026, 11, 17, 9));
      expect(a.claimed, isTrue);
      expect(a.streak, 1);
      expect(a.reward['coins']!.toDouble(), 10);
      final b = s.claim(DateTime(2026, 11, 17, 23));
      expect(b.claimed, isFalse);
      expect(s.streak, 1);
    });

    test('consecutive days extend and cycle the rewards, across month end', () {
      final s = streak();
      final days = [DateTime(2026, 11, 29), DateTime(2026, 11, 30), DateTime(2026, 12, 1), DateTime(2026, 12, 2)];
      final got = [for (final d in days) s.claim(d).reward['coins']!.toDouble()];
      expect(got, [10, 20, 50, 10]);
      expect(s.streak, 4);
      expect(s.best, 4);
    });

    test('a missed day restarts at 1 and keeps the best', () {
      final s = streak()
        ..claim(DateTime(2026, 11, 1))
        ..claim(DateTime(2026, 11, 2));
      final c = s.claim(DateTime(2026, 11, 5));
      expect(c.broken, isTrue);
      expect(c.streak, 1);
      expect(s.best, 2);
    });

    test('a clock set backwards is not a claim and not a reset', () {
      final s = streak()..claim(DateTime(2026, 11, 10));
      expect(s.claim(DateTime(2026, 11, 3)).claimed, isFalse);
      expect(s.streak, 1);
      expect(s.lastDay, '2026-11-10');
    });

    test('round-trips through JSON', () {
      final s = streak()..claim(DateTime(2026, 11, 1));
      final back = LoginStreak.fromJson(s.toJson());
      expect(back.toJson(), s.toJson());
      expect(back.canClaim(DateTime(2026, 11, 1)), isFalse);
      expect(back.canClaim(DateTime(2026, 11, 2)), isTrue);
    });
  });

  group('daily quests', () {
    test('rollover picks perDay distinct quests, deterministic by date and seed', () {
      final a = quests()..rollover(DateTime(2026, 11, 17));
      final b = quests()..rollover(DateTime(2026, 11, 17, 22));
      expect(a.active.length, 2);
      expect(a.active.toSet().length, 2);
      expect(a.active, b.active);
      final c = quests()..rollover(DateTime(2026, 11, 18));
      final d = quests(seed: 8)..rollover(DateTime(2026, 11, 17));
      expect([c.active, d.active], isNot(everyElement(equals(a.active))));
    });

    test('rollover happens once per day and clears progress and claims', () {
      final q = quests()..rollover(DateTime(2026, 11, 17));
      expect(q.rollover(DateTime(2026, 11, 17, 20)), isFalse);
      final id = q.today.first;
      q.record(id.event, 3);
      expect(q.claim(id.id), isNotNull);
      expect(q.rollover(DateTime(2026, 11, 18)), isTrue);
      expect(q.progress, isEmpty);
      expect(q.claimed, isEmpty);
    });

    test('record counts matching events up to the target; claim needs completion, once', () {
      final q = quests()..rollover(DateTime(2026, 11, 17));
      final quest = q.today.first;
      expect(q.claim(quest.id), isNull);
      q.record(quest.event, 2);
      expect(q.isComplete(quest), isFalse);
      expect(q.claim(quest.id), isNull);
      q.record(quest.event, 99);
      expect(q.progressOf(quest), quest.target);
      expect(q.claim(quest.id), quest.reward);
      expect(q.claim(quest.id), isNull);
    });

    test('unrelated events and quests not offered today do nothing', () {
      final q = quests()..rollover(DateTime(2026, 11, 17));
      q.record('nothing');
      expect(q.progress, isEmpty);
      final off = [for (final p in q.pool) p.id].firstWhere((id) => !q.active.contains(id));
      expect(q.claim(off), isNull);
    });

    test('a pool smaller than perDay offers what exists', () {
      final q = DailyQuests(pool: [const DailyQuest(id: 'only', event: 'x')], perDay: 3)..rollover(DateTime(2026, 11, 17));
      expect(q.active, ['only']);
    });

    test('round-trips through JSON mid-day', () {
      final q = quests()..rollover(DateTime(2026, 11, 17));
      q.record(q.today.first.event, 2);
      final back = DailyQuests.fromJson(q.toJson());
      expect(back.toJson(), q.toJson());
      expect(back.rollover(DateTime(2026, 11, 17)), isFalse);
    });
  });
}
