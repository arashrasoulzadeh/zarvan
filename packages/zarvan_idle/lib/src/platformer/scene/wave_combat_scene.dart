import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

import 'package:zarvan_core/zarvan_core.dart';
import 'package:zarvan_flutter/zarvan_flutter.dart' hide Text;
import 'package:zarvan_flutter/zarvan_flutter.dart' as eng show Text;
import 'package:zarvan_platformer/zarvan_platformer.dart';

import '../register_components.dart';
import '../combat/auto_combat_system.dart';
import '../combat/combat_components.dart';
import '../combat/combat_rules.dart';
import '../combat/conditions.dart';
import '../combat/lunge_system.dart';
import '../combat/skill_runner.dart';
import '../hud/wave_strings.dart';
import '../progress/loot.dart';
import '../progress/hero_skill.dart';
import '../progress/offline_rule.dart';
import '../combat/enemy_powers.dart';
import '../level/wave_plan.dart';
import '../fx/damage_numbers.dart';
import '../fx/hit_feedback.dart';
import '../fx/hit_feedback_system.dart';
import '../fx/hit_stop.dart';
import '../hud/upgrade_bar.dart';
import '../progress/gear.dart';
import '../combat/combo_tracker.dart';
import '../progress/hero_loadout.dart';
import '../progress/hero_progress.dart';
import 'scene_light.dart';
import 'sun_light.dart';
import '../combat/fighter_death_system.dart';
import '../combat/spawn_fighter.dart';
import '../fighters/fighter_meta.dart';
import '../fx/combat_fx.dart';
import '../hud/dialogue_caption.dart';
import '../hud/hud_layout.dart';
import '../hud/result_popup.dart';
import '../hud/scene_hud.dart';
import '../hud/status_badges.dart';
import '../hud/sprite_health_bar.dart';
import '../hud/wave_path.dart';
import '../hud/wave_ui_art.dart';
import '../level/level_data.dart';
import '../level/wave_progress.dart';
import 'walk_phase.dart';

/// Where a [WaveCombatScene]'s art lives and how it plays. Everything a
/// second zone or game changes is here; the scene's behaviour is shared.
class WaveCombatConfig {
  const WaveCombatConfig({
    required this.heroStem,
    required this.enemyRoot,
    required this.backgroundDir,
    required this.backgroundPrefix,
    this.heroId = 'hero',
    this.hitFxStem,
    this.slashFxStem,
    this.deathFxStem,
    this.hitBurst = 6,
    this.fighterSize = 80,
    this.enemyScale = 1,
    this.disintegration,
    this.fieldLift = 0,
    this.onCleared,
    this.openMap,
    this.meleeLunge = false,
    this.fightDelaySeconds = 0,
    this.walkSpeed = 70,
    this.enterDistance = 190,
    this.deathHoldSeconds = 0.5,
    this.fallenMessage = 'The hero has fallen — tap to replay',
    this.clearedMessage = 'Cleared — tap to replay',
    this.bossLabel = 'Boss',
    this.impactParticles = defaultImpactParticles,
    this.hud = const HudLayout(),
    this.ui = const WaveUiArt(),
    this.sun,
    this.lights = const [],
    this.upgrades = const [],
    this.coinsPerKill = 10,
    this.bossCoins = 50,
    this.damageNumbers,
    this.hitFeedback,
    this.windupSeconds = 0,
    this.comboBonusPerHit = 0,
    this.comboMax = 10,
    this.waveSeed,
    this.strings = const WaveStrings(),
    this.skills = const [],
    this.loot,
    this.checkpointEvery = 0,
    this.prestigeBonusPerStar = 0,
    this.offline,
    this.showSummary = true,
    this.hints = true,
    this.timing,
    this.squad,
  });

  /// Asset stem of the hero sheets (`<stem>_idle.png`, `_attack`, `_death`).
  final String heroStem;
  final String heroId;

  /// Directory of enemy sheets: `<enemyRoot>/<id>_idle.png` and so on.
  final String enemyRoot;

  /// Directory of parallax layer images `<name>.png`, registered as atlas
  /// `<backgroundPrefix>_<name>`.
  final String backgroundDir;
  final String backgroundPrefix;

  /// Effect sheet stems (null skips that effect).
  final String? hitFxStem;
  final String? slashFxStem;
  final String? deathFxStem;

  /// Particles bursting from a fighter each time it is hit (0 off).
  final int hitBurst;

  /// Every fighter is drawn this many world units square whatever its sheet's
  /// cell, so high-resolution sheets and small ones stand the same size.
  final double fighterSize;

  /// Multiplies every enemy's drawn size relative to the hero (1 = same
  /// size); bosses and elites keep their usual proportion on top of it.
  final double enemyScale;

  /// Called once when the zone's boss falls, e.g. to unlock the next zone.
  final void Function()? onCleared;

  /// Builds the scene the Battle tab returns to (a world map); null makes the
  /// tab only close dialogs.
  final Scene Function()? openMap;

  /// Raises the hero and the enemies by this many world units, leaving ground
  /// under their feet before a bottom bar (the background itself fills the
  /// screen and stays put).
  final double fieldLift;

  /// When set, an enemy's body comes apart into floating dust
  /// ([DisintegrationSystem]) [DisintegrationStyle.delay] seconds after its
  /// death animation has finished, each enemy of a group on its own; null leaves the plain death clip.
  final DisintegrationStyle? disintegration;

  /// Melee enemies run up to the hero as they wind up an attack and walk back
  /// after it (see `LungeSystem`); enemies with a volley power stay put. Needs
  /// [windupSeconds] above zero.
  final bool meleeLunge;

  /// Seconds the hero and the enemy stand facing each other, after the walk
  /// stops, before the first blow, so a fight does not start mid-stride.
  final double fightDelaySeconds;

  final double walkSpeed;
  final double enterDistance;

  /// How long a finished death clip lingers before the scene moves on.
  final double deathHoldSeconds;

  final String fallenMessage;
  final String clearedMessage;

  /// HUD caption for the boss encounter.
  final String bossLabel;

  /// Where the HUD's labels and health bars sit and their colours.
  final HudLayout hud;

  /// Generated UI art for the bars, path and caption (each optional).
  final WaveUiArt ui;

  /// A sun-like light over the scene; null (default) leaves it unlit.
  final SunLight? sun;

  /// Extra lights: lanterns, glows, torches (see [SceneLight]). Without a
  /// [sun] the scene is not darkened, so they only add tint.
  final List<SceneLight> lights;

  /// Hero upgrades the player can buy with coins (needs
  /// `WaveUiArt.buttonImage` for the buttons). Empty (default) means none.
  final List<HeroUpgrade> upgrades;

