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
  final world = World(width: 360, height: 640);
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
        expect(played.has('✅✅❌✅✅'), isTrue);
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
        expect(kinds.where((k) => k == ShaderEffect.glow), hasLength(4));
        final sky = [
          for (var i = 0; i < fx.length; i++) fx.denseAt(i),
        ].firstWhere((e) => e.kind == ShaderEffect.aurora);
        expect(sky.zIndex, greaterThan(-10));
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
        expect(r.has('Stage Easy'), isFalse);
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

    test(
      'the reward button shows only with an ad ready and pays 15 coins when watched',
      () async {
        final none = await Rig.make();
        await none.open(QuizHomeScreen(none.kit));
        expect(none.has('15 coins for an ad'), isFalse);
        final r = await Rig.make(ads: true);
        await r.open(QuizHomeScreen(r.kit));
        r.tap('15 coins for an ad');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(r.kit.session.progress.coins, 75);
        expect(r.ads.shown, ['coins']);
        final skip = await Rig.make(ads: true, earns: false);
        await skip.open(QuizHomeScreen(skip.kit));
        skip.tap('15 coins for an ad');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(skip.kit.session.progress.coins, 60);
      },
    );

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
