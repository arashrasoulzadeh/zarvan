import 'package:flutter_test/flutter_test.dart';
import 'package:zarvan_core/zarvan_core.dart' hide StatusEffect, StatusEffects;
import 'package:zarvan_flutter/zarvan_flutter.dart' as eng;
import 'package:zarvan_idle/zarvan_idle.dart';
import 'package:zarvan_platformer/zarvan_platformer.dart';

/// A scene with no assets: fighters come from [_meta] and nothing is drawn.
class _Scene extends WaveCombatScene {
  _Scene({required super.level, required super.config, super.progress})
    : super(metaLoader: _meta);

  @override
  Future<eng.AtlasRegistry> loadAssets() async => eng.AtlasRegistry();
}

Future<FighterMeta> _meta(String id, String stem) async => FighterMeta(
  id: id,
  name: id,
  stemPrefix: stem,
  frames: const {'idle': 1, 'attack': 1, 'death': 1},
  stats: id == 'hero'
      ? FighterStats(hp: 500, attack: 40, attackSpeed: 2, armor: 0)
      : FighterStats(
          hp: id == 'boss' ? 60 : (id == 'tank' ? 5000 : 30),
          attack: 2,
          attackSpeed: 1,
          armor: 0,
          powers: id == 'bleeder'
              ? const ['hits apply bleed: 2% hero max hp/s for 3s']
              : const [],
        ),
);

LevelData _level({List<String>? wave, Map<String, dynamic> extra = const {}}) =>
    LevelData.fromJson({
      'name': 'L',
      'wave': wave ?? ['a', 'b', 'c', 'd', 'e', 'f'],
      'boss': 'boss',
      'background': 'x',
      'hero': {'x': 10, 'y': 200},
      'enemy_anchor': {'x': 100, 'y': 200},
      ...extra,
    });

const _strength = HeroUpgrade(
  id: 's',
  label: 'S',
  stat: 'attack',
  perLevel: 0.5,
  baseCost: 5,
);

const _tabs = [
  eng.NavTab(id: 'battle', label: 'Battle', icon: 0),
  eng.NavTab(id: 'hero', label: 'Hero', icon: 1),
  eng.NavTab(id: 'upgrade', label: 'Upgrade', icon: 2),
  eng.NavTab(id: 'skills', label: 'Skills', icon: 3),
  eng.NavTab(id: 'allies', label: 'Allies', icon: 4),
  eng.NavTab(id: 'shop', label: 'Shop', icon: 5),
];

WaveCombatConfig _config({bool popup = true, bool overhead = false}) =>
    WaveCombatConfig(
      heroStem: 'hero',
      enemyRoot: 'enemies',
      backgroundDir: 'bg',
      backgroundPrefix: 'bg',
      ui: WaveUiArt(
        buttonImage: 'btn.png',
        panelImage: 'panel.png',
        iconsStem: 'icons',
        chrome: const eng.ScreenChromeStyle(tabs: _tabs),
        popup: popup ? const ResultPopupStyle() : null,
        upgradeLayout: const UpgradeLayout(
          menu: true,
          menuButton: false,
          showCoins: false,
          skillsOnDock: true,
          darkDialog: true,
          resultLift: 40,
          retryY: 200,
          retryWidth: 70,
        ),
      ),
      upgrades: const [_strength],
      coinsPerKill: 10,
      bossCoins: 50,
      deathHoldSeconds: 0.1,
      waveSeed: 1,
      hitFeedback: HitFeedback(),
      fightDelaySeconds: 0,
      hud: HudLayout(
        enemyOverhead: overhead
            ? const HudBarStyle(
                x: 0,
                y: 0,
                width: 20,
                height: 2,
                fillColorArgb: 0xFFFF0000,
              )
            : null,
        ultBar: HudBarStyle(x: 8, y: 58, fillColorArgb: 0xFF2AA198),
        ultText: HudTextStyle(x: 8, y: 73),
      ),
    );

List<String> _texts(World w) {
  final t = w.componentsOf<eng.Text>();
  return [for (var i = 0; i < t.length; i++) t.denseAt(i).text];
}

class _Run {
  _Run(this.scene, this.world, this.loaded);

  final _Scene scene;
  final World world;
  final List<eng.Scene> loaded;

  void run(double seconds, {double dt = 0.05}) {
    for (var t = 0.0; t < seconds; t += dt) {
      world.step(dt);
      scene.update(dt, world);
    }
  }

  void tap(double x, double y) =>
      scene.handleTap(world, eng.SceneController(), Offset(x, y));
}

Future<_Run> _start(_Scene scene) async {
  final world = World(width: 180, height: 320);
  registerCoreComponents(world);
  eng.registerFlutterComponents(world);
  final loaded = <eng.Scene>[];
  final controller = eng.SceneController()
    ..attach(loadScene: loaded.add, pushOverlay: (_) {}, popOverlay: () {});
  await scene.populate(world, controller, GameState());
  return _Run(scene, world, loaded);
}

