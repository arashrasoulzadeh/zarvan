import 'dart:ui' show Offset, Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:zarvan_core/zarvan_core.dart';
import 'package:zarvan_flutter/zarvan_flutter.dart' as eng;
import 'package:zarvan_flutter/zarvan_flutter.dart' show AudioOutput;
import 'package:zarvan_idle/src/menu/art_sizes.dart';
import 'package:zarvan_idle/zarvan_idle.dart';

/// Scenes with no art loaded: entities still spawn, nothing is drawn.
class _Home extends HomeScene {
  _Home(super.config);
  @override
  Future<eng.AtlasRegistry> loadAssets() async => eng.AtlasRegistry();
}

class _Map extends LevelSelectScene {
  _Map(super.config);
  @override
  Future<eng.AtlasRegistry> loadAssets() async => eng.AtlasRegistry();
}

class _Glossary extends GlossaryScene {
  _Glossary(super.config);
  @override
  Future<eng.AtlasRegistry> loadAssets() async => eng.AtlasRegistry();
}

World _world() {
  final w = World(width: 180, height: 320);
  registerCoreComponents(w);
  eng.registerFlutterComponents(w);
  return w;
}

List<String> _texts(World w) {
  final t = w.componentsOf<eng.Text>();
  return [for (var i = 0; i < t.length; i++) t.denseAt(i).text];
}