  /// Coins for each enemy killed, and for the boss.
  final int coinsPerKill;
  final int bossCoins;

  /// Floating damage numbers on hits; null (default) shows none.
  final DamageNumberStyle? damageNumbers;

  /// Knockback, red screen flash, camera shake and critical sparks; null
  /// (default) adds none.
  final HitFeedback? hitFeedback;

  /// Seconds before an attack that it is telegraphed (see
  /// `HitFeedback.windupTintArgb`); 0 (default) means no wind-up.
  final double windupSeconds;

  /// Combo: every consecutive hero hit (a hit taken resets it) adds this
  /// fraction of damage, up to [comboMax] hits. 0 (default) turns combos off.
  final double comboBonusPerHit;
  final int comboMax;

  /// Seeds the random wave order (`LevelData.randomWaves`); null = a fresh
  /// order every run.
  final int? waveSeed;

  /// Every word the scene draws itself (see [WaveStrings]); override to
  /// translate.
  final WaveStrings strings;

  /// Active abilities on buttons with cooldowns (needs `WaveUiArt.buttonImage`).
  final List<HeroSkill> skills;

  /// What enemies drop; null (default) means no loot.
  final LootTable? loot;

  /// A new run starts at the best wave rounded down to a multiple of this
  /// (0 = always wave 1).
  final int checkpointEvery;

  /// After clearing the boss the hero may ascend: a permanent star worth this
  /// fraction of hp and attack each, at the price of coins and upgrades.
  /// 0 (default) turns prestige off.
  final double prestigeBonusPerStar;

  /// Coins earned while the app was closed, credited by `WaveCombatGame` when
  /// it loads a saved `HeroProgress`. null means no offline earnings.
  final OfflineRule? offline;

  /// Show a one-line run summary under a lost run, and the first-run hints.
  final bool showSummary;
  final bool hints;

  /// The player's timing (parry, timed strike, ultimate); null = fully automatic.
  final CombatTimingRules? timing;

  /// Several enemies per wave; null = always one-on-one.
  final SquadRule? squad;

  /// Builds the spark emitter each fighter gets.
  final ParticleEmitter Function() impactParticles;

  /// Sparks that spread from a fighter when it is hit.
  static ParticleEmitter defaultImpactParticles() => ParticleEmitter(
    speedMin: 25,
    speedMax: 70,
    lifetimeMin: 0.2,
    lifetimeMax: 0.45,
    startScale: 1.6,
    colorArgb: 0xFFFFD27A,
    zIndex: 35,
    emissionShape: EmissionShape.circle,
    emissionRadius: 6,
  );
}

/// A portrait idle-combat scene: the hero walks (scenery scrolling in
/// parallax), meets the next enemy of a [LevelData] wave, auto-fights it, and
/// walks on, ending with the boss. Combat, animation states, pivots, effects,
/// shake/particle cues and the walk are engine systems this scene registers;
/// a game supplies a [LevelData] and a [WaveCombatConfig].
class WaveCombatScene extends Scene {
  WaveCombatScene({
    required this.level,
    required this.config,
    HeroProgress? progress,
    FighterMetaLoader metaLoader = FighterMeta.load,
  }) : progress = progress ?? HeroProgress(),
       _loadMeta = metaLoader;

  final LevelData level;
  final WaveCombatConfig config;

  final FighterMetaLoader _loadMeta;

  /// Coins and upgrade levels. Pass the same object to the next scene (a
  /// retry) to keep them.
  final HeroProgress progress;

  static const _hitFx = 'fx_hit';
  static const _slashFx = 'fx_slash';
  static const _deathFx = 'fx_death';
  static const _uiBars = 'ui_bars';
  static const _uiNodes = 'ui_path_nodes';
  static const _uiLine = 'ui_path_line';
  static const _uiScroll = 'ui_caption_scroll';
  static const _uiButtons = 'ui_buttons';
  static const _uiIcons = 'ui_icons';
  static const _uiPanel = 'ui_panel';
  static const _uiCurrency = 'ui_currency';
  static const _uiStatus = 'ui_status';
  double _statusCell = 32;

  late final WavePlan plan = WavePlan.generate(
    level,
    math.Random(config.waveSeed ?? DateTime.now().microsecondsSinceEpoch),
  );
  late final WaveProgress waves = WaveProgress(
    wave: plan.ids,
    boss: level.boss,
  );
  late final Map<String, String> _fxStems = {
    if (config.hitFxStem != null) _hitFx: config.hitFxStem!,
    if (config.slashFxStem != null) _slashFx: config.slashFxStem!,
    if (config.deathFxStem != null) _deathFx: config.deathFxStem!,
  };
  late SceneHud _hud;
  late DialogueCaption _caption;
  late WalkPhase _walk;
  double _fightDelayLeft = 0;
  late Camera _camera;
  final _combat = AutoCombatSystem();
  final _pivots = PivotTable();
  final Map<String, FighterMeta> _meta = {};
  EntityId? heroId;
  EntityId? enemyId;
  EntityId? _enemyHudId;
  SpriteHealthBar? _heroBar;
  SpriteHealthBar? _enemyBar;
  SpriteHealthBar? _ultBar;
  ScreenChrome? _chrome;
  ResultPopup? _popup;
  ModalDialog? _info;
  StatusBadges? _badges;
  DisintegrationSystem? _dust;
  AtlasRegistry? _registry;
  final Map<EntityId, double> _dying = {};
  final Map<EntityId, _Overhead> _overhead = {};
  double _currencyCell = 32;
  int _earnedCoins = 0;
  WavePath? _path;
  List<EntityId> _corpses = [];
  final List<EntityId> _squad = [];
  final Set<EntityId> _rewarded = {};
  EntityId? _lastDead;
  EntityId? _focus;
  EntityId? _focusMark;
  SceneController? _scenes;

  bool finished = false;
  bool _heroFell = false;
  int _rewardCoins = 0;
  HitStop? _hitStop;
  UpgradeBar? _upgradeBar;
  double _iconCell = 32;
  bool _heroWon = false;
  SkillRunner? _skills;
  EntityId? _condLabel;
  EntityId? _gearLabel;
  double _barSync = 0;
  late HeroLoadout _loadout;
  late String status = level.name;
  String enemyLabel = '';
  String enemyDescription = '';

  double _enemyTargetX = 0;
  double _enemyBaseY = 0;
  double _deathHold = 0;

  @override
  bool get showOnScreenControls => false;

  String _enemyStem(String id) => '${config.enemyRoot}/$id';

  double _fitScale(double cell) => config.fighterSize / cell;

