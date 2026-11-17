import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:zarvan_core/zarvan_core.dart' show KeyValueStore;
import 'package:zarvan_core/zarvan_core_quiz.dart';

/// Something that happened in a [QuizSession], for the app to record (for
/// example as analytics) without the session knowing about the recorder.
sealed class QuizEvent {
  const QuizEvent(this.round);

  /// The round it happened in.
  final QuizRound round;
}

/// A round began.
class RoundStarted extends QuizEvent {
  const RoundStarted(super.round);
}

/// An answer was given. [result] says whether it was right and its points;
/// [question] is the question it answered.
class AnswerGiven extends QuizEvent {
  const AnswerGiven(super.round, this.question, this.result);

  final Question question;
  final AnswerResult result;
}

/// The hint was bought for [question].
class HintUsed extends QuizEvent {
  const HintUsed(super.round, this.question);

  final Question question;
}

/// An endless round ran out of lives and a continue is being offered.
class ContinueOffered extends QuizEvent {
  const ContinueOffered(super.round);
}

/// The offered continue was taken ([taken] true) or declined.
class ContinueResolved extends QuizEvent {
  const ContinueResolved(super.round, {required this.taken});

  final bool taken;
}

/// The round ended and was booked; [reward] is what it paid.
class RoundEnded extends QuizEvent {
  const RoundEnded(super.round, this.reward);

  final RunReward reward;
}

/// Connects the quiz rules to Flutter: it owns the [QuizRound] being played
/// and the player's [QuizProgress], gives the race its real clock, saves
/// after every answer, and stops when the app goes to the background.
/// Widgets listen to it and call [answer], [useHint] and [next].
class QuizSession extends ChangeNotifier {
  QuizSession({
    required this.store,
    required this.progress,
    this.clockTick = const Duration(milliseconds: 100),
    this.raceFeedback = const Duration(seconds: 1),
  });

  /// Opens a session on the saved progress. A save that cannot be read
  /// starts fresh; [loadError] says why.
  static Future<QuizSession> open(KeyValueStore store) async {
    final loaded = await QuizProgressStore(store).load();
    return QuizSession(store: store, progress: loaded.progress)
      ..loadError = loaded.error;
  }

  final KeyValueStore store;
  final QuizProgress progress;

  /// How often the race clock is advanced.
  final Duration clockTick;

  /// How long a race answer stays on screen before the next question.
  final Duration raceFeedback;

  /// Why the saved progress was not used, if it was not.
  String? loadError;

  /// The round in play, or null before [begin].
  QuizRound? round;

  /// Option the player picked on the current question, until [next].
  int? picked;

  /// What the last answer did, until [next].
  AnswerResult? lastResult;

  /// What the finished round paid, once it is over and booked.
  RunReward? reward;

  final StreamController<QuizEvent> _events = StreamController.broadcast(
    sync: true,
  );

  /// Everything that happens in the session, in order. Nothing is emitted
  /// until someone listens.
  Stream<QuizEvent> get events => _events.stream;

  bool _paused = false;
  bool _offering = false;
  Timer? _clock;
  Timer? _auto;

  Question? _current;

  /// The question on screen, or null between rounds. It stays until [next]
  /// after an answer, so the card can show the right word.
  Question? get question => _current;

  bool get answered => picked != null;

  /// True once the round is over and booked into [progress].
  bool get finished => reward != null;

  bool get paused => _paused;

  /// True while the player is being asked whether to continue an endless
  /// round that ran out of lives (the app shows its rewarded ad, then calls
  /// [continueRound]; or [declineContinue]). The round is not booked yet.
  bool get offeringContinue => _offering;

  /// Whether the round in play may still be continued: endless, out of
  /// lives, the mode allows a continue and none was used.
  bool get canContinue {
    final r = round;
    if (r == null) return false;
    final m = r.mode;
    return m is EndlessMode &&
        m.continues >= 1 &&
        r.run.lives == 0 &&
        !r.run.continueUsed;
  }

  /// Whether a hint can be bought now: a question is open, not answered or
  /// hinted yet, not a race, and the coins cover it.
  bool get canHint {
    final q = question;
    return q != null &&
        !answered &&
        q.removedByHint.isEmpty &&
        round!.mode is! RaceMode &&
        progress.coins >= QuizProgress.hintCost;
  }

  /// Starts [r] and shows its first question. A daily already played on its
  /// date is refused (one per day) with a [StateError].
  void begin(QuizRound r) {
    final date = r.date;
    if (date != null && progress.hasPlayedDaily(date)) {
      throw StateError('The daily for $date was already played.');
    }
    _stopTimers();
    round = r;
    _offering = false;
    picked = null;
    lastResult = null;
    reward = null;
    _current = r.nextQuestion();
    if (r.mode is RaceMode) _startClock();
    _events.add(RoundStarted(r));
    notifyListeners();
  }

