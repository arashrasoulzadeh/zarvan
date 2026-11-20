import 'package:zarvan_core/zarvan_core_quiz.dart';

import 'package:zarvan_flutter/zarvan_flutter.dart' show ShareOutcome;

import 'package:zarvan_core/zarvan_core.dart' show UiRect;

import '../ornaments.dart';
import '../quiz_screen.dart';
import 'game_screen.dart';
import 'home_screen.dart';

/// What the round gave: the score, stars or record, the coins earned, and a
/// way to play again, share (the daily) or go back.
class QuizResultScreen extends QuizScreen {
  QuizResultScreen(super.kit);

  late final _note = label(
    '',
    QuizScreen.worldWidth / 2,
    _noteY,
    size: 14,
    color: 0xFFFFF1D6,
  );

  double _noteY = 416;
  double _cardBottom = 0;

  static const _ink = 0xFF3A2312;
  static const _brown = 0xFF6B4A2B;

  @override
  void build() {
    final s = kit.strings;
    final session = kit.session;
    final round = session.round!;
    final reward = session.reward;
    styledBackdrop(seed: 1, blossoms: false);
    titleBar(s.result);
    final cx = QuizScreen.worldWidth / 2;
    spread(0.12);
    // The card ends a little under its last line and the buttons follow it,
    // so a short result (a daily) leaves no empty band inside or below it.
    var end = 220.0;
    if (round.mode is StageMode) end += 92;
    if (round.mode is DailyMode && round.date != null) end += 52;
    if (reward?.newRecord == true) end += 34;
    final cardH = end + 36 - 88;
    _cardBottom = 88 + cardH;
    // The result on a parchment card with blossoms in its corners.
    cartoucheAt(
      UiRect(
        QuizScreen.margin + 4,
        88,
        QuizScreen.worldWidth - 2 * QuizScreen.margin - 8,
        cardH,
      ),
      card: true,
      flowers: 1,
    );
    final face = theme.poemFontFamily ?? theme.fontFamily;
    label(
      '${s.number(round.run.score)} ${s.score}',
      cx,
      160,
      size: 34,
      color: _ink,
      fontFamily: face,
    );
    var y = 220.0;
    final mode = round.mode;
    if (mode is StageMode) {
      // The stars are little seals: a ticked one for each earned.
      for (var i = 0; i < 3; i++) {
        sealAt(cx + (i - 1) * 54, y, 36, i < round.stars ? 2 : 0);
      }
      label(
        round.passed ? s.stageResultPassed : s.stageResultFailed,
        cx,
        y + 44,
        size: 16,
        color: _ink,
      );
      y += 92;
    }
    if (mode is DailyMode && round.date != null) {
      // One seal per question, a tick or a cross, in place of the emoji of
      // [QuizRound.resultString] (kept for sharing): the app's fonts carry no
      // emoji, so on some platforms the row was simply missing.
      final results = round.results;
      final step = 48.0;
      for (var i = 0; i < results.length; i++) {
        final x = cx + (i - (results.length - 1) / 2) * step;
        markAt(
          x,
          y,
          44,
          results[i] ? theme.correct : theme.wrong,
          cross: !results[i],
        );
      }
      y += 52;
    }
    if (reward?.newRecord == true) {
      label(s.newRecord, cx, y, size: 18, color: 0xFF8A2F1E);
      y += 34;
    }
    if (reward != null) {
      label(
        '${s.coinsEarned}: ${s.number(reward.coins)}',
        cx,
        y,
        size: 16,
        color: _brown,
      );
    }

    spread(1);
    final by = _cardBottom + 24 + 66;
    _noteY = by - 66 - 18;
    if (mode is DailyMode && round.date != null && kit.share != null) {
      bannerButton(row(by - 66, height: 56), s.share, () async {
        final outcome = await kit.share!(_shareText(round));
        _note.text!.text = switch (outcome) {
          ShareOutcome.shared => '',
          ShareOutcome.copied => s.copied,
          ShareOutcome.failed => s.shareFailed,
        };
      }, gleam: 0.5);
    } else if (mode is! DailyMode) {
      bannerButton(
        row(by - 66, height: 56),
        s.playAgain,
        () => _again(round),
        gleam: 0.5,
      );
    }
    bannerButton(
      row(by, height: 56),
      s.backToMenu,
      () => navigate(QuizHomeScreen(kit), returning: true),
      color: 0xFF1F4E86,
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
