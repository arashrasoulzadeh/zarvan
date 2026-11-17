import 'dart:convert';

import 'package:test/test.dart';
import 'package:zarvan_core/zarvan_core.dart' show MemoryKeyValueStore;
import 'package:zarvan_core/zarvan_core_quiz.dart';

import 'support.dart';

final bank = makeBank(perTier: 30);
QuestionFactory factory() => factoryOf(bank);

/// Plays a whole stage answering right where [rightAt] says so.
QuizRound stage(
  QuizTier tier,
  bool Function(int i) rightAt, {
  String author = 'a',
  int attempt = 1,
}) {
  final round = QuizRound.stage(
    factory(),
    const StageMode(),
    author: author,
    tier: tier,
    attempt: attempt,
  );
  play(round, (_, i) => rightAt(i));
  return round;
}

QuizRound endless(int rightCount) {
  final round = QuizRound.endless(
    factory(),
    const EndlessMode(),
    seedBase: 'endless:p',
  );
  play(round, (_, i) => i < rightCount);
  return round;
}

QuizRound daily(String date, {bool Function(int i)? rightAt}) {
  final round = QuizRound.daily(factory(), const DailyMode(), date: date);
  play(round, (_, i) => rightAt?.call(i) ?? true);
  return round;
}

void main() {
  group('R-PROG-1/2: start state and unlocking', () {
    test(
      'starts with 60 coins; every chapter opens at easy, the next tier waits for a pass',
      () {
        final p = QuizProgress();
        expect(p.coins, 60);
        for (final a in ['a', 'b', 'anyone']) {
          expect(p.isUnlocked(a, QuizTier.easy), isTrue);
          expect(p.isUnlocked(a, QuizTier.medium), isFalse);
          expect(p.isUnlocked(a, QuizTier.literary), isFalse);
        }
      },
    );

    test('passing a stage opens the next tier of that chapter only', () {
      final p = QuizProgress()..applyRun(stage(QuizTier.easy, (_) => true));
      expect(p.isUnlocked('a', QuizTier.medium), isTrue);
      expect(p.isUnlocked('a', QuizTier.hard), isFalse);
      expect(p.isUnlocked('b', QuizTier.medium), isFalse);
    });

    test('a failed stage opens nothing', () {
      final p = QuizProgress()..applyRun(stage(QuizTier.easy, (i) => i < 17));
      expect(p.isUnlocked('a', QuizTier.medium), isFalse);
      expect(p.stages['a']!['easy']!.passedOnce, isFalse);
      expect(p.stages['a']!['easy']!.attempts, 1);
    });
  });

  group('stage results', () {
    test('stars keep the best and attempts count every play', () {
      final p = QuizProgress();
      p.applyRun(stage(QuizTier.easy, (i) => i < 22)); // 2 stars
      p.applyRun(stage(QuizTier.easy, (i) => i < 18, attempt: 2)); // 1 star
      expect(p.stages['a']!['easy']!.stars, 2);
      expect(p.stages['a']!['easy']!.attempts, 2);
      p.applyRun(stage(QuizTier.easy, (_) => true, attempt: 3));
      expect(p.stages['a']!['easy']!.stars, 3);
    });

    test('applyRun on an unfinished round is a StateError', () {
      final round = QuizRound.stage(
        factory(),
        const StageMode(),
        author: 'a',
        tier: QuizTier.easy,
      );
      round.nextQuestion();
      expect(() => QuizProgress().applyRun(round), throwsStateError);
    });
  });

  group('R-PROG-3..5: coins earned', () {
    test(
      'R-PROG-3 and 4: 25 right = five streak bonuses plus the first pass',
      () {
        final p = QuizProgress();
        final reward = p.applyRun(stage(QuizTier.easy, (_) => true));
        expect(reward.streakCoins, 25);
        expect(reward.firstPassCoins, 10);
        expect(reward.coins, 35);
        expect(p.coins, 60 + 35);
      },
    );

    test(
      'R-PROG-4: a repeat pass pays only the streak coins, not the pass bonus',
      () {
        final p = QuizProgress();
        p.applyRun(stage(QuizTier.easy, (_) => true));
        final before = p.coins;
        final again = p.applyRun(stage(QuizTier.easy, (_) => true, attempt: 2));
        expect(again.firstPassCoins, 0);
        expect(p.coins, before + 25);
      },
    );

    test(
      'R-PROG-3: the streak resets after a wrong answer, so each run of five pays once',
      () {
        // right x5, wrong, right x5, wrong ... (11 per two blocks) -> bonuses at 5 and at 5 again
        final p = QuizProgress();
        final reward = p.applyRun(stage(QuizTier.easy, (i) => i % 6 != 5));
        // 25 questions: blocks of 5 right + 1 wrong -> 4 full blocks (24) + 1 -> 4 bonuses
        expect(reward.streakCoins, 20);
      },
    );

    test('R-PROG-3: streak 10 pays at 5 and at 10, not twice at once', () {
      final p = QuizProgress();
      final reward = p.applyRun(endlessRight(10));
      expect(reward.streakCoins, 10);
    });

    test('R-PROG-5: the daily pays 20 once and saves the result', () {
      final p = QuizProgress();
      final reward = p.applyRun(daily('2026-11-17'));
      expect(reward.dailyCoins, 20);
      expect(p.daily.results['2026-11-17'], [true, true, true, true, true]);
      expect(p.hasPlayedDaily('2026-11-17'), isTrue);
      expect(p.hasPlayedDaily('2026-11-18'), isFalse);
    });

    test(
      'R-MODE-D3: a second daily on the same date is refused and pays nothing',
      () {
        final p = QuizProgress()..applyRun(daily('2026-11-17'));
        final coins = p.coins;
        expect(
          () => p.applyRun(daily('2026-11-17', rightAt: (_) => false)),
          throwsStateError,
        );
        expect(p.coins, coins);
        expect(p.daily.results['2026-11-17'], everyElement(true));
      },
    );
  });

  group('R-PROG-6/7: ads and hints', () {
    test('a rewarded ad gives 15 coins', () {
      final p = QuizProgress()..rewardedAd();
      expect(p.coins, 75);
    });

    test('a hint costs 20; too few coins refuses and never goes negative', () {
      final p = QuizProgress(coins: 19);
      expect(p.buyHint(), isFalse);
      expect(p.coins, 19);
      p.rewardedAd();
      expect(p.buyHint(), isTrue);
      expect(p.coins, 14);
      final exact = QuizProgress(coins: 20);
      expect(exact.buyHint(), isTrue);
      expect(exact.coins, 0);
      expect(exact.buyHint(), isFalse);
    });
  });

  group('R-PROG-8: records and the daily streak', () {
    test('endless and race keep the best score only', () {
      final p = QuizProgress();
      p.applyRun(endless(5));
      final first = p.records.endlessBest;
      expect(first, greaterThan(0));
      p.applyRun(endless(2));
      expect(p.records.endlessBest, first);
      p.applyRun(endless(8));
      expect(p.records.endlessBest, greaterThan(first));
      final race = QuizRound.race(
        factory(),
        const RaceMode(),
        seedBase: 'race:p',
      );
      play(race, (_, i) => i < 3, max: 6);
      race.tick(const Duration(minutes: 2));
      p.applyRun(race);
      expect(p.records.raceBest, race.run.score);
    });

    test(
      'consecutive days extend the daily streak; a missed day restarts it',
      () {
        final p = QuizProgress();
        p.applyRun(daily('2026-11-17'));
        expect(p.daily.streakDays, 1);
        p.applyRun(daily('2026-11-18'));
        p.applyRun(daily('2026-11-19'));
        expect(p.daily.streakDays, 3);
        p.applyRun(daily('2026-11-22'));
        expect(p.daily.streakDays, 1);
        expect(p.daily.lastDate, '2026-11-22');
      },
    );

    test('the streak counts across a month and year end', () {
      final p = QuizProgress();
      p.applyRun(daily('2026-12-31'));
      p.applyRun(daily('2027-01-01'));
      expect(p.daily.streakDays, 2);
    });
  });

  group('R-PROG-9 and persistence', () {
    test('toJson matches data-format section 6 and round-trips', () {
      final p = QuizProgress();
      p.applyRun(stage(QuizTier.easy, (_) => true));
      p.applyRun(daily('2026-11-17'));
      p.flags['tutorialDone'] = true;
      final json = jsonDecode(jsonEncode(p.toJson())) as Map<String, dynamic>;
      expect(json['version'], 1);
      expect(json['coins'], p.coins);
      expect(json['stages']['a']['easy'], {
        'stars': 3,
        'attempts': 1,
        'passedOnce': true,
      });
      expect(json['records'], {'endlessBest': 0, 'raceBest': 0});
      expect(json['daily'], {
        'lastDate': '2026-11-17',
        'streakDays': 1,
        'results': {
          '2026-11-17': [true, true, true, true, true],
        },
      });
      expect(json['flags'], {'tutorialDone': true});
      expect(
        jsonEncode(QuizProgress.fromJson(json).toJson()),
        jsonEncode(p.toJson()),
      );
    });

    test('an unknown version or wrong shape is a FormatException', () {
      expect(
        () => QuizProgress.fromJson({'version': 3}),
        throwsFormatException,
      );
      expect(
        () => QuizProgress.fromJson({'version': 1, 'coins': 'many'}),
        throwsFormatException,
      );
      expect(
        () => QuizProgress.fromJson({'version': 1, 'coins': -5}),
        throwsFormatException,
      );
    });

    test(
      'the store saves and loads under quiz.progress; no key gives defaults without error',
      () async {
        final kv = MemoryKeyValueStore();
        final store = QuizProgressStore(kv);
        final empty = await store.load();
        expect(empty.error, isNull);
        expect(empty.progress.coins, 60);
        final p = QuizProgress()..rewardedAd();
        await store.save(p);
        expect(kv.values.containsKey('quiz.progress'), isTrue);
        final back = await store.load();
        expect(back.error, isNull);
        expect(back.progress.coins, 75);
      },
    );

    test(
      'a corrupt save loads as defaults, reports why, and is kept aside',
      () async {
        final kv = MemoryKeyValueStore({'quiz.progress': '{not json'});
        final loaded = await QuizProgressStore(kv).load();
        expect(loaded.progress.coins, 60);
        expect(loaded.error, isNotNull);
        expect(kv.values['quiz.progress.corrupt'], '{not json');
        final wrong = MemoryKeyValueStore({
          'quiz.progress': jsonEncode({'version': 9}),
        });
        final r2 = await QuizProgressStore(wrong).load();
        expect(r2.error, contains('9'));
        expect(r2.progress.coins, 60);
      },
    );
  });
}

QuizRound endlessRight(int n) {
  final round = QuizRound.endless(
    factory(),
    const EndlessMode(),
    seedBase: 'endless:s',
  );
  play(round, (_, i) => i < n, max: n + 3);
  return round;
}
