# zarvan_quiz

Multiple-choice / fill-in-the-blank games on top of [zarvan_core](../zarvan_core/README.md) and
[zarvan_flutter](../zarvan_flutter/README.md). **Every screen is drawn by the engine** (its shapes and text, as
`Scene`s run by `runGame`); there are no Flutter widgets in this package.

The Flutter-free rules live in `zarvan_core` (`package:zarvan_core/zarvan_core_quiz.dart`, re-exported here): the
bank, `QuestionFactory`, `QuizRound` in the four modes, `QuizScoring`, `QuizRun`, `QuizProgress` and `validateBank`
(also the `quiz.*` operations and `zarvan quiz ...` commands). The engine knows no language: strings, stop words, the
typeface and the colours are given by the game.

| Piece | What it does |
|---|---|
| `QuizSession` | Owns the round and the player's `QuizProgress`; `tick` drives the race clock (called from the screen's update, so it stops with the engine in the background), saves after every answer, books a finished round, offers the endless continue, emits `events` |
| `QuizKit` | Everything a screen needs, built once by the game: session, content, `QuizStrings`, `QuizThemes`, `QuizSettings`, an optional `QuizAdGate`, share hook, About text |
| `QuizScreen` | Base of every screen: an engine `Scene` with a `UiBuilder`, drawing in the theme and turning taps into button presses |
| `QuizHomeScreen`, `QuizChaptersScreen`, `QuizStagesScreen`, `QuizGameScreen`, `QuizResultScreen`, `QuizSettingsScreen`, `QuizAboutScreen`, `QuizTutorialScreen` | The screens, in the flow of `docs/ui-flow.md` in the Shaer repo |

```dart
final kit = QuizKit(session: session, factory: factory, strings: fa, themes: themes, settings: settings);
// in your Game:
Scene createInitialScene() => session.progress.flags['tutorialDone'] == true
    ? QuizHomeScreen(kit)
    : QuizTutorialScreen(kit);
```

The world is portrait, `QuizScreen.worldWidth` x `worldHeight` (360 x 640); give `runGame` a viewport that fits it
(`ViewportConfig.fittingWorld`). A hint costs 20 coins and is not offered in a race. A daily already played on its date
cannot be started again.
