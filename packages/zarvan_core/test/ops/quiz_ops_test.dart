import 'dart:convert';

import 'package:test/test.dart';
import 'package:zarvan_core/zarvan_core_ops.dart';
import 'package:zarvan_core/zarvan_core_quiz.dart';

import '../quiz/support.dart';
import 'support.dart';

final bank = makeBank(perTier: 30);
Map<String, Object?> bankJson() => bank.toJson();

Map<String, Object?> asMap(Object? o) => (o! as Map).cast<String, Object?>();

void main() {
  group('quiz.validate_bank (R-VAL)', () {
    test('a healthy bank is ok with stats and no errors', () async {
      final s = await Scratch.create();
      final r = await s.map('quiz.validate_bank', {'json': bankJson()});
      expect(r['ok'], isTrue);
      expect(r['errors'], isEmpty);
      expect(asMap(asMap(asMap(r['stats'])['byAuthorTier'])['a'])['easy'], 30);
      expect(asMap(r['stats'])['items'], 240);
    });

    test(
      'R-VAL-1: duplicate id, empty lines and an invalid tier are errors',
      () async {
        final s = await Scratch.create();
        final json = bankJson();
        final items = [
          for (final i in (json['items']! as List)) {...(i as Map)},
        ];
        items[1] = {...items[1], 'id': items[0]['id']};
        items[2] = {...items[2], 'lines': <String>[]};
        items[3] = {...items[3], 'tier': 'legendary'};
        json['items'] = items;
        final r = await s.map('quiz.validate_bank', {'json': json});
        final errors = (r['errors'] as List).cast<String>().join('\n');
        expect(r['ok'], isFalse);
        expect(errors, contains('duplicate id'));
        expect(errors, contains('empty lines'));
        expect(errors, contains('legendary'));
      },
    );

    test('R-VAL-1: an unsupported version is one error', () async {
      final s = await Scratch.create();
      final r = await s.map('quiz.validate_bank', {
        'json': {...bankJson(), 'version': 2},
      });
      expect(r['ok'], isFalse);
      expect((r['errors'] as List).single, contains('version 2'));
    });

    test('R-VAL-2: an item with no content word is an error', () async {
      final s = await Scratch.create();
      final json = bankJson();
      final items = (json['items']! as List).cast<Map>();
      final only = (items[0]['lines'] as List).join(' ').split(' ');
      final r = await s.map('quiz.validate_bank', {
        'json': json,
        'stopWords': only,
      });
      expect(
        (r['errors'] as List).cast<String>().any(
          (e) => e.startsWith('${items[0]['id']}: no content word'),
        ),
        isTrue,
      );
    });

    test(
      'R-VAL-3: wrong options that need the any-word fallback are warned',
      () async {
        final s = await Scratch.create();
        final tiny = {
          'version': 1,
          'authors': [
            {'id': 'a', 'name': 'A'},
          ],
          'items': [
            {
              'id': 'x',
              'author': 'a',
              'tier': 'hard',
              'fame': 1,
              'lines': ['سلامت حکمتی'],
            },
            {
              'id': 'y',
              'author': 'a',
              'tier': 'hard',
              'fame': 1,
              'lines': ['دل گل مه'],
            },
          ],
        };
        final r = await s.map('quiz.validate_bank', {'json': tiny});
        expect(r['ok'], isTrue);
        expect(
          (r['warnings'] as List).cast<String>().any(
            (w) => w.startsWith('x: '),
          ),
          isTrue,
        );
      },
    );

    test(
      'R-VAL-4: fewer items than a stage needs is a warning per author and tier',
      () async {
        final s = await Scratch.create();
        final r = await s.map('quiz.validate_bank', {
          'json': makeBank(perTier: 10, authors: ['a']).toJson(),
        });
        final w = (r['warnings'] as List).cast<String>();
        expect(w, contains('a/easy: 10 items, a stage needs 25'));
        expect(r['ok'], isTrue);
      },
    );

    test('reads the bank and stop words from project files', () async {
      final s = await Scratch.create();
      s.write('assets/quiz/bank.json', jsonEncode(bankJson()));
      s.write(
        'assets/quiz/stopwords.json',
        jsonEncode({
          'version': 1,
          'words': ['از'],
        }),
      );
      final r = await s.map('quiz.validate_bank', {
        'bank': 'assets/quiz/bank.json',
        'stopwords': 'assets/quiz/stopwords.json',
      });
      expect(r['ok'], isTrue);
      expect(
        await s.failure('quiz.validate_bank', {
          'bank': 'assets/quiz/missing.json',
        }),
        ErrorCode.notFound,
      );
      expect(
        await s.failure('quiz.validate_bank', {}),
        ErrorCode.invalidParams,
      );
    });
  });

  group('quiz.generate', () {
    test('equals QuestionFactory for the same arguments', () async {
      final s = await Scratch.create();
      final id = bank.items(author: 'a', tier: QuizTier.hard).first.id;
      final r = await s.map('quiz.generate', {
        'json': bankJson(),
        'itemId': id,
        'tier': 'hard',
        'seed': 42,
      });
      final direct = QuestionFactory(
        bank,
        const {},
      ).create(id, QuizTier.hard, 42)!;
      expect(jsonEncode(r), jsonEncode(direct.toJson()));
    });

    test(
      'tier defaults to the item tier; unknown item is notFound; missing item is invalidParams',
      () async {
        final s = await Scratch.create();
        final id = bank.items(author: 'b', tier: QuizTier.medium).first.id;
        expect(
          (await s.map('quiz.generate', {
            'json': bankJson(),
            'itemId': id,
          }))['tier'],
          'medium',
        );
        expect(
          await s.failure('quiz.generate', {
            'json': bankJson(),
            'itemId': 'nope',
          }),
          ErrorCode.notFound,
        );
        expect(
          await s.failure('quiz.generate', {'json': bankJson()}),
          ErrorCode.invalidParams,
        );
        expect(
          await s.failure('quiz.generate', {'itemId': id}),
          ErrorCode.invalidParams,
        );
      },
    );

    test('an item that cannot make a question is validationFailed', () async {
      final s = await Scratch.create();
      final id = bank.items(author: 'a', tier: QuizTier.easy).first.id;
      final words = bank.byId(id)!.lines.join(' ').split(' ');
      expect(
        await s.failure('quiz.generate', {
          'json': bankJson(),
          'itemId': id,
          'stopWords': words,
        }),
        ErrorCode.validationFailed,
      );
    });
  });

  group('quiz.start / answer / state', () {
    test(
      'a whole stage played only through operations equals playing QuizRound directly',
      () async {
        final s = await Scratch.create();
        final args = {
          'json': bankJson(),
          'mode': 'stage',
          'author': 'a',
          'tier': 'easy',
        };
        var out = await s.map('quiz.start', args);
        var run = asMap(out['run']);
        final picks = <int>[];
        while (asMap(out['summary'])['over'] != true) {
          final q = Question.fromJson(asMap(run['current']));
          final choice = picks.length % 5 == 4
              ? (q.answerIndex + 1) % 4
              : q.answerIndex;
          picks.add(choice);
          out = await s.map('quiz.answer', {
            'json': bankJson(),
            'mode': 'stage',
            'run': run,
            'choice': choice,
          });
          run = asMap(out['run']);
        }
        final round = QuizRound.stage(
          QuestionFactory(bank, const {}),
          const StageMode(),
          author: 'a',
          tier: QuizTier.easy,
        );
        for (final c in picks) {
          round.nextQuestion();
          round.answer(c);
        }
        expect(picks.length, 25);
        expect(jsonEncode(run), jsonEncode(round.run.toJson()));
        final state = await s.map('quiz.state', {
          'json': bankJson(),
          'mode': 'stage',
          'run': run,
        });
        expect(state['over'], isTrue);
        expect(state['correct'], round.correctCount);
        expect(state['stars'], round.stars);
      },
    );

    test(
      'hint is applied once, halves the points and hides two options',
      () async {
        final s = await Scratch.create();
        final args = {
          'json': bankJson(),
          'mode': 'stage',
          'author': 'a',
          'tier': 'easy',
        };
        final out = await s.map('quiz.start', args);
        final run = asMap(out['run']);
        final q = Question.fromJson(asMap(run['current']));
        final r = await s.map('quiz.answer', {
          'json': args['json'],
          'mode': 'stage',
          'run': run,
          'choice': q.answerIndex,
          'hint': true,
        });
        expect(asMap(r['result'])['points'], 5);
        final answers = (asMap(r['run'])['answers'] as List).cast<Map>();
        expect(answers.single['hint'], isTrue);
      },
    );

    test(
      'errors: removed option, out of range, answering a finished round, wrong mode, bad date',
      () async {
        final s = await Scratch.create();
        final args = {
          'json': bankJson(),
          'mode': {'type': 'endless', 'lives': 1},
          'seedBase': 'endless:t',
        };
        var out = await s.map('quiz.start', args);
        final run = asMap(out['run']);
        final q = Question.fromJson(asMap(run['current']));
        expect(
          await s.failure('quiz.answer', {
            'json': bankJson(),
            'mode': args['mode'],
            'run': run,
            'choice': 9,
          }),
          ErrorCode.invalidParams,
        );
        out = await s.map('quiz.answer', {
          'json': bankJson(),
          'mode': args['mode'],
          'run': run,
          'choice': (q.answerIndex + 1) % 4,
        });
        expect(asMap(out['summary'])['over'], isTrue);
        expect(
          await s.failure('quiz.answer', {
            'json': bankJson(),
            'mode': args['mode'],
            'run': out['run'],
            'choice': 0,
          }),
          ErrorCode.conflict,
        );
        expect(
          await s.failure('quiz.state', {
            'json': bankJson(),
            'mode': 'stage',
            'run': out['run'],
          }),
          ErrorCode.validationFailed,
        );
        expect(
          await s.failure('quiz.start', {
            'json': bankJson(),
            'mode': 'daily',
            'date': '2026-13-40',
          }),
          ErrorCode.invalidParams,
        );
        expect(
          await s.failure('quiz.start', {'json': bankJson(), 'mode': 'daily'}),
          ErrorCode.invalidParams,
        );
        expect(
          await s.failure('quiz.start', {'json': bankJson(), 'mode': 'blitz'}),
          ErrorCode.invalidParams,
        );
      },
    );

    test('daily start is deterministic from the date alone', () async {
      final s = await Scratch.create();
      Future<String> day(String d) async => jsonEncode(
        (await s.map('quiz.start', {
          'json': bankJson(),
          'mode': 'daily',
          'date': d,
        }))['run'],
      );
      expect(await day('2026-11-17'), await day('2026-11-17'));
      expect(await day('2026-11-17'), isNot(await day('2026-11-18')));
    });
  });

  group('quiz.simulate', () {
    Future<Map<String, Object?>> sim(
      Scratch s,
      String policy, {
      int runs = 80,
    }) => s.map('quiz.simulate', {
      'json': bankJson(),
      'mode': 'stage',
      'author': 'a',
      'tier': 'easy',
      'policy': policy,
      'runs': runs,
    });

    test('always_correct earns three stars every time', () async {
      final r = await sim(await Scratch.create(), 'always_correct', runs: 20);
      expect(r['stars'], [0, 0, 0, 20]);
      expect(r['passRate'], 1.0);
      expect(r['correctRate'], 1.0);
    });

    test(
      'random answers land near a quarter right over 2000 questions',
      () async {
        final r = await sim(await Scratch.create(), 'random');
        expect(r['questions'], 2000);
        expect(r['correctRate'] as double, closeTo(0.25, 0.05));
        expect(r['passRate'], 0.0);
      },
    );

    test(
      'accuracy:p lands near p and the report repeats for the same inputs',
      () async {
        final s = await Scratch.create();
        final a = await sim(s, 'accuracy:0.7');
        expect(a['correctRate'] as double, closeTo(0.7, 0.05));
        expect(jsonEncode(await sim(s, 'accuracy:0.7')), jsonEncode(a));
      },
    );

    test(
      'bad policy is invalidParams; endless and race simulate to the end',
      () async {
        final s = await Scratch.create();
        expect(
          await s.failure('quiz.simulate', {
            'json': bankJson(),
            'mode': 'stage',
            'policy': 'lucky',
          }),
          ErrorCode.invalidParams,
        );
        expect(
          await s.failure('quiz.simulate', {
            'json': bankJson(),
            'mode': 'stage',
            'policy': 'accuracy:2',
          }),
          ErrorCode.invalidParams,
        );
        final e = await s.map('quiz.simulate', {
          'json': bankJson(),
          'mode': 'endless',
          'policy': 'accuracy:0.5',
          'runs': 20,
        });
        expect(e['avgQuestions'] as double, greaterThan(3));
        final r = await s.map('quiz.simulate', {
          'json': bankJson(),
          'mode': 'race',
          'policy': 'accuracy:0.5',
          'runs': 10,
        });
        expect(r['avgScore'] as double, greaterThanOrEqualTo(0));
        final d = await s.map('quiz.simulate', {
          'json': bankJson(),
          'mode': 'daily',
          'date': '2026-11-17',
          'runs': 5,
        });
        expect(d['questions'], 25);
      },
    );
  });
}
