import 'package:flutter/foundation.dart';
import 'package:zarvan_core/zarvan_core_quiz.dart';
import 'package:zarvan_core/zarvan_core.dart' show DeterministicRandom;

/// Drives one play-through of a [QuizMode]: serves questions from a
/// [QuizGenerator], applies answers to a [SimpleQuizRun], and notifies widgets.
/// No timers inside: the host calls [tick], so tests and replays stay
/// deterministic.
class QuizController extends ChangeNotifier {
  QuizController({
    required this.generator,
    required this.mode,
    required this.run,
    int? seed,
  }) : _random = DeterministicRandom((seed ?? 1) + 7919),
       secondsLeft = mode.kind == QuizModeKind.timedRace ? mode.durationSeconds : 0 {
    _next();
  }

  final QuizGenerator generator;
  final QuizMode mode;
  final SimpleQuizRun run;
  final DeterministicRandom _random;

  /// Countdown for [QuizModeKind.timedRace]; unused (0) otherwise.
  int secondsLeft;

  /// The question on screen, or null once the run is finished.
  QuizQuestion? question;

  /// Zero-based number of the question on screen.
  int index = 0;

  /// Option indexes a hint removed from the current question.
  Set<int> hidden = {};

  /// Option the player picked on the current question, until [next].
  int? picked;

  /// Outcome of the last answer, until [next].
  SimpleAnswerResult? lastResult;

  int _continuesUsed = 0;
  bool _finished = false;

  /// Whether the run has ended (out of lives, out of questions or time).
  bool get finished => _finished;

  /// Whether the player may buy a continue after running out of lives.
  bool get canContinue =>
      _finished && run.isOver && _continuesUsed < mode.continues && mode.kind == QuizModeKind.endless;

  bool get answeredCurrent => picked != null;

  /// Hides two wrong options of the current question; no effect when
  /// already answered or already hinted.
  void hint() {
    final q = question;
    if (q == null || answeredCurrent) return;
    final cut = run.useHint(q, _random);
    if (cut.isEmpty) return;
    hidden = {...cut};
    notifyListeners();
  }

  /// Applies option [i]; ignored once answered or when it was hidden.
  void answer(int i) {
    final q = question;
    if (q == null || answeredCurrent || hidden.contains(i)) return;
    picked = i;
    lastResult = run.answer(q, i, secondsLeft: secondsLeft);
    notifyListeners();
  }

  /// Moves past the answered question and finishes the run when it is over.
  void next() {
    if (!answeredCurrent) return;
    index++;
    final endsByCount = mode.kind != QuizModeKind.endless &&
        mode.kind != QuizModeKind.timedRace &&
        index >= mode.questionCount;
    if (run.isOver || endsByCount) {
      _finish();
    } else {
      _next();
    }
    notifyListeners();
  }

  /// Advances the countdown; the run finishes when it reaches zero.
  void tick(int seconds) {
    if (_finished || mode.kind != QuizModeKind.timedRace) return;
    secondsLeft = (secondsLeft - seconds).clamp(0, mode.durationSeconds);
    if (secondsLeft == 0) {
      _finish();
    }
    notifyListeners();
  }

  /// After running out of lives in endless mode: restores one life and
  /// resumes with a new question. Returns false when not allowed.
  bool continueRun() {
    if (!canContinue) return false;
    _continuesUsed++;
    run.lives = 1;
    _finished = false;
    _next();
    notifyListeners();
    return true;
  }

  void _finish() {
    _finished = true;
    question = null;
    picked = null;
    lastResult = null;
    hidden = {};
  }

  void _next() {
    picked = null;
    lastResult = null;
    hidden = {};
    final tier = mode.tierFor(index);
    final pool = [for (final i in generator.bank) if (i.tier == tier) i];
    for (var tries = 0; tries < 20 && pool.isNotEmpty; tries++) {
      final q = generator.generate(pool[_random.nextInt(pool.length)]);
      if (q != null) {
        question = q;
        return;
      }
    }
    _finish();
  }
}