void main() {
  group('HomeScene', () {
    Future<(World, _Home, List<String>, List<String>)> start() async {
      final actions = <String>[];
      final langs = <String>[];
      final scene = _Home(
        HomeConfig(
          backgroundImage: 'bg',
          logoImage: 'logo',
          buttonImage: 'btn',
          panelImage: 'panel',
          footer: 'Offline earnings ready!',
          entries: const [
            HomeEntry(id: 'play', label: 'PLAY', primary: true),
            HomeEntry(id: 'heroes', label: 'HEROES'),
            HomeEntry(id: 'settings', label: 'SETTINGS'),
          ],
          languages: const [
            LanguageOption('en', 'English'),
            LanguageOption('fa', 'فارسی'),
          ],
          activeLanguage: 'en',
          onAction: (id, _) => actions.add(id),
          onLanguage: (code, _) => langs.add(code),
        ),
      );
      final w = _world();
      await scene.populate(w, eng.SceneController(), GameState());
      return (w, scene, actions, langs);
    }

    test('shows the buttons and footer; a tap reports the entry', () async {
      final (w, scene, actions, _) = await start();
      expect(
        _texts(w),
        containsAll(['PLAY', 'HEROES', 'SETTINGS', 'Offline earnings ready!']),
      );
      scene.handleTap(w, eng.SceneController(), const Offset(90, 182));
      scene.handleTap(w, eng.SceneController(), const Offset(90, 226));
      expect(actions, ['play', 'heroes']);
    });

    test(
      'Settings opens a pausing language dialog; picking reports the code',
      () async {
        final (w, scene, actions, langs) = await start();
        scene.handleTap(w, eng.SceneController(), const Offset(90, 270));
        expect(
          actions,
          isEmpty,
          reason: 'settings is the dialog, not an action',
        );
        expect(w.timeScale, 0);
        scene.handleTap(
          w,
          eng.SceneController(),
          const Offset(115, 158),
        ); // فارسی
        expect(langs, ['fa']);
        expect(w.timeScale, 1, reason: 'the dialog closed');
      },
    );

    test('tapping outside the dialog closes it without choosing', () async {
      final (w, scene, _, langs) = await start();
      scene.handleTap(w, eng.SceneController(), const Offset(90, 270));
      scene.handleTap(w, eng.SceneController(), const Offset(5, 5));
      expect(langs, isEmpty);
      expect(w.timeScale, 1);
    });
  });

  group('LevelSelectScene', () {
    const tap = (center: Offset(90, 108), enter: Offset(90, 250));
    const prevBtn = Offset(36, 250), nextBtn = Offset(144, 250);
    const peekPrev = Offset(10, 108), peekNext = Offset(170, 108);

    Future<(World, _Map, List<String>, List<String>)> start({
      int unlocked = 2,
      bool rtl = false,
      List<String> thumbs = const [],
    }) async {
      final opened = <String>[];
      final events = <String>[];
      final scene = _Map(
        LevelSelectConfig(
          backgroundImage: 'bg',
          buttonImage: 'btn',
          panelImage: 'panel',
          nodesStem: 'nodes',
          unlocked: () => unlocked,
          rtl: rtl,
          zones: [
            for (var i = 0; i < 7; i++)
              ZoneCard(
                key: 'z$i',
                title: 'Zone $i',
                subtitle: 'Stages $i',
                thumbImages: thumbs,
              ),
          ],
          onOpen: (z, _) => opened.add(z.key),
          onBack: (_) => events.add('back'),
        ),
      );
      final w = _world();
      await scene.populate(w, eng.SceneController(), GameState());
      return (w, scene, opened, events);
    }

    void tapAt(World w, _Map s, Offset at) =>
        s.handleTap(w, eng.SceneController(), at);

    test(
      'opens on the current zone, captioned, with an Enter button',
      () async {
        final (w, scene, _, _) = await start();
        expect(
          scene.focusedIndex,
          1,
          reason: 'unlocked 2 -> zone 1 is current',
        );
        expect(_texts(w), containsAll(['Zone 1', 'Stages 1', 'Enter']));
        expect(
          _texts(w),
          isNot(contains('Zone 0')),
          reason: 'one caption only',
        );
      },
    );

    test('Enter and the hero card open an unlocked zone', () async {
      final (w, scene, opened, _) = await start();
      tapAt(w, scene, tap.enter);
      tapAt(w, scene, tap.center);
      expect(opened, ['z1', 'z1']);
    });

    test('a locked zone says so and cannot be entered', () async {
      final (w, scene, opened, _) = await start();
      tapAt(w, scene, nextBtn);
      expect(scene.focusedIndex, 2);
      expect(_texts(w), containsAll(['Zone 2', 'Locked']));
      expect(_texts(w), isNot(contains('Enter')));
      tapAt(w, scene, tap.enter);
      tapAt(w, scene, tap.center);
      expect(opened, isEmpty);
    });

    test('arrows and the peeking neighbours move the focus, clamped', () async {
      final (w, scene, _, _) = await start(unlocked: 1);
      tapAt(w, scene, peekNext);
      expect(scene.focusedIndex, 1);
      tapAt(w, scene, peekNext);
      tapAt(w, scene, peekPrev);
      tapAt(w, scene, prevBtn);
      expect(scene.focusedIndex, 0);
      tapAt(w, scene, prevBtn);
      expect(scene.focusedIndex, 0, reason: 'no zone before the first');
      for (var i = 0; i < 9; i++) {
        tapAt(w, scene, nextBtn);
      }
      expect(scene.focusedIndex, 6, reason: 'no zone after the last');
      expect(_texts(w), contains('Zone 6'));
    });

    test(
      'in Persian next is on the left and the arrows point inward',
      () async {
        final (w, scene, _, _) = await start(unlocked: 1, rtl: true);
        expect(_texts(w), containsAll(['‹', '›']));
        tapAt(w, scene, prevBtn); // the left button is "next" in RTL
        expect(scene.focusedIndex, 1);
        tapAt(w, scene, nextBtn);
        expect(scene.focusedIndex, 0);
        tapAt(w, scene, peekPrev); // the left neighbour is the next zone
        expect(scene.focusedIndex, 1);
      },
    );

    test(
      'the row slides in after a move and settles where it started',
      () async {
        final (w, scene, _, _) = await start(unlocked: 1);
        double sumX() {
          final p = w.componentsOf<Position>();
          var total = 0.0;
          for (var i = 0; i < p.length; i++) {
            total += p.denseAt(i).x;
          }
          return total;
        }

        final rest = sumX();
        tapAt(w, scene, nextBtn);
        final sliding = sumX();
        expect(sliding, isNot(rest), reason: 'cards start off to one side');
        scene.update(0.05, w);
        expect(sumX(), isNot(sliding), reason: 'and move while time passes');
        scene.update(2, w);
        final settled = sumX();
        scene.update(1, w);
        expect(sumX(), settled, reason: 'done: nothing keeps moving');
      },
    );

    test(
      'dragging the row left shows the next zone, right the previous',
      () async {
        final (w, scene, _, _) = await start(unlocked: 1);
        void drag(double dx, [double dy = 0]) {
          scene.handleDrag(
            w,
            eng.SceneController(),
            const Offset(90, 108),
            Offset(dx, dy),
            false,
          );
          scene.handleDrag(
            w,
            eng.SceneController(),
            const Offset(90, 108),
            Offset(dx, dy),
            true,
          );
        }

        drag(-60);
        expect(scene.focusedIndex, 1);
        drag(-60);
        drag(60);
        expect(scene.focusedIndex, 1);
        drag(60);
        drag(60);
        expect(scene.focusedIndex, 0, reason: 'clamped at the first zone');
      },
    );

    test(
      'the row follows the finger and springs back when released short',
      () async {
        final (w, scene, _, _) = await start(unlocked: 1);
        double sumX() {
          final p = w.componentsOf<Position>();
          var total = 0.0;
          for (var i = 0; i < p.length; i++) {
            total += p.denseAt(i).x;
          }
          return total;
        }

        final rest = sumX();
        const at = Offset(90, 108);
        scene.handleDrag(
          w,
          eng.SceneController(),
          at,
          const Offset(-20, 0),
          false,
        );
        final held = sumX();
        expect(
          held,
          lessThan(rest),
          reason: 'cards moved left with the finger',
        );
        scene.handleDrag(
          w,
          eng.SceneController(),
          at,
          const Offset(-20, 0),
          true,
        );
        expect(scene.focusedIndex, 0, reason: '20 units is short of a turn');
        expect(sumX(), held, reason: 'nothing jumps on release');
        scene.update(2, w);
        expect(sumX(), rest, reason: 'it eased back to where it rested');
      },
    );

    test(
      'a committed drag carries on from where the finger left the row',
      () async {
        final (w, scene, _, _) = await start(unlocked: 1);
        // x of each card's centre piece, as the player sees it.
        Map<String, int> centres() {
          final counts = <String, int>{};
          final sprites = w.componentsOf<eng.Sprite>();
          for (var i = 0; i < sprites.length; i++) {
            if (sprites.denseAt(i).region != 'f11') continue;
            final pos = w.componentsOf<Position>().get(sprites.entityAt(i));
            if (pos == null || (pos.y - 108).abs() > 0.01) continue;
            final k = pos.x.toStringAsFixed(2);
            counts[k] = (counts[k] ?? 0) + 1;
          }
          return counts;
        }

        const at = Offset(90, 108);
        scene.handleDrag(
          w,
          eng.SceneController(),
          at,
          const Offset(-50, 0),
          false,
        );
        final before = centres();
        scene.handleDrag(
          w,
          eng.SceneController(),
          at,
          const Offset(-50, 0),
          true,
        );
        expect(scene.focusedIndex, 1);
        final after = centres();
        for (final e in before.entries) {
          expect(
            after[e.key] ?? 0,
            greaterThanOrEqualTo(e.value),
            reason: 'the card at x=${e.key} did not jump when the zone changed',
          );
        }
      },
    );

    test(
      'mostly vertical drags do nothing; Persian mirrors; ends resist',
      () async {
        final (w, scene, _, _) = await start(unlocked: 1);
        const at = Offset(90, 108);
        scene.handleDrag(
          w,
          eng.SceneController(),
          at,
          const Offset(-40, 80),
          true,
        );
        expect(scene.focusedIndex, 0);
        scene.handleDrag(
          w,
          eng.SceneController(),
          at,
          const Offset(60, 0),
          true,
        );
        expect(scene.focusedIndex, 0, reason: 'nothing before the first zone');
        final (w2, rtl, _, _) = await start(unlocked: 1, rtl: true);
        rtl.handleDrag(
          w2,
          eng.SceneController(),
          at,
          const Offset(60, 0),
          true,
        );
        expect(rtl.focusedIndex, 1, reason: 'right drag is "next" in Persian');
      },
    );

    test(
      'every zone is a portal; locked ones are the same one in grey',
      () async {
        final (w, scene, _, _) = await start(thumbs: ['sky.png', 'far.png']);
        List<eng.ShaderEffect> portals() {
          final fx = w.componentsOf<eng.ShaderEffect>();
          return [for (var i = 0; i < fx.length; i++) fx.denseAt(i)];
        }

        // Zones 0..3 are on show around zone 1; zone 2 and up are locked.
        expect(portals(), hasLength(4));
        final focused = portals().firstWhere((p) => p.width == 120);
        expect(focused.images, ['map_t_z1_0', 'map_t_z1_1']);
        expect(focused.saturation, 1, reason: 'the open zone in full colour');
        expect(
          focused.detail,
          greaterThan(60),
          reason: 'finer than the default',
        );
        expect(focused.blur, lessThan(0.02), reason: 'readable, not hazy');
        expect(focused.rimGlow, lessThan(1), reason: 'a calmer rim');
        expect(focused.border, greaterThan(0), reason: 'framed');
        final locked = portals().where((p) => p.saturation == 0);
        expect(locked, hasLength(2), reason: 'zones 2 and 3 are shut');
        for (final p in locked) {
          expect(p.speed, lessThan(1), reason: 'a shut doorway barely stirs');
          expect(
            p.images,
            isNotEmpty,
            reason: 'still the shader, not flat art',
          );
        }
        tapAt(w, scene, nextBtn);
        expect(scene.focusedIndex, 2);
        expect(
          portals().firstWhere((p) => p.width == 120).saturation,
          0,
          reason: 'the focused locked zone is grey too',
        );
      },
    );

    test(
      'the title banner is drawn 140 wide at any art size, on screen',
      () async {
        artSizes['banner.png'] = const Size(560, 134);
        final scene = _Map(
          LevelSelectConfig(
            backgroundImage: 'bg',
            buttonImage: 'btn',
            panelImage: 'panel',
            nodesStem: 'nodes',
            titleBannerImage: 'banner.png',
            unlocked: () => 1,
            zones: const [
              ZoneCard(key: 'z', title: 'Z', subtitle: 's', thumbImages: []),
            ],
            onOpen: (_, _) {},
            onBack: (_) {},
          ),
        );
        final w = _world();
        await scene.populate(w, eng.SceneController(), GameState());
        scene.update(0.016, w);
        final sprites = w.componentsOf<eng.Sprite>();
        final banner = [
          for (var i = 0; i < sprites.length; i++)
            if (sprites.denseAt(i).atlasId == 'map_banner') i,
        ].single;
        final width = sprites.denseAt(banner).scaleX * 560;
        expect(width, closeTo(140, 0.01));
        final pos = w.componentsOf<Position>().get(sprites.entityAt(banner))!;
        expect(pos.x - width / 2, greaterThanOrEqualTo(0));
        expect(pos.x + width / 2, lessThanOrEqualTo(180));
      },
    );

    test('back reports', () async {
      final (w, scene, _, events) = await start();
      tapAt(w, scene, const Offset(90, 298));
      expect(events, ['back']);
    });
  });

  group('HomeScene animation and corners', () {
    test('embers rise, the logo floats, and a corner button acts', () async {
      final actions = <String>[];
      final scene = _Home(
        HomeConfig(
          backgroundImage: 'bg',
          logoImage: 'logo',
          buttonImage: 'btn',
          panelImage: 'panel',
          entries: const [HomeEntry(id: 'play', label: 'PLAY')],
          cornerFrameImage: 'frame',
          cornerIconsStem: 'icons',
          embersStem: 'embers',
          corners: const [HomeCorner(id: 'sound', icon: 5)],
          onAction: (id, _) => actions.add(id),
        ),
      );
      final w = _world();
      await scene.populate(w, eng.SceneController(), GameState());
      double sumY() {
        final p = w.componentsOf<Position>();
        var total = 0.0;
        for (var i = 0; i < p.length; i++) {
          total += p.denseAt(i).y;
        }
        return total;
      }

      final before = sumY();
      scene.update(0.5, w);
      expect(sumY(), isNot(before), reason: 'something moved');
      scene.handleTap(w, eng.SceneController(), const Offset(30, 14));
      expect(actions, ['sound']);
    });
  });

  group('HomeScene showcase layout', () {
    HomeConfig config(List<String> actions, {bool rtl = false}) => HomeConfig(
      backgroundImage: 'bg',
      logoImage: 'logo',
      buttonImage: 'btn',
      panelImage: 'panel',
      entries: const [],
      rtl: rtl,
      showcase: const HomeShowcase(
        bannerImage: 'b',
        title: 'Mobarez',
        scrollImage: 's',
        continueLabel: 'Continue',
        plateImage: 'p',
        playId: 'play',
        playLabel: 'PLAY',
        tabBarImage: 'bar',
        tabs: [
          HomeTab(id: 'heroes', label: 'Heroes', iconsStem: 'i', icon: 0),
          HomeTab(id: 'shop', label: 'Shop', iconsStem: 'i', icon: 1),
          HomeTab(id: 'gifts', label: 'Gifts', iconsStem: 'i', icon: 2),
        ],
      ),
      onAction: (id, _) => actions.add(id),
    );

    Future<(World, _Home)> open(HomeConfig c) async {
      final scene = _Home(c);
      final w = _world();
      await scene.populate(w, eng.SceneController(), GameState());
      return (w, scene);
    }

    test('the plate and the tabs report their ids', () async {
      final actions = <String>[];
      final (w, scene) = await open(config(actions));
      scene.handleTap(w, eng.SceneController(), const Offset(90, 244));
      scene.handleTap(w, eng.SceneController(), const Offset(30, 300));
      scene.handleTap(w, eng.SceneController(), const Offset(70, 300));
      expect(actions, ['play', 'heroes', 'shop']);
      expect(_texts(w), containsAll(['Mobarez', 'Continue', 'PLAY', 'Shop']));
    });

    test('the gate gets a shader portal in its doorway', () async {
      final (w, _) = await open(config([]));
      final fx = w.componentsOf<eng.ShaderEffect>();
      final kinds = [for (var i = 0; i < fx.length; i++) fx.denseAt(i).kind];
      expect(kinds.where((k) => k == eng.ShaderEffect.portal), hasLength(1));
      expect(
        kinds.where((k) => k == eng.ShaderEffect.glow),
        hasLength(3),
        reason: 'a halo, a pool on the floor and a soft glow behind the title',
      );
      expect(
        kinds.where((k) => k == eng.ShaderEffect.shine),
        hasLength(1),
        reason: 'one sweep, over the play plate',
      );
      for (var i = 0; i < fx.length; i++) {
        expect(
          fx.denseAt(i).zIndex,
          lessThan(12),
          reason: 'under the tab bar and its icons',
        );
      }
    });

    test('in Persian the first tab is on the right', () async {
      final actions = <String>[];
      final (w, scene) = await open(config(actions, rtl: true));
      scene.handleTap(w, eng.SceneController(), const Offset(150, 300));
      expect(actions, ['heroes']);
    });

    test('the plate animates as time passes', () async {
      final (w, scene) = await open(config([]));
      final sprites = w.componentsOf<eng.Sprite>();
      List<(int?, double, double)> snapshot() => [
        for (var i = 0; i < sprites.length; i++)
          (
            sprites.denseAt(i).tintArgb,
            sprites.denseAt(i).scaleX,
            sprites.denseAt(i).rotation,
          ),
      ];
      scene.update(0.1, w);
      final a = snapshot();
      scene.update(0.5, w);
      expect(snapshot(), isNot(a));
    });
  });

  group('GlossaryScene', () {
    Future<(World, _Glossary)> start({bool rtl = false}) async {
      final scene = _Glossary(
        GlossaryConfig(
          backgroundImage: 'bg',
          buttonImage: 'btn',
          panelImage: 'panel',
          rtl: rtl,
          categories: const [
            GlossaryCategory(id: 'level', labelEn: 'Levels', labelFa: 'مراحل'),
            GlossaryCategory(
              id: 'enemy',
              labelEn: 'Enemies',
              labelFa: 'دشمنان',
            ),
          ],
          entries: const [
            GlossaryEntry(
              id: 'zabulistan',
              category: 'level',
              nameEn: 'Zabulistan',
              nameFa: 'زابلستان',
              subtitleEn: 'Stages 1-10',
              subtitleFa: 'مراحل ۱ تا ۱۰',
              detailEn: "Rostam's homeland.",
              detailFa: 'زادگاه رستم.',
            ),
            GlossaryEntry(
              id: 'wolf',
              category: 'enemy',
              nameEn: 'Grey wolf',
              nameFa: 'گرگ خاکستری',
              subtitleEn: 'Zabulistan · enemy',
              subtitleFa: 'زابلستان · دشمن',
              detailEn: 'A lean grey wolf.',
              detailFa: 'گرگی خاکستری و لاغر.',
            ),
          ],
          onBack: (_) {},
        ),
      );
      final w = _world();
      await scene.populate(w, eng.SceneController(), GameState());
      return (w, scene);
    }

    test('opens on the first category and lists only its entries', () async {
      final (w, _) = await start();
      expect(_texts(w), contains('Zabulistan'));
      expect(_texts(w), isNot(contains('Grey wolf')));
    });

    test('the other category tab switches the list', () async {
      final (w, scene) = await start();
      scene.handleTap(w, eng.SceneController(), const Offset(118, 46));
      expect(_texts(w), contains('Grey wolf'));
      expect(_texts(w), isNot(contains('Zabulistan')));
    });

    test('tapping a row opens a paused detail dialog with its text', () async {
      final (w, scene) = await start();
      scene.handleTap(w, eng.SceneController(), const Offset(90, 70));
      expect(w.timeScale, 0);
      expect(_texts(w), containsAll(['Zabulistan', "Rostam's homeland."]));
    });

    test('tapping outside the dialog closes it', () async {
      final (w, scene) = await start();
      scene.handleTap(w, eng.SceneController(), const Offset(90, 70));
      scene.handleTap(w, eng.SceneController(), const Offset(5, 5));
      expect(w.timeScale, 1);
    });

    test("a level's detail shows one reused orb effect, not one spawned per "
        'entry (the orb a level opens into, vs. an enemy with no art of its '
        'own to put there)', () async {
      final (w, scene) = await start();
      scene.handleTap(w, eng.SceneController(), const Offset(90, 70));
      final afterLevel = w.componentsOf<eng.ShaderEffect>();
      expect(afterLevel.length, 1);
      expect(afterLevel.denseAt(0).kind, eng.ShaderEffect.orb);
      scene.handleTap(w, eng.SceneController(), const Offset(5, 5));
      scene.handleTap(w, eng.SceneController(), const Offset(118, 46));
      scene.handleTap(w, eng.SceneController(), const Offset(90, 70));
      expect(
        w.componentsOf<eng.ShaderEffect>().length,
        1,
        reason: 'the same effect entity is reused, not duplicated',
      );
    });

    test(
      'a category whose entries carry art draws a grid and opening one '
      'loads its clips without crashing (even when the asset is missing)',
      () async {
        final scene = _Glossary(
          GlossaryConfig(
            backgroundImage: 'bg',
            buttonImage: 'btn',
            panelImage: 'panel',
            categories: const [
              GlossaryCategory(
                id: 'enemy',
                labelEn: 'Enemies',
                labelFa: 'دشمنان',
              ),
            ],
            entries: const [
              GlossaryEntry(
                id: 'wolf',
                category: 'enemy',
                nameEn: 'Grey wolf',
                nameFa: 'گرگ خاکستری',
                subtitleEn: 'Zabulistan · enemy',
                subtitleFa: 'زابلستان · دشمن',
                detailEn: 'A lean grey wolf.',
                detailFa: 'گرگی خاکستری و لاغر.',
                spriteStem: 'assets/no_such/wolf',
              ),
            ],
            onBack: (_) {},
          ),
        );
        final w = _world();
        await scene.populate(w, eng.SceneController(), GameState());
        expect(_texts(w), contains('Grey wolf'));
        // First grid cell, roughly: left=20, cellW~(140-8)/3, top=62.
        scene.handleTap(w, eng.SceneController(), const Offset(40, 75));
        expect(w.timeScale, 0, reason: 'the detail dialog opened');
        expect(_texts(w), contains("A lean grey wolf."));
      },
    );

    test('back reports', () async {
      var backed = false;
      final scene = _Glossary(
        GlossaryConfig(
          backgroundImage: 'bg',
          buttonImage: 'btn',
          panelImage: 'panel',
          categories: const [
            GlossaryCategory(id: 'level', labelEn: 'Levels', labelFa: 'مراحل'),
          ],
          entries: const [],
          onBack: (_) => backed = true,
        ),
      );
      final w = _world();
      await scene.populate(w, eng.SceneController(), GameState());
      scene.handleTap(w, eng.SceneController(), const Offset(90, 298));
      expect(backed, isTrue);
    });

    test(
      'initialCategory opens on that category instead of the first',
      () async {
        final scene = _Glossary(
          GlossaryConfig(
            backgroundImage: 'bg',
            buttonImage: 'btn',
            panelImage: 'panel',
            initialCategory: 'enemy',
            categories: const [
              GlossaryCategory(
                id: 'level',
                labelEn: 'Levels',
                labelFa: 'مراحل',
              ),
              GlossaryCategory(
                id: 'enemy',
                labelEn: 'Enemies',
                labelFa: 'دشمنان',
              ),
            ],
            entries: const [
              GlossaryEntry(
                id: 'zabulistan',
                category: 'level',
                nameEn: 'Zabulistan',
                nameFa: 'زابلستان',
                subtitleEn: 'Stages 1-10',
                subtitleFa: 'مراحل ۱ تا ۱۰',
                detailEn: "Rostam's homeland.",
                detailFa: 'زادگاه رستم.',
              ),
              GlossaryEntry(
                id: 'wolf',
                category: 'enemy',
                nameEn: 'Grey wolf',
                nameFa: 'گرگ خاکستری',
                subtitleEn: 'Zabulistan · enemy',
                subtitleFa: 'زابلستان · دشمن',
                detailEn: 'A lean grey wolf.',
                detailFa: 'گرگی خاکستری و لاغر.',
              ),
            ],
            onBack: (_) {},
          ),
        );
        final w = _world();
        await scene.populate(w, eng.SceneController(), GameState());
        expect(_texts(w), contains('Grey wolf'));
        expect(_texts(w), isNot(contains('Zabulistan')));
      },
    );

    test(
      'a row with backgroundImages draws its layers instead of crashing',
      () async {
        final scene = _Glossary(
          GlossaryConfig(
            backgroundImage: 'bg',
            buttonImage: 'btn',
            panelImage: 'panel',
            categories: const [
              GlossaryCategory(
                id: 'level',
                labelEn: 'Levels',
                labelFa: 'مراحل',
              ),
            ],
            entries: const [
              GlossaryEntry(
                id: 'zabulistan',
                category: 'level',
                nameEn: 'Zabulistan',
                nameFa: 'زابلستان',
                subtitleEn: 'Stages 1-10',
                subtitleFa: 'مراحل ۱ تا ۱۰',
                detailEn: "Rostam's homeland.",
                detailFa: 'زادگاه رستم.',
                backgroundImages: ['sky.png', 'far.png'],
              ),
            ],
            onBack: (_) {},
          ),
        );
        final w = _world();
        await scene.populate(w, eng.SceneController(), GameState());
        expect(_texts(w), contains('Zabulistan'));
      },
    );
  });

  test('artFit draws bigger art at the same world size once measured', () {
    expect(artFit('a.png', 100, 50), 2.0, reason: 'nominal until known');
    artSizes['a.png'] = const Size(200, 100);
    expect(artFit('a.png', 100, 50), 0.5);
    expect(artFit('a.png', 100, 50, tall: true), 1.0);
  });

  group('HomeScene music', () {
    test('the round speaker switch shows on and off looks', () async {
      final music = MenuMusic(output: _MusicOut([]), asset: 'm.mp3');
      final scene = _Home(
        HomeConfig(
          backgroundImage: 'bg',
          logoImage: 'logo',
          buttonImage: 'btn',
          panelImage: 'panel',
          entries: const [HomeEntry(id: 'settings', label: 'S')],
          languages: const [LanguageOption('en', 'English')],
          activeLanguage: 'en',
          music: music,
          musicFrameImage: 'on.png',
          musicFrameOffImage: 'off.png',
          musicIconsStem: 'icons',
          musicIcon: 5,
          onAction: (_, _) {},
        ),
      );
      final w = _world();
      await scene.populate(w, eng.SceneController(), GameState());
      eng.Sprite? frame() {
        final sprites = w.componentsOf<eng.Sprite>();
        for (var i = 0; i < sprites.length; i++) {
          if (sprites.denseAt(i).atlasId.startsWith('home_music_') &&
              sprites.denseAt(i).atlasId != 'home_music_icons') {
            return sprites.denseAt(i);
          }
        }
        return null;
      }

      expect(frame()?.atlasId, 'home_music_on');
      scene.handleTap(w, eng.SceneController(), const Offset(90, 182));
      scene.handleTap(w, eng.SceneController(), const Offset(90, 188));
      expect(music.muted, isTrue);
      expect(frame()?.atlasId, 'home_music_off', reason: 'pressed-in look');
      expect(_texts(w), contains('Music: Off'));
    });

    test('plays the theme on entry and the settings switch mutes it', () async {
      final played = <String>[];
      final out = _MusicOut(played);
      final music = MenuMusic(output: out, asset: 'm.mp3');
      final scene = _Home(
        HomeConfig(
          backgroundImage: 'bg',
          logoImage: 'logo',
          buttonImage: 'btn',
          panelImage: 'panel',
          entries: const [HomeEntry(id: 'settings', label: 'S')],
          languages: const [LanguageOption('en', 'English')],
          activeLanguage: 'en',
          music: music,
          onAction: (_, _) {},
        ),
      );
      final w = _world();
      await scene.populate(w, eng.SceneController(), GameState());
      expect(played, ['play m.mp3']);
      expect(_texts(w), contains('Music: On'));

      // Open the settings dialog, then tap the music switch.
      scene.handleTap(w, eng.SceneController(), const Offset(90, 182));
      scene.handleTap(w, eng.SceneController(), const Offset(90, 188));
      expect(music.muted, isTrue);
      expect(_texts(w), contains('Music: Off'));
    });
  });
}

class _MusicOut implements AudioOutput {
  _MusicOut(this.log);
  final List<String> log;

  @override
  Future<void> playMusic(
    String assetPath, {
    double volume = 1.0,
    bool loop = true,
  }) async => log.add('play $assetPath');

  @override
  Future<void> playSound(String assetPath, {double volume = 1.0}) async {}

  @override
  Future<void> stopMusic() async => log.add('stop');
  @override
  Future<void> pauseMusic() async => log.add('pause');
  @override
  Future<void> resumeMusic() async => log.add('resume');
}
