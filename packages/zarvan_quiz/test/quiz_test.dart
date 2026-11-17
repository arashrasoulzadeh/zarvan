import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zarvan_core/zarvan_core.dart' show MemoryKeyValueStore;
import 'package:zarvan_quiz/zarvan_quiz.dart';

import 'support.dart';

final bank = makeBank();

QuizRound stage() => QuizRound.stage(
  factoryOf(bank),
  const StageMode(),
  author: 'a',
  tier: QuizTier.easy,
);

QuizRound race() =>
    QuizRound.race(factoryOf(bank), const RaceMode(), seedBase: 'race:t');

QuizSession newSession([MemoryKeyValueStore? kv, int coins = 60]) =>
    QuizSession(
      store: kv ?? MemoryKeyValueStore(),
      progress: QuizProgress(coins: coins),
    );

int right(QuizSession s) => s.question!.answerIndex;
int wrong(QuizSession s) => (s.question!.answerIndex + 1) % 4;

void main() {
  group('QuizSession', () {
    test(
      'answering scores, saves the run after each answer and moves on with next',
      () async {
        final kv = MemoryKeyValueStore();
        final s = newSession(kv)..begin(stage());
        s.answer(right(s));
        expect(s.round!.run.score, 10);
        expect(s.answered, isTrue);
        await Future<void>.delayed(Duration.zero);
        final saved =
            jsonDecode(kv.values[QuizSession.runKey]!) as Map<String, dynamic>;
        expect(saved['score'], 10);
        s.answer(0); // ignored: already answered
        expect(s.round!.run.answers.length, 1);
        s.next();
        expect(s.answered, isFalse);
        expect(s.question!.itemId, isNot(saved['usedItemIds'][0]));
      },
    );

    test('a finished stage is booked into progress and saved', () async {
      final kv = MemoryKeyValueStore();
      final s = newSession(kv)..begin(stage());
      for (var i = 0; i < 25; i++) {
        s.answer(right(s));
        s.next();
      }
      expect(s.finished, isTrue);
      expect(s.reward!.firstPassCoins, 10);
      expect(s.progress.stages['a']!['easy']!.stars, 3);
      await Future<void>.delayed(Duration.zero);
      final back = await QuizProgressStore(kv).load();
      expect(back.progress.coins, s.progress.coins);
      expect(back.progress.isUnlocked('a', QuizTier.medium), isTrue);
      expect(kv.values.containsKey(QuizSession.runKey), isFalse);
    });

    test('hint costs 20 coins, hides two wrong options, once per question', () {
      final s = newSession()..begin(stage());
      expect(s.canHint, isTrue);
      expect(s.useHint(), isTrue);
      expect(s.progress.coins, 40);
      expect(s.question!.removedByHint.length, 2);
      expect(s.canHint, isFalse);
      expect(s.useHint(), isFalse);
      expect(s.progress.coins, 40);
      s.answer(s.question!.removedByHint.first);
      expect(s.answered, isFalse, reason: 'a removed option cannot be chosen');
    });

    test('a hint is refused without coins and never goes negative', () {
      final s = newSession(null, 19)..begin(stage());
      expect(s.canHint, isFalse);
      expect(s.useHint(), isFalse);
      expect(s.progress.coins, 19);
    });

    group('continue', () {
      QuizSession endless({int lives = 1}) => newSession()
        ..begin(
          QuizRound.endless(
            factoryOf(bank),
            EndlessMode(lives: lives),
            seedBase: 'endless:c',
          ),
        );

      test('running out of lives offers one continue instead of finishing', () {
        final s = endless();
        s.answer(wrong(s));
        expect(s.canContinue, isTrue);
        s.next();
        expect(s.offeringContinue, isTrue);
        expect(s.finished, isFalse);
        expect(s.answered, isTrue, reason: 'the answered question stays up');
      });

      test(
        'continuing gives a life, a fresh question, and no second offer',
        () {
          final s = endless();
          s.answer(wrong(s));
          s.next();
          final before = s.round!.run.score;
          expect(s.continueRound(), isTrue);
          expect(s.offeringContinue, isFalse);
          expect(s.round!.run.lives, 1);
          expect(s.round!.run.continueUsed, isTrue);
          expect(s.answered, isFalse);
          expect(s.question, isNotNull);
          expect(s.round!.run.score, before);
          s.answer(wrong(s));
          expect(s.canContinue, isFalse);
          s.next();
          expect(s.offeringContinue, isFalse);
          expect(s.finished, isTrue);
        },
      );

      test('declining books the round as it ended', () {
        final s = endless();
        s.answer(right(s));
        s.next();
        s.answer(wrong(s));
        s.next();
        expect(s.offeringContinue, isTrue);
        s.declineContinue();
        expect(s.finished, isTrue);
        expect(s.offeringContinue, isFalse);
        expect(s.progress.records.endlessBest, s.round!.run.score);
      });

      test(
        'continue is refused when nothing is being offered; stage and race never offer',
        () {
          final s = endless();
          expect(s.continueRound(), isFalse);
          s.declineContinue();
          expect(s.finished, isFalse);
          final stageSession = newSession()..begin(stage());
          expect(stageSession.canContinue, isFalse);
          final raceSession = newSession()..begin(race());
          expect(raceSession.canContinue, isFalse);
          raceSession.dispose();
        },
      );
    });

    test('a rewarded ad pays 15 coins, saves, and tells listeners', () async {
      final kv = MemoryKeyValueStore();
      final s = newSession(kv);
      var heard = 0;
      s.addListener(() => heard++);
      await s.rewardForAd();
      expect(s.progress.coins, 75);
      expect(heard, 1);
      final back = await QuizProgressStore(kv).load();
      expect(back.progress.coins, 75);
    });

    group('events', () {
      test('a stage play-through is reported in order, with its details', () {
        final s = newSession();
        final seen = <QuizEvent>[];
        s.events.listen(seen.add);
        s.begin(stage());
        expect(s.useHint(), isTrue);
        s.answer(right(s));
        s.next();
        s.answer(wrong(s));
        for (var i = 0; i < 23; i++) {
          s.next();
          s.answer(right(s));
        }
        s.next();
        expect(s.finished, isTrue);
        expect(seen.first, isA<RoundStarted>());
        expect(seen[1], isA<HintUsed>());
        final answers = seen.whereType<AnswerGiven>().toList();
        expect(answers.length, 25);
        expect(answers.first.result.correct, isTrue);
        expect(answers.first.result.record.hint, isTrue);
        expect(answers[1].result.correct, isFalse);
        expect(answers.first.question.itemId, isNotEmpty);
        final end = seen.last as RoundEnded;
        expect(end.reward.coins, greaterThanOrEqualTo(0));
        expect(seen.whereType<RoundEnded>().length, 1);
      });

      test('a continue is reported as offered, then taken or declined', () {
        final seen = <QuizEvent>[];
        final s = newSession()
          ..begin(
            QuizRound.endless(
              factoryOf(bank),
              const EndlessMode(lives: 1),
              seedBase: 'endless:e',
            ),
          );
        s.events.listen(seen.add);
        s.answer(wrong(s));
        s.next();
        expect(seen.whereType<ContinueOffered>().length, 1);
        s.continueRound();
        expect((seen.last as ContinueResolved).taken, isTrue);
        s.answer(wrong(s));
        s.next();
        expect(seen.whereType<RoundEnded>().length, 1);
        final s2 = newSession()
          ..begin(
            QuizRound.endless(
              factoryOf(bank),
              const EndlessMode(lives: 1),
              seedBase: 'endless:f',
            ),
          );
        final seen2 = <QuizEvent>[];
        s2.events.listen(seen2.add);
        s2.answer(wrong(s2));
        s2.next();
        s2.declineContinue();
        expect(seen2.whereType<ContinueResolved>().single.taken, isFalse);
        expect(seen2.last, isA<RoundEnded>());
      });

      test('nothing is emitted for a refused action', () {
        final s = newSession(null, 5)..begin(stage());
        final seen = <QuizEvent>[];
        s.events.listen(seen.add);
        expect(s.useHint(), isFalse);
        s.next();
        expect(seen, isEmpty);
      });
    });

    test('a daily already played is refused', () {
      final s = newSession();
      final d = QuizRound.daily(
        factoryOf(bank),
        const DailyMode(),
        date: '2026-11-17',
      );
      s.begin(d);
      for (var i = 0; i < 5; i++) {
        s.answer(right(s));
        s.next();
      }
      expect(s.finished, isTrue);
      expect(
        () => s.begin(
          QuizRound.daily(
            factoryOf(bank),
            const DailyMode(),
            date: '2026-11-17',
          ),
        ),
        throwsStateError,
      );
    });

    test('opening on a corrupt save starts fresh and says why', () async {
      final kv = MemoryKeyValueStore({'quiz.progress': '{nope'});
      final s = await QuizSession.open(kv);
      expect(s.progress.coins, 60);
      expect(s.loadError, isNotNull);
    });
  });

  group('race clock (tick)', () {
    test('moves only with tick, ends at zero and books the round', () {
      final s = newSession()..begin(race());
      expect(s.round!.run.clockMs, 60000);
      s.tick(const Duration(seconds: 3));
      expect(s.round!.run.clockMs, 57000);
      s.tick(const Duration(seconds: 70));
      expect(s.finished, isTrue);
      expect(s.round!.run.clockMs, 0);
    });

    test('pause stops it and answers; resume lets it run again', () {
      final s = newSession()..begin(race());
      s.pause();
      s.tick(const Duration(seconds: 5));
      expect(s.round!.run.clockMs, 60000);
      s.answer(right(s));
      expect(s.answered, isFalse);
      s.resume();
      s.tick(const Duration(seconds: 2));
      expect(s.round!.run.clockMs, 58000);
    });

    test('the next question comes by itself after the feedback second', () {
      final s = newSession()..begin(race());
      final first = s.question!.itemId;
      s.answer(right(s));
      expect(s.answered, isTrue);
      s.tick(const Duration(milliseconds: 900));
      expect(s.answered, isTrue);
      s.tick(const Duration(milliseconds: 200));
      expect(s.answered, isFalse);
      expect(s.question!.itemId, isNot(first));
      expect(s.round!.run.clockMs, greaterThan(60000 - 2000));
    });

    test(
      'a hint is not offered in a race, and tick does nothing outside a race',
      () {
        final s = newSession()..begin(race());
        expect(s.canHint, isFalse);
        final stageSession = newSession()..begin(stage());
        stageSession.tick(const Duration(seconds: 100));
        expect(stageSession.round!.run.clockMs, isNull);
        expect(stageSession.finished, isFalse);
      },
    );
  });
}