  @override
  Future<void> populate(
    World world,
    SceneController scenes,
    GameState state,
  ) async {
    _scenes = scenes;
    registerWaveCombatComponents(world);
    progress.startRun();
    world
      ..addSystem(_combat)
      ..addSystem(TweenSystem())
      ..addSystem(MovementSystem())
      ..addSystem(ParticleSystem())
      ..addSystem(HitFlashSystem())
      ..addSystem(HealthSystem())
      ..addSystem(HealthHudSystem())
      ..addSystem(FighterDeathSystem())
      ..addSystem(SpriteStateSystem())
      ..addSystem(AnimationSystem())
      ..addSystem(SpritePivotSystem(_pivots))
      ..addSystem(OneShotFxSystem())
      ..addSystem(DamageNumberSystem())
      ..addSystem(HitFeedbackSystem());
    if (config.meleeLunge) world.addSystem(LungeSystem());
    final dust = config.disintegration;
    if (dust != null) {
      world.addSystem(_dust = DisintegrationSystem(style: dust));
    }

    // The HUD (z 100 and up) stays still while the fight shakes.
    _camera = Camera(x: world.width / 2, y: world.height / 2)
      ..shakeFreeFromZ = 100;
    // Shake / particle cues authored in the level JSON fire from animation
    // frames through the engine's cue bridges.
    installAnimationCueSystems(world, camera: _camera);
    _walk = WalkPhase(
      scroller: ParallaxScroller.spawn(
        world,
        config.backgroundPrefix,
        level.parallax,
      ),
      speed: config.walkSpeed,
      distance: config.enterDistance,
    );
    Future<FxClip?> fx(String id) async =>
        _fxStems.containsKey(id) ? loadFxClip(id, _fxStems[id]!) : null;
    installCombatFx(
      world,
      CombatFx(
        hit: await fx(_hitFx),
        slash: await fx(_slashFx),
        death: await fx(_deathFx),
        hitBurst: config.hitBurst,
      ),
      pivots: _pivots,
    );
    final numbers = config.damageNumbers;
    if (numbers != null) installDamageNumbers(world, numbers);
    final feedback = config.hitFeedback;
    if (feedback != null) {
      _hitStop = HitStop(world);
      installHitFeedback(
        world,
        feedback,
        _camera,
        hitStop: _hitStop,
        warningStyle: numbers ?? const DamageNumberStyle(),
        // With the panel art loaded the red flash is a game-layer sprite, so it
        // never covers the HUD, tabs or dialogs.
        flashAtlasId: config.ui.panelImage == null ? null : _uiPanel,
        flashRegionSize: Size(
          config.ui.upgradeLayout.frameSource.width -
              2 * config.ui.upgradeLayout.frameInset,
          config.ui.upgradeLayout.frameSource.height -
              2 * config.ui.upgradeLayout.frameInset,
        ),
      );
    }
    _combat.windupSeconds = config.windupSeconds;
    final timing = config.timing;
    if (timing != null) {
      timing.applyTo(_combat);
      world.events
        ..on<AttackParried>(
          (_) => _announce(
            world,
            config.strings.parry,
            150,
            color: 0xFF7FE0FF,
            size: 8,
            life: 1.2,
          ),
        )
        ..on<TimedStrike>(
          (_) => _announce(
            world,
            config.strings.perfect,
            150,
            color: 0xFFFFD84A,
            size: 8,
            life: 1.2,
          ),
        )
        ..on<TapMissed>(
          (_) => _announce(
            world,
            config.strings.tooEarly,
            150,
            color: 0xFFB0B0B0,
            size: 5,
            life: 0.8,
          ),
        );
    }
    world.addSystem(ConditionSystem());
    if (config.skills.isNotEmpty) _skills = SkillRunner(config.skills, _combat);
    if (config.comboBonusPerHit > 0) {
      ComboTracker.install(
        world,
        _combat,
        bonusPerHit: config.comboBonusPerHit,
        maxHits: config.comboMax,
      );
    }

    _meta[config.heroId] = await _loadMeta(config.heroId, config.heroStem);
    for (final id in level.enemyIds) {
      _meta[id] = await _loadMeta(id, _enemyStem(id));
    }

    _spawnHero(world);
    _hud = SceneHud.spawn(world, status: status, layout: config.hud);
    final ui = config.ui;
    _caption = DialogueCaption.spawn(
      world,
      style: config.hud.description,
      backdropAtlasId: ui.captionBackdropImage == null ? null : _uiScroll,
      backdropWidth: ui.captionBackdropWidth,
      backdropHeight: ui.captionBackdropHeight,
    );
    if (ui.pathNodesStem != null) {
      _path = WavePath.spawn(
        world,
        nodesAtlasId: _uiNodes,
        lineAtlasId: ui.pathLineImage == null ? null : _uiLine,
        count: level.wave.length + 1,
        y: ui.pathY,
        left: ui.pathInset,
        right: world.width - ui.pathInset,
        nodeSize: ui.pathNodeSize,
      );
    }
    installSceneLights(
      world,
      sun: config.sun,
      lights: config.lights,
      heroOf: () => heroId,
      enemyOf: () => enemyId,
    );
    if ((config.upgrades.isNotEmpty || config.skills.isNotEmpty) &&
        config.ui.buttonImage != null) {
      _upgradeBar = UpgradeBar.spawn(
        world,
        atlasId: _uiButtons,
        iconAtlasId: config.ui.iconsStem == null ? null : _uiIcons,
        iconCellSize: _iconCell,
        frameAtlasId: config.ui.panelImage == null ? null : _uiPanel,
        upgrades: config.upgrades,
        progress: progress,
        layout: config.ui.upgradeLayout,
        skills: config.skills,
        strings: config.strings,
      );
      final skills = _skills;
      if (skills != null) {
        _upgradeBar!.syncSkills(
          world,
          skills.cooldowns,
          ultimate: _combat.ultimate,
        );
      }
    }
    final chrome = config.ui.chrome;
    if (chrome != null && config.ui.panelImage != null) {
      _chrome = ScreenChrome.spawn(
        world,
        style: chrome,
        fillAtlasId: _uiPanel,
        fillSize: Size(
          config.ui.upgradeLayout.frameSource.width -
              2 * config.ui.upgradeLayout.frameInset,
          config.ui.upgradeLayout.frameSource.height -
              2 * config.ui.upgradeLayout.frameInset,
        ),
        iconAtlasId: config.ui.iconsStem == null ? null : _uiIcons,
        iconCell: _iconCell,
        currencyAtlasId: config.ui.currencyIconsStem == null
            ? null
            : _uiCurrency,
        currencyCell: _currencyCell,
      );
      _syncChrome();
    }
    if (chrome != null && config.ui.panelImage != null) {
      final layout = config.ui.upgradeLayout;
      _info = ModalDialog.spawn(
        world,
        rect: const Rect.fromLTRB(24, 104, 156, 204),
        z: 150,
        frameAtlasId: _uiPanel,
        frameSource: layout.frameSource,
        frameInset: layout.frameInset,
        frameCorner: layout.frameCorner,
        dark: layout.darkDialog,
        blurSigma: layout.blurSigma,
        rtl: chrome.rtl,
      )..addText(90, 156, config.strings.comingSoon, 7, 0xFFF6E7B4);
    }
    final badgeStyle = config.hud.statusBadges;
    if (badgeStyle != null && config.ui.panelImage != null) {
      _badges = StatusBadges.spawn(
        world,
        style: badgeStyle,
        fillAtlasId: _uiPanel,
        iconAtlasId: badgeStyle.iconsStem == null ? null : _uiStatus,
        iconCell: _statusCell,
        fillSize: Size(
          config.ui.upgradeLayout.frameSource.width -
              2 * config.ui.upgradeLayout.frameInset,
          config.ui.upgradeLayout.frameSource.height -
              2 * config.ui.upgradeLayout.frameInset,
        ),
      );
    }
    if (config.ui.popup != null && config.ui.panelImage != null) {
      _popup = ResultPopup(
        world,
        frameAtlasId: _uiPanel,
        scrollAtlasId: config.ui.captionBackdropImage == null
            ? null
            : _uiScroll,
        currencyAtlasId: config.ui.currencyIconsStem == null
            ? null
            : _uiCurrency,
        currencyCell: _currencyCell,
        goldIcon: config.ui.chrome?.goldIcon ?? 0,
        style: config.ui.popup!,
      );
    }
    waves.index = math.min(
      progress.checkpoint(config.checkpointEvery),
      plan.ids.length,
    );
    _condLabel = spawnWorldText(
      world,
      0,
      0,
      '',
      fontSize: 4.6,
      colorArgb: 0xFFE8B4FF,
      zIndex: 126,
    );
    _gearLabel = spawnWorldText(
      world,
      90,
      config.hud.gearY,
      config.strings.gearSummary(progress.gear.values),
      fontSize: 4.2,
      colorArgb: 0xFFCFE8FF,
      zIndex: 125,
    );
    _greetPlayer(world);
    _spawnEnemy(world);
  }

