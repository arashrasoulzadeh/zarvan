import 'package:test/test.dart';
import 'package:zarvan_core/zarvan_core_quiz.dart';

/// Distinct three-letter Persian words, so no two items share a word and a
/// question never lacks wrong options.
String word(int n) {
  const letters = 'ابتثجحخدذرزسشصضطظعغفقکگلمنهی';
  final b = letters.length;
  return letters[n % b] + letters[(n ~/ b) % b] + letters[(n ~/ (b * b)) % b];
}

QuizBank makeBank({int perTier = 12, List<String> authors = const ['a', 'b']}) {
  var w = 0;
  final items = <Map<String, dynamic>>[];
  for (final a in authors) {
    for (final t in QuizTier.values) {
      for (var i = 0; i < perTier; i++) {
        items.add({
          'id': '$a-${t.name}-${i.toString().padLeft(2, '0')}',
          'author': a,
          'tier': t.name,
          'fame': 100 - i,
          'lines': ['${word(w++)} ${word(w++)}', '${word(w++)} ${word(w++)}'],
        });
      }
    }
  }
  return QuizBank.fromJson({
    'version': 1,
    'authors': [
      for (final a in authors) {'id': a, 'name': a},
    ],
    'items': items,
  });
}

QuestionFactory factoryOf(QuizBank b) => QuestionFactory(b, const {});

/// Plays [round] to its end answering by [pick] and returns the questions.
List<Question> play(
  QuizRound round,
  bool Function(Question q, int index) pick, {
  int max = 500,
}) {
  final asked = <Question>[];
  while (!round.isOver && asked.length < max) {
    final q = round.nextQuestion();
    if (q == null) break;
    asked.add(q);
    final right = pick(q, asked.length - 1);
    round.answer(right ? q.answerIndex : (q.answerIndex + 1) % 4);
  }
  return asked;
}

