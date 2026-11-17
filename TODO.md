# Remaining work

The single source of truth for what is left. Only open work lives here; delete items once shipped —
what shipped is recorded in [CHANGELOG.md](CHANGELOG.md); reasoning lives
in git history. Add newly discovered work here rather than in comments or
side files.

Related (not task lists):
- [docs/studio/design.md](docs/studio/design.md) — studio PRD / design / delivered phases
- [docs/concepts/turn-based-strategy.md](docs/concepts/turn-based-strategy.md)
- [engine_mcp.md](engine_mcp.md) — agent API (phases 0–7 shipped; add ops via
  `zarvan_core` groups + `gen_api_docs.dart`)

Per-area lists live next to what they track: studio in
[docs/studio/studio.md](docs/studio/studio.md), and the sample games in
`mobarez/mobarez_todo.md` and `zahaak/zahaak_todo.md` (both folders are gitignored,
so those files exist only on the owner's machine).

Sections: [Release](#release) ·
[Wanted: engine gaps](#wanted-engine-gaps) ·
[Wanted: idle gaps](#wanted-idle-gaps) ·
[Wanted: quiz genre](#wanted-quiz-genre)

## Release

- [ ] After the release exists, tell downstream projects `World.storeOf` is gone
      (see [docs/migrating-from-storeof.md](docs/migrating-from-storeof.md)); it was removed
      before the tag at the owner's request.
- [ ] Cut the first public release (the local `v0.1.0` tag is 600+ commits stale, retag at `main`), decide tag/`ref`
      policy for generated projects, publish packages to pub.dev (drops the
      self-referencing git-dep constraint), then swap README badges to
      pub.dev version badges. Checklist: [docs/engine-releasing.md](docs/engine-releasing.md).

## Wanted: engine gaps

Ten things a general 2D engine needed and did not have were checked against the source and built (time scale and
hit-stop, pooling, spawners, camera rig, joints, developer console, post-processing and shader effects, screen-reader
semantics, level mechanics, UI toolkit models); see the changelog. One follow-up remains. Tick items off as they
ship, with a test and docs.

- [x] **Flat shape primitives** (`Shape`: circle, rounded rect, ring, dashes, screen space) for art-free games such as Adad Bazi; tests in `shape_test.dart`, benchmark in `benchmark/`.
- [x] **Render a world to PNG** (`captureWorldToPng`) for share cards; tests in `capture_world_test.dart`.
- [x] **Key-value store for save blobs** (`KeyValueStore`, `MemoryKeyValueStore`, `PreferencesKeyValueStore`) so a game keeps plain data without a platform import; tests in `key_value_store_test.dart`.
- [ ] **UI toolkit: Flutter widgets for the new models.** `layoutStack`, `anchorRect`, `ScrollListModel` and
      `TextInputModel` exist as pure models; scenes still need widgets that render and drive them.

## Wanted: idle gaps

What `zarvan_idle` and the wave-combat layer still lack for a full idle game, most important first:

- [ ] **Automation in wave combat.** `AutoBuyer` exists in core, but the wave scene still needs taps to buy upgrades,
      cast skills, retry and ascend. Add auto-buy, auto-cast, auto-retry and auto-ascend toggles (generic, config-driven).
- [ ] **Flutter widgets for the UI toolkit models** (see above): scrolling lists, tabs, popups and tooltips for shops,
      inventories and skill trees.
- [ ] **Meta-progression beyond one prestige.** A talent or skill tree bought with prestige currency, achievements with
      permanent bonuses, daily quests and login streaks.
- [ ] **Many heroes.** Party or companions, summon or collection, and a gear inventory screen with rarity and merging
      (loot drops exist; browsing and comparing gear does not).
- [ ] **Offline that includes combat.** Offline pays coins only; simulate waves cleared and loot, and show a
      "welcome back" breakdown.
- [ ] Big-number formatting (1.2K, 3.4aa) and values beyond double range; a multi-currency HUD.
- [x] A rewarded-boost extension point (for example "double offline earnings") that works with any ads or purchase SDK: `zarvan_ads` `AdService.showRewarded()` (true = reward earned) drives `IdleSession.doubleOffline`.
- [ ] Ads follow-ups: (consent helper done: `AdService.requestConsent`, UMP source) wire a rewarded button into the idle welcome-back dialog, a `remove ads` purchase hook.
- [ ] Live events: remote config or an event calendar, server-time anti-cheat, leaderboards.
- [ ] A visual balance-curve viewer on top of the existing simulator.
- [ ] **Snapshot-free shader path.** Run the same `post_fx` shader through `ImageFilter.shader` on Impeller platforms, so
      the per-frame snapshot (the whole cost on the web, about 6 ms per megapixel; on an Android phone the shader work shows too) disappears on iOS and Android.

## Wanted: quiz genre

A multiple-choice / fill-in-the-blank genre, first used by the Persian poetry game "Shaer" (separate repo; its PRD is
the source for the rules below). Same split as idle: Flutter-free rules in `zarvan_core` so the CLI and MCP can run
them, widgets in a new leaf package. Nothing language- or poetry-specific goes into the engine: tokenizer, stop words
and the item bank are passed in as data.

- [x] **Core quiz rules** (`zarvan_core/lib/src/quiz/`, exported from `zarvan_core_quiz.dart`): item model (lines +
      metadata + `tier`), seeded RNG, blank-word choice per tier (e.g. last word of a line vs. a random content word,
      skipping caller-supplied stop words), distractor generation per tier (unrelated / same length / same rhyme,
      same author), all JSON-serializable.
- [x] **Scoring and modes**: per-tier base score, streak multiplier, hint (remove two options, halves the score), lives,
      countdown with time bonus/penalty; modes as data: staged levels (unlock threshold, stars), endless (tier steps
      every N questions, one continue), timed race, daily set seeded by date.
- [ ] **Progress model**: stars and unlocks per chapter/stage, records, currency balance; saved through the existing
      save/`KeyValueStore` path.
- [ ] **`zarvan_quiz` package** (depends on `zarvan_core` + `zarvan_flutter`): RTL-ready question card, option buttons,
      answer feedback, HUD (currency, lives, timer), `QuizController`/`QuizSession` for lifecycle and saving.
- [ ] **Agent operations**: `quiz.generate`, `quiz.answer`, `quiz.state`, `quiz.validate_bank` (blankable words exist,
      no duplicate options, tier counts) in the operation registry, each with its `zarvan` command (1:1 rule), and
      `docs/reference/operations.md` regenerated.
- [ ] Add `zarvan_quiz` to the package map in CLAUDE.md and the README.
