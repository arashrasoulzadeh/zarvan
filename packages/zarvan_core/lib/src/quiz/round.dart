import 'game_mode.dart';
import 'question.dart';
import 'quiz_bank.dart';
import 'quiz_item.dart';
import 'run.dart';
import 'seeded_random.dart';

/// Which item and seed come next in a mode. Each mode is one small strategy,
/// so [QuizRound] stays the same whatever is being played.
abstract class _Plan {
  /// Candidates for the next question as (item id, tier, question seed),
  /// best first. The round takes the first that can be asked.
  Iterable<(String, QuizTier, int)> candidates(QuizRun run, int cursor);

  /// Whether no more questions can be asked.
  bool finished(QuizRun run, int cursor);
}

class _StagePlan extends _Plan {
  _StagePlan(this.items, this.author, this.tier, this.attempt);

  final List<QuizItem> items;
  final String author;
  final QuizTier tier;
  final int attempt;

  @override
  Iterable<(String, QuizTier, int)> candidates(QuizRun run, int cursor) sync* {
    for (var i = cursor; i < items.length; i++) {
      yield (
        items[i].id,
        tier,
        seedOf('stage:$author:${tier.name}:$attempt:$i'),
      );
    }
  }

  @override
  bool finished(QuizRun run, int cursor) => cursor >= items.length;
}

/// Shared by endless and race: tier by question number, a fixed shuffled
/// order per tier, repeats only once a tier is used up.
class _SteppedPlan extends _Plan {
  _SteppedPlan(this.bank, this.seedBase, this.tierFor);

  final QuizBank bank;
  final String seedBase;
  final QuizTier Function(int n) tierFor;
  final Map<QuizTier, List<QuizItem>> _order = {};

  List<QuizItem> _orderOf(QuizTier t) => _order.putIfAbsent(t, () {
    final list = bank.items(tier: t);
    SeededRandom(seedOf('$seedBase:order:${t.name}')).shuffle(list);
    return list;
  });

  @override
  Iterable<(String, QuizTier, int)> candidates(QuizRun run, int cursor) sync* {
    final n = run.index + 1;
    final tier = tierFor(n);
    final order = _orderOf(tier);
    if (order.isEmpty) return;
    final seed = seedOf('$seedBase:$n');
    final fresh = [
      for (final i in order)
        if (!run.usedItemIds.contains(i.id)) i,
    ];
    if (fresh.isNotEmpty) {
      for (final i in fresh) {
        yield (i.id, tier, seed);
      }
      return;
    }
    final askedHere = run.answers.where((a) => a.tier == tier).length;
    for (var k = 0; k < order.length; k++) {
      yield (order[(askedHere + k) % order.length].id, tier, seed);
    }
  }

  @override
  bool finished(QuizRun run, int cursor) => false;
}

class _DailyPlan extends _Plan {
  _DailyPlan(this.bank, this.tiers, this.date);

  final QuizBank bank;
  final List<QuizTier> tiers;
  final String date;

  @override
  Iterable<(String, QuizTier, int)> candidates(QuizRun run, int cursor) sync* {
    final i = run.index;
    if (i >= tiers.length) return;
    final pool = [
      for (final item in bank.items(tier: tiers[i]))
        if (!run.usedItemIds.contains(item.id)) item,
    ];
    SeededRandom(seedOf('daily:$date:$i')).shuffle(pool);
    final seed = seedOf('daily:$date:q$i');
    for (final item in pool) {
      yield (item.id, tiers[i], seed);
    }
  }

  @override
  bool finished(QuizRun run, int cursor) => run.index >= tiers.length;
}

/// One game round in a mode: asks the questions, applies answers, runs the
/// clock and lives, and says when it is over. Wraps an immutable [QuizRun]
/// (`run`) that can be saved at any step; the rules and the numbers come from
/// the [GameMode].
class QuizRound {
  QuizRound._(this._factory, this.mode, this._plan, this._run);

  final QuestionFactory _factory;
  final GameMode mode;
  final _Plan _plan;
  QuizRun _run;
  int _cursor = 0;

  /// The saved-able state of the round.
  QuizRun get run => _run;

  /// A stage: the [mode]'s count of most famous items for [author] and
  /// [tier]; [attempt] (1, 2, ...) changes which word is blanked, not which
  /// items are asked.
  factory QuizRound.stage(
    QuestionFactory factory,
    StageMode mode, {
    required String author,
    required QuizTier tier,
    int attempt = 1,
  }) {
    final items = factory.bank
        .items(author: author, tier: tier)
        .take(mode.questionCount)
        .toList();
    return QuizRound._(
      factory,
      mode,
      _StagePlan(items, author, tier, attempt),
      QuizRun.start(
        mode: mode.type,
        seedBase: 'stage:$author:${tier.name}:$attempt',
      ),
    );
  }

