import 'package:test/test.dart';

import 'support.dart';

Map<String, Object?> bank(int n) => {
      'items': [
        for (var i = 0; i < n; i++)
          {'id': 'i$i', 'lines': ['w${i}a w${i}b w${i}c']},
      ],
    };

void main() {
  test('quiz.generate is deterministic and respects count', () async {
    final s = await Scratch.create();
    final a = await s.map('quiz.generate', {'json': bank(6), 'seed': 3, 'count': 4});
    final b = await s.map('quiz.generate', {'json': bank(6), 'seed': 3, 'count': 4});
    expect((a['questions'] as List).length, 4);
    expect(a['questions'], b['questions']);
    final q = (a['questions'] as List).first as Map;
    expect((q['options'] as List)[q['correctIndex'] as int], q['answer']);
  });

  test('quiz.generate skips items that cannot make a question', () async {
    final s = await Scratch.create();
    final r = await s.map('quiz.generate', {'json': bank(1)});
    expect(r['questions'], isEmpty);
    expect(r['skipped'], ['i0']);
  });

  test('quiz.generate filters by tier', () async {
    final s = await Scratch.create();
    final json = bank(5);
    (json['items']! as List)[0] = {'id': 'hard', 'lines': ['x y z'], 'tier': 2};
    final r = await s.map('quiz.generate', {'json': json, 'tier': 2, 'count': 5});
    expect((r['questions'] as List).length + (r['skipped'] as List).length, 1);
  });

  test('quiz.generate without a bank is invalid_params', () async {
    final s = await Scratch.create();
    final r = await s.call('quiz.generate', {});
    expect(r.ok, isFalse);
    expect(r.error!.code.code, 'invalid_params');
  });

  test('quiz.answer scores, carries the run forward and ends on no lives', () async {
    final s = await Scratch.create();
    final gen = await s.map('quiz.generate', {'json': bank(6), 'count': 1});
    final q = (gen['questions'] as List).first as Map;
    final wrong = ((q['correctIndex'] as int) + 1) % (q['options'] as List).length;
    var r = await s.map('quiz.answer', {'question': q, 'option': q['correctIndex']});
    expect(r['correct'], isTrue);
    expect(r['pointsDelta'], greaterThan(0));
    var run = r['run'];
    for (var i = 0; i < 3; i++) {
      r = await s.map('quiz.answer', {'question': q, 'option': wrong, 'run': run});
      run = r['run'];
    }
    expect(r['over'], isTrue);
    expect(r['livesLeft'], 0);
  });

  test('quiz.answer rejects an out-of-range option', () async {
    final s = await Scratch.create();
    final gen = await s.map('quiz.generate', {'json': bank(6), 'count': 1});
    final q = (gen['questions'] as List).first;
    final r = await s.call('quiz.answer', {'question': q, 'option': 99});
    expect(r.error!.code.code, 'invalid_params');
  });

  test('quiz.state summarizes a run and progress; needs at least one', () async {
    final s = await Scratch.create();
    final r = await s.map('quiz.state', {
      'run': {
        'rules': <String, Object?>{},
        'lives': 2,
        'score': 40,
        'streak': 3,
        'answered': 5,
        'correctCount': 4,
      },
      'progress': {'currency': 9},
    });
    expect((r['run'] as Map)['score'], 40);
    expect((r['run'] as Map)['multiplier'], closeTo(1.3, 1e-9));
    expect((r['progress'] as Map)['currency'], 9);
    expect((await s.call('quiz.state', {})).error!.code.code, 'invalid_params');
  });

  test('quiz.validate_bank flags duplicates, empty text, blank-less and small tiers', () async {
    final s = await Scratch.create();
    final json = {
      'items': [
        {'id': 'a', 'lines': ['p q r']},
        {'id': 'a', 'lines': ['s t u']},
        {'id': 'e', 'lines': <String>[]},
        {'id': 'm', 'lines': ['stop']},
      ],
      'stopWords': ['stop'],
    };
    final r = await s.map('quiz.validate_bank', {'json': json, 'minPerTier': {'2': 1}});
    final problems = (r['problems'] as List).cast<String>();
    expect(r['ok'], isFalse);
    expect(problems, contains('a: duplicate id'));
    expect(problems, contains('e: has no text'));
    expect(problems, contains('m: no blankable word'));
    expect(problems, contains('tier 2: has 0 items, needs 1'));
  });

  test('quiz.validate_bank passes a healthy bank', () async {
    final s = await Scratch.create();
    final r = await s.map('quiz.validate_bank', {'json': bank(6)});
    expect(r['ok'], isTrue);
    expect(r['items'], 6);
  });
}
