# Quiz games

The quiz genre (multiple choice and fill-in-the-blank) is split the same way as
idle games: Flutter-free rules in `zarvan_core`, session and widgets in
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
zarvan quiz validate-bank assets/bank.json
zarvan quiz generate
zarvan quiz start
zarvan quiz answer
zarvan quiz state
zarvan quiz simulate
```

See [Operations](../reference/operations.md#quiz).

## The Flutter layer

```dart
final session = await QuizSession.open(store); // any KeyValueStore
session.begin(QuizRound.stage(factory, const StageMode(),
    author: 'hafez', tier: QuizTier.easy));
```

`QuizSession` owns the round and progress, runs the race clock, saves after every
answer and books a finished round. Draw it with `QuizQuestionCard`,
`QuizOptions`, `QuizFeedback` and `QuizHud`; wrap the app in `QuizLifecycleHost`
so the round pauses in the background. `QuizSession.rewardForAd` pairs with
[rewarded ads](ads.md).