  /// An endless round; [seedBase] (for example `endless:<start time>`) makes
  /// it reproducible.
  factory QuizRound.endless(
    QuestionFactory factory,
    EndlessMode mode, {
    required String seedBase,
  }) => QuizRound._(
    factory,
    mode,
    _SteppedPlan(factory.bank, seedBase, mode.tierFor),
    QuizRun.start(mode: mode.type, seedBase: seedBase, lives: mode.lives),
  );

  /// A timed race; the clock only moves through [tick] and answers.
  factory QuizRound.race(
    QuestionFactory factory,
    RaceMode mode, {
    required String seedBase,
  }) => QuizRound._(
    factory,
    mode,
    _SteppedPlan(factory.bank, seedBase, mode.tierFor),
    QuizRun.start(
      mode: mode.type,
      seedBase: seedBase,
      clockMs: mode.durationMs,
    ),
  );

  /// The daily set for [date] (`YYYY-MM-DD`, the player's local calendar
  /// date, given by the app so every device with that date gets the same
  /// questions).
  factory QuizRound.daily(
    QuestionFactory factory,
    DailyMode mode, {
    required String date,
  }) {
    final parsed = DateTime.tryParse(date);
    final ok =
        RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) &&
        parsed != null &&
        '${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}' ==
            date;
    if (!ok)
      throw ArgumentError.value(
        date,
        'date',
        'must be a real date as YYYY-MM-DD',
      );
    return QuizRound._(
      factory,
      mode,
      _DailyPlan(factory.bank, mode.tiers, date),
      QuizRun.start(mode: mode.type, seedBase: 'daily:$date'),
    );
  }

  /// True when no more questions are accepted: stage or daily finished, no
  /// lives left, or the clock at zero.
  bool get isOver {
    final lives = _run.lives;
    if (lives != null && lives <= 0) return true;
    final clock = _run.clockMs;
    if (clock != null && clock <= 0) return true;
    return _run.current == null && _plan.finished(_run, _cursor);
  }

  /// The question on screen, asking the next one first if there is none.
  /// Null when the round is over or the bank has nothing left to ask.
  Question? nextQuestion() {
    if (isOver) return null;
    if (_run.current != null) return _run.current;
    for (final (id, tier, seed) in _plan.candidates(_run, _cursor)) {
      _cursor = _planCursorAfter(id);
      final q = _factory.create(id, tier, seed);
      if (q != null) {
        _run = _run.withQuestion(q);
        return q;
      }
    }
    _cursor = 1 << 30;
    return null;
  }

  /// Stage items are consumed in order; the cursor follows the item asked.
  int _planCursorAfter(String id) {
    final plan = _plan;
    if (plan is _StagePlan) {
      return plan.items.indexWhere((i) => i.id == id) + 1;
    }
    return _cursor;
  }

  /// Answers the current question with option [choice]. In a race the clock
  /// gains or loses time. Throws [StateError] when the round is over or no
  /// question is waiting.
  AnswerResult answer(int choice) {
    if (isOver) throw StateError('The round is over.');
    final (next, result) = _run.answer(choice);
    _run = next;
    final m = mode;
    if (m is RaceMode) {
      final clock = _run.clockMs! + (result.correct ? m.bonusMs : -m.penaltyMs);
      _run = _run.copyWith(clockMs: clock < 0 ? 0 : clock);
    }
    return result;
  }

  /// Takes the hint on the current question; not allowed in a race.
  void useHint() {
    if (mode is RaceMode) throw StateError('The hint is off in the race.');
    _run = _run.useHint();
  }

  /// Moves the race clock forward by [elapsed]. Only a race has a clock.
  void tick(Duration elapsed) {
    if (mode is! RaceMode) throw StateError('Only the race has a clock.');
    final left = _run.clockMs! - elapsed.inMilliseconds;
    _run = _run.copyWith(clockMs: left < 0 ? 0 : left);
  }

  /// After losing the last life in endless mode: gives one life back, once
  /// per round, if the mode allows it. Showing an ad first is the app's job.
  /// Returns whether it applied.
  bool continueRun() {
    final m = mode;
    if (m is! EndlessMode || m.continues < 1) return false;
    if (_run.lives != 0 || _run.continueUsed) return false;
    _run = _run.copyWith(lives: 1, continueUsed: true);
    return true;
  }

  /// Right answers so far.
  int get correctCount => _run.answers.where((a) => a.correct).length;

  /// Stars for a stage (0 for other modes).
  int get stars {
    final m = mode;
    return m is StageMode ? m.starsFor(correctCount) : 0;
  }

  /// Whether a stage was passed (false for other modes).
  bool get passed {
    final m = mode;
    return m is StageMode && m.passed(correctCount);
  }

  /// One entry per answered question: right or wrong.
  List<bool> get results => [for (final a in _run.answers) a.correct];

  /// The share text of a daily result: ✅ for right, ❌ for wrong. The app
  /// adds the date and the rest.
  String get resultString => results.map((r) => r ? '✅' : '❌').join();
}
