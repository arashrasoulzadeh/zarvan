# zarvan_quiz

Multiple-choice / fill-in-the-blank games on top of [zarvan_core](../zarvan_core/README.md).

The Flutter-free rules live in `zarvan_core` (`package:zarvan_core/zarvan_core_quiz.dart`, re-exported here): the
bank (`QuizBank`), `QuestionFactory`, `QuizRound` in the four modes (`StageMode`, `EndlessMode`, `RaceMode`,
`DailyMode`), `QuizScoring`, `QuizRun`, `QuizProgress` and `validateBank`. They are also the `quiz.*` operations
(`zarvan quiz validate-bank`, `generate`, `start`, `answer`, `state`, `simulate`). Nothing language-specific is in
the engine: the stop words and the bank are data you pass in.

| Piece | What it does |
|---|---|
| `QuizSession` | Owns the round and the player's `QuizProgress`; gives the race its real clock, saves the run after every answer, books a finished round (stars, coins, records) and saves progress |
| `QuizLifecycleHost` | Pauses the session when the app goes to the background and resumes it |
| `QuizQuestionCard` | The poem with its blank, right-to-left by default; shows the right word after an answer |
| `QuizOptions` | The four options; the right one takes the theme's primary colour, a wrong pick its error colour; hinted-away options are disabled |
| `QuizFeedback` | The whole poem, its author and a Next button (a race moves on by itself after a second) |
| `QuizHud` | Score, streak, lives or the race clock, coins and the hint button |

```dart
final session = await QuizSession.open(store); // any KeyValueStore
session.begin(QuizRound.stage(factory, const StageMode(), author: 'hafez', tier: QuizTier.easy));
// then QuizQuestionCard / QuizOptions / QuizFeedback / QuizHud(session: session)
```

A hint costs 20 coins and is not offered in a race. A daily already played on its date cannot be started again.
