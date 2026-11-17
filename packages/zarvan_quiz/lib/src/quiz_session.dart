import 'package:zarvan_core/zarvan_core.dart' show KeyValueStore;
import 'package:zarvan_core/zarvan_core_quiz.dart';

import 'quiz_controller.dart';

/// Owns the saved [QuizProgress] and books finished runs into it.
class QuizSession {
  QuizSession._(this.store, this.progress, this.key);

  final KeyValueStore store;
  final QuizProgress progress;
  final String key;

  /// Loads the saved progress (fresh if none, corrupt copy kept aside).
  static Future<QuizSession> open(KeyValueStore store, {String key = 'quiz_progress'}) async =>
      QuizSession._(store, await QuizProgress.load(store, key: key), key);

  /// Coins earned per this many score points when a run is booked.
  static const scorePerCoin = 10;

  /// Books a finished [c] into [progress] and saves. Staged runs record
  /// stars and unlocks for [stageId]; other modes update the mode record.
  /// Returns the currency earned. Does nothing for a run still in play.
  Future<int> finishRun(QuizController c, {String? stageId, String? nextStageId}) async {
    if (!c.finished) return 0;
    if (c.mode.kind == QuizModeKind.staged && stageId != null) {
      progress.completeStage(
        stageId: stageId,
        mode: c.mode,
        correct: c.run.correctCount,
        score: c.run.score,
        nextStageId: nextStageId,
      );
    } else {
      progress.recordScore(c.mode.kind, c.run.score);
    }
    final coins = c.run.score ~/ scorePerCoin;
    progress.earn(coins);
    await progress.save(store, key: key);
    return coins;
  }
}
