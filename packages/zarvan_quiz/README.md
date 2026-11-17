# zarvan_quiz

Multiple-choice / fill-in-the-blank games on top of [zarvan_core](../zarvan_core/README.md) and
[zarvan_flutter](../zarvan_flutter/README.md).

The Flutter-free rules live in `zarvan_core` (`package:zarvan_core/zarvan_core_quiz.dart`): `QuizItem`,
`QuizGenerator`, `ScoreRules`/`SimpleQuizRun`, `QuizMode`, `QuizProgress` and `validateQuizBank`. They are also exposed as
the `quiz.*` operations (`zarvan quiz generate`, `answer`, `state`, `validate-bank`). Nothing language-specific is in
the engine: the tokenizer, stop words and item bank are data you pass in.

| Piece | What it does |
|---|---|
| `QuizController` | Drives one run: current question, hint, answer, countdown, finish; notifies widgets |
| `QuizSession` | Loads and saves `QuizProgress` through a `KeyValueStore` and books a finished run into it |
| `QuestionCard` | The question lines with the blank, in a caller-chosen text direction (RTL ready) |
| `OptionButtons` | The options, with right/wrong feedback after an answer and hidden ones after a hint |
| `QuizHud` | Score, streak, lives, timer and currency |
