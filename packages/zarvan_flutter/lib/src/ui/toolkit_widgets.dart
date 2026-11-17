import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:zarvan_core/zarvan_core.dart';

/// Builds one row of a [ModelScrollList].
typedef ModelRowBuilder =
    Widget Function(BuildContext context, int index, bool selected);

/// A scrolling list of equal-height rows driven by a [ScrollListModel]: the
/// same drag, fling, wheel, arrow-key selection and hit-testing the model
/// gives scenes, so a shop, inventory or skill list behaves like the rest of
/// the game's UI. Only the rows in the model's visible range are built.
///
/// The widget owns no state of its own beyond a ticker that coasts flings;
/// pass the same [model] to read `selected` or `offset` elsewhere.
class ModelScrollList extends StatefulWidget {
  const ModelScrollList({
    super.key,
    required this.model,
    required this.itemBuilder,
    this.onActivate,
    this.autofocus = false,
  });

  final ScrollListModel model;
  final ModelRowBuilder itemBuilder;

  /// Called with the row index on tap or Enter.
  final ValueChanged<int>? onActivate;
  final bool autofocus;

  @override
  State<ModelScrollList> createState() => _ModelScrollListState();
}

class _ModelScrollListState extends State<ModelScrollList>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker.start();
  }

  void _tick(Duration t) {
    final dt = (t - _last).inMicroseconds / 1e6;
    _last = t;
    final before = widget.model.offset;
    widget.model.update(dt);
    if (widget.model.offset != before) setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _scroll(double delta) => setState(() => widget.model.scrollBy(delta));

  KeyEventResult _key(FocusNode node, KeyEvent e) {
    if (e is KeyUpEvent) return KeyEventResult.ignored;
    final m = widget.model;
    if (e.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() => m.moveSelection(1));
    } else if (e.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() => m.moveSelection(-1));
    } else if (e.logicalKey == LogicalKeyboardKey.enter && m.selected != null) {
      widget.onActivate?.call(m.selected!);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final m = widget.model;
      if (c.maxHeight.isFinite && c.maxHeight != m.viewportHeight) {
        m.viewportHeight = c.maxHeight;
        m.scrollBy(0);
      }
      final range = m.visibleRange;
      return Focus(
        autofocus: widget.autofocus,
        onKeyEvent: _key,
        child: Listener(
          onPointerSignal: (s) {
            if (s is PointerScrollEvent) _scroll(s.scrollDelta.dy);
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: (d) => _scroll(-d.delta.dy),
            onVerticalDragEnd: (d) =>
                m.fling(-(d.primaryVelocity ?? 0)),
            onTapUp: (d) {
              final i = m.indexAt(d.localPosition.dy);
              if (i == null) return;
              setState(() => m.selected = i);
              widget.onActivate?.call(i);
            },
            child: ClipRect(
              child: Stack(
                children: [
                  if (range != null)
                    for (var i = range.$1; i <= range.$2; i++)
                      Positioned(
                        key: ValueKey('row_$i'),
                        left: 0,
                        right: 0,
                        top: i * m.itemHeight - m.offset,
                        height: m.itemHeight,
                        child: widget.itemBuilder(context, i, m.selected == i),
                      ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// A single-line text field driven by a [TextInputModel] (caret, length limit
/// and character filter live in the model). Takes hardware-keyboard input; a
/// game that needs the on-screen keyboard wraps a platform field instead.
class ModelTextField extends StatefulWidget {
  const ModelTextField({
    super.key,
    required this.model,
    this.onChanged,
    this.onSubmitted,
    this.style,
    this.autofocus = false,
  });

  final TextInputModel model;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextStyle? style;
  final bool autofocus;

  @override
  State<ModelTextField> createState() => _ModelTextFieldState();
}

class _ModelTextFieldState extends State<ModelTextField> {
  KeyEventResult _key(FocusNode node, KeyEvent e) {
    if (e is KeyUpEvent) return KeyEventResult.ignored;
    final m = widget.model;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.backspace) {
      m.backspace();
    } else if (k == LogicalKeyboardKey.delete) {
      m.delete();
    } else if (k == LogicalKeyboardKey.arrowLeft) {
      m.moveCaret(-1);
    } else if (k == LogicalKeyboardKey.arrowRight) {
      m.moveCaret(1);
    } else if (k == LogicalKeyboardKey.home) {
      m.home();
    } else if (k == LogicalKeyboardKey.end) {
      m.end();
    } else if (k == LogicalKeyboardKey.enter) {
      widget.onSubmitted?.call(m.text);
      return KeyEventResult.handled;
    } else if (e.character != null &&
        e.character!.isNotEmpty &&
        e.character!.codeUnitAt(0) >= 32) {
      m.insert(e.character!);
    } else {
      return KeyEventResult.ignored;
    }
    setState(() {});
    widget.onChanged?.call(m.text);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.model;
    final style = widget.style ?? Theme.of(context).textTheme.bodyLarge;
    return Focus(
      autofocus: widget.autofocus,
      onKeyEvent: _key,
      child: Builder(
        builder: (context) => GestureDetector(
          onTap: () => Focus.of(context).requestFocus(),
          child: InputDecorator(
            isFocused: Focus.of(context).hasFocus,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: m.text.substring(0, m.caret)),
                  const TextSpan(text: '|'),
                  TextSpan(text: m.text.substring(m.caret)),
                ],
              ),
              style: style,
            ),
          ),
        ),
      ),
    );
  }
}

/// One tab of [GameTabs].
class GameTab {
  const GameTab({required this.label, required this.builder});

  final String label;
  final WidgetBuilder builder;
}

/// A tab strip over one visible page, for shop/inventory/skill screens.
/// Only the selected page is built. Left/Right arrows switch tabs when the
/// strip has focus.
class GameTabs extends StatefulWidget {
  const GameTabs({
    super.key,
    required this.tabs,
    this.initialIndex = 0,
    this.onChanged,
  }) : assert(tabs.length > 0);

  final List<GameTab> tabs;
  final int initialIndex;
  final ValueChanged<int>? onChanged;

  @override
  State<GameTabs> createState() => _GameTabsState();
}

class _GameTabsState extends State<GameTabs> {
  late int _index = widget.initialIndex.clamp(0, widget.tabs.length - 1);

  void _select(int i) {
    if (i == _index) return;
    setState(() => _index = i);
    widget.onChanged?.call(i);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Focus(
        onKeyEvent: (_, e) {
          if (e is! KeyDownEvent) return KeyEventResult.ignored;
          if (e.logicalKey == LogicalKeyboardKey.arrowRight &&
              _index < widget.tabs.length - 1) {
            _select(_index + 1);
            return KeyEventResult.handled;
          }
          if (e.logicalKey == LogicalKeyboardKey.arrowLeft && _index > 0) {
            _select(_index - 1);
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Row(
          children: [
            for (var i = 0; i < widget.tabs.length; i++)
              Expanded(
                child: TextButton(
                  key: ValueKey('tab_$i'),
                  style: TextButton.styleFrom(
                    backgroundColor: i == _index
                        ? Theme.of(context).colorScheme.primaryContainer
                        : null,
                  ),
                  onPressed: () => _select(i),
                  child: Text(widget.tabs[i].label),
                ),
              ),
          ],
        ),
      ),
      Expanded(child: Builder(builder: widget.tabs[_index].builder)),
    ],
  );
}

/// Shows [child] in a [width] x [height] box pinned to [anchor] on the screen
/// (via the core `anchorRect`), over a dismissible scrim. Completes with
/// whatever the popup pops with.
Future<T?> showGamePopup<T>(
  BuildContext context, {
  required Widget child,
  UiAnchor anchor = UiAnchor.center,
  required double width,
  required double height,
  double dx = 0,
  double dy = 0,
}) => showGeneralDialog<T>(
  context: context,
  barrierDismissible: true,
  barrierLabel: 'Close',
  barrierColor: Colors.black54,
  pageBuilder: (context, _, _) {
    final size = MediaQuery.sizeOf(context);
    final r = anchorRect(
      UiRect(0, 0, size.width, size.height),
      anchor,
      width,
      height,
      dx: dx,
      dy: dy,
    );
    return Stack(
      children: [
        Positioned(
          left: r.x,
          top: r.y,
          width: r.width,
          height: r.height,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            clipBehavior: Clip.antiAlias,
            child: child,
          ),
        ),
      ],
    );
  },
);

/// A tooltip that shows on long-press (touch) and hover (pointer), for item
/// and upgrade descriptions.
class GameTooltip extends StatelessWidget {
  const GameTooltip({super.key, required this.message, required this.child});

  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: message,
    triggerMode: TooltipTriggerMode.longPress,
    child: child,
  );
}
