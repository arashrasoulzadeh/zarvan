import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zarvan_core/zarvan_core.dart' show MemoryKeyValueStore;
import 'package:zarvan_quiz/zarvan_quiz.dart';

List<QuizItem> bank() => [
      for (var i = 0; i < 8; i++) QuizItem(id: 'i$i', lines: ['w${i}a w${i}b w${i}c']),
    ];

QuizController make({
  QuizMode mode = const QuizMode(kind: QuizModeKind.staged, questionCount: 2),
  int lives = 3,
  int seed = 1,
}) =>
    QuizController(
      generator: QuizGenerator(bank: bank(), seed: seed),
      mode: mode,
      run: QuizRun(rules: const ScoreRules(), lives: lives),
      seed: seed,
    );

void right(QuizController c) => c.answer(c.question!.correctIndex);
void wrong(QuizController c) =>
    c.answer((c.question!.correctIndex + 1) % c.question!.options.length);

void main() {
  test('staged run finishes after questionCount and scores correct answers', () {
    final c = make();
    right(c);
    expect(c.run.score, greaterThan(0));
    c.next();
    expect(c.finished, isFalse);
    right(c);
    c.next();
    expect(c.finished, isTrue);
    expect(c.question, isNull);
    expect(c.run.correctCount, 2);
  });

  test('answers are ignored once answered; next needs an answer', () {
    final c = make();
    c.next();
    expect(c.index, 0);
    right(c);
    final score = c.run.score;
    right(c);
    expect(c.run.score, score);
  });

  test('hint hides two wrong options, answering a hidden one does nothing', () {
    final c = make();
    c.hint();
    expect(c.hidden.length, 2);
    expect(c.hidden.contains(c.question!.correctIndex), isFalse);
    c.answer(c.hidden.first);
    expect(c.answeredCurrent, isFalse);
  });

  test('running out of lives ends the run', () {
    final c = make(lives: 1, mode: const QuizMode(kind: QuizModeKind.staged, questionCount: 5));
    wrong(c);
    c.next();
    expect(c.finished, isTrue);
  });

  test('timed race ends when the clock runs out and ignores ticks otherwise', () {
    final c = make(mode: const QuizMode(kind: QuizModeKind.timedRace, durationSeconds: 10));
    c.tick(4);
    expect(c.secondsLeft, 6);
    c.tick(99);
    expect(c.secondsLeft, 0);
    expect(c.finished, isTrue);
    final s = make();
    s.tick(5);
    expect(s.secondsLeft, 0);
    expect(s.finished, isFalse);
  });

  test('endless mode offers one continue after losing', () {
    final c = make(lives: 1, mode: const QuizMode(kind: QuizModeKind.endless));
    wrong(c);
    c.next();
    expect(c.canContinue, isTrue);
    expect(c.continueRun(), isTrue);
    expect(c.finished, isFalse);
    expect(c.run.lives, 1);
    wrong(c);
    c.next();
    expect(c.canContinue, isFalse);
    expect(c.continueRun(), isFalse);
  });

  test('a tier with no usable items finishes instead of looping', () {
    final c = make(mode: const QuizMode(kind: QuizModeKind.staged, startTier: 3));
    expect(c.finished, isTrue);
  });

  test('session books staged stars, unlock and coins, and persists', () async {
    final store = MemoryKeyValueStore();
    final session = await QuizSession.open(store);
    final c = make();
    expect(await session.finishRun(c, stageId: 's1'), 0);
    right(c);
    c.next();
    right(c);
    c.next();
    final coins = await session.finishRun(c, stageId: 's1', nextStageId: 's2');
    expect(coins, c.run.score ~/ QuizSession.scorePerCoin);
    expect(session.progress.starsOf('s1'), 3);
    expect(session.progress.isUnlocked('s2'), isTrue);
    final reopened = await QuizSession.open(store);
    expect(reopened.progress.toJson(), session.progress.toJson());
  });

  test('session records a mode high score outside staged mode', () async {
    final session = await QuizSession.open(MemoryKeyValueStore());
    final c = make(mode: const QuizMode(kind: QuizModeKind.timedRace, durationSeconds: 5));
    right(c);
    c.next();
    c.tick(5);
    await session.finishRun(c);
    expect(session.progress.records['timedRace'], c.run.score);
  });

  testWidgets('options answer, show feedback and the card shows the blank', (t) async {
    final c = make();
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListView(children: [
          QuizHud(controller: c, currency: 5),
          QuestionCard(question: c.question!, textDirection: TextDirection.rtl),
          OptionButtons(controller: c),
        ]),
      ),
    ));
    expect(find.textContaining(QuizQuestion.blankMarker), findsOneWidget);
    expect(find.byKey(const ValueKey('hud_currency')), findsOneWidget);
    expect(find.byKey(const ValueKey('hud_time')), findsNothing);
    final card = tester(t);
    expect(card, TextDirection.rtl);

    final correct = c.question!.correctIndex;
    await t.tap(find.byKey(ValueKey('option_$correct')));
    await t.pump();
    expect(c.run.correctCount, 1);
    expect(find.text('Score ${c.run.score}'), findsOneWidget);
    final btn = t.widget<FilledButton>(find.byKey(ValueKey('option_$correct')));
    expect(btn.onPressed, isNull);
  });

  testWidgets('hidden options disappear after a hint; timed HUD shows the clock', (t) async {
    final c = make(mode: const QuizMode(kind: QuizModeKind.timedRace, durationSeconds: 30));
    await t.pumpWidget(MaterialApp(
      home: Scaffold(body: Column(children: [QuizHud(controller: c), OptionButtons(controller: c)])),
    ));
    expect(find.text('Time 30'), findsOneWidget);
    expect(find.byType(FilledButton), findsNWidgets(4));
    c.hint();
    await t.pump();
    expect(find.byType(FilledButton), findsNWidgets(2));
  });
}

TextDirection tester(WidgetTester t) {
  final ctx = t.element(find.byType(Card));
  return Directionality.of(ctx);
}
