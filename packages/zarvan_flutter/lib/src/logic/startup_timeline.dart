import 'package:flutter/foundation.dart' show debugPrint;

/// Named moments of a game's start, in milliseconds since the first mark, so
/// a slow start can be traced to the phase that took the time (fonts, the
/// scene's own load, assets, shader warm-up, first frame) instead of guessed
/// at. Switched on by `GameConfig.logFrameTimings`; costs a stopwatch read
/// per mark.
class StartupTimeline {
  StartupTimeline({void Function(String line)? sink, Stopwatch? clock})
    : _sink = sink ?? debugPrint,
      _clock = clock ?? Stopwatch();

  final void Function(String line) _sink;
  final Stopwatch _clock;
  final List<(String, double)> _marks = [];

  /// The marks so far: `(label, ms since the first mark)`.
  List<(String, double)> get marks => List.unmodifiable(_marks);

  /// Records [label] now. The first mark starts the clock.
  void mark(String label) {
    if (!_clock.isRunning) _clock.start();
    _marks.add((label, _clock.elapsedMicroseconds / 1000));
  }

  /// `label=total(+since previous)ms` for every mark, in order.
  String format() {
    final out = StringBuffer();
    var previous = 0.0;
    for (final (label, at) in _marks) {
      if (out.isNotEmpty) out.write(' ');
      out.write(
        '$label=${at.toStringAsFixed(0)}(+${(at - previous).toStringAsFixed(0)})ms',
      );
      previous = at;
    }
    return out.toString();
  }

  /// Logs [format] on one `[zarvan:startup]` line, if anything was marked.
  void flush() {
    if (_marks.isEmpty) return;
    _sink('[zarvan:startup] ${format()}');
  }
}