  DamageNumberStyle get _say =>
      config.damageNumbers ?? const DamageNumberStyle();

  /// Shows [text] as a floating line (messages, loot, hints).
  void _announce(
    World world,
    String text,
    double y, {
    int color = 0xFFFFE7A0,
    double size = 6.5,
    double life = 3.2,
  }) => spawnFloatingText(
    world,
    text,
    90,
    y,
    size: size,
    colorArgb: color,
    style: _say,
    life: life,
    rise: 6,
    popScale: 1.3,
  );

  /// The welcome-back earnings, and the one-time hints.
  void _greetPlayer(World world) {
    if (progress.pendingOfflineCoins > 0) {
      _announce(
        world,
        config.strings.awayMessage(progress.pendingOfflineCoins),
        105,
        size: 7.5,
        life: 4.5,
      );
      progress.pendingOfflineCoins = 0;
    }
    if (!config.hints) return;
    if (config.upgrades.isNotEmpty && progress.markHintSeen('upgrade')) {
      _announce(world, config.strings.hintUpgrade, 235, life: 5);
    }
    if (config.skills.isNotEmpty && progress.markHintSeen('skill')) {
      _announce(world, config.strings.hintSkill, 224, life: 5);
    }
    if (config.timing != null && progress.markHintSeen('parry')) {
      _announce(world, config.strings.hintParry, 213, life: 5);
    }
  }

  @override
  double? get ambientBrightness => config.sun?.ambientBrightness;

  @override
  Future<AtlasRegistry> loadAssets() async {
    final registry = _registry = AtlasRegistry();
    final ui = config.ui;
    final total =
        level.parallax.length +
        _meta.values.fold<int>(0, (n, m) => n + m.frames.length) +
        _fxStems.length +
        (ui.barsStem != null ? 1 : 0) +
        (ui.pathNodesStem != null ? 1 : 0) +
        (ui.pathLineImage != null ? 1 : 0) +
        (ui.captionBackdropImage != null ? 1 : 0) +
        (ui.buttonImage != null ? 1 : 0) +
        (ui.iconsStem != null ? 1 : 0) +
        (ui.currencyIconsStem != null ? 1 : 0) +
        (config.hud.statusBadges?.iconsStem != null ? 1 : 0);
    var done = 0;
    void loaded() => reportAssetProgress(++done, total);
    for (final layer in level.parallax) {
      registry.register(
        layer.atlasId(config.backgroundPrefix),
        await SpriteAtlas.loadFullImageFromAssets(
          '${config.backgroundDir}/${layer.name}.png',
        ),
      );
      loaded();
    }
    for (final meta in _meta.values) {
      for (final state in meta.frames.keys) {
        final sheet = await loadSpriteSheet(meta.stem(state));
        registry.register(meta.atlasId(state), sheet.atlas);
        if (config.disintegration != null && state == 'death') {
          await DisintegrationSystem.prepare(sheet.atlas);
        }
        _pivots.register(
          meta.atlasId(state),
          sheet.pivots,
          cell: sheet.sidecar.cell.toDouble(),
        );
        loaded();
      }
    }
    for (final e in _fxStems.entries) {
      registry.register(
        e.key,
        (await loadSpriteSheet(e.value, measurePivots: false)).atlas,
      );
      loaded();
    }
    if (ui.barsStem != null) {
      registry.register(_uiBars, await BarsArt.load(ui.barsStem!));
      loaded();
    }
    if (ui.pathNodesStem != null) {
      registry.register(
        _uiNodes,
        (await loadSpriteSheet(ui.pathNodesStem!, measurePivots: false)).atlas,
      );
      loaded();
    }
    if (ui.pathLineImage != null) {
      registry.register(
        _uiLine,
        await SpriteAtlas.loadFullImageFromAssets(ui.pathLineImage!),
      );
      loaded();
    }
    if (ui.captionBackdropImage != null) {
      registry.register(
        _uiScroll,
        await SpriteAtlas.loadFullImageFromAssets(ui.captionBackdropImage!),
      );
      loaded();
    }
    if (ui.panelImage != null) {
      final full = await SpriteAtlas.loadFullImageFromAssets(ui.panelImage!);
      registry.register(
        _uiPanel,
        panelFrameAtlas(full, ui.upgradeLayout.frameInset),
      );
      loaded();
    }
    if (ui.buttonImage != null) {
      registry.register(
        _uiButtons,
        UpgradeBar.atlasFor(
          await SpriteAtlas.loadFullImageFromAssets(ui.buttonImage!),
        ),
      );
      loaded();
    }
    if (ui.iconsStem != null) {
      final icons = await loadSpriteSheet(ui.iconsStem!, measurePivots: false);
      registry.register(_uiIcons, icons.atlas);
      _iconCell = (await loadSheetSidecar(ui.iconsStem!)).cell.toDouble();
      loaded();
    }
    if (ui.currencyIconsStem != null) {
      final icons = await loadSpriteSheet(
        ui.currencyIconsStem!,
        measurePivots: false,
      );
      registry.register(_uiCurrency, icons.atlas);
      _currencyCell = (await loadSheetSidecar(
        ui.currencyIconsStem!,
      )).cell.toDouble();
      loaded();
    }
    final statusStem = config.hud.statusBadges?.iconsStem;
    if (statusStem != null) {
      final icons = await loadSpriteSheet(statusStem, measurePivots: false);
      registry.register(_uiStatus, icons.atlas);
      _statusCell = (await loadSheetSidecar(statusStem)).cell.toDouble();
      loaded();
    }
    return registry;
  }

