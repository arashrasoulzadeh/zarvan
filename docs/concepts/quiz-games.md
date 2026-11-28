# Quiz games

The quiz genre (multiple choice and fill-in-the-blank) is split the same way as
idle games: Flutter-free rules in `zarvan_core`, session and engine-drawn screens in
[`zarvan_quiz`](../packages/zarvan_quiz.md). Nothing language-specific is in the
engine. The tokenizer's stop words and the question bank are **data you pass in**.

## The rules (`zarvan_core_quiz.dart`)

| Piece | Role |
|---|---|
| `QuizBank`, `QuizItem` | The content: items (a text, its author, a tier) loaded from JSON. |
| `QuestionFactory` | Builds a question from an item: picks the blank (`blank_picker`) and the distractors (`distractors`) deterministically from a seed. |
| `QuizRound` | One round in a mode: `StageMode`, `EndlessMode`, `RaceMode` or `DailyMode`. |
| `QuizScoring`, `QuizRun` | Points, streaks, lives and the run state an answer advances. |
| `QuizProgress` | Stars, coins and records that persist between rounds. |
| `validateBank` | Checks a bank before it ships. |
| `simulate` | Plays a bank with a scripted player to check difficulty and balance. |

Everything seeds from `SeededRandom`, so a round replays identically.

## Modes

- **Stage**: a fixed number of questions at a tier, ending with stars.
- **Endless**: continues until lives run out; offers one continue.
- **Race**: against a clock. No hints; the next question comes automatically.
- **Daily**: one seeded round per date. A daily already played cannot restart.

A hint costs 20 coins and is not offered in a race.

## From the command line or an agent

The rules are registry operations, so they work from the shell, MCP, REST and
JSON-RPC without Flutter:

```bash
zarvan quiz validate-bank --args '{"bank":"assets/bank.json"}' --json
zarvan quiz generate --args '{"bank":"assets/bank.json","itemId":"x","seed":42}' --json
```

The `quiz.start`, `quiz.answer`, `quiz.state` and `quiz.simulate` operations require mode and run parameters as applicable. Follow [Tutorial 8](../tutorials/08-quiz-game.md) for the complete headless workflow. See [Operations](../reference/operations.md#quiz).

## The Flutter layer

For a complete consumer application using the engine-drawn screens, see [Tutorial 9](../tutorials/09-flutter-quiz-app.md).

```dart
final session = await QuizSession.open(store); // any KeyValueStore
session.begin(QuizRound.stage(factory, const StageMode(),
    author: 'hafez', tier: QuizTier.easy));
```

`QuizSession` owns the round and progress, runs the race clock, saves after every
answer and books a finished round. Create a `QuizKit` with the game's session, factory, strings, themes and settings, then return an exported `QuizHomeScreen` or `QuizTutorialScreen` from `Game.createInitialScene`. `QuizScreen` draws with engine shapes and text; these are not Flutter widgets. The game supplies optional ad and analytics integration. See the [package README](../../packages/zarvan_quiz/README.md).
