import 'package:test/test.dart';
import 'package:zarvan_core/zarvan_core.dart' show MemoryKeyValueStore;
import 'package:zarvan_core/zarvan_core_quiz.dart';

const staged = QuizMode(kind: QuizModeKind.staged, questionCount: 10);

void main() {
  test('stars and best score never decrease on a worse replay', () {
    final p = QuizProgress();
    p.completeStage(stageId: 's1', mode: staged, correct: 10, score: 200);
    final earned = p.completeStage(stageId: 's1', mode: staged, correct: 6, score: 90);
    expect(earned, 1);
    expect(p.starsOf('s1'), 3);
    expect(p.stages['s1']!.bestScore, 200);
    expect(p.stages['s1']!.plays, 2);
    expect(p.totalStars, 3);
  });

  test('next stage unlocks only past the threshold', () {
    final p = QuizProgress();
    p.completeStage(stageId: 's1', mode: staged, correct: 5, score: 1, nextStageId: 's2');
    expect(p.isUnlocked('s2'), isFalse);
    p.completeStage(stageId: 's1', mode: staged, correct: 6, score: 1, nextStageId: 's2');
    expect(p.isUnlocked('s2'), isTrue);
  });

  test('records only update on a higher score', () {
    final p = QuizProgress();
    expect(p.recordScore(QuizModeKind.endless, 50), isTrue);
    expect(p.recordScore(QuizModeKind.endless, 50), isFalse);
    expect(p.recordScore(QuizModeKind.endless, 40), isFalse);
    expect(p.records['endless'], 50);
  });

  test('currency: spend refuses when short and rejects negatives', () {
    final p = QuizProgress()..earn(10);
    expect(p.spend(11), isFalse);
    expect(p.currency, 10);
    expect(p.spend(4), isTrue);
    expect(p.currency, 6);
    expect(() => p.earn(-1), throwsArgumentError);
    expect(() => p.spend(-1), throwsArgumentError);
  });

  test('save then load restores everything', () async {
    final store = MemoryKeyValueStore();
    final p = QuizProgress()
      ..earn(7)
      ..recordScore(QuizModeKind.timedRace, 33);
    p.completeStage(stageId: 's1', mode: staged, correct: 8, score: 70, nextStageId: 's2');
    await p.save(store);
    final back = await QuizProgress.load(store);
    expect(back.toJson(), p.toJson());
  });

  test('missing save gives fresh progress; corrupt save is kept aside', () async {
    final store = MemoryKeyValueStore();
    expect((await QuizProgress.load(store)).totalStars, 0);
    store.values['quiz_progress'] = '{not json';
    final p = await QuizProgress.load(store);
    expect(p.currency, 0);
    expect(store.values['quiz_progress.corrupt'], '{not json');
  });
}
