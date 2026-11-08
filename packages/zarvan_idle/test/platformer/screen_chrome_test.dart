import 'package:flutter_test/flutter_test.dart';
import 'package:zarvan_core/zarvan_core.dart';
import 'package:zarvan_flutter/zarvan_flutter.dart' as eng;
import 'package:zarvan_idle/zarvan_idle.dart';
import 'package:zarvan_platformer/zarvan_platformer.dart';

World _world() {
  final w = World(width: 180, height: 320);
  registerCoreComponents(w);
  eng.registerFlutterComponents(w);
  registerPlatformerComponents(w);
  return w;
}

List<String> _texts(World w) {
  final t = w.componentsOf<eng.Text>();
  return [for (var i = 0; i < t.length; i++) t.denseAt(i).text];
}

void main() {
  group('ResultPopup', () {
    test('show draws a veil, the panel, banner, title and reward once', () {
      final w = _world();
      final popup = ResultPopup(
        w,
        frameAtlasId: 'panel',
        scrollAtlasId: 'scroll',
        currencyAtlasId: 'coins',
      );
      expect(popup.visible, isFalse);
      popup.show(
        title: 'VICTORY',
        message: 'Zone cleared',
        detail: 'Wave 10',
        reward: '+2,480',
      );
      expect(popup.visible, isTrue);
      expect(
        _texts(w),
        containsAll(['VICTORY', 'Zone cleared', 'Wave 10', '+2,480']),
      );
      final first = popup.dialog;
      popup.show(title: 'AGAIN', message: 'x');
      expect(identical(popup.dialog, first), isTrue, reason: 'shown only once');
      expect(_texts(w), isNot(contains('AGAIN')));
    });

    test('without a reward there is no coin row', () {
      final w = _world();
      final popup = ResultPopup(w, frameAtlasId: 'panel');
      popup.show(title: 'DEFEAT', message: 'The Mobarez has fallen');
      expect(_texts(w), isNot(contains('+0')));
      final sprites = w.componentsOf<eng.Sprite>();
      for (var i = 0; i < sprites.length; i++) {
        expect(sprites.denseAt(i).atlasId, 'panel');
      }
    });
  });

  group('WaveStrings', () {
    test('wave counter, ultimate label and digits follow the language', () {
      const en = WaveStrings();
      expect(en.waveLabel(4, 10), 'Wave 4/10');
      expect(en.ultimateLabel(0.6), 'ULT 60%');
      const fa = WaveStrings(
        wave: 'موج',
        waveTemplate: '{wave} {n} از {total}',
        digits: '۰۱۲۳۴۵۶۷۸۹',
      );
      expect(fa.waveLabel(4, 10), 'موج ۴ از ۱۰');
      expect(fa.localize('+2,480'), '+۲,۴۸۰');
    });
  });

  group('SpriteHealthBar', () {
    test('end caps keep their aspect; only the channel stretches', () {
      final w = _world();
      final owner = w.spawn();
      var meter = 0.5;
      final bar = SpriteHealthBar.spawn(
        w,
        atlasId: 'ui_bars',
        source: owner,
        left: 0,
        top: 0,
        width: 150,
        height: 10,
        fractionOf: () => meter,
      );
      final sprites = w.componentsOf<eng.Sprite>();
      final mid = sprites.denseAt(0);
      final fill = sprites.denseAt(1);
      final capL = sprites.denseAt(2);
      final capR = sprites.denseAt(3);
      final s = 10 / BarsArt.frame.height;
      expect(capL.scaleX, closeTo(s, 1e-9));
      expect(capL.scaleY, closeTo(s, 1e-9), reason: 'caps are not stretched');
      expect(capR.scaleX, capL.scaleX);
      expect(mid.scaleY, closeTo(s, 1e-9));
      final channel = 150 - 2 * BarsArt.innerLeft * s;
      expect(mid.scaleX, closeTo(channel / BarsArt.innerWidth, 1e-9));
      expect(
        fill.scaleX,
        closeTo(channel * 0.5 / BarsArt.fillSize.w, 1e-9),
        reason: 'fractionOf drives the fill',
      );
      meter = 1;
      bar.sync();
      expect(fill.scaleX, closeTo(channel / BarsArt.fillSize.w, 1e-9));
    });
  });

  group('SceneHud', () {
    test('an ultimate label appears only when the layout has one', () {
      final w = _world();
      final withUlt = SceneHud.spawn(
        w,
        status: 's',
        layout: const HudLayout(ultText: HudTextStyle(x: 10, y: 10)),
      );
      withUlt.sync(w, status: 'Wave 1/10', enemy: 'Wolf', ultimate: 'ULT 5%');
      expect(_texts(w), containsAll(['Wave 1/10', 'Wolf', 'ULT 5%']));
      final w2 = _world();
      SceneHud.spawn(
        w2,
        status: 's',
      ).sync(w2, status: 'a', enemy: 'b', ultimate: 'u');
      expect(_texts(w2), isNot(contains('u')));
    });
  });
}
