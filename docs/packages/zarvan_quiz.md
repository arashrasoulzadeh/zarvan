# zarvan_quiz

**Runtime:** Flutter · **Audience:** developers, game makers · **Depends on:** `zarvan_core`, `zarvan_flutter`

Multiple-choice and fill-in-the-blank games. The Flutter-free rules live in
`zarvan_core` (`zarvan_core_quiz.dart`, re-exported here) and are also exposed
as `quiz.*` operations. Nothing language-specific is in the engine: the stop
words and the question bank are data you pass in.

## What's inside

| Piece | What it does |
|---|---|
| `QuizSession` | Owns the round and `QuizProgress`; runs the race clock, saves after every answer, books a finished round (stars, coins, records). Exposes an event stream and `rewardForAd`. |
| `QuizLifecycleHost` | Pauses the session when the app backgrounds. |
| `QuizQuestionCard` | The question with its blank, right-to-left by default. |
| `QuizOptions` | The four options with right/wrong colouring and hint-disabled state. |
| `QuizFeedback` | The full answer, its author and a Next button. |
| `QuizHud` | Score, streak, lives or race clock, coins and the hint button. |

Modes: `StageMode`, `EndlessMode` (offers one continue), `RaceMode`, `DailyMode`.

## Quick example

```dart
final session = await QuizSession.open(store); // any KeyValueStore
session.begin(QuizRound.stage(factory, const StageMode(),
    author: 'hafez', tier: QuizTier.easy));
// QuizQuestionCard, QuizOptions, QuizFeedback, QuizHud(session: session)
```

A hint costs 20 coins and is not offered in a race. A daily already played on
its date cannot be started again. See [Quiz games](../concepts/quiz-games.md).

## Install

Not on pub.dev yet (pre-1.0). Depend on it through git, the same way `zarvan create` wires generated projects:

```yaml
dependencies:
  zarvan_quiz:
    git:
      url: https://github.com/arashrasoulzadeh/zarvan.git
      path: packages/zarvan_quiz
      ref: main
```

## Links

- [Source and README](https://github.com/arashrasoulzadeh/zarvan/tree/main/packages/zarvan_quiz)
- [Changelog](https://github.com/arashrasoulzadeh/zarvan/blob/main/packages/zarvan_quiz/CHANGELOG.md)

- [All packages](../packages.md)