void main() {
  const heroTab = Offset(45, 305);
  const battleTab = Offset(15, 305);
  const alliesTab = Offset(135, 305);

  test('Hero opens the upgrades dialog and pauses; Battle closes it', () async {
    final r = await _start(_Scene(level: _level(), config: _config()));
    r.tap(heroTab.dx, heroTab.dy);
    expect(r.world.timeScale, 0);
    r.tap(battleTab.dx, battleTab.dy);
    expect(r.world.timeScale, 1);
  });

  test('a tab with no screen opens a blurred, pausing dialog', () async {
    final r = await _start(_Scene(level: _level(), config: _config()));
    r.tap(alliesTab.dx, alliesTab.dy);
    expect(r.world.timeScale, 0);
    r.run(0.5, dt: 0.05);
    final blurs = r.world.componentsOf<eng.BackdropBlur>();
    expect([
      for (var i = 0; i < blurs.length; i++) blurs.denseAt(i).sigma,
    ], contains(3));
    r.tap(90, 20); // outside the dialog closes it
    expect(r.world.timeScale, 1);
  });

  test('the wave counter and ultimate meter are written to the HUD', () async {
    final r = await _start(_Scene(level: _level(), config: _config()));
    expect(_texts(r.world), containsAll(['Wave 1/6', 'ULT 0%']));
  });

  test(
    'a lost run shows the DEFEAT popup and its Retry button works',
    () async {
      final progress = HeroProgress();
      final r = await _start(
        _Scene(level: _level(), config: _config(), progress: progress),
      );
      r.world.componentsOf<Health>().get(r.scene.heroId!)!.current = 0;
      r.run(6);
      expect(r.scene.finished, isTrue);
      expect(_texts(r.world), contains('DEFEAT'));
      expect(
        _texts(r.world).where((t) => t == r.scene.config.fallenMessage),
        hasLength(1),
        reason: 'the message is on the popup only, not repeated in the HUD',
      );
      r.tap(heroTab.dx, heroTab.dy);
      expect(
        r.world.timeScale,
        0,
        reason: 'the popup pauses; tabs change nothing',
      );
      r.tap(90, 200);
      expect(r.loaded.single, isA<WaveCombatScene>());
    },
  );

  test('without a popup style a lost run keeps the plain message', () async {
    final r = await _start(
      _Scene(level: _level(), config: _config(popup: false)),
    );
    r.world.componentsOf<Health>().get(r.scene.heroId!)!.current = 0;
    r.run(6);
    expect(_texts(r.world), isNot(contains('DEFEAT')));
  });

  group('overhead enemy bars', () {
    // The small overhead bars are the 20-wide ones.
    List<int> small(World w) {
      final hud = w.componentsOf<eng.HudBar>();
      return [
        for (var i = 0; i < hud.length; i++)
          if (hud.denseAt(i).width == 20) hud.entityAt(i),
      ];
    }

    test(
      'each enemy gets a small bar that follows it and goes when it dies',
      () async {
        final r = await _start(
          _Scene(level: _level(), config: _config(overhead: true)),
        );
        final enemy = r.scene.enemyId!;
        expect(small(r.world), hasLength(1));
        final pos = r.world.componentsOf<Position>();
        r.run(0.5);
        final bar = small(r.world).single;
        expect(
          pos.get(bar)!.x,
          closeTo(pos.get(enemy)!.x - 10, 4),
          reason: 'centred over the enemy, a frame behind while it walks',
        );
        expect(pos.get(bar)!.y, lessThan(pos.get(enemy)!.y));
        r.world.componentsOf<Health>().get(enemy)!.current = 0;
        r.run(0.1);
        expect(small(r.world), isEmpty);
      },
    );

    test('without the style no overhead bars are drawn', () async {
      final r = await _start(_Scene(level: _level(), config: _config()));
      expect(small(r.world), isEmpty);
    });
  });

  test(
    'the red hit flash is a game-layer sprite, not a screen overlay',
    () async {
      final r = await _start(_Scene(level: _level(), config: _config()));
      expect(
        r.world.componentsOf<eng.ScreenTint>().length,
        0,
        reason: 'a ScreenTint would draw over the HUD, tabs and dialogs',
      );
      final sprites = r.world.componentsOf<eng.Sprite>();
      final flash = [
        for (var i = 0; i < sprites.length; i++)
          if (sprites.denseAt(i).zIndex == 95) sprites.denseAt(i),
      ];
      expect(flash, hasLength(1));
      expect(flash.single.zIndex, lessThan(100), reason: 'below the HUD');
    },
  );
}
