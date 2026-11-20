import 'dart:math' as math;

import 'package:zarvan_core/zarvan_core.dart' show UiRect, World;
import 'package:zarvan_core/zarvan_core_quiz.dart';
import 'package:zarvan_flutter/zarvan_flutter.dart' show UiButton;

import '../medal_overlay.dart';
import '../ornaments.dart';
import '../quiz_screen.dart';
import 'about_screen.dart';
import 'game_screen.dart';
import 'settings_screen.dart';

/// The next stage to play: the first author (in the bank's order) that is not
/// finished, and the first tier of theirs that has not been passed. When
/// everything is passed it is the hardest stage of the last author.
({QuizAuthor author, QuizTier tier}) nextStage(
  QuizBank bank,
  QuizProgress progress,
) {
  for (final a in bank.authors) {
    for (final t in QuizTier.values) {
      if (!(progress.stages[a.id]?[t.name]?.passedOnce ?? false)) {
        return (author: a, tier: t);
      }
    }
  }
  return (author: bank.authors.last, tier: QuizTier.literary);
}

/// The main menu, laid out like a page of a Persian miniature: blue paper
/// with swirling clouds, a heading in calligraphy, the authors as gilded
/// arched cards (a portrait in a window of their robe's colour over a name on
/// a scalloped plaque), the daily challenge on a parchment banner, Endless and
/// Race and a big Continue on green velvet ones, and blossoming branches in the
/// corners. Everything is drawn by the engine's shaders (no image files); the
/// glows breathe by themselves and the clouds and blossoms drift in [update].
class QuizHomeScreen extends QuizScreen {
  QuizHomeScreen(super.kit);

  late final MedalOverlay _medal = MedalOverlay(this);
  final List<DriftingCloud> _clouds = [];
  final math.Random _rng = math.Random(11);

  static const _cream = 0xFFFFF1D6;
  static const _ink = 0xFF3A2312;
  static const _navy = 0xFF1B2A55;
  static const _plaque = 0.24;

  @override
  void build() {
    final s = kit.strings;
    final theme = this.theme;
    final session = kit.session;
    final progress = session.progress;
    lapisSky();

    // Clouds that drift across the page, one band of sky each.
    spread(0);
    _clouds.add(DriftingCloud(this, 0, 6, 60));
    spread(0.45);
    _clouds.add(DriftingCloud(this, 2, 296, 340));
    _clouds.add(DriftingCloud(this, 3, 396, 440));

    // Top bar: coins and settings.
    spread(0.02);
    _coinPill(20, 20, '${s.number(progress.coins)} ${s.coins}');
    final gear = button(
      UiRect(QuizScreen.worldWidth - 64, 16, 44, 44),
      '⚙',
      () => goTo(QuizSettingsScreen(kit)),
      style: QuizButtonStyle.outline,
      size: 22,
    );
    gear.bg.shape!.cornerRadius = 22;
    gear.bg.shape!.colorArgb = _cream;
    gear.label.text!.colorArgb = _cream;

    // The heading, with a soft shadow under it.
    spread(0.12);
    const cx = QuizScreen.worldWidth / 2;
    final heading = theme.poemFontFamily ?? theme.fontFamily;
    label(
      s.wallTitle,
      cx + 1.5,
      79.5,
      size: 40,
      color: 0x99102040,
      fontFamily: heading,
    );
    label(s.wallTitle, cx, 78, size: 40, color: _cream, fontFamily: heading);

    // The authors: five to a row.
    spread(0.3);
    final authors = kit.bank.authors;
    final next = nextStage(kit.bank, progress);
    const perRow = 5;
    const cardW = 62.0;
    // The cards are pictures at their own proportions when the game has them.
    final art = kit.cardArt;
    final cardH = art?.heightFor(cardW) ?? 114.0;
    const gap = 5.0;
    final left =
        (QuizScreen.worldWidth - (perRow * cardW + (perRow - 1) * gap)) / 2;
    for (var i = 0; i < authors.length; i++) {
      final row = i ~/ perRow;
      final col = i % perRow;
      final x = rtl
          ? QuizScreen.worldWidth - left - cardW - col * (cardW + gap)
          : left + col * (cardW + gap);
      final y = 118.0 + row * (cardH + 12);
      _card(
        authors[i],
        x,
        y,
        cardW,
        cardH,
        current: authors[i].id == next.author.id,
      );
    }

    // Daily challenge banner, then Endless and Race side by side.
    spread(0.42);
    final today = kit.today;
    final played = progress.hasPlayedDaily(today);
    final daily = UiRect(18, 392, QuizScreen.worldWidth - 36, 64);
    cartoucheAt(daily, paper: true, flowers: 1, gleam: played ? 0 : 0.7);
    if (!played) lightAt(daily, theme.accent, intensity: 0.35);
    final dailyTap = button(
      daily,
      played ? s.dailyDone : '${s.dailyChallenge} · ${s.dailyTodayPlay}',
      () {
        if (played) return;
        play(
          QuizRound.daily(kit.factory, const DailyMode(), date: today),
          () => QuizGameScreen(kit),
        );
      },
      style: QuizButtonStyle.option,
      size: 16,
    );
    dailyTap.bg.shape!.alpha = 0;
    dailyTap.label.text
      ?..colorArgb = played ? 0xFF7A6A4F : _navy
      ..maxWidth = daily.width - 90;

    // Continue, and the quiet About link.
    spread(0.55);
    final cont = UiRect(cx - 124, 466, 248, 76);
    lightAt(cont, theme.accent, intensity: 0.4);
    final tap = _velvet(cont, s.continueGame, 22, () {
      final entry = progress.stages[next.author.id]?[next.tier.name];
      play(
        QuizRound.stage(
          kit.factory,
          kit.stageMode,
          author: next.author.id,
          tier: next.tier,
          attempt: (entry?.attempts ?? 0) + 1,
        ),
        () => QuizGameScreen(kit),
      );
    }, gleam: 0.8);
    tap.label.pos.y -= 9;
    label(
      '${next.author.name} · ${s.tierName(next.tier.level)}',
      cx,
      cont.centerY + 18,
      size: 12,
      color: 0xFFE9D7A6,
      z: 12,
    );

    // Endless and Race, side by side under Continue.
    const modeW = 118.0;
    const modeY = 550.0;
    final endlessRect = UiRect(cx - modeW - 6, modeY, modeW, 46);
    final raceRect = UiRect(cx + 6, modeY, modeW, 46);
    _velvet(endlessRect, s.endless, 15, () {
      play(
        QuizRound.endless(
          kit.factory,
          const EndlessMode(),
          seedBase: 'endless:${kit.now().millisecondsSinceEpoch}',
        ),
        () => QuizGameScreen(kit),
      );
    });
    _velvet(raceRect, s.race, 15, () {
      play(
        QuizRound.race(
          kit.factory,
          const RaceMode(),
          seedBase: 'race:${kit.now().millisecondsSinceEpoch}',
        ),
        () => QuizGameScreen(kit),
      );
    });

    spread(1);
    footBlossoms();

    spread(0.92);
    final about = button(
      UiRect(cx - 50, 606, 100, 28),
      s.about,
      () => goTo(QuizAboutScreen(kit)),
      style: QuizButtonStyle.option,
      size: 13,
    );
    about.bg.shape!.alpha = 0;
    about.label.text!.colorArgb = _cream;
    openVeil();
  }

