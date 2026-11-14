import 'dart:math' as math;

import 'package:zarvan_core/zarvan_core.dart';

/// Engine-side interaction and presentation state for a vertically scrolling
/// list. The controller consumes cumulative drag distances from [Scene] and
/// exposes a smoothed offset plus an edge fade for row renderers.
class ScrollListController {
  ScrollListController({
    required int itemCount,
    required double itemHeight,
    required double viewportHeight,
    double offset = 0,
  }) : model = ScrollListModel(
         itemCount: itemCount,
         itemHeight: itemHeight,
         viewportHeight: viewportHeight,
       ),
       _offset = offset,
       _target = offset {
    _clamp();
  }

  final ScrollListModel model;
  double _offset;
  double _target;
  double? _dragOrigin;

  /// Current rendered offset.
  double get offset => _offset;

  /// The clamped position requested by the current drag.
  double get targetOffset => _target;

  /// Whether a finger is currently controlling the list.
  bool get dragging => _dragOrigin != null;

  /// Starts a finger drag at the current list position.
  void beginDrag() => _dragOrigin = _target;

  /// Applies the cumulative finger displacement reported by the engine.
  void dragTo(double totalDy) {
    _dragOrigin ??= _target;
    _target = _dragOrigin! - totalDy;
    _clamp();
  }

  /// Ends the current drag and prevents stale deltas affecting the next one.
  void endDrag() => _dragOrigin = null;

  /// Smoothly follows the target offset.
  void update(double dt) {
    // Touch lists should remain locked to the finger; delayed catch-up reads
    // as lag and makes a short swipe feel disproportionately fast.
    _offset = _target;
  }

  /// Returns opacity for a row as it enters/leaves the viewport.
  double edgeFade(double rowTop, {double fadeExtent = 48}) {
    final top = (rowTop / fadeExtent).clamp(0.0, 1.0);
    final bottom =
        ((model.viewportHeight - rowTop - model.itemHeight) / fadeExtent).clamp(
          0.0,
          1.0,
        );
    return math.min(top, bottom);
  }

  void _clamp() {
    _target = _target.clamp(0, model.maxOffset).toDouble();
  }
}
