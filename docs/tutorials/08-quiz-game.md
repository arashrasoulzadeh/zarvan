# 8 · Build and test a quiz bank

**You will build:** a small quiz content bank, generate deterministic questions, run a round and simulate its difficulty with the CLI. This is a headless workflow; a Flutter game can use the same bank and rules through `zarvan_quiz`. There is no dedicated quiz starter in the current CLI.

## 1. Create a bank

Install the CLI using [Getting started](../getting-started.md). In a game project, save this as `assets/bank.json`:

```json
{
  "version": 1,
  "authors": [{"id": "a", "name": "A"}],
  "items": [
    {"id": "x", "author": "a", "tier": "easy", "fame": 1, "lines": ["الف بب", "جج دد"]},
    {"id": "y", "author": "a", "tier": "easy", "fame": 1, "lines": ["ابر باد", "ماه شب"]}
  ]
}
```

The example is intentionally tiny and follows the registry's documented bank shape. Real banks need enough distinct items and distractors to fill the selected round.

## 2. Validate and generate

Run the registry-backed CLI from the project directory (or pass the global `--project /path/to/game`).

```bash
zarvan quiz validate-bank --args '{"bank":"assets/bank.json","stageSize":2}' --json
zarvan quiz generate --args '{"bank":"assets/bank.json","itemId":"x","seed":42}' --json
```

Inspect the outer `ok` and the validation report's `data.ok`, errors and warnings. Generating a question with the same bank, stop words, tier and seed gives the same question. If the bank is too small, add items and rerun validation.

## 3. Start and answer a round

Discover the exact mode schema with `zarvan engine operation quiz.start --json`. A stage takes a bank, mode, author and tier; a daily also needs its date. An endless or race round can take a seed base.

```bash
zarvan quiz start --args '{"bank":"assets/bank.json","mode":"endless","seedBase":"demo"}' --json
```

Keep the returned `data.run`. Invoke `quiz.answer` with the same bank and mode, the returned run object and a zero-based choice index. Replace the run with the new `data.run` on each answer. `quiz.state` summarizes the run without advancing it. Unlike `world.*`, these operations are stateless: the run travels in the request and response.

For an untrusted player, do not expose internal run JSON containing question-answer information; provide a filtered player-facing view instead.

## 4. Tune difficulty

With a representative bank, simulate multiple rounds. For example:

```bash
zarvan quiz simulate --args '{"bank":"assets/bank.json","mode":"endless","runs":10,"policy":"accuracy:0.7","seed":1}' --json
```

Use a realistic bank for meaningful balance results. The engine's fixed-seed policies are reproducible, not a prediction of actual human performance.

## 5. Integrate with a game

Use [zarvan_quiz](../packages/zarvan_quiz.md) for the session, content repository, `QuizKit` and engine-drawn screens. A game supplies its bank, stop words, localized strings, themes, settings and persistence. See the [package README](../../packages/zarvan_quiz/README.md) for its screen integration contract and [Quiz games](../concepts/quiz-games.md) for modes and rules.

## Checkpoint

The bank validates, repeated generation with the same seed is consistent, and you can pass the returned run into the next call without relying on process state. For exact parameters and error codes, use [Operations](../reference/operations.md#quiz).
