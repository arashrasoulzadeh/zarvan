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
        ShaderEffect,
        Shape,
        ShareOutcome;
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
  final controller = SceneController();

  static Future<Rig> make({
    bool ads = false,
    bool earns = true,
    bool tutorialDone = true,
    DateTime? now,
    void Function(QuizProgress)? setup,
    QuizBank? bank,
    QuizPortraits? portraits,
    bool transitions = false,
    String transitionKind = 'kashi',
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
      share: (t) async {
        sharedTexts.add(t);
        return outcome;
      },
      portraits: portraits,
      transitions: transitions,
      transitionKind: transitionKind,
      now: () => now ?? DateTime(2026, 11, 17, 10),
    );
    gates[kit] = gate;
    return Rig(kit);
  }

  static final sharedTexts = <String>[];
  static ShareOutcome outcome = ShareOutcome.shared;
  static final gates = <QuizKit, FakeAds>{};
  FakeAds get ads => gates[kit]!;

  Future<void> open(Scene s) async {
    registerCoreComponents(world);
    eng.registerFlutterComponents(world);
    controller.attach(
      loadScene: (n) => loaded = n,
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
      'the card and each option are ornate shader frames, not images',
      () async {
        final r = await stage();
        final fx = r.world.componentsOf<ShaderEffect>();
        final ornate = [
          for (var i = 0; i < fx.length; i++)
            if (fx.denseAt(i).kind == ShaderEffect.ornate) fx.denseAt(i),
        ];
        expect(ornate.length, 5, reason: 'one card and four options');
        expect(ornate.where((e) => e.coreArgb == 0xFFD9B97B).length, 1);
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

    test('the game has the night sky and lights the poem card', () async {
      final r = await stage();
      final fx = r.world.componentsOf<ShaderEffect>();
      final kinds = [for (var i = 0; i < fx.length; i++) fx.denseAt(i).kind];
      expect(kinds, contains(ShaderEffect.aurora));
      expect(kinds.where((k) => k == ShaderEffect.glow), hasLength(1));
    });

    test('the poem is written word by word, then stays', () async {
      final r = await stage();
      List<double> poem() {
        final t = r.world.componentsOf<eng.Text>();
        return [
          for (var i = 0; i < t.length; i++)
            if (t.denseAt(i).fontSize == 20 &&
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
            if (t.denseAt(i).fontSize == 20 &&
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
            if (t.denseAt(i).fontSize == 20 &&
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

    test('every next question is written again, both verses', () async {
      final r = await stage();
      List<double> poem() {
        final t = r.world.componentsOf<eng.Text>();
        return [
          for (var i = 0; i < t.length; i++)
            if (t.denseAt(i).fontSize == 20 &&
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

    test('a hint redraw does not restart the writing', () async {
      final r = await stage();
      r.run(4);
      r.tap(
        r.hasPart('Hint') ? r.texts.firstWhere((t) => t.contains('Hint')) : '',
      );
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

    test('the right option is lit up, not just filled', () async {
      final r = await stage();
      int glows() {
        final fx = r.world.componentsOf<ShaderEffect>();
        return [
          for (var i = 0; i < fx.length; i++) fx.denseAt(i).kind,
        ].where((k) => k == ShaderEffect.glow).length;
      }

      expect(glows(), 1);
      r.tap(r.optionRight);
      r.run(0.1);
      expect(glows(), 2, reason: 'the card and the right option both glow');
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

    test('the hint costs coins, removes two options and disappears', () async {
      final r = await stage();
      r.tap('Hint · 20');
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
        expect(aboutY(tall) - aboutY(short), closeTo(119, 1));
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
          'Endless',
          'Race',
          'About',
          'Poet a',
          'Poet b',
          'Poet c',
        ]) {
          expect(r.has(t), isTrue, reason: t);
        }
        expect(r.has('0 of 3 complete'), isTrue);
        expect(r.hasPart('Daily'), isTrue);
        expect(r.hasPart('Continue · Poet a · Easy'), isTrue);
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
        expect(r.has('1 of 3 complete'), isTrue);
        expect(r.hasPart('Continue · Poet b · Medium'), isTrue);
        r.tap('Continue · Poet b · Medium');
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
      'home buttons start the daily, endless and race, and open settings and about',
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
        final endless = await Rig.make();
        await endless.open(QuizHomeScreen(endless.kit));
        endless.tap('Endless');
        expect(endless.kit.session.round!.mode, isA<EndlessMode>());
        final race = await Rig.make();
        await race.open(QuizHomeScreen(race.kit));
        race.tap('Race');
        expect(race.kit.session.round!.mode, isA<RaceMode>());
      },
    );

    test(
      'the menu has a GPU night sky behind it and a light on the next poet',
      () async {
        final r = await Rig.make(bank: makeMultiBank());
        await r.open(QuizHomeScreen(r.kit));
        final fx = r.world.componentsOf<ShaderEffect>();
        final kinds = [for (var i = 0; i < fx.length; i++) fx.denseAt(i).kind];
        expect(kinds.where((k) => k == ShaderEffect.aurora), hasLength(1));
        expect(kinds.where((k) => k == ShaderEffect.glow), hasLength(3));
        final sky = [
          for (var i = 0; i < fx.length; i++) fx.denseAt(i),
        ].firstWhere((e) => e.kind == ShaderEffect.aurora);
        expect(sky.zIndex, greaterThan(-10));
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
      final shapesPlain = plain.world.componentsOf<Shape>().length;

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
      expect(
        r.world.componentsOf<Shape>().length,
        shapesPlain - 4,
        reason: 'two diamonds less for each of the two portraits',
      );
    });

    test(
      'starting a game plays the veil: it covers the menu, then lifts off the game',
      () async {
        ShaderEffect? veil(Rig r) {
          final fx = r.world.componentsOf<ShaderEffect>();
          for (var i = 0; i < fx.length; i++) {
            final k = fx.denseAt(i).kind;
            if (k == ShaderEffect.kashi ||
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
        r.tap('Endless');
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
        r.tap('Race');
        expect(
          r.kit.session.round!.mode,
          isA<EndlessMode>(),
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
        r.tap('Endless');
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
      'tapping a poet blurs the screen and opens a medal with the levels',
      () async {
        final r = await Rig.make(bank: makeMultiBank());
        await r.open(QuizHomeScreen(r.kit));
        expect(r.world.componentsOf<BackdropBlur>().length, 0);
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
        expect(fx.length, 5, reason: 'the medal brings its own light');
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
      'the menu animates: glows and sparkles change opacity over time',
      () async {
        final r = await Rig.make(bank: makeMultiBank());
        await r.open(QuizHomeScreen(r.kit));
        double sum() {
          final shapes = r.world.componentsOf<Shape>();
          var s = 0.0;
          for (var i = 0; i < shapes.length; i++) {
            s += shapes.denseAt(i).alpha;
          }
          return s;
        }

        final before = sum();
        r.run(0.8);
        expect(sum(), isNot(before));
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
      r2.tap('Sound · ✓');
      expect(r.kit.settings.sound, isFalse);
      r2.tap('Haptics · ✓');
      expect(r.kit.settings.haptics, isFalse);
    });

    test('about shows the source lines, the link and the version', () async {
      final r = await Rig.make();
      await r.open(QuizAboutScreen(r.kit));
      expect(r.has('Poems from Ganjoor'), isTrue);
      expect(r.has('https://ganjoor.net'), isTrue);
      expect(r.has('Version: 1.0'), isTrue);
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
        expect(r.has('★★★'), isTrue);
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
        expect(r.has('✅✅✅✅✅'), isTrue);
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
