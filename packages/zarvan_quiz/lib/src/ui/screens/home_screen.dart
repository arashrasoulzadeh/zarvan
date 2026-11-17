import 'package:zarvan_core/zarvan_core.dart' show UiRect;
import 'package:zarvan_core/zarvan_core_quiz.dart';
import 'package:zarvan_flutter/zarvan_flutter.dart' show TextAlignment;

import '../quiz_screen.dart';
import 'about_screen.dart';
import 'chapters_screen.dart';
import 'game_screen.dart';
import 'settings_screen.dart';

/// The main menu: coins and settings on top, the daily challenge card, and a
/// button for each other mode.
class QuizHomeScreen extends QuizScreen {
  QuizHomeScreen(super.kit);

  @override
  void build() {
    final s = kit.strings;
    final theme = this.theme;
    final session = kit.session;
    titleBar(s.appName);
    final sx = rtl
        ? QuizScreen.margin
        : QuizScreen.worldWidth - QuizScreen.margin - 36;
    button(
      UiRect(sx, 18, 36, 36),
      '⚙',
      () => goTo(QuizSettingsScreen(kit)),
      style: QuizButtonStyle.outline,
      size: 20,
    );
    label(
      '${s.number(session.progress.coins)} ${s.coins}',
      rtl
          ? QuizScreen.worldWidth - QuizScreen.margin - 36
          : QuizScreen.margin + 30,
      70,
      size: 14,
      color: theme.soft,
      align: TextAlignment.center,
    );

    // The daily card.
    final today = kit.today;
    final played = session.progress.hasPlayedDaily(today);
    box(
      UiRect(
        QuizScreen.margin,
        92,
        QuizScreen.worldWidth - 2 * QuizScreen.margin,
        118,
      ),
      theme.surface,
      radius: 16,
    );
    if (played) {
      label(s.dailyChallenge, QuizScreen.worldWidth / 2, 116, size: 20);
      final marks = (session.progress.daily.results[today] ?? const [])
          .map((r) => r ? '✅' : '❌')
          .join();
      label(marks, QuizScreen.worldWidth / 2, 150, size: 20);
      final now = kit.now();
      final left = DateTime(now.year, now.month, now.day + 1).difference(now);
      label(
        '${s.dailyNextIn}: ${s.number(left.inHours)}:${(left.inMinutes % 60).toString().padLeft(2, '0')}',
        QuizScreen.worldWidth / 2,
        186,
        size: 14,
        color: theme.soft,
      );
    } else {
      label(
        s.dailyTodayPlay,
        QuizScreen.worldWidth / 2,
        122,
        size: 14,
        color: theme.soft,
      );
      button(
        UiRect(
          QuizScreen.margin + 16,
          150,
          QuizScreen.worldWidth - 2 * QuizScreen.margin - 32,
          48,
        ),
        s.dailyChallenge,
        () {
          play(
            QuizRound.daily(kit.factory, const DailyMode(), date: today),
            () => QuizGameScreen(kit),
          );
        },
      );
    }

    var y = 232.0;
    button(row(y), s.chapters, () => goTo(QuizChaptersScreen(kit)));
    y += 60;
    button(row(y), s.endless, () {
      play(
        QuizRound.endless(
          kit.factory,
          const EndlessMode(),
          seedBase: 'endless:${kit.now().millisecondsSinceEpoch}',
        ),
        () => QuizGameScreen(kit),
      );
    });
    y += 60;
    button(row(y), s.race, () {
      play(
        QuizRound.race(
          kit.factory,
          const RaceMode(),
          seedBase: 'race:${kit.now().millisecondsSinceEpoch}',
        ),
        () => QuizGameScreen(kit),
      );
    });
    y += 60;
    final ads = kit.ads;
    if (ads != null && ads.isRewardedReady) {
      button(
        row(y, height: 44),
        s.rewardAd,
        () async {
          if (await ads.showRewarded('coins')) {
            await session.rewardForAd();
            goTo(QuizHomeScreen(kit));
          }
        },
        style: QuizButtonStyle.outline,
        size: 16,
      );
      y += 56;
    }
    button(
      row(y + 8, height: 40),
      s.about,
      () => goTo(QuizAboutScreen(kit)),
      style: QuizButtonStyle.outline,
      size: 15,
    );
  }
}