  /// Answers option [choice] of the open question; ignored when already
  /// answered, paused, or when the hint removed that option.
  void answer(int choice) {
    final r = round;
    final q = question;
    if (r == null || q == null || answered || _paused) return;
    if (q.removedByHint.contains(choice)) return;
    final result = r.answer(choice);
    lastResult = result;
    picked = choice;
    _events.add(AnswerGiven(r, q, result));
    unawaited(_saveRun());
    if (r.mode is RaceMode && !r.isOver) {
      _auto?.cancel();
      _auto = Timer(raceFeedback, next);
    }
    notifyListeners();
  }

  /// Pays the rewarded-ad coins (the app calls this only after its ad was
  /// watched to the end), saves, and tells listeners.
  Future<void> rewardForAd() async {
    progress.rewardedAd();
    notifyListeners();
    await _saveProgress();
  }

  /// Buys and applies the hint (20 coins). False, with nothing changed, when
  /// it cannot be had (see [canHint]).
  bool useHint() {
    if (!canHint) return false;
    final asked = question!;
    progress.buyHint();
    round!.useHint();
    _current = round!.run.current;
    _events.add(HintUsed(round!, asked));
    unawaited(_saveProgress());
    notifyListeners();
    return true;
  }

  /// Moves on from the answered question: the next question, or, when the
  /// round is over, books it into [progress] and saves.
  void next() {
    final r = round;
    if (r == null || !answered) return;
    _auto?.cancel();
    if (r.isOver && canContinue && !finished) {
      _offering = true;
      _events.add(ContinueOffered(r));
      notifyListeners();
      return;
    }
    picked = null;
    lastResult = null;
    if (r.isOver) {
      _finish();
    } else {
      _current = r.nextQuestion();
      if (r.isOver || _current == null) _finish();
    }
    notifyListeners();
  }

  /// After the player agreed to continue (the app showed its ad): gives one
  /// life back and moves on to a new question. False when no continue is
  /// being offered.
  bool continueRound() {
    final r = round;
    if (!_offering || r == null || !r.continueRun()) return false;
    _offering = false;
    picked = null;
    lastResult = null;
    _current = r.nextQuestion();
    _events.add(ContinueResolved(r, taken: true));
    notifyListeners();
    return true;
  }

  /// The player did not continue: books the round as it ended.
  void declineContinue() {
    if (!_offering) return;
    _offering = false;
    picked = null;
    lastResult = null;
    _events.add(ContinueResolved(round!, taken: false));
    _finish();
    notifyListeners();
  }

  /// Stops the race clock (the app went to the background).
  void pause() {
    if (_paused) return;
    _paused = true;
    _clock?.cancel();
    _auto?.cancel();
    unawaited(_saveRun());
    notifyListeners();
  }

  /// Starts the race clock again.
  void resume() {
    if (!_paused) return;
    _paused = false;
    final r = round;
    if (r != null && r.mode is RaceMode && !finished) {
      _startClock();
      if (answered && !r.isOver) _auto = Timer(raceFeedback, next);
    }
    notifyListeners();
  }

  void _startClock() {
    _clock?.cancel();
    _clock = Timer.periodic(clockTick, (_) {
      final r = round;
      if (r == null || _paused || finished) return;
      r.tick(clockTick);
      if (r.isOver) {
        _clock?.cancel();
        _finish();
      }
      notifyListeners();
    });
  }

  void _finish() {
    final r = round!;
    _stopTimers();
    _current = null;
    picked = null;
    lastResult = null;
    final paid = progress.applyRun(r);
    reward = paid;
    _events.add(RoundEnded(r, paid));
    unawaited(store.remove(runKey));
    unawaited(_saveProgress());
  }

  /// Where the run in play is kept so a crash can resume it
  /// (`QuizRound.resume`).
  static const runKey = 'quiz.run';

  Future<void> _saveRun() async {
    final r = round;
    if (r == null || finished) return;
    await store.setString(runKey, jsonEncode(r.run.toJson()));
  }

  Future<void> _saveProgress() => QuizProgressStore(store).save(progress);

  void _stopTimers() {
    _clock?.cancel();
    _auto?.cancel();
    _clock = null;
    _auto = null;
  }

  @override
  void dispose() {
    _stopTimers();
    unawaited(_events.close());
    super.dispose();
  }
}

/// Pauses a [QuizSession] when the app leaves the foreground and resumes it
/// when it returns, so a race clock does not run in the background.
class QuizLifecycleHost extends StatefulWidget {
  const QuizLifecycleHost({
    super.key,
    required this.session,
    required this.child,
  });

  final QuizSession session;
  final Widget child;

  @override
  State<QuizLifecycleHost> createState() => _QuizLifecycleHostState();
}

class _QuizLifecycleHostState extends State<QuizLifecycleHost>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.session.resume();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      widget.session.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
