import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zarvan_core/zarvan_core.dart'
    show
        GameState,
        MemoryKeyValueStore,
        Position,
        World,
        registerCoreComponents;
import 'package:zarvan_flutter/zarvan_flutter.dart' as eng;
import 'package:zarvan_flutter/zarvan_flutter.dart'
    show
        BackdropBlur,
        Scene,
        SceneController,
        SceneTransitionConfig,
        SceneTransitionType,
        ShaderEffect,
        Shape,
        ShapeKind,
        ShareOutcome;
import 'package:zarvan_quiz/src/ui/medal_overlay.dart';
import 'package:zarvan_quiz/zarvan_quiz.dart';

import 'support.dart';

const strings = QuizStrings(
  appName: 'Shaer',
  coins: 'coins',
  settings: 'Settings',
  about: 'About',
  dailyChallenge: 'Daily',
  dailyDone: 'Done',
  dailyTodayPlay: 'Five new poems',
  chapters: 'Chapters',
  wallTitle: 'Wall of divans',
  chaptersDone: 'complete',
  outOf: 'of',
  continueGame: 'Continue',
  endless: 'Endless',
  race: 'Race',
  stageLockedHint: '18 of 25 before',
  stars: 'stars',
  stage: 'Stage',
  next: 'Next',
  hint: 'Hint',
  lives: 'Lives',
  clock: 'Time',
  score: 'Score',
  streak: 'Streak',
  result: 'Result',
  stageResultPassed: 'Passed',
  stageResultFailed: 'Try again',
  newRecord: 'New record',
  coinsEarned: 'Coins earned',
  backToMenu: 'Menu',
  playAgain: 'Again',
  share: 'Share',
  copied: 'Copied',
  shareFailed: 'Could not share',
  continueWithAd: 'Continue with an ad',
  continueQuestion: 'Out of lives. One more for an ad?',
  noThanks: 'No, finish',
  tutorialTitle: 'Find the word',
  tutorialBody: 'One word is missing',
  tutorialDone: 'Start',
  theme: 'Theme',
  themeSystem: 'System',
  themeLight: 'Light',
  themeDark: 'Dark',
  sound: 'Sound',
  haptics: 'Haptics',
  aboutSource: 'Poems from Ganjoor',
  aboutVersion: 'Version',
  aboutLicenseNote: 'Used with credit',
  difficulty: 'Difficulty',
  notEnoughCoins: 'Not enough coins',
  loadError: 'Save not read',
  rewardAd: '15 coins for an ad',
  tierNames: ['Easy', 'Medium', 'Hard', 'Literary'],
  number: _plain,
);
String _plain(int n) => '$n';

const themes = QuizThemes(
  light: QuizTheme(
    background: 0xFFFFFFFF,
    ink: 0xFF111111,
    soft: 0xFF888888,
    surface: 0xFFEEEEEE,
    accent: 0xFF1F6F6B,
    onAccent: 0xFFFFFFFF,
    correct: 0xFF2E7D32,
    wrong: 0xFFC62828,
  ),
  dark: QuizTheme(
    background: 0xFF101010,
    ink: 0xFFEEEEEE,
    soft: 0xFF999999,
    surface: 0xFF222222,
    accent: 0xFF6FC2BC,
    onAccent: 0xFF101010,
    correct: 0xFF66BB6A,
    wrong: 0xFFEF5350,
    isDark: true,
  ),
);

class FakeAds implements QuizAdGate {
  FakeAds({this.ready = true, this.earns = true});
  bool ready;
  bool earns;
  final shown = <String>[];
  @override
  bool get isRewardedReady => ready;
  @override
  Future<bool> showRewarded(String placement) async {
    shown.add(placement);
    return earns;
  }
}

/// A scene run without a window: the world, the scenes it asks to load, and
/// helpers to read its text and press its buttons.
class Rig {
  Rig(this.kit);

  final QuizKit kit;
  late final world = World(width: 360, height: worldHeight);
  double worldHeight = 640;
  late Scene scene;
  Scene? loaded;
  SceneTransitionConfig? loadedWith;
  final controller = SceneController();

  static Future<Rig> make({
    bool ads = false,
    bool earns = true,
    bool tutorialDone = true,
    DateTime? now,
    void Function(QuizProgress)? setup,
    QuizBank? bank,
    QuizPortraits? portraits,
    QuizCardArt? cardArt,
    bool transitions = false,
    String transitionKind = 'curtain',
    String? returnTransitionKind,
  }) async {
    final kv = MemoryKeyValueStore();
    final session = await QuizSession.open(kv);
    if (tutorialDone) session.progress.flags['tutorialDone'] = true;
    setup?.call(session.progress);
    final gate = FakeAds(earns: earns);
    final kit = QuizKit(
      session: session,
      factory: factoryOf(bank ?? makeBank()),
      strings: strings,
      themes: themes,
      settings: await QuizSettings.load(kv),
      about: const QuizAbout(
        lines: ['Poems from Ganjoor', 'Used with credit'],
        link: 'https://ganjoor.net',
        version: '1.0',
      ),
      ads: ads ? gate : null,
      haptic: buzzes.add,
      share: (t) async {
        sharedTexts.add(t);
        return outcome;
      },
      portraits: portraits,
      cardArt: cardArt,
      transitions: transitions,
      transitionKind: transitionKind,
      returnTransitionKind: returnTransitionKind ?? transitionKind,
      now: () => now ?? DateTime(2026, 11, 17, 10),
    );
    gates[kit] = gate;
    return Rig(kit);
  }

  static final buzzes = <QuizHaptic>[];
  static final sharedTexts = <String>[];
  static ShareOutcome outcome = ShareOutcome.shared;
  static final gates = <QuizKit, FakeAds>{};
  FakeAds get ads => gates[kit]!;

  Future<void> open(Scene s) async {
    registerCoreComponents(world);
    eng.registerFlutterComponents(world);
    controller.attach(
      loadScene: (n) => loaded = n,
      loadSceneWithTransition: (n, t) {
        loaded = n;
        loadedWith = t;
      },
      pushOverlay: (_) {},
      popOverlay: () {},
    );
    scene = s;
    await s.populate(world, controller, GameState());
  }

  /// Every text on screen that is on screen (not parked off to the side).
  List<String> get texts {
    final store = world.componentsOf<eng.Text>();
    final pos = world.componentsOf<Position>();
    final out = <String>[];
    for (var i = 0; i < store.length; i++) {
      final p = pos.get(store.entityAt(i));
      if (p != null && p.x > -1000) out.add(store.denseAt(i).text);
    }
    return out;
  }

  bool has(String t) => texts.contains(t);
  bool hasPart(String t) => texts.any((x) => x.contains(t));

  Position _at(String text) {
    final store = world.componentsOf<eng.Text>();
    final pos = world.componentsOf<Position>();
    for (var i = 0; i < store.length; i++) {
      if (store.denseAt(i).text == text) {
        final p = pos.get(store.entityAt(i));
        if (p != null && p.x > -1000) return p;
      }
    }
    throw StateError('no text "$text" on screen; have $texts');
  }

  /// Presses the button labelled [text].
  void tap(String text) {
    final p = _at(text);
    scene.handleTap(world, controller, Offset(p.x, p.y));
  }

  /// Buys a hint: the banner needs a second tap to confirm.
  void buyHint() {
    tap(texts.firstWhere((t) => t.contains('Hint')));
    run(0.1);
    tap(texts.firstWhere((t) => t.contains('Hint')));
  }

  void tapAt(double x, double y) =>
      scene.handleTap(world, controller, Offset(x, y));

  void run(double seconds, {double dt = 0.05}) {
    for (var t = 0.0; t < seconds; t += dt) {
      scene.update(dt, world);
    }
  }

  /// The colour of the full-screen background shape.
  int get backgroundColor {
    final shapes = world.componentsOf<Shape>();
    for (var i = 0; i < shapes.length; i++) {
      if (shapes.denseAt(i).zIndex == -10) return shapes.denseAt(i).colorArgb;
    }
    throw StateError('no background');
  }

