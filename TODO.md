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

Sections: [Release](#release) · [Idle gaps](#idle-gaps) · [Rendering](#rendering) · [Studio](#studio)

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

## Rendering

Ideas for `zarvan_flutter`'s render path. Measure with the frame-timing monitor and the benchmarks before and after
each one. Already built, so not listed: shared-atlas `drawRawAtlas` batching (per `zIndex`), tile-map culling,
warm-up of the lighting and normal-map shaders (`EngineWarmup`), and batching of mirrored (flipped) sprites.

### Safe, start here

Change only what is drawn or when a shader compiles, never the simulation or draw order. Done: warm-up of every
shader (lighting, normal maps, `ShaderEffect` kinds, `ShaderPostProcessed.warmUp()`) and camera culling of sprites.

- [ ] Call `ShaderPostProcessed.warmUp()` from the loading screens of the sample games that use post-fx.

### Riskier (change draw order or existing visuals)

- [ ] **Batch the remaining sprite fallbacks.** Sprites with non-uniform scale, normal-mapped sprites and
      unregistered atlases still cost one `drawImageRect` each. Add a 5k-sprite benchmark and measure first whether it
      matters.
- [ ] **Explicit render layers and sort keys.** One ordered layer list (background, world, lights, fx, HUD) with a
      per-entity layer and z-order, so parallax, lighting, post-fx and the HUD stop depending on system
      registration order; layers become data an agent can patch.
- [ ] **Cache static layers.** Cache unchanging layers (tile maps, parallax) as a `Picture` or image redrawn only when
      the camera moves a whole tile or the layer changes.
- [ ] **Shader pass pipeline.** Chain post-fx, colorblind filter, ambient and GPU lighting and screen tint as an
      ordered list of passes that share one snapshot (today each can force its own), with passes toggled by data.
- [ ] **Plain-canvas fallback.** When a shader fails to load or the platform lacks support, fall back to a flat tint
      with no normal maps; test both paths.

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
