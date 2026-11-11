import 'package:flutter_test/flutter_test.dart';
import 'package:zarvan_flutter/zarvan_flutter.dart' show AudioOutput;
import 'package:zarvan_idle/zarvan_idle.dart';

class _Out implements AudioOutput {
  final calls = <String>[];
  bool refuse = false;

  @override
  Future<void> playMusic(
    String assetPath, {
    double volume = 1.0,
    bool loop = true,
  }) async {
    if (refuse) throw StateError('blocked until a user gesture');
    calls.add('play $assetPath');
  }

  @override
  Future<void> playSound(String assetPath, {double volume = 1.0}) async {}

  @override
  Future<void> stopMusic() async => calls.add('stop');
  @override
  Future<void> pauseMusic() async => calls.add('pause');
  @override
  Future<void> resumeMusic() async => calls.add('resume');
}

void main() {
  test(
    'entering a menu plays the theme once; moving between menus keeps it',
    () async {
      final out = _Out();
      final m = MenuMusic(output: out, asset: 'a.mp3');
      await m.enter();
      await m.enter();
      expect(out.calls, [
        'play a.mp3',
      ], reason: 'no restart on the second menu');
      expect(m.playing, isTrue);
    },
  );

  test('leaving for a battle stops it, coming back plays it again', () async {
    final out = _Out();
    final m = MenuMusic(output: out, asset: 'a.mp3');
    await m.enter();
    await m.leave();
    await m.enter();
    expect(out.calls, ['play a.mp3', 'stop', 'play a.mp3']);
  });

  test(
    'muted stays silent; unmuting starts it only while a menu shows',
    () async {
      final out = _Out();
      final saved = <bool>[];
      final m = MenuMusic(
        output: out,
        asset: 'a.mp3',
        muted: true,
        onMutedChanged: saved.add,
      );
      await m.enter();
      expect(out.calls, isEmpty);
      await m.setMuted(false);
      expect(out.calls, ['play a.mp3']);
      await m.leave();
      out.calls.clear();
      await m.setMuted(true);
      await m.setMuted(false);
      expect(out.calls, isEmpty, reason: 'no menu is showing, so no music');
      expect(saved, [false, true, false], reason: 'each change is saved');
    },
  );

  test('muting while playing stops it at once', () async {
    final out = _Out();
    final m = MenuMusic(output: out, asset: 'a.mp3');
    await m.enter();
    await m.toggle();
    expect(m.muted, isTrue);
    expect(out.calls.last, 'stop');
    expect(m.playing, isFalse);
  });

  test('a refused play (no user gesture) stays quiet and can retry', () async {
    final out = _Out()..refuse = true;
    final m = MenuMusic(output: out, asset: 'a.mp3');
    await m.enter();
    expect(m.playing, isFalse);
    out.refuse = false;
    await m.enter();
    expect(out.calls, ['play a.mp3']);
  });
}
