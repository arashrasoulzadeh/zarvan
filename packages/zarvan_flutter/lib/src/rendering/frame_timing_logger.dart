
import 'package:flutter/scheduler.dart';
import 'package:flutter/foundation.dart' show debugPrint;

/// Percentiles of a set of frame durations, in milliseconds.
class FrameTimingSummary {
  const FrameTimingSummary({
    required this.frames,
    required this.buildP50,
    required this.buildP90,
    required this.buildP99,
    required this.rasterP50,
    required this.rasterP90,
    required this.rasterP99,
    required this.jankyShare,
  });

  /// How many frames were measured.
  final int frames;

  /// Median / 90th / 99th percentile of the UI thread's build time.
  final double buildP50;
  final double buildP90;
  final double buildP99;

  /// The same for the raster (GPU) thread, where shader cost shows up.
  final double rasterP50;
  final double rasterP90;
  final double rasterP99;

  /// Share of frames (0..1) that took longer than the frame budget on either
  /// thread.
  final double jankyShare;

  @override
  String toString() =>
      'frames=$frames build p50/p90/p99='
      '${buildP50.toStringAsFixed(1)}/${buildP90.toStringAsFixed(1)}/${buildP99.toStringAsFixed(1)}ms '
      'raster p50/p90/p99='
      '${rasterP50.toStringAsFixed(1)}/${rasterP90.toStringAsFixed(1)}/${rasterP99.toStringAsFixed(1)}ms '
      'janky=${(jankyShare * 100).toStringAsFixed(0)}%';
}

/// The value at fraction [p] (0..1) of [sorted] (nearest rank).
double percentile(List<double> sorted, double p) {
  if (sorted.isEmpty) return 0;
  final i = (p * (sorted.length - 1)).round().clamp(0, sorted.length - 1);
  return sorted[i];
}

/// Summarises [builds] and [rasters] (milliseconds, one pair per frame);
/// a frame is janky when either exceeds [budgetMs].
FrameTimingSummary summarizeFrameTimings(
  List<double> builds,
  List<double> rasters, {
  double budgetMs = 16.7,
}) {
  final b = [...builds]..sort();
  final r = [...rasters]..sort();
  var janky = 0;
  for (var i = 0; i < builds.length && i < rasters.length; i++) {
    if (builds[i] > budgetMs || rasters[i] > budgetMs) janky++;
  }
  final n = builds.length;
  return FrameTimingSummary(
    frames: n,
    buildP50: percentile(b, 0.5),
    buildP90: percentile(b, 0.9),
    buildP99: percentile(b, 0.99),
    rasterP50: percentile(r, 0.5),
    rasterP90: percentile(r, 0.9),
    rasterP99: percentile(r, 0.99),
    jankyShare: n == 0 ? 0 : janky / n,
  );
}

/// Logs how long frames really take on the device, every [interval], from
/// Flutter's own `FrameTiming` reports (build thread and raster thread). It
/// exists because shader cost is paid on the GPU raster thread, which neither
/// `FrameStats` (CPU paint) nor a desktop run can show: switch it on with
/// `GameConfig.logFrameTimings` in a release build and read the lines from
/// `adb logcat -s flutter`.
class FrameTimingLogger {
  FrameTimingLogger({
    this.interval = const Duration(seconds: 3),
    this.label = 'zarvan:timings',
    void Function(String line)? sink,
  }) : _sink = sink ?? debugPrint;

  final Duration interval;
  final String label;
  final void Function(String line) _sink;

  final List<double> _builds = [];
  final List<double> _rasters = [];
  final Stopwatch _window = Stopwatch();
  bool _started = false;

  /// Starts listening to frame timings.
  void start() {
    if (_started) return;
    _started = true;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  /// Stops listening.
  void stop() {
    if (!_started) return;
    _started = false;
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
  }

  void _onTimings(List<FrameTiming> timings) {
    if (!_window.isRunning) _window.start();
    for (final t in timings) {
      _builds.add(t.buildDuration.inMicroseconds / 1000);
      _rasters.add(t.rasterDuration.inMicroseconds / 1000);
    }
    if (_window.elapsed >= interval) flush();
  }

  /// Logs the frames gathered so far and starts a new window.
  void flush() {
    if (_builds.isEmpty) return;
    _sink('[$label] ${summarizeFrameTimings(_builds, _rasters)}');
    _builds.clear();
    _rasters.clear();
    _window
      ..reset()
      ..start();
  }
}