  @override
  Camera createCamera(World world) => _camera;

  void _spawnHero(World world) {
    final meta = _meta[config.heroId]!;
    final hs = meta.stats;
    final scale = _fitScale(hs.cell);
    final drawn = hs.cell * scale;
    _loadout = HeroLoadout(
      hp: level.scaled('hp', hs.hp),
      attack: level.scaled('attack', hs.attack),
      attackSpeed: level.scaled('attack_speed', hs.attackSpeed),
      armor: level.scaled('armor', hs.armor),
      upgrades: config.upgrades,
      progress: progress,
      starBonusPerStar: config.prestigeBonusPerStar,
    );
    heroId = spawnFighter(
      world,
      side: 'hero',
      x: level.hero.x + drawn / 2,
      y: level.hero.y + drawn / 2 - config.fieldLift,
      hp: _loadout.maxHp,
      attack: _loadout.attackNow,
      attackSpeed: _loadout.attackSpeedNow,
      armor: _loadout.armorNow,
      critChance: level.heroCritChance,
      critMultiplier: level.heroCritMultiplier,
      atlasId: meta.atlasId('idle'),
      frameCount: meta.frames['idle']!,
      extraClips: meta.extraClips(cues: level.cues),
      impactParticles: config.impactParticles(),
      scaleX: scale,
      scaleY: scale,
      // The hero draws in front of enemies and the corpse sliding past him.
      zIndex: 25,
    );
    final bar = config.hud.heroBar;
    if (config.ui.barsStem != null) {
      _heroBar = SpriteHealthBar.spawn(
        world,
        atlasId: _uiBars,
        source: heroId!,
        left: bar.x,
        top: bar.y,
        width: bar.width,
        height: bar.artHeight,
        fill: bar.fillArt ?? 'xp',
      );
      final ult = config.hud.ultBar;
      if (ult != null) {
        _ultBar = SpriteHealthBar.spawn(
          world,
          atlasId: _uiBars,
          source: heroId!,
          left: ult.x,
          top: ult.y,
          width: ult.width,
          height: ult.artHeight,
          fill: ult.fillArt ?? 'xp',
          fractionOf: () => _combat.ultimate,
        );
      }
    } else {
      spawnHealthHudBar(
        world,
        source: heroId!,
        x: bar.x,
        y: bar.y,
        width: bar.width,
        height: bar.height,
        fillColorArgb: bar.fillColorArgb,
        screenSpace: false,
        zIndex: 100,
      );
    }
  }

  /// Brings the next enemy in from off-screen; combat starts once it has
  /// walked up to its anchor. The previous one stays as a corpse that
  /// scrolls away with the ground.
  void _spawnEnemy(World world) {
    _clearOverhead(world);
    _dying.clear();
    _rewarded.clear();
    _lastDead = null;
    _focus = null;
    for (final c in _corpses) {
      world.destroy(c);
    }
    // The squad that just fell becomes the corpses that slide off.
    _corpses = List.of(_squad);
    _squad.clear();
    // Cleared once destroyed: entity ids are recycled, so destroying the same
    // bar twice would destroy whatever was spawned into its ids in between.
    if (_enemyHudId != null) world.destroy(_enemyHudId!);
    _enemyHudId = null;
    _enemyBar?.destroy();
    _enemyBar = null;

    final meta = _meta[waves.currentId]!;
    final stats = meta.stats;
    status = waves.isBoss
        ? config.bossLabel
        : config.strings.waveLabel(waves.index + 1, waves.wave.length);
    final kind = waves.isBoss ? WaveKind.normal : plan.kinds[waves.index];
    final rw = level.randomWaves;
    final sizeKind = kind.sizeFactor(rw);
    _rewardCoins = waves.isBoss
        ? config.bossCoins
        : kind.coins(rw, config.coinsPerKill);
    final scale = _fitScale(stats.cell) * sizeKind * config.enemyScale;
    final drawn = stats.cell * scale;
    _enemyTargetX = level.enemyAnchor.x + drawn / 2;
    _enemyBaseY =
        level.enemyAnchor.y +
        drawn / config.enemyScale -
        drawn / 2 -
        config.fieldLift;
    enemyId = spawnFighter(
      world,
      side: 'enemy',
      x: _enemyTargetX + config.enterDistance,
      y: _enemyBaseY + _bottomPadding(meta, scale),
      hp: waves.isBoss
          ? level.bossScaled('hp', stats.hp)
          : stats.hp * level.enemyRamp(waves.index) * kind.hpFactor(rw),
      attack: waves.isBoss
          ? level.bossScaled('attack', stats.attack)
          : stats.attack * level.enemyRamp(waves.index) * kind.attackFactor(rw),
      attackSpeed: stats.attackSpeed,
      armor: stats.armor,
      powers: kind == WaveKind.treasure
          ? null
          : EnemyPowers.parse(stats.powers),
      atlasId: meta.atlasId('idle'),
      frameCount: meta.frames['idle']!,
      extraClips: meta.extraClips(cues: level.cues),
      impactParticles: config.impactParticles(),
      // Sheets already face the hero (leftward); do not mirror.
      scaleX: scale,
      scaleY: scale,
      zIndex: 20,
    );
    _squad.add(enemyId!);
    _spawnExtras(world, meta, stats, kind, scale);
    _combat.focus = enemyId;
    _spawnEnemyBar(world);
    _addOverhead(world, enemyId!, meta, scale);
    _path?.update(waves.index, config.ui.pathNodeSize);
    enemyLabel = switch (kind) {
      WaveKind.elite => config.strings.eliteName(meta.name),
      WaveKind.treasure => config.strings.goldenName(meta.name),
      WaveKind.normal => meta.name,
    };
    enemyDescription = meta.descriptionFa;
    _combat.enabled = false;
    _walk.start(
      world,
      hero: heroId!,
      enemy: _squad.first,
      corpses: _corpses,
      companions: _squad.skip(1).toList(),
    );
    _caption.show(world, enemyDescription);
    _syncHud(world);
  }

