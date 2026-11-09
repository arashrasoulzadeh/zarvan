import 'package:flutter_test/flutter_test.dart';
import 'package:zarvan_core/zarvan_core.dart';
import 'package:zarvan_flutter/zarvan_flutter.dart' as eng;
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
    Future<(World, _Map, List<String>, List<String>)> start({
      int unlocked = 2,
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
          zones: [
            for (var i = 0; i < 7; i++)
              ZoneCard(
                key: 'z$i',
                title: 'Zone $i',
                subtitle: 'Stages',
                thumbImages: const [],
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

    test('lists one page of cards and a page counter', () async {
      final (w, _, _, _) = await start();
      expect(_texts(w), containsAll(['Zone 0', 'Zone 4', '1 / 2']));
      expect(_texts(w), isNot(contains('Zone 5')));
    });

    test(
      'an unlocked card opens its zone, a locked one does nothing',
      () async {
        final (w, scene, opened, _) = await start();
        scene.handleTap(
          w,
          eng.SceneController(),
          const Offset(90, 52),
        ); // zone 0
        scene.handleTap(
          w,
          eng.SceneController(),
          const Offset(90, 98),
        ); // zone 1
        scene.handleTap(
          w,
          eng.SceneController(),
          const Offset(90, 144),
        ); // zone 2: locked
        expect(opened, ['z0', 'z1']);
      },
    );

    test('next and previous page the list; back reports', () async {
      final (w, scene, opened, events) = await start(unlocked: 7);
      scene.handleTap(w, eng.SceneController(), const Offset(144, 298)); // next
      expect(_texts(w), containsAll(['Zone 5', 'Zone 6', '2 / 2']));
      expect(_texts(w), isNot(contains('Zone 0')));
      scene.handleTap(w, eng.SceneController(), const Offset(90, 52));
      expect(opened, ['z5'], reason: 'cards are the second page now');
      scene.handleTap(w, eng.SceneController(), const Offset(36, 298)); // prev
      expect(_texts(w), contains('Zone 0'));
      scene.handleTap(w, eng.SceneController(), const Offset(90, 298)); // back
      expect(events, ['back']);
    });
  });
}
