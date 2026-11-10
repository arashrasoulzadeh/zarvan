import 'package:zarvan_flutter/zarvan_flutter.dart' show AudioOutput;

/// The theme that plays on the menu screens (home, world map) and stops when a
/// battle starts, with a mute switch the player controls.
///
/// A scene calls [enter] when it opens and a battle calls [leave]; [enter] on a
/// track that is already playing changes nothing, so moving between menu
/// screens never restarts it. Muting stops it at once and unmuting starts it
/// again if a menu is showing. Browsers refuse to start sound before the player
/// touches the page, so a game can begin muted (`muted: true`) and let the
/// player switch it on: that tap is the gesture the browser needs.
class MenuMusic {
  /// Plays [asset] (a path relative to the app's `assets/` folder, as the audio
  /// player expects it) through [output] at [volume].
  MenuMusic({
    required AudioOutput output,
    required this.asset,
    bool muted = false,
    this.volume = 0.6,
    this.onMutedChanged,
  }) : _output = output,
       _muted = muted;

  final AudioOutput _output;

  /// The track.
  final String asset;
  final double volume;

  /// Told when the player mutes or unmutes, to save the choice.
  final void Function(bool muted)? onMutedChanged;

  bool _muted;
  bool _wanted = false;
  bool _playing = false;

  /// Whether the music is switched off.
  bool get muted => _muted;

  /// Whether a menu is showing (the music is wanted, audible or not).
  bool get wanted => _wanted;

  /// Whether the track is playing right now.
  bool get playing => _playing;

  /// A menu screen opened: play unless muted.
  Future<void> enter() async {
    _wanted = true;
    await _start();
  }

  /// A battle started: stop.
  Future<void> leave() async {
    _wanted = false;
    await _stop();
  }

  /// Mutes or unmutes, saves the choice and starts or stops to match.
  Future<void> setMuted(bool value) async {
    if (value == _muted) return;
    _muted = value;
    onMutedChanged?.call(value);
    if (value) {
      await _stop();
    } else {
      await _start();
    }
  }

  /// Flips the mute switch.
  Future<void> toggle() => setMuted(!_muted);

  Future<void> _start() async {
    if (_muted || !_wanted || _playing) return;
    _playing = true;
    try {
      await _output.playMusic(asset, volume: volume);
    } catch (_) {
      // The platform refused (e.g. no user gesture yet): stay silent and let a
      // later unmute or menu change try again.
      _playing = false;
    }
  }

  Future<void> _stop() async {
    if (!_playing) return;
    _playing = false;
    await _output.stopMusic();
  }
}