  /// Empty rows under a fighter's feet in its sheet, in world units at
  /// [scale]: sheets are cropped per creature, so one with space below its feet
  /// would hover above the ground if drawn cell-aligned.
  double _bottomPadding(FighterMeta meta, double scale) {
    final body = _pivots.bodyOf(meta.atlasId('idle'));
    return body == null ? 0 : math.max(0, body.cell - 1 - body.bottom) * scale;
  }

  /// Puts a small plain health bar over [enemy] ([HudLayout.enemyOverhead]).
  void _addOverhead(
    World world,
    EntityId enemy,
    FighterMeta meta,
    double scale,
  ) {
    final style = config.hud.enemyOverhead;
    if (style == null) return;
    // The bar sits over the creature's own head and feet-centre, measured from
    // its sprite, not over the middle of a cell that may be mostly empty.
    final body = _pivots.bodyOf(meta.atlasId('idle'));
    final half = meta.stats.cell / 2;
    final dx = body == null ? 0.0 : (body.x - half) * scale;
    final dy = (body == null ? -half : body.top - half) * scale;
    _overhead[enemy] = _Overhead(
      spawnHealthHudBar(
        world,
        source: enemy,
        x: -1000,
        y: -1000,
        width: style.width,
        height: style.height,
        fillColorArgb: style.fillColorArgb,
        backgroundColorArgb: 0xB0000000,
        screenSpace: false,
        // Below the HUD's draw order, so it shakes with the game it floats in.
        zIndex: 90,
      ),
      dx,
      dy,
    );
  }

  /// Seconds an overhead bar stays up after the enemy last lost health.
  static const _overheadShowSeconds = 2.5;

  /// Moves every overhead bar to its enemy's head, shows it only while the
  /// enemy is being hurt (and for a moment after), and drops the bars of dead
  /// or removed enemies.
  void _followOverhead(World world, double dt) {
    final style = config.hud.enemyOverhead;
    if (style == null || _overhead.isEmpty) return;
    for (final e in _overhead.entries.toList()) {
      final pos = world.componentsOf<Position>().get(e.key);
      if (pos == null || !_alive(world, e.key)) {
        world.destroy(e.value.bar);
        _overhead.remove(e.key);
        continue;
      }
      final o = e.value;
      final hp = world.componentsOf<Health>().get(e.key)?.current ?? 0;
      if (o.hp != null && hp < o.hp!) o.shown = _overheadShowSeconds;
      o.hp = hp;
      o.shown = math.max(0, o.shown - dt);
      world.componentsOf<Position>().get(o.bar)
        ?..x = pos.x + o.feetDx - style.width / 2
        ..y = o.shown > 0 ? pos.y + o.headDy - style.height - 1 : -1000;
    }
  }

  /// Starts the dust of each enemy once its death clip has ended and the
  /// short delay after it has run out.
  void _tickDying(World world, double dt) {
    final dust = _dust;
    if (dust == null || _dying.isEmpty) return;
    for (final id in _dying.keys.toList()) {
      var left = _dying[id]!;
      if (left < 0) {
        // Waiting for the death clip to end; the delay counts from then on.
        if (!spriteStateFinished(world, id, 'death')) continue;
        left = dust.style.delay;
      }
      left -= dt;
      if (left > 0) {
        _dying[id] = left;
        continue;
      }
      _dying.remove(id);
      final sprite = world.componentsOf<Sprite>().get(id);
      final atlas = sprite == null
          ? null
          : _registry?.tryResolve(sprite.atlasId);
      if (atlas != null) dust.start(world, id, atlas);
    }
  }

  void _clearOverhead(World world) {
    for (final e in _overhead.values) {
      world.destroy(e.bar);
    }
    _overhead.clear();
  }

  /// The health bar of the enemy being fought (the focused one).
  void _spawnEnemyBar(World world) {
    if (config.hud.enemyOverhead != null) return;
    if (_enemyHudId != null) world.destroy(_enemyHudId!);
    _enemyHudId = null;
    _enemyBar?.destroy();
    _enemyBar = null;
    final bar = config.hud.enemyBar;
    if (config.ui.barsStem != null) {
      _enemyBar = SpriteHealthBar.spawn(
        world,
        atlasId: _uiBars,
        source: enemyId!,
        left: bar.x,
        top: bar.y,
        width: bar.width,
        height: bar.artHeight,
        fill: waves.isBoss ? 'boss' : (bar.fillArt ?? 'hp'),
      );
    } else {
      _enemyHudId = spawnHealthHudBar(
        world,
        source: enemyId!,
        x: bar.x,
        y: bar.y,
        width: bar.width,
        height: bar.height,
        fillColorArgb: waves.isBoss
            ? config.hud.bossBarColorArgb
            : bar.fillColorArgb,
        screenSpace: false,
        zIndex: 100,
      );
    }
  }

  /// Spawns the extra enemies of a squad behind the front one.
  void _spawnExtras(
    World world,
    FighterMeta meta,
    FighterStats stats,
    WaveKind kind,
    double scale,
  ) {
    final rule = config.squad;
    if (rule == null) return;
    final n = rule.extrasFor(waves.index, boss: waves.isBoss, kind: kind);
    final rw = level.randomWaves;
    for (var i = 1; i <= n; i++) {
      final s = scale * math.pow(rule.backScale, i);
      final id = spawnFighter(
        world,
        side: 'enemy',
        x: _enemyTargetX + config.enterDistance + rule.rowOffsetX * i,
        y: _enemyBaseY + rule.rowOffsetY * i + _bottomPadding(meta, s),
        hp:
            stats.hp *
            level.enemyRamp(waves.index) *
            kind.hpFactor(rw) *
            rule.extraStrength,
        attack:
            stats.attack *
            level.enemyRamp(waves.index) *
            kind.attackFactor(rw) *
            rule.extraStrength,
        attackSpeed: stats.attackSpeed,
        armor: stats.armor,
        powers: EnemyPowers.parse(stats.powers),
        atlasId: meta.atlasId('idle'),
        frameCount: meta.frames['idle']!,
        extraClips: meta.extraClips(cues: level.cues),
        impactParticles: config.impactParticles(),
        scaleX: s,
        scaleY: s,
        zIndex: 20 - i,
      );
      _squad.add(id);
      _addOverhead(world, id, meta, s);
    }
  }