  /// A green velvet cartouche button over [r] showing [text].
  UiButton _velvet(
    UiRect r,
    String text,
    double size,
    void Function() onTap, {
    double gleam = 0.15,
  }) {
    cartoucheAt(r, flowers: 1, gleam: gleam);
    final b = button(r, text, onTap, style: QuizButtonStyle.option, size: size);
    b.bg.shape!.alpha = 0;
    b.label.text!.colorArgb = _cream;
    return b;
  }

  void _coinPill(double x, double y, String text) {
    frame(UiRect(x, y, 92, 32), _cream, radius: 16, alpha: 0.8);
    dot(x + 18, y + 16, 18, 0xFFE0A93B);
    diamondAt(x + 18, y + 16, 7, 0xFFFFE3A3, z: 7);
    label(text, x + 58, y + 16, size: 13, color: _cream);
  }

  void _card(
    QuizAuthor a,
    double x,
    double y,
    double w,
    double h, {
    required bool current,
  }) {
    final cx = x + w / 2;
    final rect = UiRect(x, y, w, h);
    final style = kit.portraits?.styles[a.id];
    if (current) lightAt(rect, theme.accent, intensity: 0.75);
    if (cardPictureAt(a.id, rect) != null) {
      // The picture carries the portrait and the name; only a tap is left.
      final hit = button(
        rect,
        a.name,
        () => _medal.open(a, UiRect(x, y + yShift, w, h)),
        style: QuizButtonStyle.option,
        size: 11,
      );
      hit.bg.shape!.alpha = 0;
      hit.label.text!.alpha = 0;
      return;
    }
    cartoucheAt(
      rect,
      arch: true,
      plaque: _plaque,
      gleam: current ? 1 : 0,
      window: style?.window ?? 0xFF1F5E58,
    );
    portraitAt(a.id, cx, y + 52, 38, 0xFFFFF0CF);
    final tap = button(
      rect,
      a.name,
      () => _medal.open(a, UiRect(x, y + yShift, w, h)),
      style: QuizButtonStyle.option,
      size: 11,
    );
    tap.bg.shape!.alpha = 0;
    // The name sits on the plaque at the foot of the card; a long one wraps to
    // two lines and is set a little smaller.
    final long = a.name.length > 9 && a.name.contains(' ');
    final gw = 0.04 * w;
    final plaqueY = h - _plaque * h / 2 - gw * 1.05;
    tap.label.pos.y += plaqueY - h / 2;
    tap.label.text
      ?..fontSize = long ? 10 : 11.5
      ..maxWidth = w - 12
      ..colorArgb = _ink;
  }

  @override
  void update(double dt, World world) {
    super.update(dt, world);
    _medal.update(dt);
    for (final c in _clouds) {
      c.step(dt, _rng);
    }
  }
}
