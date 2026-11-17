import 'dart:convert';

import 'package:test/test.dart';
import 'package:zarvan_core/zarvan_core_quiz.dart';

Question q(
  String id, {
  QuizTier tier = QuizTier.easy,
  int answer = 2,
  List<int> removed = const [],
}) => Question(
  itemId: id,
  tier: tier,
  seed: 1,
  lines: [
    [const Token('الف'), const Token('＿＿＿')],
  ],
  blankLine: 0,
  blankToken: 1,
  options: const ['a', 'b', 'c', 'd'],
  answerIndex: answer,
  removedByHint: removed,
);

QuizRun start({int? lives, int? clockMs}) => QuizRun.start(
  mode: 'endless',
  seedBase: 'endless:x',
  lives: lives,
  clockMs: clockMs,
);

void main() {
  test('a right answer scores by tier, extends the streak and records it', () {
    final run = start(lives: 3).withQuestion(q('a', tier: QuizTier.medium));
    final (next, result) = run.answer(2);
    expect(result.correct, isTrue);
    expect(result.points, 20);
    expect(next.score, 20);
    expect(next.streak, 1);
    expect(next.lives, 3);
    expect(next.current, isNull);
    expect(next.answers.single.itemId, 'a');
    expect(next.answers.single.chosen, 2);
    expect(next.answers.single.points, 20);
    expect(next.index, 1);
  });

  test('R-SCORE-2: the streak multiplier applies from the fifth in a row', () {
    var run = start();
    var last = 0;
    for (var i = 0; i < 5; i++) {
      run = run.withQuestion(q('q$i'));
      final (n, r) = run.answer(2);
      run = n;
      last = r.points;
    }
    expect(run.streak, 5);
    expect(last, 15);
    expect(run.score, 10 + 10 + 10 + 10 + 15);
  });

  test(
    'R-SCORE-4: a wrong answer scores nothing, resets the streak, costs a life',
    () {
      var run = start(lives: 3);
      run = run.answer0(q('a'), 2);
      run = run.answer0(q('b'), 2);
      final (next, result) = run.withQuestion(q('c')).answer(0);
      expect(result.correct, isFalse);
      expect(result.points, 0);
      expect(next.streak, 0);
      expect(next.score, 20);
      expect(next.lives, 2);
      expect(result.livesLeft, 2);
      expect(result.over, isFalse);
    },
  );

  test(
    'without lives a wrong answer changes nothing else; with 1 life it ends the run',
    () {
      final (a, ra) = start().withQuestion(q('a')).answer(0);
      expect(a.lives, isNull);
      expect(ra.over, isFalse);
      final (b, rb) = start(lives: 1).withQuestion(q('a')).answer(0);
      expect(b.lives, 0);
      expect(rb.over, isTrue);
    },
  );

  test('a hint halves the points and is read from the question', () {
    final hinted = q('a', removed: const [0, 1]);
    final (next, result) = start().withQuestion(hinted).answer(2);
    expect(result.points, 5);
    expect(next.answers.single.hint, isTrue);
  });

  test(
    'an option the hint removed cannot be chosen; out-of-range is an error',
    () {
      final run = start().withQuestion(q('a', removed: const [0, 1]));
      expect(() => run.answer(0), throwsArgumentError);
      expect(() => run.answer(4), throwsArgumentError);
      expect(() => run.answer(-1), throwsArgumentError);
    },
  );

  test('R-SCORE-5: useHint removes two wrong options once per question', () {
    final run = start().withQuestion(q('a'));
    final hinted = run.useHint();
    expect(hinted.current!.removedByHint.length, 2);
    expect(hinted.current!.removedByHint, isNot(contains(2)));
    expect(hinted.useHint, throwsStateError);
  });

  test('answering twice, or with no question, is a StateError', () {
    final (next, _) = start().withQuestion(q('a')).answer(2);
    expect(() => next.answer(2), throwsStateError);
    expect(() => start().answer(0), throwsStateError);
    expect(() => start().useHint(), throwsStateError);
  });

  test('withQuestion remembers used items without repeats', () {
    var run = start().withQuestion(q('a'));
    run = run.answer(2).$1.withQuestion(q('b'));
    run = run.answer(2).$1.withQuestion(q('a'));
    expect(run.usedItemIds, ['a', 'b']);
  });

  test('the run is immutable: answering leaves the old run as it was', () {
    final run = start(lives: 2).withQuestion(q('a'));
    run.answer(0);
    expect(run.score, 0);
    expect(run.lives, 2);
    expect(run.current, isNotNull);
    expect(run.answers, isEmpty);
  });

  test(
    'data-format §5: JSON round trip, race clock, current question, answers',
    () {
      var run = start(lives: 3, clockMs: 60000).withQuestion(q('a'));
      run = run
          .answer(2)
          .$1
          .withQuestion(q('b', tier: QuizTier.hard, removed: const [0, 3]));
      final json = jsonDecode(jsonEncode(run.toJson())) as Map<String, dynamic>;
      expect(json['version'], 1);
      expect(json['mode'], 'endless');
      expect(json['seedBase'], 'endless:x');
      expect(json['clockMs'], 60000);
      expect(json['usedItemIds'], ['a', 'b']);
      expect((json['answers'] as List).single, {
        'itemId': 'a',
        'tier': 'easy',
        'chosen': 2,
        'correct': true,
        'hint': false,
        'points': 10,
      });
      final back = QuizRun.fromJson(json);
      expect(jsonEncode(back.toJson()), jsonEncode(run.toJson()));
      expect(back.current!.itemId, 'b');
    },
  );

  test('clockMs is null outside race mode and stays null in JSON', () {
    final json = start().toJson();
    expect(json['clockMs'], isNull);
    expect(json['lives'], isNull);
    expect(QuizRun.fromJson(json).clockMs, isNull);
  });

  test('a run saved with an unknown version is a FormatException', () {
    final json = {...start().toJson(), 'version': 9};
    expect(() => QuizRun.fromJson(json), throwsFormatException);
  });
}

extension on QuizRun {
  /// Shortcut for tests: ask [question] and answer option [choice].
  QuizRun answer0(Question question, int choice) =>
      withQuestion(question).answer(choice).$1;
}
