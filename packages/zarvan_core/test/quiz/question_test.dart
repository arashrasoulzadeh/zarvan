import 'dart:convert';

import 'package:test/test.dart';
import 'package:zarvan_core/zarvan_core_quiz.dart';

QuizBank bank() => QuizBank.fromJson({
  'version': 1,
  'authors': [
    {'id': 'a', 'name': 'A'},
  ],
  'items': [
    {
      'id': 'a1',
      'author': 'a',
      'tier': 'easy',
      'fame': 5,
      'lines': ['الا یا ایها الساقی', 'که عشق آسان نمود'],
    },
    {
      'id': 'a2',
      'author': 'a',
      'tier': 'medium',
      'fame': 4,
      'lines': ['سلامت حکمتی نسب', 'رحیم بلند کتابخانه'],
    },
    {
      'id': 'a3',
      'author': 'a',
      'tier': 'hard',
      'fame': 3,
      'lines': ['نشق فشق خشق', 'سلم حکم نسب'],
    },
    {
      'id': 'stop',
      'author': 'a',
      'tier': 'easy',
      'fame': 1,
      'lines': ['از به'],
    },
  ],
});

QuestionFactory factory() => QuestionFactory(bank(), const {'از', 'به', 'که'});

void main() {
  test('R-Q-1: the same input gives the same question', () {
    final a = factory().create('a1', QuizTier.easy, 99)!;
    final b = factory().create('a1', QuizTier.easy, 99)!;
    expect(jsonEncode(a.toJson()), jsonEncode(b.toJson()));
    final c = factory().create('a1', QuizTier.easy, 100)!;
    expect(c.seed, 100);
  });

  test(
    'R-Q-2: four options, the answer at answerIndex, hidden in the lines',
    () {
      for (final tier in QuizTier.values) {
        for (var seed = 0; seed < 10; seed++) {
          final q = factory().create('a3', tier, seed)!;
          expect(q.options.length, 4);
          expect(q.options.toSet().length, 4);
          final answer = q.options[q.answerIndex];
          final shown = q.render().join(' ');
          expect(shown, contains('＿＿＿'));
          expect(q.lines[q.blankLine][q.blankToken].text, '＿＿＿');
          expect(q.itemId, 'a3');
          expect(q.tier, tier);
          expect(answer.isNotEmpty, isTrue);
        }
      }
    },
  );

  test('R-Q-2: punctuation around the blanked word stays around the gap', () {
    final b = QuizBank.fromJson({
      'version': 1,
      'authors': [
        {'id': 'a', 'name': 'A'},
      ],
      'items': [
        {
          'id': 'm',
          'author': 'a',
          'tier': 'hard',
          'fame': 1,
          'lines': ['«سلام» جهان'],
        },
        {
          'id': 'o',
          'author': 'a',
          'tier': 'hard',
          'fame': 1,
          'lines': ['نسب رحم بحر کلم'],
        },
      ],
    });
    final f = QuestionFactory(b, const {});
    for (var s = 0; s < 20; s++) {
      final q = f.create('m', QuizTier.hard, s)!;
      final t = q.lines[0][q.blankToken];
      if (q.blankToken == 0) {
        expect([t.pre, t.post], ['«', '»']);
      } else {
        expect([t.pre, t.post], ['', '']);
      }
      expect(q.options[q.answerIndex], q.blankToken == 0 ? 'سلام' : 'جهان');
    }
  });

  test('R-Q-3: toJson/fromJson round trips without change', () {
    final q = factory().create('a2', QuizTier.medium, 7)!;
    final json = jsonDecode(jsonEncode(q.toJson())) as Map<String, dynamic>;
    expect(Question.fromJson(json).toJson(), q.toJson());
    expect(json['tier'], 'medium');
    expect(json['blank'], {'line': q.blankLine, 'token': q.blankToken});
    expect(json['removedByHint'], isEmpty);
  });

  test('R-Q-4: the hint removes two wrong options, deterministically', () {
    final q = factory().create('a2', QuizTier.medium, 7)!;
    final h = q.applyHint();
    expect(h.removedByHint.length, 2);
    expect(h.removedByHint.toSet().length, 2);
    expect(h.removedByHint, isNot(contains(q.answerIndex)));
    expect(h.answerIndex, q.answerIndex);
    expect(h.options, q.options);
    expect(q.removedByHint, isEmpty);
    expect(q.applyHint().removedByHint, h.removedByHint);
  });

  test('R-SCORE-5: a second hint on the same question is an error', () {
    final h = factory().create('a2', QuizTier.medium, 7)!.applyHint();
    expect(h.applyHint, throwsStateError);
  });

  test('a hinted question survives JSON', () {
    final h = factory().create('a2', QuizTier.medium, 3)!.applyHint();
    expect(Question.fromJson(h.toJson()).removedByHint, h.removedByHint);
  });

  test('an item with no usable word gives null; an unknown id is an error', () {
    expect(factory().create('stop', QuizTier.easy, 1), isNull);
    expect(
      () => factory().create('missing', QuizTier.easy, 1),
      throwsArgumentError,
    );
  });

  test(
    'a bank too small for three wrong options is a StateError, not a short question',
    () {
      final small = QuizBank.fromJson({
        'version': 1,
        'authors': [
          {'id': 'a', 'name': 'A'},
        ],
        'items': [
          {
            'id': 'x',
            'author': 'a',
            'tier': 'easy',
            'fame': 1,
            'lines': ['سلامت حکمتی'],
          },
        ],
      });
      expect(
        () => QuestionFactory(small, const {}).create('x', QuizTier.easy, 1),
        throwsStateError,
      );
    },
  );
}
