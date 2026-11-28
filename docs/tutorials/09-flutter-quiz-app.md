# 9 · Build a Flutter quiz app

**You will build:** a small portrait quiz with engine-drawn screens, deterministic questions and persistent player progress. Start with [Tutorial 8](08-quiz-game.md) if you want to understand the rules or validate a production question bank before integrating the UI.

## 1. Create a consumer project

Create a Flutter application (outside the engine repository):

```bash
flutter create word_garden
cd word_garden
```

Add the three engine dependencies under the existing `dependencies:` section of `pubspec.yaml`. Keep the Flutter SDK dependency. These Git refs must agree with the engine's own sibling dependency refs; the example uses the current main-ref layout.

```yaml
  zarvan_core:
    git:
      url: https://github.com/arashrasoulzadeh/zarvan.git
      path: packages/zarvan_core
      ref: main
  zarvan_flutter:
    git:
      url: https://github.com/arashrasoulzadeh/zarvan.git
      path: packages/zarvan_flutter
      ref: main
  zarvan_quiz:
    git:
      url: https://github.com/arashrasoulzadeh/zarvan.git
      path: packages/zarvan_quiz
      ref: main
```

## 2. Add the application

Replace `lib/main.dart` with the following complete demo. The bank contains short original English sentences rather than external copyrighted content. Each tier has two items; the stage is deliberately shortened to two questions. The UI strings and themes are game-owned configuration, not hidden defaults. Production games should supply a larger bank, fonts suitable for their language, and their own content and branding.

```dart
import 'package:flutter/widgets.dart' show WidgetsFlutterBinding;
import 'package:zarvan_core/zarvan_core.dart' show KeyValueStore;
import 'package:zarvan_flutter/zarvan_flutter.dart';
import 'package:zarvan_quiz/zarvan_quiz.dart';

Future<QuizKit> createKit(KeyValueStore store) async {
  final bank = QuizBank.fromJson({
    'version': 1,
    'authors': [
      {'id': 'garden', 'name': 'Word Garden'},
    ],
    'items': [
      for (final (tier, sentences) in [
        ('easy', [
          'bright flowers grow beside rivers',
          'gentle birds sing above trees',
        ]),
        ('medium', [
          'silver moonlight covers quiet valleys',
          'autumn leaves drift across meadows',
        ]),
        ('hard', [
          'distant thunder echoes through mountains',
          'morning mist surrounds ancient forests',
        ]),
        ('literary', [
          'amber twilight softens silent horizons',
          'patient tides polish weathered stones',
        ]),
      ])
        for (var i = 0; i < sentences.length; i++)
          {
            'id': '$tier-$i',
            'author': 'garden',
            'tier': tier,
            'fame': 10 - i,
            'lines': [sentences[i]],
          },
    ],
  });
  return QuizKit(
    session: await QuizSession.open(store),
    factory: QuestionFactory(bank, const {}),
    strings: strings,
    themes: themes,
    settings: await QuizSettings.load(store),
    stageMode: const StageMode(
      questionCount: 2,
      passAt: 1,
      starAt: [1, 2],
    ),
    transitions: false,
  );
}

class WordGarden extends Game {
  WordGarden(this.kit);
  final QuizKit kit;

  @override
  GameConfig get config => const GameConfig(
    title: 'Word Garden',
    worldWidth: QuizScreen.worldWidth,
    worldHeight: QuizScreen.worldHeight,
    orientation: GameOrientation.portrait,
    onScreenControls: OnScreenControlsMode.off,
    fixedTimestepSeconds: 1 / 60,
  );

  @override
  ViewportConfig get viewportConfig => const ViewportConfig.fittingWorld(
    QuizScreen.worldWidth, QuizScreen.worldHeight,
  );

  @override
  Scene createInitialScene() =>
      kit.session.progress.flags['tutorialDone'] == true
          ? QuizHomeScreen(kit)
          : QuizTutorialScreen(kit);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = await PreferencesKeyValueStore.open();
  runGame(WordGarden(await createKit(store)));
}

const strings = QuizStrings(
  appName: 'Word Garden',
  coins: 'coins',
  settings: 'Settings',
  about: 'About',
  dailyChallenge: 'Daily',
  dailyDone: 'Done',
  dailyTodayPlay: 'Five new questions',
  chapters: 'Chapters',
  wallTitle: 'Collections',
  chaptersDone: 'complete',
  outOf: 'of',
  continueGame: 'Continue',
  endless: 'Endless',
  race: 'Race',
  stageLockedHint: 'Pass the previous stage',
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
  tutorialTip: 'A hint costs 20 coins',
  theme: 'Theme',
  themeSystem: 'System',
  themeLight: 'Light',
  themeDark: 'Dark',
  sound: 'Sound',
  haptics: 'Haptics',
  aboutSource: 'Original demo sentences',
  aboutVersion: 'Version',
  aboutLicenseNote: 'Demo content',
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
```

## 3. Run and check

```bash
flutter pub get
flutter analyze
flutter run
```

Complete the tutorial, open the chapter, play a short stage, and return to the menu. Restart the app and check that progress is retained. The demo does not wire ads, sharing, sound or haptic hooks. It uses a tiny bank for integration, not meaningful balance testing. Expand the bank before relying on long endless/race sessions.

Flutter's generated counter widget test no longer applies after replacing the app entry point; replace it with a game-specific test rather than retaining the original counter assertions.

## 4. Understand the responsibilities

| Layer | Responsibility |
|---|---|
| `QuizBank`, `QuestionFactory`, `QuizRound` | Portable content and deterministic rules |
| `QuizSession` | Current run, feedback, score, rewards and progress |
| `QuizKit` | Session, content factory, strings, themes, settings and optional hooks |
| `QuizScreen` and subclasses | Engine-drawn screens and transitions |
| `Game`, `runGame` | Flutter lifecycle, rendering, viewport and scene management |
| `PreferencesKeyValueStore` | Platform-backed persistence; use `MemoryKeyValueStore` for tests |

For a real asset-backed game, declare bank and stop-word files under `flutter.assets` and call `QuizContentRepository.load(bankAsset: ..., stopWordsAsset: ...)` instead of embedding the bank. Supply its `factory` to the kit. Use a game-specific `QuizStrings` and `QuizThemes`; select `rtl: true` and a font with the appropriate glyphs when necessary.

## Verification

The exact demo is also checked by a package-level smoke test (see [tutorial_app_docs_test.dart](../../packages/zarvan_quiz/test/tutorial_app_docs_test.dart)). It constructs the kit with an in-memory store and starts a short stage, without launching a device or testing platform persistence. Run `flutter test test/tutorial_app_docs_test.dart` from `packages/zarvan_quiz`.

Related: [Quiz package](../packages/zarvan_quiz.md), [quiz rules](../concepts/quiz-games.md), [agent operations](../reference/operations.md#quiz).