  String get optionRight =>
      kit.session.question!.options[kit.session.question!.answerIndex];
  String optionWrong(int k) => kit
      .session
      .question!
      .options[(kit.session.question!.answerIndex + 1 + k) % 4];
}

void main() {
  setUp(() {
    Rig.sharedTexts.clear();
    Rig.outcome = ShareOutcome.shared;
  });

  group('game screen', () {
    Future<Rig> stage() async {
      final r = await Rig.make();
      r.kit.session.begin(
        QuizRound.stage(
          r.kit.factory,
          const StageMode(),
          author: 'a',
          tier: QuizTier.easy,
        ),
      );
      await r.open(QuizGameScreen(r.kit));
      return r;
    }

    test(
      'an answered option stays cream on its cartouche, with no box over it',
      () async {
        final r = await stage();
        r.tap(r.optionRight);
        r.run(0.1);
        final texts = r.world.componentsOf<eng.Text>();
        final alphaOf = <String, double>{};
        var cream = false;
        for (var i = 0; i < texts.length; i++) {
          final t = texts.denseAt(i);
          if (t.text == r.optionRight && t.colorArgb == 0xFFF5E9C8)
            cream = true;
          if (t.text == r.optionWrong(0) && t.colorArgb == 0xFFF5E9C8) {
            alphaOf[t.text] = t.alpha;
          }
        }
        expect(cream, isTrue, reason: 'readable on green velvet');
        expect(alphaOf[r.optionWrong(0)], 0.45, reason: 'others only dim');
        final shapes = r.world.componentsOf<Shape>();
        for (var i = 0; i < shapes.length; i++) {
          final sh = shapes.denseAt(i);
          expect(
            sh.kind == ShapeKind.roundedRect && sh.alpha > 0 && sh.zIndex == 7,
            isFalse,
            reason: 'the old rounded verdict frame is gone',
          );
        }
      },
    );

    test(
      'the answer mark is a shader tick or cross that is drawn in by a pen',
      () async {
        List<List<double>> marks(Rig r) {
          final fx = r.world.componentsOf<ShaderEffect>();
          return [
            for (var i = 0; i < fx.length; i++)
              if (fx.denseAt(i).kind == ShaderEffect.mark) fx.denseAt(i).params,
          ];
        }

        final right = await stage();
        expect(marks(right), isEmpty, reason: 'no mark before an answer');
        right.tap(right.optionRight);
        right.run(0.1);
        final early = marks(right).single;
        expect(early[0], 0, reason: 'a tick');
        expect(early[1], lessThan(0.5), reason: 'the pen has barely started');
        right.run(0.8);
        expect(marks(right).single[1], 1, reason: 'then it is fully drawn');
        expect(
          right.world.componentsOf<eng.Sprite>().length,
          0,
          reason: 'no images',
        );

        final wrong = await stage();
        wrong.tap(wrong.optionWrong(0));
        wrong.run(0.9);
        final crosses = marks(wrong).where((m) => m[0] == 1);
        expect(crosses.length, 1, reason: 'the wrong pick gets a cross');
      },
    );

    test('a seal leaves room around its star for the glow', () async {
      final r = await stage();
      final fx = r.world.componentsOf<ShaderEffect>();
      var seals = 0;
      for (var i = 0; i < fx.length; i++) {
        final e = fx.denseAt(i);
        if (e.kind == ShaderEffect.seal) {
          seals++;
          expect(e.width, closeTo(38 * 1.9, 0.01));
        }
      }
      expect(seals, 5);
    });

    test(
      'a stage shows five seals that follow the current question, drawn by a shader',
      () async {
        List<List<double>> seals(Rig r) {
          final fx = r.world.componentsOf<ShaderEffect>();
          return [
            for (var i = 0; i < fx.length; i++)
              if (fx.denseAt(i).kind == ShaderEffect.seal) fx.denseAt(i).params,
          ];
        }

        final r = await stage();
        expect(seals(r).map((p) => p[0]), [
          1,
          0,
          0,
          0,
          0,
        ], reason: 'the first is lit');
        for (var i = 0; i < 3; i++) {
          r.tap(r.optionRight);
          r.run(0.1);
          r.tap('Next');
          r.run(0.1);
        }
        expect(
          seals(r).map((p) => p[0]),
          [2, 2, 1, 0, 0],
          reason:
              'on the fourth question the window has moved one along: two done, this one, two to come',
        );
        expect(r.world.componentsOf<eng.Sprite>().length, 0);

        final endless = await Rig.make();
        endless.kit.session.begin(
          QuizRound.endless(
            endless.kit.factory,
            const EndlessMode(),
            seedBase: 'e',
          ),
        );
        await endless.open(QuizGameScreen(endless.kit));
        expect(
          seals(endless),
          isEmpty,
          reason: 'endless has no length to show',
        );
      },
    );

    test(
      'the card and each option are gilded cartouches drawn by a shader, not images',
      () async {
        final r = await stage();
        final fx = r.world.componentsOf<ShaderEffect>();
        final shapes = [
          for (var i = 0; i < fx.length; i++)
            if (fx.denseAt(i).kind == ShaderEffect.cartouche)
              fx.denseAt(i).params[0],
        ];
        expect(shapes.where((p) => p == 2).length, 1, reason: 'the poem card');
        expect(
          shapes.where((p) => p == 0).length,
          5,
          reason: 'four options and the hint, all banners',
        );
        expect(
          r.world.componentsOf<eng.Sprite>().length,
          0,
          reason: 'no art files',
        );
      },
    );

    test('shows the HUD, the poem with its blank and four options', () async {
      final r = await stage();
      expect(r.hasPart(QuizScreen.blank), isTrue);
      for (final o in r.kit.session.question!.options) {
        expect(r.has(o), isTrue, reason: o);
      }
      expect(r.has('Score 0'), isTrue);
      expect(r.has('Streak 0'), isTrue);
      expect(r.has('coins 60'.replaceAll('coins 60', 'coins 60')), isTrue);
      expect(r.hasPart('Hint'), isTrue);
    });

    test(
      'a stage shows no lives or clock, only score, streak and coins',
      () async {
        final r = await stage();
        expect(r.hasPart('Lives'), isFalse);
        expect(r.hasPart('Time'), isFalse);
      },
    );

    test(
      'the blank is drawn with plain underscores that a line cannot break inside',
      () async {
        final r = await stage();
        final line = r.texts.firstWhere((t) => t.contains(QuizScreen.blank));
        expect(line.contains('＿'), isFalse);
      },
    );

    test(
      'the game is blue paper with clouds and blossoms, and lights the poem card',
      () async {
        final r = await stage();
        final fx = r.world.componentsOf<ShaderEffect>();
        final kinds = [for (var i = 0; i < fx.length; i++) fx.denseAt(i).kind];
        expect(kinds, contains(ShaderEffect.lapis));
        expect(kinds, isNot(contains(ShaderEffect.aurora)));
        expect(kinds.where((k) => k == ShaderEffect.cloud), hasLength(3));
        expect(kinds.where((k) => k == ShaderEffect.blossom), hasLength(2));
        // The gold light behind the card and the pen of light that rides on the
        // writing.
        expect(kinds.where((k) => k == ShaderEffect.glow), hasLength(2));
        expect(kinds.where((k) => k == ShaderEffect.dust), hasLength(1));
      },
    );

    test(
      'a pen of light follows the word being written, then goes out',
      () async {
        final r = await stage();
        final fx = r.world.componentsOf<ShaderEffect>();
        final pos = r.world.componentsOf<Position>();
        Position? pen() {
          for (var i = 0; i < fx.length; i++) {
            final e = fx.denseAt(i);
            if (e.kind == ShaderEffect.glow && e.coreArgb == 0xFFFFE08A) {
              return pos.get(fx.entityAt(i));
            }
          }
          return null;
        }

        r.run(0.4);
        expect(
          pen()!.x,
          greaterThan(0),
          reason: 'it sits on a word being written',
        );
        r.run(2);
        expect(
          pen()!.x,
          lessThan(0),
          reason: 'and is out once the poem is written',
        );
      },
    );

    test('the poem is written word by word, then stays', () async {
      final r = await stage();
      List<double> poem() {
        final t = r.world.componentsOf<eng.Text>();
        return [
          for (var i = 0; i < t.length; i++)
            if (t.denseAt(i).fontSize != 13 &&
                !t.denseAt(i).text.startsWith('Hint') &&
                !r.kit.session.question!.options.contains(t.denseAt(i).text))
              t.denseAt(i).alpha,
        ];
      }

      r.run(0.2);
      final early = poem();
      expect(early.length, greaterThan(3));
      expect(early.first, greaterThan(0), reason: 'the first word is in');
      expect(early.last, 0, reason: 'the last word is not written yet');
      r.run(4);
      expect(poem().every((a) => a == 1), isTrue);
    });

    test('the whole poem is written within a second and a half', () async {
      final r = await stage();
      List<double> poem() {
        final t = r.world.componentsOf<eng.Text>();
        return [
          for (var i = 0; i < t.length; i++)
            if (t.denseAt(i).fontSize != 13 &&
                !t.denseAt(i).text.startsWith('Hint') &&
                !r.kit.session.question!.options.contains(t.denseAt(i).text))
              t.denseAt(i).alpha,
        ];
      }

      r.run(1.55);
      expect(poem().every((a) => a == 1), isTrue);
    });

    test('a verse too long for one row is written word by word too', () async {
      final r = await Rig.make(bank: makeBank(wordsPerLine: 14));
      r.kit.session.begin(
        QuizRound.stage(
          r.kit.factory,
          const StageMode(),
          author: 'a',
          tier: QuizTier.easy,
        ),
      );
      await r.open(QuizGameScreen(r.kit));
      List<double> poem() {
        final t = r.world.componentsOf<eng.Text>();
        return [
          for (var i = 0; i < t.length; i++)
            if (t.denseAt(i).fontSize != 13 &&
                !t.denseAt(i).text.startsWith('Hint') &&
                !r.kit.session.question!.options.contains(t.denseAt(i).text))
              t.denseAt(i).alpha,
        ];
      }

      r.run(0.2);
      final early = poem();
      expect(early.length, greaterThan(20));
      expect(early.last, 0, reason: 'the end of the poem is not written yet');
      r.run(1.6);
      expect(poem().every((a) => a == 1), isTrue);
    });

    test(
      'a long poem squeezes the options so none runs into the hint',
      () async {
        final r = await Rig.make(bank: makeBank(wordsPerLine: 14));
        r.kit.session.begin(
          QuizRound.stage(
            r.kit.factory,
            const StageMode(),
            author: 'a',
            tier: QuizTier.easy,
          ),
        );
        await r.open(QuizGameScreen(r.kit));
        final fx = r.world.componentsOf<ShaderEffect>();
        final pos = r.world.componentsOf<Position>();
        final banners = <(double, double)>[];
        for (var i = 0; i < fx.length; i++) {
          final e = fx.denseAt(i);
          if (e.kind == ShaderEffect.cartouche && e.params[0] == 0) {
            final y = pos.get(fx.entityAt(i))!.y;
            banners.add((y - e.height / 2, y + e.height / 2));
          }
        }
        banners.sort((a, b) => a.$1.compareTo(b.$1));
        expect(banners, hasLength(5), reason: 'four options and the hint');
        for (var i = 1; i < banners.length; i++) {
          expect(
            banners[i].$1,
            greaterThanOrEqualTo(banners[i - 1].$2),
            reason: 'banner $i must start below the one above it',
          );
        }
      },
    );

    test('every next question is written again, both verses', () async {
      final r = await stage();
      List<double> poem() {
        final t = r.world.componentsOf<eng.Text>();
        return [
          for (var i = 0; i < t.length; i++)
            if (t.denseAt(i).fontSize != 13 &&
                !t.denseAt(i).text.startsWith('Hint') &&
                !r.kit.session.question!.options.contains(t.denseAt(i).text))
              t.denseAt(i).alpha,
        ];
      }

      r.run(2);
      r.tap(r.optionRight);
      r.run(0.2);
      r.tap('Next');
      r.run(0.2);
      final early = poem();
      expect(early.length, greaterThan(3));
      expect(early.first, greaterThan(0));
      expect(early.last, 0, reason: 'the second verse is written too');
      r.run(1.6);
      expect(poem().every((a) => a == 1), isTrue);
    });

    test(
      'the card leaves room under the last line for the corner blossoms',
      () async {
        final r = await stage();
        r.run(4);
        final fx = r.world.componentsOf<ShaderEffect>();
        final pos = r.world.componentsOf<Position>();
        late double bottom;
        for (var i = 0; i < fx.length; i++) {
          final e = fx.denseAt(i);
          if (e.kind == ShaderEffect.cartouche && e.params[0] == 2) {
            bottom = pos.get(fx.entityAt(i))!.y + e.height / 2 - 14;
          }
        }
        final texts = r.world.componentsOf<eng.Text>();
        var lowest = -1e9;
        for (var i = 0; i < texts.length; i++) {
          final t = texts.denseAt(i);
          final y = pos.get(texts.entityAt(i))!.y;
          if (t.fontSize >= 18 && y < bottom && y > lowest) lowest = y;
        }
        expect(bottom - lowest, greaterThanOrEqualTo(60));
      },
    );

    test(
      'a used hint leaves no pale box round the removed options or itself',
      () async {
        final r = await stage();
        r.run(4);
        r.buyHint();
        r.run(0.1);
        final shapes = r.world.componentsOf<Shape>();
        for (var i = 0; i < shapes.length; i++) {
          final sh = shapes.denseAt(i);
          if (sh.kind == ShapeKind.roundedRect &&
              sh.width > 150 &&
              sh.height < 80) {
            expect(sh.alpha, 0, reason: 'button plates stay invisible');
          }
        }
      },
    );

    test('a hint redraw does not restart the writing', () async {
      final r = await stage();
      r.run(4);
      r.buyHint();
      r.run(0.1);
      final t = r.world.componentsOf<eng.Text>();
      for (var i = 0; i < t.length; i++) {
        final x = t.denseAt(i);
        if (x.fontSize == 20 &&
            !r.kit.session.question!.options.contains(x.text)) {
          expect(x.alpha, 1, reason: '"${x.text}" ${x.fontSize}');
        }
      }
    });

    test(
      'answers and the armed hint give haptic feedback, unless turned off',
      () async {
        Rig.buzzes.clear();
        final r = await stage();
        r.run(4);
        r.tap(r.optionRight);
        r.run(0.2);
        expect(Rig.buzzes, [QuizHaptic.correct]);
        r.run(0.2);

        Rig.buzzes.clear();
        final w = await stage();
        w.run(4);
        w.tap(w.optionWrong(0));
        w.run(0.2);
        expect(Rig.buzzes, [QuizHaptic.wrong]);

        Rig.buzzes.clear();
        final h = await stage();
        h.run(4);
        h.tap(h.texts.firstWhere((t) => t.contains('Hint')));
        expect(Rig.buzzes, [QuizHaptic.tap]);

        Rig.buzzes.clear();
        final off = await stage();
        off.kit.settings.setHaptics(false);
        off.run(4);
        off.tap(off.optionRight);
        off.run(0.2);
        expect(Rig.buzzes, isEmpty);
      },
    );

    test('the right option is lit up, not just filled', () async {
      final r = await stage();
      int glows() {
        final fx = r.world.componentsOf<ShaderEffect>();
        return [
          for (var i = 0; i < fx.length; i++) fx.denseAt(i).kind,
        ].where((k) => k == ShaderEffect.glow).length;
      }

      expect(glows(), 2);
      r.tap(r.optionRight);
      r.run(0.1);
      expect(glows(), 3, reason: 'the right option glows as well');
    });

    test('an answer throws a burst of sparks that then fades away', () async {
      final r = await stage();
      int shapes() => r.world.componentsOf<Shape>().length;
      final before = shapes();
      r.tap(r.optionRight);
      r.run(0.1);
      final peak = shapes();
      expect(peak, greaterThan(before + 20));
      r.run(2);
      expect(shapes(), lessThan(peak - 20), reason: 'the sparks are gone');
    });

    test('the right answer fills the blank, scores, and offers Next', () async {
      final r = await stage();
      final right = r.optionRight;
      r.tap(right);
      r.run(0.1);
      expect(r.hasPart(QuizScreen.blank), isFalse);
      expect(r.has('Score 10'), isTrue);
      expect(r.has('Streak 1'), isTrue);
      expect(r.has('Next'), isTrue);
      final other = r.kit.session.question!.options.firstWhere(
        (o) => o != right,
      );
      r.tap(other); // options are disabled after an answer
      expect(r.kit.session.round!.run.answers.length, 1);
    });

    test(
      'a wrong answer resets the streak and still shows the right word',
      () async {
        final r = await stage();
        r.tap(r.optionRight);
        r.run(0.1);
        r.tap('Next');
        r.run(0.1);
        r.tap(r.optionWrong(0));
        r.run(0.1);
        expect(r.has('Streak 0'), isTrue);
        expect(r.has('Score 10'), isTrue);
      },
    );

    test('one tap on the hint only arms it; a second tap buys', () async {
      final r = await stage();
      r.tap(r.texts.firstWhere((t) => t.contains('Hint')));
      r.run(0.1);
      expect(r.kit.session.progress.coins, 60, reason: 'nothing spent yet');
      final armed = r.world.componentsOf<eng.Text>();
      expect(
        [
          for (var i = 0; i < armed.length; i++)
            if (armed.denseAt(i).text.contains('Hint'))
              armed.denseAt(i).colorArgb,
        ],
        contains(QuizGameScreen.hintArmedInk),
        reason: 'the banner shows it is armed',
      );
      r.tap(r.texts.firstWhere((t) => t.contains('Hint')));
      expect(r.kit.session.progress.coins, 40);
    });

    test('an armed hint disarms itself after a moment', () async {
      final r = await stage();
      r.tap(r.texts.firstWhere((t) => t.contains('Hint')));
      r.run(QuizGameScreen.hintConfirmSeconds + 0.5);
      final after = r.world.componentsOf<eng.Text>();
      expect([
        for (var i = 0; i < after.length; i++)
          if (after.denseAt(i).text.contains('Hint'))
            after.denseAt(i).colorArgb,
      ], isNot(contains(QuizGameScreen.hintArmedInk)));
      r.tap(r.texts.firstWhere((t) => t.contains('Hint')));
      expect(r.kit.session.progress.coins, 60, reason: 'first tap again');
    });

    test('the hint costs coins, removes two options and disappears', () async {
      final r = await stage();
      r.buyHint();
      r.run(0.1);
      expect(r.kit.session.progress.coins, 40);
      expect(r.kit.session.question!.removedByHint.length, 2);
      expect(r.has('coins 40'), isTrue);
      expect(r.kit.session.canHint, isFalse);
      final removed = r
          .kit
          .session
          .question!
          .options[r.kit.session.question!.removedByHint.first];
      r.tap(removed);
      expect(r.kit.session.answered, isFalse);
    });

    test('finishing the round opens the result', () async {
      final r = await stage();
      for (var i = 0; i < 25; i++) {
        r.tap(r.optionRight);
        r.run(0.1);
        r.tap('Next');
        r.run(0.1);
      }
      expect(r.loaded, isA<QuizResultScreen>());
    });

    test(
      'the race clock runs from update and ends the round at zero',
      () async {
        final r = await Rig.make();
        r.kit.session.begin(
          QuizRound.race(r.kit.factory, const RaceMode(), seedBase: 'race:t'),
        );
        await r.open(QuizGameScreen(r.kit));
        expect(r.has('Time 60'), isTrue);
        expect(r.hasPart('Hint'), isFalse);
        r.run(10);
        expect(r.has('Time 50'), isTrue);
        r.run(55);
        expect(r.loaded, isA<QuizResultScreen>());
      },
    );
  });

  group('endless continue', () {
    Future<Rig> endless({bool ads = true, bool earns = true}) async {
      final r = await Rig.make(ads: ads, earns: earns);
      r.kit.session.begin(
        QuizRound.endless(
          r.kit.factory,
          const EndlessMode(),
          seedBase: 'endless:t',
        ),
      );
      await r.open(QuizGameScreen(r.kit));
      return r;
    }

    Future<void> lose(Rig r, int n) async {
      for (var i = 0; i < n; i++) {
        r.tap(r.optionWrong(0));
        r.run(0.1);
        r.tap('Next');
        r.run(0.1);
      }
    }

    test('after the last life an ad can give one more, once', () async {
      final r = await endless();
      await lose(r, 3);
      expect(r.has('Out of lives. One more for an ad?'), isTrue);
      expect(r.kit.session.finished, isFalse);
      r.tap('Continue with an ad');
      await Future<void>.delayed(Duration.zero);
      r.run(0.1);
      expect(r.ads.shown, ['continue']);
      expect(r.kit.session.round!.run.lives, 1);
      expect(r.has('Out of lives. One more for an ad?'), isFalse);
      await lose(r, 1);
      expect(r.has('Out of lives. One more for an ad?'), isFalse);
      expect(r.loaded, isA<QuizResultScreen>());
    });

    test(
      'closing the ad early ends the round; saying no shows no ad',
      () async {
        final r = await endless(earns: false);
        await lose(r, 3);
        r.tap('Continue with an ad');
        await Future<void>.delayed(Duration.zero);
        r.run(0.1);
        expect(r.loaded, isA<QuizResultScreen>());
        final r2 = await endless();
        await lose(r2, 3);
        r2.tap('No, finish');
        r2.run(0.1);
        expect(r2.ads.shown, isEmpty);
        expect(r2.loaded, isA<QuizResultScreen>());
      },
    );

    test('with no ad ready the round just ends', () async {
      final r = await endless(ads: false);
      await lose(r, 3);
      r.run(0.1);
      expect(r.loaded, isA<QuizResultScreen>());
    });
  });

  group('menu screens', () {
    test(
      'a taller screen spreads the home layout over its whole height',
      () async {
        double aboutY(Rig r) => r._at('About').y;

        final short = await Rig.make(bank: makeMultiBank());
        await short.open(QuizHomeScreen(short.kit));
        final tall = await Rig.make(bank: makeMultiBank())
          ..worldHeight = 780;
        await tall.open(QuizHomeScreen(tall.kit));
        expect(aboutY(tall) - aboutY(short), closeTo(140 * 0.92, 1));
      },
    );

    test(
      'home: coins, the poets shelf, the daily card and the modes',
      () async {
        final r = await Rig.make(bank: makeMultiBank());
        await r.open(QuizHomeScreen(r.kit));
        expect(r.has('60 coins'), isTrue);
        for (final t in [
          'Wall of divans',
          'About',
          'Poet a',
          'Poet b',
          'Poet c',
        ]) {
          expect(r.has(t), isTrue, reason: t);
        }
        expect(
          r.texts.any((x) => x.contains('complete')),
          isFalse,
          reason: 'no "n of m complete" line on the menu',
        );
        expect(r.hasPart('Daily'), isTrue);
        expect(r.has('Continue'), isTrue);
        expect(r.has('Poet a · Easy'), isTrue);
        expect(r.has('Endless'), isTrue);
        expect(r.has('Race'), isTrue);
        final played = await Rig.make(
          setup: (p) =>
              p.daily.results['2026-11-17'] = [true, true, false, true, true],
        );
        await played.open(QuizHomeScreen(played.kit));
        expect(played.has('Done'), isTrue);
        expect(played.hasPart('✅'), isFalse);
        expect(played.hasPart('❌'), isFalse);
        expect(played.hasPart('Next in'), isFalse);
        expect(played.hasPart('Five new poems'), isFalse);
      },
    );

    test(
      'Continue goes on with the first stage not yet passed, and the shelf shows progress',
      () async {
        final r = await Rig.make(
          bank: makeMultiBank(),
          setup: (p) {
            p.stages['a'] = {
              for (final t in QuizTier.values)
                t.name: StageProgress(stars: 3, attempts: 1, passedOnce: true),
            };
            p.stages['b'] = {
              'easy': StageProgress(stars: 2, attempts: 2, passedOnce: true),
            };
          },
        );
        await r.open(QuizHomeScreen(r.kit));

        expect(r.has('Poet b · Medium'), isTrue);
        r.tap('Continue');
        expect(r.loaded, isA<QuizGameScreen>());
        expect(r.kit.session.round!.author, 'b');
        expect(r.kit.session.round!.tier, QuizTier.medium);
        expect(r.kit.session.round!.run.seedBase, endsWith(':1'));
      },
    );

    test(
      'nextStage falls back to the last author hardest stage when everything is passed',
      () async {
        final r = await Rig.make(
          bank: makeMultiBank(authors: 2),
          setup: (p) {
            for (final a in ['a', 'b']) {
              p.stages[a] = {
                for (final t in QuizTier.values)
                  t.name: StageProgress(
                    stars: 3,
                    attempts: 1,
                    passedOnce: true,
                  ),
              };
            }
          },
        );
        final n = nextStage(r.kit.bank, r.kit.session.progress);
        expect((n.author.id, n.tier), ('b', QuizTier.literary));
      },
    );

    test(
      'home buttons start the daily and the next stage, and open settings and about',
      () async {
        Future<Scene?> press(String t) async {
          final r = await Rig.make(ads: true);
          await r.open(QuizHomeScreen(r.kit));
          r.tap(t);
          await Future<void>.delayed(Duration.zero);
          return r.loaded;
        }

        expect(await press('About'), isA<QuizAboutScreen>());
        expect(await press('⚙'), isA<QuizSettingsScreen>());
        final daily = await Rig.make();
        await daily.open(QuizHomeScreen(daily.kit));
        daily.tap('Daily · Five new poems');
        expect(daily.loaded, isA<QuizGameScreen>());
        expect(daily.kit.session.round!.date, '2026-11-17');
        final go = await Rig.make();
        await go.open(QuizHomeScreen(go.kit));
        go.tap('Continue');
        expect(go.loaded, isA<QuizGameScreen>());
        expect(go.kit.session.round!.author, 'a');
        for (final (label, mode) in [
          ('Endless', EndlessMode),
          ('Race', RaceMode),
        ]) {
          final m = await Rig.make();
          await m.open(QuizHomeScreen(m.kit));
          m.tap(label);
          expect(m.loaded, isA<QuizGameScreen>(), reason: label);
          expect(m.kit.session.round!.mode.runtimeType, mode, reason: label);
        }
      },
    );

    test(
      'the menu is blue paper with clouds, gilded cards and blossoms, and a light on the next poet',
      () async {
        final r = await Rig.make(bank: makeMultiBank());
        await r.open(QuizHomeScreen(r.kit));
        final fx = r.world.componentsOf<ShaderEffect>();
        final kinds = [for (var i = 0; i < fx.length; i++) fx.denseAt(i).kind];
        expect(kinds.where((k) => k == ShaderEffect.lapis), hasLength(1));
        expect(kinds.where((k) => k == ShaderEffect.aurora), isEmpty);
        expect(kinds.where((k) => k == ShaderEffect.glow), hasLength(3));
        expect(kinds.where((k) => k == ShaderEffect.cloud), hasLength(3));
        expect(kinds.where((k) => k == ShaderEffect.blossom), hasLength(2));
        final cards = [
          for (var i = 0; i < fx.length; i++) fx.denseAt(i),
        ].where((e) => e.kind == ShaderEffect.cartouche && e.params[0] == 1);
        expect(cards, hasLength(3), reason: 'one arched card for each poet');
        expect(
          cards.where((e) => e.params[1] > 0),
          hasLength(1),
          reason: 'only the next poet gleams',
        );
        final sky = [
          for (var i = 0; i < fx.length; i++) fx.denseAt(i),
        ].firstWhere((e) => e.kind == ShaderEffect.lapis);
        expect(sky.zIndex, greaterThan(-10));
        expect(
          sky.width,
          greaterThan(QuizScreen.worldWidth * 2),
          reason: 'a wide window shows sky at its sides, not bare bars',
        );
        expect(
          sky.params[0],
          QuizScreen.worldWidth,
          reason: 'the grain stays the size it has on a phone',
        );
      },
    );

    test(
      'with card art the cards are the pictures, at their own proportions',
      () async {
        const art = QuizCardArt(
          atlasId: 'cards',
          width: 240,
          height: 405,
          authors: {'a', 'b'},
        );
        final r = await Rig.make(bank: makeMultiBank(), cardArt: art);
        await r.open(QuizHomeScreen(r.kit));
        final sprites = r.world.componentsOf<eng.Sprite>();
        expect(
          sprites.length,
          2,
          reason: 'a and b have one, c has the shader card',
        );
        for (var i = 0; i < sprites.length; i++) {
          final s = sprites.denseAt(i);
          expect(s.atlasId, 'cards');
          expect(s.scaleX, s.scaleY, reason: 'never stretched');
          expect(240 * s.scaleX, closeTo(62, 0.001));
          expect(405 * s.scaleY, closeTo(art.heightFor(62), 0.001));
        }
        expect(art.heightFor(62), closeTo(104.6, 0.1));
        final fx = r.world.componentsOf<ShaderEffect>();
        final arches = [
          for (var i = 0; i < fx.length; i++)
            if (fx.denseAt(i).kind == ShaderEffect.cartouche &&
                fx.denseAt(i).params[0] == 1)
              fx.denseAt(i),
        ];
        expect(arches, hasLength(1), reason: 'only c is still a shader card');
        r.tap('Poet a');
        expect(
          r.world.componentsOf<BackdropBlur>().length,
          1,
          reason: 'still tappable',
        );
      },
    );

    test('with portraits the shelf draws each face with a shader', () async {
      List<ShaderEffect> portraits(Rig r) {
        final fx = r.world.componentsOf<ShaderEffect>();
        return [
          for (var i = 0; i < fx.length; i++)
            if (fx.denseAt(i).kind == ShaderEffect.portrait) fx.denseAt(i),
        ];
      }

      final plain = await Rig.make(bank: makeMultiBank());
      await plain.open(QuizHomeScreen(plain.kit));
      expect(portraits(plain), isEmpty);

      final r = await Rig.make(
        bank: makeMultiBank(),
        portraits: const QuizPortraits({
          'a': QuizPortraitStyle(beard: 22),
          'b': QuizPortraitStyle(headwear: QuizHeadwear.scarf, woman: true),
        }),
      );
      await r.open(QuizHomeScreen(r.kit));
      final drawn = portraits(r);
      expect(drawn.length, 2, reason: 'a and b have one, c does not');
      expect(
        drawn.map((e) => e.params).toSet(),
        {
          [22.0, 1.0, 0.0, 0.0],
          [0.0, 1.0, 6.0, 8.0],
        },
        reason: 'the style reaches the shader as numbers',
      );
      expect(r.world.componentsOf<eng.Sprite>().length, 0, reason: 'no images');
    });

    test(
      'starting a game plays the veil: it covers the menu, then lifts off the game',
      () async {
        ShaderEffect? veil(Rig r) {
          final fx = r.world.componentsOf<ShaderEffect>();
          for (var i = 0; i < fx.length; i++) {
            final k = fx.denseAt(i).kind;
            if (k == ShaderEffect.curtain ||
                k == ShaderEffect.kashi ||
                k == ShaderEffect.ink ||
                k == ShaderEffect.veil) {
              return fx.denseAt(i);
            }
          }
          return null;
        }

        final r = await Rig.make(bank: makeMultiBank(), transitions: true);
        await r.open(QuizHomeScreen(r.kit));
        expect(veil(r), isNull);
        r.tap('Continue');
        expect(
          r.loaded,
          isNull,
          reason: 'the game waits for the veil to cover',
        );
        expect(veil(r), isNotNull);
        r.run(0.3);
        final half = veil(r)!.params[0];
        expect(half, greaterThan(0.3));
        expect(half, lessThan(1));
        r.tap('Daily · Five new poems');
        expect(
          r.kit.session.round!.mode,
          isNot(isA<DailyMode>()),
          reason: 'taps are ignored under the veil',
        );
        r.run(0.5);
        expect(r.loaded, isA<QuizGameScreen>());

        final next = await Rig.make(bank: makeMultiBank(), transitions: true);
        next.kit.veilPending = true;
        next.kit.session.begin(
          QuizRound.endless(
            next.kit.factory,
            const EndlessMode(),
            seedBase: 's',
          ),
        );
        await next.open(QuizGameScreen(next.kit));
        expect(veil(next)!.params[0], 1, reason: 'the game starts covered');
        next.run(0.3);
        expect(veil(next)!.params[0], lessThan(0.7));
        next.run(1);
        expect(veil(next), isNull, reason: 'and the veil is gone');
      },
    );

    test(
      'going back from the game to the menu has a transition too, in either style',
      () async {
        for (final kind in [
          ShaderEffect.curtain,
          ShaderEffect.kashi,
          ShaderEffect.ink,
          ShaderEffect.veil,
        ]) {
          final r = await Rig.make(
            bank: makeMultiBank(),
            transitions: true,
            transitionKind: kind,
          );
          r.kit.session.begin(
            QuizRound.endless(
              r.kit.factory,
              const EndlessMode(),
              seedBase: 's',
            ),
          );
          await r.open(QuizGameScreen(r.kit));
          r.run(1);
          r.tap('←');
          expect(r.loaded, isNull, reason: '$kind: waits for the cover');
          final fx = r.world.componentsOf<ShaderEffect>();
          final kinds = [
            for (var i = 0; i < fx.length; i++) fx.denseAt(i).kind,
          ];
          expect(kinds, contains(kind), reason: 'drawn with the chosen shader');
          r.run(1);
          expect(r.loaded, isA<QuizHomeScreen>());
          expect(r.kit.veilPending, isTrue);

          final home = await Rig.make(
            bank: makeMultiBank(),
            transitions: true,
            transitionKind: kind,
          );
          home.kit.veilPending = true;
          await home.open(QuizHomeScreen(home.kit));
          final hfx = home.world.componentsOf<ShaderEffect>();
          expect(
            [for (var i = 0; i < hfx.length; i++) hfx.denseAt(i).kind],
            contains(kind),
            reason: 'the menu starts covered',
          );
          home.run(1);
          expect(home.kit.veilPending, isFalse);
        }
      },
    );

    test(
      'the verse transition swirls poem words over an ink wash, then clears them',
      () async {
        final r = await Rig.make(
          bank: makeMultiBank(),
          transitions: true,
          transitionKind: quizVerseTransition,
        );
        await r.open(QuizHomeScreen(r.kit));
        final before = r.world.componentsOf<eng.Text>().length;
        r.tap('Continue');
        final words = r.world.componentsOf<eng.Text>().length - before;
        expect(words, greaterThan(30), reason: 'a page of words was spawned');
        final fx = r.world.componentsOf<ShaderEffect>();
        expect([
          for (var i = 0; i < fx.length; i++) fx.denseAt(i).kind,
        ], contains(ShaderEffect.ink));
        r.run(0.3);
        final texts = r.world.componentsOf<eng.Text>();
        final seen = [
          for (var i = 0; i < texts.length; i++) texts.denseAt(i).alpha,
        ].where((a) => a > 0 && a < 1.01).length;
        expect(seen, greaterThan(10), reason: 'words are fading in');
        r.run(0.6);
        expect(r.loaded, isA<QuizGameScreen>());
        expect(
          r.world.componentsOf<eng.Text>().length,
          before,
          reason: 'the words are gone',
        );
      },
    );

    test(
      'the page turn hands the screen to the engine as a snapshot that curls away',
      () async {
        final r = await Rig.make(
          bank: makeMultiBank(),
          transitions: true,
          transitionKind: quizPageTurnTransition,
        );
        await r.open(QuizHomeScreen(r.kit));
        r.tap('Continue');
        expect(
          r.loaded,
          isA<QuizGameScreen>(),
          reason: 'the next screen loads at once, no cover phase',
        );
        expect(r.loadedWith?.type, SceneTransitionType.pageTurn);
        final fx = r.world.componentsOf<ShaderEffect>();
        expect(
          [for (var i = 0; i < fx.length; i++) fx.denseAt(i).kind],
          isNot(contains(ShaderEffect.veil)),
          reason: 'no overlay is drawn by the screen itself',
        );
      },
    );

    test(
      'going back to the menu is carried up on lanterns by the engine',
      () async {
        final r = await Rig.make(
          bank: makeMultiBank(),
          transitions: true,
          transitionKind: quizPageTurnTransition,
          returnTransitionKind: quizLanternsTransition,
        );
        r.kit.session.begin(
          QuizRound.endless(r.kit.factory, const EndlessMode(), seedBase: 's'),
        );
        await r.open(QuizGameScreen(r.kit));
        r.run(1);
        r.tap('←');
        expect(
          r.loaded,
          isA<QuizHomeScreen>(),
          reason: 'the menu is loaded at once, underneath',
        );
        expect(r.loadedWith?.type, SceneTransitionType.lanterns);
        expect(r.kit.veilPending, isFalse, reason: 'no overlay to lift');
      },
    );

    test('the ripple starts where the player touched', () async {
      final r = await Rig.make(
        bank: makeMultiBank(),
        transitions: true,
        transitionKind: quizRippleTransition,
      );
      await r.open(QuizHomeScreen(r.kit));
      r.tap('Continue');
      expect(r.loadedWith?.type, SceneTransitionType.ripple);
      final cfg = r.loadedWith!;
      final p = r._at('Continue');
      expect(cfg.originX, closeTo(p.x / 360, 0.08));
      expect(cfg.originY, closeTo(p.y / r.world.height, 0.08));
    });

    test(
      'after an overlay transition the screen takes no taps for 0.1 s more',
      () async {
        final r = await Rig.make(
          bank: makeMultiBank(),
          transitions: true,
          transitionKind: ShaderEffect.curtain,
        );
        r.kit.session.begin(
          QuizRound.endless(r.kit.factory, const EndlessMode(), seedBase: 's'),
        );
        r.kit.veilPending = true;
        await r.open(QuizGameScreen(r.kit));
        r.run(0.65);
        expect(
          r.kit.inputGrace,
          greaterThan(0),
          reason: 'the veil has just lifted',
        );
        r.tap(r.optionRight);
        expect(
          r.kit.session.answered,
          isFalse,
          reason: 'a tap in the grace does nothing',
        );
        r.run(0.15);
        r.tap(r.optionRight);
        expect(r.kit.session.answered, isTrue, reason: 'afterwards it counts');
      },
    );

    test(
      'cards show no emblem or stage dots; the medal adds the epithet and an emblem',
      () async {
        List<ShaderEffect> emblems(Rig r) {
          final fx = r.world.componentsOf<ShaderEffect>();
          return [
            for (var i = 0; i < fx.length; i++)
              if (fx.denseAt(i).kind == ShaderEffect.emblem) fx.denseAt(i),
          ];
        }

        final r = await Rig.make(
          bank: makeMultiBank(),
          portraits: const QuizPortraits({
            'a': QuizPortraitStyle(
              emblem: QuizEmblem.cup,
              epithet: 'Tongue of the Unseen',
            ),
            'b': QuizPortraitStyle(
              emblem: QuizEmblem.rose,
              epithet: 'Master of Speech',
            ),
          }),
        );
        await r.open(QuizHomeScreen(r.kit));
        expect(
          emblems(r),
          isEmpty,
          reason: 'the gilded cards carry a portrait and a name, no emblem',
        );
        final shapes = r.world.componentsOf<Shape>();
        var pips = 0;
        for (var i = 0; i < shapes.length; i++) {
          final sh = shapes.denseAt(i);
          if (sh.kind == ShapeKind.ring && sh.width == 7) pips++;
        }
        expect(pips, 0, reason: 'the four little stage dots are gone');

        r.tap('Poet a');
        r.run(1);
        expect(
          r.has('Tongue of the Unseen'),
          isTrue,
          reason: 'the epithet is under the name',
        );
        expect(
          emblems(r).length,
          1,
          reason: 'the medal brings its own larger emblem',
        );
      },
    );

    test(
      'the medal header carries the poet\'s own card as a stamp, not the emblem',
      () async {
        const art = QuizCardArt(
          atlasId: 'cards',
          width: 240,
          height: 405,
          authors: {'a'},
        );
        final r = await Rig.make(
          bank: makeMultiBank(),
          cardArt: art,
          portraits: const QuizPortraits({
            'a': QuizPortraitStyle(emblem: QuizEmblem.cup, epithet: 'E'),
          }),
        );
        await r.open(QuizHomeScreen(r.kit));
        final before = r.world.componentsOf<eng.Sprite>().length;
        r.tap('Poet a');
        r.run(2);
        final sprites = r.world.componentsOf<eng.Sprite>();
        expect(sprites.length, before + 1, reason: 'a stamp joins the card');
        final fx = r.world.componentsOf<ShaderEffect>();
        for (var i = 0; i < fx.length; i++) {
          expect(fx.denseAt(i).kind, isNot(ShaderEffect.emblem));
        }
      },
    );

    test(
      'tapping a poet blurs the screen and opens a medal with the levels',
      () async {
        final r = await Rig.make(bank: makeMultiBank());
        await r.open(QuizHomeScreen(r.kit));
        expect(r.world.componentsOf<BackdropBlur>().length, 0);
        final before = r.world.componentsOf<ShaderEffect>().length;
        r.tap('Poet b');
        expect(r.loaded, isNull);
        expect(r.world.componentsOf<BackdropBlur>().length, 1);
        expect(
          r.has('Stage Easy'),
          isTrue,
          reason:
              'the levels are on the medal from the first moment of the spin',
        );
        r.tap('Stage Easy');
        expect(
          r.loaded,
          isNull,
          reason: 'but cannot be pressed while it turns',
        );
        final fx = r.world.componentsOf<ShaderEffect>();
        expect(
          fx.length - before,
          greaterThan(0),
          reason: 'the medal brings its own light',
        );
        r.run(0.3);
        final mid = r.world.componentsOf<BackdropBlur>().denseAt(0).sigma;
        expect(mid, greaterThan(0));
        r.run(0.6);
        expect(r.world.componentsOf<BackdropBlur>().denseAt(0).sigma, 4);
        expect(r.has('Stage Easy'), isTrue);
        expect(r.has('Stage Literary'), isTrue);
        r.tap('Stage Easy');
        expect(r.loaded, isA<QuizGameScreen>());
        expect(r.kit.session.round!.author, 'b');
      },
    );

    test(
      'the panel unfurls from the card: wide first, then taller, with no spin',
      () async {
        final r = await Rig.make(bank: makeMultiBank());
        await r.open(QuizHomeScreen(r.kit));
        r.tap('Poet a');
        ShaderEffect panel() {
          final fx = r.world.componentsOf<ShaderEffect>();
          return [for (var i = 0; i < fx.length; i++) fx.denseAt(i)].firstWhere(
            (e) => e.kind == ShaderEffect.cartouche && e.params[0] == 3,
          );
        }

        expect(panel().blur, 1, reason: 'invisible at the start');
        final startW = panel().width;
        expect(startW, closeTo(MedalOverlay.medalW * 0.3, 0.01));
        expect(
          panel().height,
          lessThan(MedalOverlay.medalH * 0.15),
          reason: 'a thin strip before it unrolls',
        );
        r.run(0.1);
        final mid = panel();
        expect(mid.blur, inExclusiveRange(0, 1));
        expect(mid.width, greaterThan(startW));
        expect(mid.width, lessThan(MedalOverlay.medalW));
        expect(
          mid.height / MedalOverlay.medalH,
          lessThan(mid.width / MedalOverlay.medalW),
          reason: 'the height follows the width',
        );
        r.run(0.3);
        expect(panel().blur, 0);
        expect(panel().width, closeTo(MedalOverlay.medalW, 0.01));
        expect(MedalOverlay.seconds, lessThan(0.3), reason: 'brief');
      },
    );

    test(
      'a level that can be played is velvet, a locked one parchment with lozenges',
      () async {
        final r = await Rig.make(bank: makeMultiBank());
        await r.open(QuizHomeScreen(r.kit));
        r.tap('Poet a');
        r.run(0.5);
        final fx = r.world.componentsOf<ShaderEffect>();
        final banners = [
          for (var i = 0; i < fx.length; i++)
            if (fx.denseAt(i).kind == ShaderEffect.cartouche &&
                fx.denseAt(i).params[0] == 0 &&
                fx.denseAt(i).height == 62)
              fx.denseAt(i),
        ];
        expect(banners, hasLength(4));
        expect(banners.first.params[2], 0, reason: 'the open one is velvet');
        expect(banners.first.params[3], greaterThan(0), reason: 'with flowers');
        expect(banners.last.params[2], 1, reason: 'a locked one is parchment');
        expect(banners.last.params[3], lessThan(0), reason: 'with lozenges');
      },
    );

    test('tapping outside the medal spins it back to the shelf', () async {
      final r = await Rig.make(bank: makeMultiBank());
      await r.open(QuizHomeScreen(r.kit));
      r.tap('Poet b');
      r.run(1);
      r.tapAt(10, 620);
      r.run(1);
      expect(r.world.componentsOf<BackdropBlur>().length, 0);
      expect(r.has('Stage Easy'), isFalse);
      r.tap('Poet a');
      r.run(1);
      expect(r.has('Stage Easy'), isTrue);
    });

    test(
      'the clouds drift across the page and come back from a side',
      () async {
        final r = await Rig.make(bank: makeMultiBank());
        await r.open(QuizHomeScreen(r.kit));
        List<double> xs() {
          final fx = r.world.componentsOf<ShaderEffect>();
          final pos = r.world.componentsOf<Position>();
          return [
            for (var i = 0; i < fx.length; i++)
              if (fx.denseAt(i).kind == ShaderEffect.cloud)
                pos.get(fx.entityAt(i))!.x,
          ];
        }

        final before = xs();
        r.run(0.8);
        final after = xs();
        expect(after, isNot(before), reason: 'they move by themselves');
        var wrapped = false;
        for (var i = 0; i < 400 && !wrapped; i++) {
          r.run(1);
          for (final x in xs()) {
            if (x < -90 || x > 450) wrapped = true;
          }
          for (final x in xs()) {
            expect(x, inInclusiveRange(-200.0, 560.0), reason: 'never lost');
          }
        }
      },
    );

    test(
      'clouds differ in depth and fade in and out at the page edge',
      () async {
        final r = await Rig.make(bank: makeMultiBank());
        await r.open(QuizHomeScreen(r.kit));
        final sizes = <double>{};
        final opacities = <double>{};
        for (var i = 0; i < 60; i++) {
          r.run(10);
          final fx = r.world.componentsOf<ShaderEffect>();
          for (var k = 0; k < fx.length; k++) {
            final e = fx.denseAt(k);
            if (e.kind != ShaderEffect.cloud) continue;
            sizes.add(e.width);
            opacities.add(e.params[2]);
          }
        }
        expect(sizes.length, greaterThan(3), reason: 'depths differ');
        for (final o in opacities) {
          expect(o, inInclusiveRange(0.0, 0.95));
        }
        expect(opacities.reduce((a, b) => a < b ? a : b), lessThan(0.5));
        expect(opacities.reduce((a, b) => a > b ? a : b), greaterThan(0.7));
      },
    );

    test('the home has no ad button and no title on top', () async {
      final r = await Rig.make(ads: true);
      await r.open(QuizHomeScreen(r.kit));
      expect(r.has('15 coins for an ad'), isFalse);
      expect(r.has('Shaer'), isFalse);
      final g = await Rig.make();
      await g.open(QuizGameScreen(g.kit));
      expect(g.has('Shaer'), isFalse);
    });

    test(
      'stages: later ones are locked with the hint until the one before is passed',
      () async {
        final r = await Rig.make(bank: makeMultiBank());
        final author = r.kit.bank.authors.first;
        await r.open(QuizStagesScreen(r.kit, author));
        expect(r.has('☆☆☆'), isTrue);
        expect(r.texts.where((t) => t == '18 of 25 before').length, 3);
        r.tap('Stage Medium');
        expect(r.loaded, isNull, reason: 'a locked stage does nothing');
        r.tap('Stage Easy');
        expect(r.loaded, isA<QuizGameScreen>());
        expect(r.kit.session.round!.author, 'a');
      },
    );

    test('a passed stage unlocks the next and shows its stars', () async {
      final r = await Rig.make(
        bank: makeMultiBank(),
        setup: (p) {
          p.stages['a'] = {
            'easy': StageProgress(stars: 2, attempts: 3, passedOnce: true),
          };
        },
      );
      await r.open(QuizStagesScreen(r.kit, r.kit.bank.authors.first));
      expect(r.has('★★☆'), isTrue);
      expect(r.texts.where((t) => t == '18 of 25 before').length, 2);
      r.tap('Stage Medium');
      expect(r.loaded, isA<QuizGameScreen>());
      r.tap('Stage Easy');
    });

    test('settings change the theme at once and are saved', () async {
      final r = await Rig.make();
      await r.open(QuizSettingsScreen(r.kit));
      final before = r.backgroundColor;
      r.tap('Dark');
      expect(r.kit.settings.themeMode, QuizThemeMode.dark);
      final next = r.loaded!;
      final r2 = Rig(r.kit);
      await r2.open(next);
      expect(r2.backgroundColor, isNot(before));
      expect(r2.backgroundColor, 0xFF101010);
      r2.tap('Sound');
      expect(r.kit.settings.sound, isFalse);
      r2.tap('Haptics');
      expect(r.kit.settings.haptics, isFalse);
    });

    test('about shows the source lines, the link and the version', () async {
      final r = await Rig.make();
      await r.open(QuizAboutScreen(r.kit));
      expect(r.has('Poems from Ganjoor'), isTrue);
      expect(r.has('https://ganjoor.net'), isTrue);
      expect(r.has('Version: 1.0'), isTrue);
    });

    test('the about link is sienna, not web-blue, on the parchment', () async {
      final r = await Rig.make();
      await r.open(QuizAboutScreen(r.kit));
      final store = r.world.componentsOf<eng.Text>();
      final link = [
        for (var i = 0; i < store.length; i++)
          if (store.denseAt(i).text == 'https://ganjoor.net') store.denseAt(i),
      ].single;
      expect(link.colorArgb, 0xFF8A3F12);
    });

    test('tutorial: the options end above the Start banner', () async {
      final r = await Rig.make(tutorialDone: false);
      await r.open(QuizTutorialScreen(r.kit));
      final q = r.kit.factory.create(
        r.kit.bank.items(tier: QuizTier.easy).first.id,
        QuizTier.easy,
        1,
      )!;
      final texts = r.world.componentsOf<eng.Text>();
      final pos = r.world.componentsOf<Position>();
      double yOf(String t) {
        for (var i = 0; i < texts.length; i++) {
          if (texts.denseAt(i).text == t) {
            return pos.get(texts.entityAt(i))!.y;
          }
        }
        throw StateError(t);
      }

      final lastOption = q.options.map(yOf).reduce((a, b) => a > b ? a : b);
      expect(yOf('Start') - lastOption, greaterThan(56));
    });

    test(
      'tutorial: Start waits for an answer, then sets the flag and opens the menu',
      () async {
        final r = await Rig.make(tutorialDone: false);
        await r.open(QuizTutorialScreen(r.kit));
        expect(r.hasPart(QuizScreen.blank), isTrue);
        r.tap('Start');
        expect(r.loaded, isNull);
        final q = r.kit.factory.create(
          r.kit.bank.items(tier: QuizTier.easy).first.id,
          QuizTier.easy,
          1,
        )!;
        r.tap(q.options[0]);
        expect(r.hasPart(QuizScreen.blank), isFalse);
        r.tap('Start');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(r.kit.session.progress.flags['tutorialDone'], isTrue);
        expect(r.loaded, isA<QuizHomeScreen>());
      },
    );
  });

  group('result screen', () {
    Future<Rig> finished(QuizRound Function(Rig r) mk) async {
      final r = await Rig.make();
      final round = mk(r);
      r.kit.session.begin(round);
      for (var i = 0; i < 40 && !r.kit.session.finished; i++) {
        r.kit.session.answer(r.kit.session.question!.answerIndex);
        r.kit.session.next();
      }
      await r.open(QuizResultScreen(r.kit));
      return r;
    }

    test(
      'the buttons follow the card closely, with no wide empty band',
      () async {
        final r = await finished(
          (r) => QuizRound.stage(
            r.kit.factory,
            const StageMode(),
            author: 'a',
            tier: QuizTier.easy,
          ),
        );
        final texts = r.world.componentsOf<eng.Text>();
        final pos = r.world.componentsOf<Position>();
        double yOf(bool Function(String) f) {
          for (var i = 0; i < texts.length; i++) {
            if (f(texts.denseAt(i).text)) return pos.get(texts.entityAt(i))!.y;
          }
          throw StateError('missing');
        }

        final coins = yOf((t) => t.contains('Coins') || t.contains('coins'));
        expect(yOf((t) => t == 'Menu') - coins, lessThan(180));
      },
    );

    test(
      'a stage shows its score, stars and coins, and Again starts a new attempt',
      () async {
        final r = await finished(
          (r) => QuizRound.stage(
            r.kit.factory,
            const StageMode(),
            author: 'a',
            tier: QuizTier.easy,
          ),
        );
        expect(r.hasPart('Score'), isTrue);
        final fx = r.world.componentsOf<ShaderEffect>();
        final earned = [
          for (var i = 0; i < fx.length; i++)
            if (fx.denseAt(i).kind == ShaderEffect.seal &&
                fx.denseAt(i).params[0] == 2)
              fx.denseAt(i),
        ];
        expect(
          earned,
          hasLength(3),
          reason: 'three stars, drawn as ticked seals',
        );
        expect(r.has('Passed'), isTrue);
        expect(r.hasPart('Coins earned'), isTrue);
        r.tap('Again');
        expect(r.kit.session.round!.run.seedBase, endsWith(':2'));
        expect(r.loaded, isA<QuizGameScreen>());
      },
    );

    test(
      'a daily shows its marks and shares the text; copying is announced',
      () async {
        final r = await finished(
          (r) => QuizRound.daily(
            r.kit.factory,
            const DailyMode(),
            date: '2026-11-17',
          ),
        );
        final fx = r.world.componentsOf<ShaderEffect>();
        final marks = [
          for (var i = 0; i < fx.length; i++)
            if (fx.denseAt(i).kind == ShaderEffect.mark) fx.denseAt(i),
        ];
        expect(marks, hasLength(5), reason: 'one seal per question');
        expect(marks.every((m) => m.params[0] == 0), isTrue, reason: 'ticks');
        expect(r.has('✅✅✅✅✅'), isFalse, reason: 'no emoji row any more');
        expect(r.has('Again'), isFalse);
        r.tap('Share');
        await Future<void>.delayed(Duration.zero);
        expect(Rig.sharedTexts.single, contains('2026-11-17'));
        Rig.outcome = ShareOutcome.copied;
        r.tap('Share');
        await Future<void>.delayed(Duration.zero);
        expect(r.has('Copied'), isTrue);
        Rig.outcome = ShareOutcome.failed;
        r.tap('Share');
        await Future<void>.delayed(Duration.zero);
        expect(r.has('Could not share'), isTrue);
      },
    );

    test('back to the menu', () async {
      final r = await finished(
        (r) => QuizRound.endless(
          r.kit.factory,
          const EndlessMode(lives: 1),
          seedBase: 'e',
        ),
      );
      r.tap('Menu');
      expect(r.loaded, isA<QuizHomeScreen>());
    });
  });

  group('no Flutter in this package', () {
    test('no file in lib imports a Flutter library', () {
      final offenders = <String>[];
      for (final f in Directory(
        'lib',
      ).listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        for (final line in f.readAsLinesSync()) {
          if (line.startsWith("import 'package:flutter/")) {
            offenders.add('${f.path}: $line');
          }
        }
      }
      expect(offenders, isEmpty);
    });
  });
}
