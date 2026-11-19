# Remaining work

The single source of truth for what is left in the engine and Studio. Only open work lives here; delete items once
shipped — what shipped is recorded in [CHANGELOG.md](CHANGELOG.md); reasoning lives in git history. Add newly
discovered work here rather than in comments or side files.

Related (not task lists):
- [docs/studio/design.md](docs/studio/design.md) — studio PRD / design / delivered phases
- [docs/concepts/turn-based-strategy.md](docs/concepts/turn-based-strategy.md)
- [engine_mcp.md](engine_mcp.md) — agent API (phases 0–7 shipped; add ops via
  `zarvan_core` groups + `gen_api_docs.dart`)
- [docs/studio/qa-level-editor.md](docs/studio/qa-level-editor.md) — manual QA checklist for the level editor

The sample games' own lists (`mobarez/mobarez_todo.md`, `zahaak/zahaak_todo.md`, `adad_bazi/TODO.md`) stay with the
games: those folders are gitignored, so the files exist only on the owner's machine.

Sections: [Release](#release) · [Idle gaps](#idle-gaps) · [Studio](#studio)

## Release

- [ ] After the release exists, tell downstream projects `World.storeOf` is gone
      (see [docs/migrating-from-storeof.md](docs/migrating-from-storeof.md)); it was removed
      before the tag at the owner's request.
- [ ] Cut the first public release (the local `v0.1.0` tag is 600+ commits stale, retag at `main`), decide tag/`ref`
      policy for generated projects, publish packages to pub.dev (drops the
      self-referencing git-dep constraint), then swap README badges to
      pub.dev version badges. Checklist: [docs/engine-releasing.md](docs/engine-releasing.md).

## Idle gaps

What `zarvan_idle` and the wave-combat layer still lack for a full idle game, most important first:

- [ ] **Many heroes.** Party or companions, summon or collection, and a gear inventory screen with rarity and merging
      (loot drops exist; browsing and comparing gear does not).
- [ ] **Offline that includes combat.** Offline pays coins only; simulate waves cleared and loot, and show a
      "welcome back" breakdown.
- [ ] Big-number formatting (1.2K, 3.4aa) and values beyond double range; a multi-currency HUD.
- [ ] Ads follow-ups (consent helper is done: `AdService.requestConsent`): wire a rewarded button into the idle
      welcome-back dialog, a `remove ads` purchase hook.
- [ ] Live events: remote config or an event calendar, server-time anti-cheat, leaderboards.
- [ ] A visual balance-curve viewer on top of the existing simulator.
- [ ] **Snapshot-free shader path.** Run the same `post_fx` shader through `ImageFilter.shader` on Impeller platforms, so
      the per-frame snapshot (the whole cost on the web, about 6 ms per megapixel; on an Android phone the shader work
      shows too) disappears on iOS and Android.

## Studio

Package: `packages/zarvan_studio`.

### Distribution

- [ ] Stand-in packing is CI-checked for macOS `.dmg` (`tool/verify_dmg_pack.sh`),
      Linux AppDir/AppImage (`tool/verify_appimage_pack.sh`) and the Windows zip/MSI
      hook (`tool/verify_windows_pack.sh`). Still open:
    - a real `flutter build macos --release` (the FlutterMacOS.framework arch check failed on the dev machine);
    - WiX `.msi` authoring;
    - `appimagetool` on release hosts;
    - code signing and notarization;
    - a release server and signing key (the update client exists; nothing to talk to).

### Tests

- [ ] **Flaky `play_test_test.dart`**: "devices and stopping the device in use appears
      in the launch arguments" failed once in CI with "failed after test completion"
      (a timer or stream outliving the test). Not reproduced locally.
- [ ] `rename_test.dart` is sensitive to load timing; it uses larger retry budgets
      but can still flake on a busy machine.

### Features

- [ ] **Debugger**: its own phase, not in the current IDE scope.
- [ ] Not scheduled: play-test process profiling, a live cursor feed, and a visual
      three-way merge UI (`studio merge` covers the CLI).

### Docs

- [ ] A studio screenshot with real entity-label text (`UPDATE_SCREENSHOTS=1`
      regenerates `docs/img/`).