  bool _alive(World world, EntityId id) =>
      (world.componentsOf<Health>().get(id)?.current ?? 0) > 0;

  List<EntityId> _livingEnemies(World world) => [
    for (final id in _squad)
      if (_alive(world, id)) id,
  ];

  /// Focuses the living enemy under [at] (a tap on it); true when one was hit.
  /// Only meaningful while several are standing.
  bool _focusEnemyAt(World world, Offset at) {
    final living = _livingEnemies(world);
    if (living.length < 2) return false;
    final pos = world.componentsOf<Position>();
    EntityId? best;
    var bestDist = config.fighterSize * 0.5;
    for (final id in living) {
      final p = pos.get(id);
      if (p == null) continue;
      final d = (Offset(p.x, p.y) - at).distance;
      if (d <= bestDist) {
        bestDist = d;
        best = id;
      }
    }
    if (best == null) return false;
    _focus = best;
    _refreshSquad(world);
    return true;
  }

  /// Pays for enemies that just fell, then points the fight (and the health
  /// bar) at the focused enemy, or the first one left standing.
  void _refreshSquad(World world) {
    for (final id in _squad) {
      if (_alive(world, id) || !_rewarded.add(id)) continue;
      final front = id == _squad.first;
      final reward = front
          ? _rewardCoins
          : (_rewardCoins * (config.squad?.extraStrength ?? 1)).ceil();
      progress.addCoins(reward);
      _earnedCoins += reward;
      progress.recordKill();
      if (front) _rollLoot(world);
      _upgradeBar?.sync(world);
      _lastDead = id;
      final style = config.disintegration;
      if (style != null) _dying[id] = -1;
    }
    final living = [
      for (final id in _squad)
        if (_alive(world, id)) id,
    ];
    final target = _focus != null && living.contains(_focus)
        ? _focus
        : living.firstOrNull;
    if (target != null && target != enemyId) {
      enemyId = target;
      _combat.focus = target;
      _spawnEnemyBar(world);
    }
    _updateFocusMark(world, living.length > 1 ? target : null);
  }

  /// A marker over the enemy the hero is fighting, only while there are several.
  void _updateFocusMark(World world, EntityId? target) {
    final pos = target == null
        ? null
        : world.componentsOf<Position>().get(target);
    var mark = _focusMark;
    if (pos == null) {
      if (mark != null) {
        world.destroy(mark);
        _focusMark = null;
      }
      return;
    }
    mark ??= _focusMark = spawnWorldText(
      world,
      pos.x,
      pos.y,
      'v',
      fontSize: 8,
      colorArgb: 0xFFFFD84A,
      zIndex: 130,
    );
    world.componentsOf<Position>().get(mark)
      ?..x = pos.x
      ..y = pos.y - config.fighterSize * 0.55;
  }

  void _syncHud(World world) => _hud.sync(
    world,
    status: status,
    enemy: enemyLabel,
    ultimate: config.strings.ultimateLabel(_combat.ultimate),
  );

  /// Whether a tab's dialog is open; the engine has paused the world and
  /// blurred the fight, and the scene's own logic stands still too.
  bool get _modalOpen =>
      (_upgradeBar?.dialogOpen ?? false) || (_info?.isOpen ?? false);

  void _syncChrome() => _chrome?.sync(
    gold: config.strings.localize(_compact(progress.coins)),
    gems: config.strings.localize('${progress.stars}'),
    title: level.name,
  );

  /// 12400 -> `12.4K`, so the currency bar never outgrows its slot.
  static String _compact(int n) =>
      n >= 10000 ? '${(n / 1000).toStringAsFixed(n >= 100000 ? 0 : 1)}K' : '$n';

  void _finish(World world, String message) {
    finished = true;
    // The popup carries the message; the wave label stays as it was.
    if (_popup == null || !(_heroFell || _heroWon)) status = message;
    _caption.hide();
    _syncHud(world);
    final bar = _upgradeBar;
    final popup = _popup;
    if (popup != null && (_heroFell || _heroWon)) {
      popup.show(
        title: _heroWon ? config.strings.victory : config.strings.defeat,
        message: message,
        detail: config.showSummary
            ? config.strings.summary(
                wave: waves.index + 1,
                killCount: progress.kills,
                bestWave: progress.bestWave,
              )
            : null,
        reward: _heroWon || _earnedCoins > 0
            ? config.strings.localize('+${_withCommas(_earnedCoins)}')
            : null,
      );
      _syncChrome();
    } else if (config.showSummary && _heroFell) {
      _caption.show(
        world,
        config.strings.summary(
          wave: waves.index + 1,
          killCount: progress.kills,
          bestWave: progress.bestWave,
        ),
      );
    }
    if (bar == null) return;
    final startWave = progress.checkpoint(config.checkpointEvery) + 1;
    if (_heroFell || _heroWon) {
      bar.showRetry(world, label: config.strings.retryLabel(startWave));
    }
    if (_heroWon && config.prestigeBonusPerStar > 0) bar.showAscend(world);
  }

