import 'package:zarvan_core/zarvan_core_quiz.dart';

import 'package:zarvan_flutter/zarvan_flutter.dart' show ShareOutcome;

import '../quiz_screen.dart';
import 'game_screen.dart';
import 'home_screen.dart';

/// What the round gave: the score, stars or record, the coins earned, and a
/// way to play again, share (the daily) or go back.
class QuizResultScreen extends QuizScreen {
  QuizResultScreen(super.kit);

  late final _note = label('', QuizScreen.worldWidth / 2, 416, size: 14);

  @override
  void build() {
    final s = kit.strings;
    final session = kit.session;
    final round = session.round!;
    final reward = session.reward;
    titleBar(s.result);
    final cx = QuizScreen.worldWidth / 2;
    spread(0.2);
    label('${s.number(round.run.score)} ${s.score}', cx, 130, size: 32);
    var y = 180.0;
    final mode = round.mode;
    if (mode is StageMode) {
      label(
        List.generate(3, (i) => i < round.stars ? '★' : '☆').join(),
        cx,
        y,
        size: 34,
        color: theme.accent,
      );
      label(
        round.passed ? s.stageResultPassed : s.stageResultFailed,
        cx,
        y + 36,
        size: 16,
      );
      y += 80;
    }
    if (mode is DailyMode && round.date != null) {
      label(round.resultString, cx, y, size: 26);
      y += 44;
    }
    if (reward?.newRecord == true) {
      label(s.newRecord, cx, y, size: 18, color: theme.accent);
      y += 34;
    }
    if (reward != null) {
      label(
        '${s.coinsEarned}: ${s.number(reward.coins)}',
        cx,
        y,
        size: 16,
        color: theme.soft,
      );
    }

    spread(1);
    var by = 500.0;
    if (mode is DailyMode && round.date != null && kit.share != null) {
      button(row(by - 60), s.share, () async {
        final outcome = await kit.share!(_shareText(round));
        _note.text!.text = switch (outcome) {
          ShareOutcome.shared => '',
          ShareOutcome.copied => s.copied,
          ShareOutcome.failed => s.shareFailed,
        };
      });
    } else if (mode is! DailyMode) {
      button(row(by - 60), s.playAgain, () => _again(round));
    }
    button(
      row(by),
      s.backToMenu,
      () => navigate(QuizHomeScreen(kit)),
      style: QuizButtonStyle.outline,
    );
  }

  /// The text shared after a daily: marks and score; the game may wrap it.
  String _shareText(QuizRound round) =>
      kit.shareText?.call(round.date!, round.results) ??
      '${kit.strings.appName} · ${round.date} · ${round.resultString}';

  void _again(QuizRound old) {
    final f = kit.factory;
    final stamp = kit.now().millisecondsSinceEpoch;
    final p = kit.session.progress;
    final QuizRound next;
    switch (old.mode) {
      case StageMode():
        final attempts = p.stages[old.author]?[old.tier!.name]?.attempts ?? 0;
        next = QuizRound.stage(
          f,
          kit.stageMode,
          author: old.author!,
          tier: old.tier!,
          attempt: attempts + 1,
        );
      case EndlessMode():
        next = QuizRound.endless(
          f,
          const EndlessMode(),
          seedBase: 'endless:$stamp',
        );
      case RaceMode():
        next = QuizRound.race(f, const RaceMode(), seedBase: 'race:$stamp');
      case DailyMode():
        return;
    }
    play(next, () => QuizGameScreen(kit));
  }
}