void main() {
  group('definitions (04.01)', () {
    test('defaults are the PRD numbers', () {
      const s = StageMode();
      expect(
        [s.questionCount, s.passAt, s.starAt],
        [
          25,
          18,
          [18, 22, 25],
        ],
      );
      const e = EndlessMode();
      expect([e.lives, e.tierStep, e.continues], [3, 10, 1]);
      const r = RaceMode();
      expect([r.durationMs, r.bonusMs, r.penaltyMs], [60000, 2000, 5000]);
      expect(const DailyMode().tiers, [
        QuizTier.easy,
        QuizTier.easy,
        QuizTier.medium,
        QuizTier.medium,
        QuizTier.hard,
      ]);
    });

    test('fromJson overrides defaults and round-trips', () {
      final m = GameMode.fromJson({
        'type': 'endless',
        'lives': 5,
        'tierStep': 4,
      });
      expect(m, isA<EndlessMode>());
      expect((m as EndlessMode).lives, 5);
      expect(m.tierStep, 4);
      expect(m.continues, 1);
      for (final j in [
        const StageMode().toJson(),
        const EndlessMode(lives: 2).toJson(),
        const RaceMode(durationMs: 30000).toJson(),
        const DailyMode().toJson(),
      ]) {
        expect(GameMode.fromJson(j).toJson(), j);
      }
    });

    test('bad JSON gives a clear FormatException', () {
      expect(
        () => GameMode.fromJson({'type': 'blitz'}),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'm',
            contains('blitz'),
          ),
        ),
      );
      expect(() => GameMode.fromJson({}), throwsFormatException);
      expect(
        () => GameMode.fromJson({'type': 'endless', 'lives': 'x'}),
        throwsFormatException,
      );
      expect(
        () => GameMode.fromJson({'type': 'stage', 'passAt': 30}),
        throwsFormatException,
      );
      expect(
        () => GameMode.fromJson({'type': 'race', 'durationMs': 0}),
        throwsFormatException,
      );
    });
  });

  group('stage (R-MODE-S)', () {
    final bank = makeBank(perTier: 30);

    test(
      'S2: the stage is the 25 most famous items of the author and tier, in order',
      () {
        final round = QuizRound.stage(
          factoryOf(bank),
          const StageMode(),
          author: 'a',
          tier: QuizTier.easy,
        );
        final ids = [for (final q in play(round, (_, _) => true)) q.itemId];
        expect(ids.length, 25);
        expect(ids, [
          for (var i = 0; i < 25; i++) 'a-easy-${i.toString().padLeft(2, '0')}',
        ]);
        expect(round.isOver, isTrue);
      },
    );

    test(
      'S3: same attempt gives the same blanks, another attempt moves some',
      () {
        List<String> run(int attempt) => [
          for (final q in play(
            QuizRound.stage(
              factoryOf(bank),
              const StageMode(),
              author: 'a',
              tier: QuizTier.easy,
              attempt: attempt,
            ),
            (_, _) => true,
          ))
            '${q.blankLine}:${q.blankToken}',
        ];
        expect(run(1), run(1));
        expect(run(1), isNot(run(2)));
      },
    );

    test('S3: the order of items does not depend on the attempt', () {
      List<String> ids(int a) => [
        for (final q in play(
          QuizRound.stage(
            factoryOf(bank),
            const StageMode(),
            author: 'b',
            tier: QuizTier.hard,
            attempt: a,
          ),
          (_, _) => true,
        ))
          q.itemId,
      ];
      expect(ids(1), ids(7));
    });

    test('S4: no lives and no clock; a wrong answer just moves on', () {
      final round = QuizRound.stage(
        factoryOf(bank),
        const StageMode(),
        author: 'a',
        tier: QuizTier.easy,
      );
      expect(round.run.lives, isNull);
      expect(round.run.clockMs, isNull);
      final asked = play(round, (_, _) => false);
      expect(asked.length, 25);
    });

    test('S5: pass mark and star boundaries', () {
      const m = StageMode();
      expect(
        [
          for (final c in [17, 18, 21, 22, 24, 25]) m.starsFor(c),
        ],
        [0, 1, 1, 2, 2, 3],
      );
      expect(
        [
          for (final c in [17, 18, 25]) m.passed(c),
        ],
        [false, true, true],
      );
    });

    test('S5: the round reports stars from its right answers', () {
      final round = QuizRound.stage(
        factoryOf(bank),
        const StageMode(),
        author: 'a',
        tier: QuizTier.easy,
      );
      play(round, (_, i) => i < 22);
      expect(round.correctCount, 22);
      expect(round.stars, 2);
      expect(round.passed, isTrue);
    });

    test('a stage with fewer items than the count ends when they run out', () {
      final small = makeBank(perTier: 10);
      final round = QuizRound.stage(
        factoryOf(small),
        const StageMode(),
        author: 'a',
        tier: QuizTier.easy,
      );
      expect(play(round, (_, _) => true).length, 10);
    });
  });

  group('endless (R-MODE-E)', () {
    test('E2: the tier steps at 10/11, 20/21 and 30/31', () {
      const m = EndlessMode();
      final tiers = {
        for (final n in [1, 10, 11, 20, 21, 30, 31, 99]) n: m.tierFor(n),
      };
      expect(tiers, {
        1: QuizTier.easy,
        10: QuizTier.easy,
        11: QuizTier.medium,
        20: QuizTier.medium,
        21: QuizTier.hard,
        30: QuizTier.hard,
        31: QuizTier.literary,
        99: QuizTier.literary,
      });
      expect(const EndlessMode(tierStep: 3).tierFor(4), QuizTier.medium);
    });

    test('E1: three lives, a wrong answer costs one, zero ends the round', () {
      final round = QuizRound.endless(
        factoryOf(makeBank()),
        const EndlessMode(),
        seedBase: 'endless:t',
      );
      expect(round.run.lives, 3);
      final asked = play(round, (_, _) => false);
      expect(asked.length, 3);
      expect(round.isOver, isTrue);
      expect(round.run.lives, 0);
    });

    test(
      'E2/E3: questions follow the tier steps and do not repeat inside a tier',
      () {
        final bank = makeBank(perTier: 6);
        final round = QuizRound.endless(
          factoryOf(bank),
          const EndlessMode(tierStep: 4),
          seedBase: 'endless:t',
        );
        final asked = play(round, (_, _) => true, max: 16);
        expect([
          for (final q in asked.take(4)) q.tier,
        ], everyElement(QuizTier.easy));
        expect([
          for (final q in asked.skip(4).take(4)) q.tier,
        ], everyElement(QuizTier.medium));
        expect([
          for (final q in asked.skip(8).take(4)) q.tier,
        ], everyElement(QuizTier.hard));
        expect([
          for (final q in asked.skip(12)) q.tier,
        ], everyElement(QuizTier.literary));
        for (final t in QuizTier.values) {
          final ids = [
            for (final q in asked.where((q) => q.tier == t)) q.itemId,
          ];
          expect(ids.toSet().length, ids.length);
        }
      },
    );

    test('E3: once a tier is used up its items may repeat', () {
      final bank = makeBank(perTier: 2, authors: ['a']);
      final round = QuizRound.endless(
        factoryOf(bank),
        const EndlessMode(tierStep: 100),
        seedBase: 'endless:t',
      );
      final asked = play(round, (_, _) => true, max: 5);
      expect(asked.length, 5);
      expect({for (final q in asked) q.itemId}.length, 2);
    });

    test('same seedBase gives the same questions, another one differs', () {
      List<String> ids(String base) => [
        for (final q in play(
          QuizRound.endless(
            factoryOf(makeBank()),
            const EndlessMode(),
            seedBase: base,
          ),
          (_, _) => true,
          max: 8,
        ))
          q.itemId,
      ];
      expect(ids('endless:1'), ids('endless:1'));
      expect(ids('endless:1'), isNot(ids('endless:2')));
    });

    test(
      'E4: one continue per round gives one life back; the second is refused',
      () {
        final round = QuizRound.endless(
          factoryOf(makeBank()),
          const EndlessMode(),
          seedBase: 'endless:t',
        );
        expect(round.continueRun(), isFalse); // still alive
        play(round, (_, _) => false);
        expect(round.isOver, isTrue);
        expect(round.continueRun(), isTrue);
        expect(round.run.lives, 1);
        expect(round.run.continueUsed, isTrue);
        expect(round.isOver, isFalse);
        play(round, (_, _) => false);
        expect(round.isOver, isTrue);
        expect(round.continueRun(), isFalse);
      },
    );
  });

  group('race (R-MODE-R)', () {
    QuizRound race() => QuizRound.race(
      factoryOf(makeBank()),
      const RaceMode(),
      seedBase: 'race:t',
    );

    test('R1: starts with 60 seconds that only tick() moves', () {
      final r = race();
      expect(r.run.clockMs, 60000);
      r.tick(const Duration(seconds: 10));
      expect(r.run.clockMs, 50000);
    });

    test('R2: right adds two seconds, wrong takes five', () {
      final r = race();
      var q = r.nextQuestion()!;
      r.answer(q.answerIndex);
      expect(r.run.clockMs, 62000);
      q = r.nextQuestion()!;
      r.answer((q.answerIndex + 1) % 4);
      expect(r.run.clockMs, 57000);
    });

    test(
      'R2: the round ends when the clock reaches zero, and nothing more is accepted',
      () {
        final r = race();
        r.tick(const Duration(seconds: 59));
        expect(r.isOver, isFalse);
        r.tick(const Duration(seconds: 1));
        expect(r.isOver, isTrue);
        expect(r.run.clockMs, 0);
        expect(r.nextQuestion(), isNull);
      },
    );

    test('R2: a wrong answer that spends the last seconds ends the round', () {
      final r = race();
      r.tick(const Duration(milliseconds: 56000));
      final q = r.nextQuestion()!;
      r.answer((q.answerIndex + 1) % 4);
      expect(r.isOver, isTrue);
      expect(r.run.clockMs, 0);
    });

    test('R3: tiers step like endless and the hint is off', () {
      final r = race();
      final q = r.nextQuestion()!;
      expect(q.tier, QuizTier.easy);
      expect(r.useHint, throwsStateError);
    });

    test('R1: score follows R-SCORE as in any mode', () {
      final r = race();
      final q = r.nextQuestion()!;
      final result = r.answer(q.answerIndex);
      expect(result.points, 10);
      expect(r.run.score, 10);
    });
  });

  group('daily (R-MODE-D)', () {
    final bank = makeBank();
    List<Map<String, dynamic>> day(String date, {QuizBank? b}) => [
      for (final q in play(
        QuizRound.daily(factoryOf(b ?? bank), const DailyMode(), date: date),
        (_, _) => true,
      ))
        q.toJson(),
    ];

    test('D1: five questions, tiers easy easy medium medium hard', () {
      final qs = play(
        QuizRound.daily(factoryOf(bank), const DailyMode(), date: '2026-11-17'),
        (_, _) => true,
      );
      expect(qs.length, 5);
      expect([for (final q in qs) q.tier], const DailyMode().tiers);
      expect({for (final q in qs) q.itemId}.length, 5);
    });

    test(
      'D2: the same date gives the same set; another date a different one',
      () {
        expect(day('2026-11-17'), day('2026-11-17'));
        expect(day('2026-11-17'), isNot(day('2026-11-18')));
      },
    );

    test('D2: the set does not depend on how many times it was built', () {
      final first = day('2026-12-01');
      day('2026-01-01');
      expect(day('2026-12-01'), first);
    });

    test('D2: a date that is not YYYY-MM-DD is an error', () {
      for (final bad in ['2026-1-5', '17/11/2026', '', '2026-13-40']) {
        expect(
          () => QuizRound.daily(factoryOf(bank), const DailyMode(), date: bad),
          throwsArgumentError,
          reason: bad,
        );
      }
    });

    test('D4: the result string is one mark per question', () {
      final round = QuizRound.daily(
        factoryOf(bank),
        const DailyMode(),
        date: '2026-11-17',
      );
      play(round, (_, i) => i != 2 && i != 4);
      expect(round.results, [true, true, false, true, false]);
      expect(round.resultString, '✅✅❌✅❌');
      expect(round.correctCount, 3);
    });

    test('D4: the share text before the end only shows what was answered', () {
      final round = QuizRound.daily(
        factoryOf(bank),
        const DailyMode(),
        date: '2026-11-17',
      );
      final q = round.nextQuestion()!;
      round.answer(q.answerIndex);
      expect(round.resultString, '✅');
    });
  });
}
