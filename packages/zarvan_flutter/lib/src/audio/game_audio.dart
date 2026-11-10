import 'audio_manager.dart';

/// The playback calls [GameAudio] needs, so it works over the real
/// [AudioManager] in a game and over a recording fake in tests.
abstract class AudioOutput {
  /// Plays a one-shot sound from asset [assetPath].
  Future<void> playSound(String assetPath, {double volume = 1.0});

  /// Starts background music from asset [assetPath].
  Future<void> playMusic(
    String assetPath, {
    double volume = 1.0,
    bool loop = true,
  });

  /// Stops the background music.
  Future<void> stopMusic();

  /// Pauses the background music in place, for when the app loses focus.
  /// Defaults to nothing so existing outputs keep compiling.
  Future<void> pauseMusic() async {}

  /// Continues music paused by [pauseMusic] from where it stopped.
  Future<void> resumeMusic() async {}
}

/// Optional lifecycle controls for outputs that can suspend active effects.
abstract class AudioLifecycleOutput {
  /// Pauses active one-shot effects.
  Future<void> pauseSounds();

  /// Resumes effects paused by [pauseSounds].
  Future<void> resumeSounds();
}

/// Optional asset preloading for outputs that can warm short effects.
abstract class AudioPreloadOutput {
  /// Loads [assetPaths] into the platform audio cache.
  Future<void> preloadSounds(Iterable<String> assetPaths);
}

/// Plays sounds and music by short name: `audio.sfx('jump')`,
/// `audio.music('theme')`, instead of passing asset paths through game code.
///
/// Names are checked even when nothing is audible, so a typo fails in a
/// headless test rather than going silently missing on a device. Use
/// [GameAudio.silent] for servers, tests and CLIs: every call validates the
/// name and then does nothing.
///
/// ```dart
/// final audio = GameAudio(
///   AudioManager(),
///   sounds: {'jump': 'sfx/jump.wav'},
///   tracks: {'theme': 'music/theme.mp3'},
/// );
/// audio.sfx('jump');
/// audio.music('theme');
/// ```
class GameAudio {
  final AudioOutput? _output;
  final Map<String, String> sounds;
  final Map<String, String> tracks;

  /// Master volume multiplier for sound effects (0..1).
  double sfxVolume = 1.0;

  /// Master volume multiplier for music (0..1).
  double musicVolume = 1.0;

  String? _currentTrack;
  Future<void> _musicQueue = Future<void>.value();
  bool _musicPaused = false;

  /// Plays through [output] using the given name -> asset path maps.
  GameAudio(
    AudioOutput output, {
    this.sounds = const {},
    this.tracks = const {},
  }) : _output = output;

  /// Validates names but makes no sound.
  GameAudio.silent({this.sounds = const {}, this.tracks = const {}})
    : _output = null;

  /// The track started by the last [music] call, or null.
  String? get currentTrack => _currentTrack;

  /// Plays the sound registered as [name] at [volume] (times [sfxVolume]).
  /// Throws an [ArgumentError] listing the known names if [name] is unknown.
  Future<void> sfx(String name, {double volume = 1.0}) async {
    final path = _lookup(sounds, name, 'sound');
    await _output?.playSound(path, volume: volume * sfxVolume);
  }

  /// Starts the track registered as [name]. Asking for the track that is
  /// already playing does nothing, so scenes can call it on every entry
  /// without restarting the music.
  Future<void> music(
    String name, {
    double volume = 1.0,
    bool loop = true,
  }) async {
    final path = _lookup(tracks, name, 'track');
    if (_currentTrack == name) return;
    _currentTrack = name;
    _musicQueue = _musicQueue.then((_) async {
      if (_currentTrack != name) return;
      try {
        await _output?.playMusic(
          path,
          volume: volume * musicVolume,
          loop: loop,
        );
      } catch (_) {
        if (_currentTrack == name) _currentTrack = null;
        rethrow;
      }
    });
    await _musicQueue;
  }

  /// Stops the music and forgets the current track.
  Future<void> stopMusic() async {
    _musicQueue = _musicQueue.then((_) async {
      await _output?.stopMusic();
      _currentTrack = null;
    });
    await _musicQueue;
  }

  /// Pauses the current music without forgetting it, so [resumeMusic]
  /// continues the same track (an app losing focus must not restart the
  /// theme, nor leave it playing in the background).
  Future<void> pauseMusic() async => _output?.pauseMusic();

  /// Continues music paused by [pauseMusic].
  Future<void> resumeMusic() async {
    if (_currentTrack != null) await _output?.resumeMusic();
  }

  /// Pauses music and active effects as one ordered lifecycle transition.
  Future<void> pauseAll() async {
    _musicPaused = true;
    _musicQueue = _musicQueue.then((_) async {
      await _output?.pauseMusic();
      final lifecycle = _output is AudioLifecycleOutput
          ? _output as AudioLifecycleOutput
          : null;
      await lifecycle?.pauseSounds();
    });
    await _musicQueue;
  }

  /// Resumes audio only after the app is active again.
  Future<void> resumeAll() async {
    _musicPaused = false;
    _musicQueue = _musicQueue.then((_) async {
      if (!_musicPaused) {
        await _output?.resumeMusic();
        final lifecycle = _output is AudioLifecycleOutput
            ? _output as AudioLifecycleOutput
            : null;
        await lifecycle?.resumeSounds();
      }
    });
    await _musicQueue;
  }

  static String _lookup(Map<String, String> map, String name, String kind) {
    final path = map[name];
    if (path != null) return path;
    final known = (map.keys.toList()..sort()).join(', ');
    throw ArgumentError.value(
      name,
      kind,
      'No $kind registered under this name. Known: '
      '${known.isEmpty ? '(none)' : known}.',
    );
  }
}
