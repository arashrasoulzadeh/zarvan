import 'package:zarvan_core/zarvan_core.dart' show UiRect, World;
import 'package:zarvan_core/zarvan_core_quiz.dart';

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

/// The main menu: a magical wall of shelves with one card per author (their
/// four stages as pips), the daily challenge, Endless and Race, and a big
/// Continue that goes on with the next stage. Drawn only with engine shapes
/// and text; the glows pulse and sparkles twinkle in [update].
class QuizHomeScreen extends QuizScreen {
  QuizHomeScreen(super.kit);

  final List<Twinkle> _twinkles = [];
  double _time = 0;
  late final MedalOverlay _medal = MedalOverlay(this);

  static const _gold = 0xFFE0A93B;

  @override
  void build() {
    final s = kit.strings;
    final theme = this.theme;
    final session = kit.session;
    final progress = session.progress;
    nightSky();
    _twinkles.addAll(sparkles(16));

    // Top bar: coins, the title plaque, settings.
    _coinPill(20, 20, '${s.number(progress.coins)} ${s.coins}');
    lightAt(UiRect(110, 16, 140, 44), theme.accent, intensity: 0.35, z: 2);
    _twinkles.add(
      Twinkle(
        plaque(UiRect(110, 16, 140, 44), s.appName, size: 28),
        low: 0.08,
        high: 0.3,
      ),
    );
    final gear = button(
      UiRect(QuizScreen.worldWidth - 64, 16, 44, 44),
      '⚙',
      () => goTo(QuizSettingsScreen(kit)),
      style: QuizButtonStyle.outline,
      size: 22,
    );
    gear.bg.shape!.cornerRadius = 22;

    final ads = kit.ads;
    if (ads != null && ads.isRewardedReady) {
      button(
        UiRect(16, 62, 160, 24),
        s.rewardAd,
        () async {
          if (await ads.showRewarded('coins')) {
            await session.rewardForAd();
            goTo(QuizHomeScreen(kit));
          }
        },
        style: QuizButtonStyle.outline,
        size: 11,
      );
    }

    // The wall: heading, progress, and the shelves of authors.
    const cx = QuizScreen.worldWidth / 2;
    line(24, 108, 100, theme.accent);
    line(
      QuizScreen.worldWidth - 108,
      QuizScreen.worldWidth - 24,
      100,
      theme.accent,
    );
    _twinkles.add(
      Twinkle(
        plaque(UiRect(126, 84, 108, 32), s.wallTitle, size: 15),
        low: 0.06,
        high: 0.25,
        phase: 1,
      ),
    );
    final authors = kit.bank.authors;
    final done = authors
        .where((a) => _passed(a) == QuizTier.values.length)
        .length;
    label(
      '${s.number(done)} ${s.outOf} ${s.number(authors.length)} ${s.chaptersDone}',
      cx,
      134,
      size: 12,
      color: theme.soft,
    );

    final next = nextStage(kit.bank, progress);
    const perRow = 5;
    const cardW = 58.0;
    const cardH = 104.0;
    const gap = 8.0;
    final left =
        (QuizScreen.worldWidth - (perRow * cardW + (perRow - 1) * gap)) / 2;
    for (var i = 0; i < authors.length; i++) {
      final row = i ~/ perRow;
      final col = i % perRow;
      final x = rtl
          ? QuizScreen.worldWidth - left - cardW - col * (cardW + gap)
          : left + col * (cardW + gap);
      final y = 154.0 + row * 128;
      if (col == 0) {
        final plank = box(
          UiRect(14, y + cardH + 4, QuizScreen.worldWidth - 28, 10),
          theme.accent,
          radius: 5,
          z: 3,
        );
        plank.shape!.alpha = 0.22;
      }
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
    final today = kit.today;
    final played = progress.hasPlayedDaily(today);
    final daily = UiRect(
      QuizScreen.margin,
      418,
      QuizScreen.worldWidth - 2 * QuizScreen.margin,
      48,
    );
    if (played) {
      final glow = box(
        UiRect(daily.x - 3, daily.y - 3, daily.width + 6, daily.height + 6),
        theme.accent,
        radius: 17,
        z: 3,
      );
      glow.shape!.alpha = 0.1;
      frame(daily, theme.accent, alpha: 0.7, radius: 14);
      label(s.dailyDone, cx, daily.centerY, size: 17, color: theme.soft);
    } else {
      final glow = box(
        UiRect(daily.x - 4, daily.y - 4, daily.width + 8, daily.height + 8),
        theme.accent,
        radius: 18,
        z: 3,
      );
      glow.shape!.alpha = 0.2;
      lightAt(daily, theme.accent, intensity: 0.4);
      _twinkles.add(Twinkle(glow.shape!, low: 0.1, high: 0.35, speed: 1.3));
      button(daily, '${s.dailyChallenge} · ${s.dailyTodayPlay}', () {
        play(
          QuizRound.daily(kit.factory, const DailyMode(), date: today),
          () => QuizGameScreen(kit),
        );
      }, size: 15);
    }
    const half = (QuizScreen.worldWidth - 2 * QuizScreen.margin - 12) / 2;
    button(
      UiRect(QuizScreen.margin, 478, half, 44),
      s.endless,
      () {
        play(
          QuizRound.endless(
            kit.factory,
            const EndlessMode(),
            seedBase: 'endless:${kit.now().millisecondsSinceEpoch}',
          ),
          () => QuizGameScreen(kit),
        );
      },
      style: QuizButtonStyle.outline,
      size: 16,
    );
    button(
      UiRect(QuizScreen.margin + half + 12, 478, half, 44),
      s.race,
      () {
        play(
          QuizRound.race(
            kit.factory,
            const RaceMode(),
            seedBase: 'race:${kit.now().millisecondsSinceEpoch}',
          ),
          () => QuizGameScreen(kit),
        );
      },
      style: QuizButtonStyle.outline,
      size: 16,
    );

    // Continue, and the quiet About link.
    final cont = UiRect(
      QuizScreen.margin,
      534,
      QuizScreen.worldWidth - 2 * QuizScreen.margin,
      52,
    );
    final contGlow = box(
      UiRect(cont.x - 3, cont.y - 3, cont.width + 6, cont.height + 6),
      theme.accent,
      radius: 17,
      z: 3,
    );
    contGlow.shape!.alpha = 0.18;
    lightAt(cont, theme.accent, intensity: 0.45);
    _twinkles.add(Twinkle(contGlow.shape!, low: 0.08, high: 0.28, phase: 2));
    button(
      cont,
      '${s.continueGame} · ${next.author.name} · ${s.tierName(next.tier.level)}',
      () {
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
      },
      size: 17,
    );
    final about = button(
      UiRect(cx - 50, 598, 100, 28),
      s.about,
      () => goTo(QuizAboutScreen(kit)),
      style: QuizButtonStyle.option,
      size: 13,
    );
    about.bg.shape!.alpha = 0;
    about.label.text!.colorArgb = theme.soft;
  }

  /// How many of the author's four stages have been passed.
  int _passed(QuizAuthor a) => [
    for (final t in QuizTier.values)
      if (kit.session.progress.stages[a.id]?[t.name]?.passedOnce ?? false) 1,
  ].length;

  void _coinPill(double x, double y, String text) {
    frame(UiRect(x, y, 92, 32), theme.accent, radius: 16, alpha: 0.7);
    dot(x + 18, y + 16, 18, _gold);
    diamondAt(x + 18, y + 16, 7, 0xFFFFE3A3, z: 7);
    label(text, x + 58, y + 16, size: 13);
  }

  void _card(
    QuizAuthor a,
    double x,
    double y,
    double w,
    double h, {
    required bool current,
  }) {
    final theme = this.theme;
    final cx = x + w / 2;
    if (current) {
      lightAt(UiRect(x, y, w, h), theme.accent, intensity: 0.7);
      final glow = box(
        UiRect(x - 5, y - 5, w + 10, h + 10),
        theme.accent,
        radius: 16,
        z: 3,
      );
      glow.shape!.alpha = 0.3;
      _twinkles.add(Twinkle(glow.shape!, low: 0.18, high: 0.5, speed: 1.4));
    }
    final body = box(
      UiRect(x, y, w, h),
      current ? theme.accent : theme.surface,
      radius: 12,
      z: 5,
    );
    body.shape!.alpha = current ? 0.28 : 1;
    frame(
      UiRect(x, y, w, h),
      theme.accent,
      radius: 12,
      alpha: current ? 0.95 : 0.5,
      z: 6,
    );
    frame(
      UiRect(x + 4, y + 4, w - 8, h - 8),
      theme.accent,
      radius: 9,
      alpha: 0.25,
      dash: 3,
      z: 6,
    );
    final portrait = portraitAt(
      a.id,
      cx,
      y + 34,
      44,
      current ? theme.ink : (0xE0 << 24 | (theme.accent & 0xFFFFFF)),
    );
    if (portrait == null) {
      diamondAt(cx, y + 36, 30, theme.accent, stroke: 1.2, alpha: 0.3);
      diamondAt(cx, y + 36, 14, theme.accent, stroke: 1.2, alpha: 0.35);
    }
    final passed = _passed(a);
    for (var i = 0; i < QuizTier.values.length; i++) {
      final px = cx + (i - 1.5) * 11;
      if (i < passed) {
        dot(px, y + h - 9, 7, theme.accent, alpha: 0.95);
      } else {
        ringAt(px, y + h - 9, 7, theme.accent, stroke: 1, alpha: 0.6);
      }
    }
    if (current) diamondAt(cx, y + h, 11, theme.accent, z: 8);
    final tap = button(
      UiRect(x, y, w, h),
      a.name,
      () => _medal.open(a, UiRect(x, y, w, h)),
      style: QuizButtonStyle.option,
      size: 12,
    );
    tap.bg.shape!.alpha = 0;
    tap.label.pos.y += portrait == null ? -6 : 21;
    tap.label.text!
      ..maxWidth = w - 8
      ..colorArgb = theme.ink;
  }

  @override
  void update(double dt, World world) {
    _time += dt;
    _medal.update(dt);
    for (final t in _twinkles) {
      t.apply(_time);
    }
  }
}