  static String _withCommas(int n) => n.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (m) => ',',
  );

  /// Rolls the loot for the enemy just killed and wears it if it is better.
  void _rollLoot(World world) {
    final table = config.loot;
    if (table == null) return;
    final kind = waves.isBoss ? WaveKind.treasure : plan.kinds[waves.index];
    final random = math.Random(
      progress.kills * 7919 + waves.index * 31 + progress.coins,
    );
    final gear = table.roll(random, kind, waves.index);
    if (gear == null) return;
    if (!progress.equipIfBetter(gear)) return;
    _announce(
      world,
      config.strings.lootLabel(gear),
      190,
      color: switch (gear.rarity) {
        GearRarity.epic => 0xFFD38CFF,
        GearRarity.rare => 0xFF6FB6FF,
        GearRarity.common => 0xFFFFFFFF,
      },
      life: 2.6,
    );
    final id = _gearLabel;
    if (id != null) {
      world.componentsOf<eng.Text>().get(id)?.text = config.strings.gearSummary(
        progress.gear.values,
      );
    }
    final h = heroId;
    if (h != null) _loadout.apply(world, h);
  }

  /// True once [fighter]'s death clip has finished and lingered for a beat.
  bool _deathPlayed(World world, EntityId fighter, double dt) {
    if (!spriteStateFinished(world, fighter, 'death')) return false;
    _deathHold += dt;
    if (_deathHold < config.deathHoldSeconds) return false;
    _deathHold = 0;
    return true;
  }

  @override
  void update(double dt, World world) {
    _upgradeBar?.update(world, dt);
    _popup?.update(dt);
    _info?.update(dt);
    if (_modalOpen) return;
    _hitStop?.update(dt);
    _skills?.tick(dt);
    _barSync += dt;
    if (_barSync >= 0.2) {
      _barSync = 0;
      _syncChrome();
      _syncHud(world);
      final skills = _skills;
      if (skills != null) {
        _upgradeBar?.syncSkills(
          world,
          skills.cooldowns,
          ultimate: _combat.ultimate,
        );
      }
    }
    _updateConditionLabel(world);
    _caption.update(world, dt);
    _heroBar?.sync();
    _followOverhead(world, dt);
    _tickDying(world, dt);
    _enemyBar?.sync();
    _ultBar?.sync();
    if (finished) return;
    final h = heroId;
    final e = enemyId;
    if (h == null || e == null) return;

    if (_walk.active) {
      if (_walk.update(world)) {
        _corpses = [];
        _fightDelayLeft = config.fightDelaySeconds;
        _combat.enabled = _fightDelayLeft <= 0;
      }
      return;
    }
    if (_fightDelayLeft > 0) {
      _fightDelayLeft -= dt;
      if (_fightDelayLeft <= 0) _combat.enabled = true;
      return;
    }

    final heroHp = world.componentsOf<Health>().get(h);
    if (heroHp != null && heroHp.current <= 0) {
      if (!_deathPlayed(world, h, dt)) return;
      _heroFell = true;
      return _finish(world, config.fallenMessage);
    }
    _refreshSquad(world);
    if (_squad.any((id) => _alive(world, id))) return; // the fight goes on
    // The description stays up for the whole encounter and goes with the enemy.
    _caption.hide();
    // The dust of a fallen body plays out before the next enemy walks in, and
    // after the boss before the victory popup pauses the world.
    final dust = _dust;
    if (dust != null &&
        (_dying.isNotEmpty ||
            (waves.isBoss ? dust.isBusy : dust.activeCount > 0))) {
      return;
    }
    if (!_deathPlayed(world, _lastDead ?? e, dt)) return;
    if (waves.isBoss) {
      _heroWon = true;
      config.onCleared?.call();
      return _finish(world, config.clearedMessage);
    }
    waves.advance();
    progress.reachWave(waves.index);
    _spawnEnemy(world);
  }

  /// Keeps the hero's condition line (Bleed 2s...) over its head.
  void _updateConditionLabel(World world) {
    final badges = _badges;
    if (badges != null) {
      final hero = heroId;
      badges.sync(
        world,
        hero == null ? null : world.componentsOf<Conditions>().get(hero),
      );
      return;
    }
    final label = _condLabel;
    final h = heroId;
    if (label == null || h == null) return;
    final pos = world.componentsOf<Position>().get(h);
    final text = world.componentsOf<eng.Text>().get(label);
    if (pos == null || text == null) return;
    text.text = world.componentsOf<Conditions>().get(h)?.describe() ?? '';
    world.componentsOf<Position>().get(label)
      ?..x = pos.x
      ..y = pos.y - 46;
  }

  @override
  void handleTap(World world, SceneController scenes, Offset worldPosition) {
    final bar = _upgradeBar;
    final tab = _chrome?.hit(worldPosition);
    if (tab != null) return _onTab(world, bar, tab);
    final info = _info;
    if (info != null && info.isOpen) {
      if (info.closesOn(worldPosition)) _closeTabs(bar);
      return;
    }
    final pressed = bar?.hit(worldPosition);
    if (pressed == UpgradeBar.retryAction) return _restart(scenes);
    if (pressed == UpgradeBar.ascendAction) {
      progress.ascend();
      return _restart(scenes);
    }
    if (pressed == UpgradeBar.menuAction) {
      bar!.toggleMenu(world);
      if (!bar.dialogOpen) _chrome?.setActive(-1);
      return;
    }
    if (pressed != null && pressed.startsWith(UpgradeBar.skillPrefix)) {
      final skill = config.skills.firstWhere(
        (s) => '${UpgradeBar.skillPrefix}${s.id}' == pressed,
      );
      final h = heroId;
      final skills = _skills;
      if (h != null && skills != null) {
        skills.use(
          world,
          skill,
          hero: h,
          enemy: enemyId,
          enemies: _livingEnemies(world),
        );
        bar!.syncSkills(world, skills.cooldowns, ultimate: _combat.ultimate);
      }
      return;
    }
    if (pressed != null) {
      final upgrade = config.upgrades.firstWhere((u) => u.id == pressed);
      if (progress.buy(upgrade)) {
        final h = heroId;
        if (h != null) _loadout.apply(world, h);
        bar!.sync(world);
      }
      return;
    }
    if (_modalOpen) return;
    if (!finished) {
      if (_focusEnemyAt(world, worldPosition)) return;
      if (config.timing != null) _combat.tap(world);
      return;
    }
    // With buttons, a finished run restarts only from them; without, any tap
    // replays.
    if (bar != null) return;
    _restart(scenes);
  }

  /// Closes whatever tab dialog is open and lights the Battle tab again.
  void _closeTabs(UpgradeBar? bar) {
    bar?.closeMenu();
    _info?.close();
    _chrome?.setActive(-1);
  }

  /// A tap on the tab bar: Battle closes any dialog; Hero, Upgrade and Skills
  /// open the upgrades dialog; the tabs with no screen yet open a "coming
  /// soon" dialog. Every dialog blurs and pauses the fight (`ModalDialog`).
  void _onTab(World world, UpgradeBar? bar, String tab) {
    final chrome = _chrome!;
    if (finished) return;
    switch (tab) {
      case 'battle':
        if (!(bar?.dialogOpen ?? false) && config.openMap != null) {
          _scenes?.loadScene(config.openMap!());
          return;
        }
        _closeTabs(bar);
      case 'hero' || 'upgrade' || 'skills':
        if (bar == null) return;
        _info?.close();
        if (!bar.dialogOpen) bar.toggleMenu(world);
        chrome.setActive(chrome.indexOf(tab));
      default:
        bar?.closeMenu();
        _info
          ?..setTitle(chrome.style.tabs[chrome.indexOf(tab)].label)
          ..open();
        chrome.setActive(chrome.indexOf(tab));
    }
  }

  void _restart(SceneController scenes) => (_scenes ?? scenes).loadScene(
    WaveCombatScene(level: level, config: config, progress: progress),
  );
}

/// An enemy's overhead health bar and when it last needed showing.
class _Overhead {
  _Overhead(this.bar, this.feetDx, this.headDy);

  final EntityId bar;

  /// Offset of the creature's feet-centre from its sprite centre, and of its
  /// head top (negative: above), in world units.
  final double feetDx;
  final double headDy;
  double? hp;
  double shown = 0;
}
