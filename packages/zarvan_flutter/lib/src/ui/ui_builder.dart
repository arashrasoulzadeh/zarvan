import 'package:zarvan_core/zarvan_core.dart';

import '../rendering/shape.dart';
import '../rendering/text.dart';

/// The three colours the [UiBuilder] and [UiButton] need; a game's own palette
/// implements it so the engine never knows the game's theme type.
abstract interface class UiColors {
  /// Screen background; also the colour of text drawn on filled shapes.
  int get background;

  /// Strokes and body text.
  int get ink;

  /// Quiet things: a disabled control.
  int get soft;
}

/// One entity with its `Position` and `Shape` or `Text` held directly, so a
/// scene animates a label by mutating fields instead of looking components up
/// every frame.
class UiNode {
  UiNode._(this.id, this.pos, {this.shape, this.text});

  final EntityId id;
  final Position pos;
  final Shape? shape;
  final Text? text;

  static const _hidden = -4000.0;

  /// A shape entity, parked off screen until [show]n unless [x] and [y] are given.
  static UiNode shapeNode(
    World world,
    Shape shape, {
    double x = _hidden,
    double y = _hidden,
  }) {
    final id = world.spawn();
    final pos = Position(x, y);
    world.componentsOf<Position>().set(id, pos);
    world.componentsOf<Shape>().set(id, shape);
    return UiNode._(id, pos, shape: shape);
  }

  /// A text entity. [fontFamily] fills in a text that has none, so a whole
  /// game can share one typeface (the engine's default lacks some scripts).
  static UiNode textNode(
    World world,
    Text text, {
    double x = _hidden,
    double y = _hidden,
    String? fontFamily,
  }) {
    text.fontFamily ??= fontFamily;
    final id = world.spawn();
    final pos = Position(x, y);
    world.componentsOf<Position>().set(id, pos);
    world.componentsOf<Text>().set(id, text);
    return UiNode._(id, pos, text: text);
  }

  /// Moves the node to ([x], [y]).
  void show(double x, double y) {
    pos.x = x;
    pos.y = y;
  }

  /// Parks the node far off screen.
  void hide() {
    pos.x = _hidden;
    pos.y = _hidden;
  }

  bool get isHidden => pos.x == _hidden;
}

/// A tappable rounded box with a label. Hit testing is done by
/// [UiBuilder.tap] against [box]; everything drawn is an engine `Shape` and
/// `Text`.
class UiButton {
  UiButton(this.box, this.bg, this.label, this.onTap, {this.enabled = true});

  final UiRect box;
  final UiNode bg;
  final UiNode label;
  void Function() onTap;
  bool enabled;

  /// Whether the button is drawn at all (hidden buttons ignore taps).
  bool visible = true;

  /// Draws the button in [colors]: outlined when enabled, faint when not;
  /// [filled] draws it as a solid block.
  void style(UiColors colors, {bool filled = false}) {
    final color = enabled ? colors.ink : colors.soft;
    bg.shape!
      ..colorArgb = color
      ..strokeWidth = filled && enabled ? 0 : 2.5;
    label.text!.colorArgb = filled && enabled ? colors.background : color;
  }

  void setVisible(bool v) {
    visible = v;
    if (!v) {
      bg.hide();
      label.hide();
    } else {
      bg.show(box.centerX, box.centerY);
      label.show(box.centerX, box.centerY);
    }
  }

  void setText(String text) => label.text!.text = text;
}

/// Builds and tracks the pieces of a menu screen on a [World]: a full-screen
/// background, labels, shapes and [UiButton]s, all engine `Shape`s and `Text`s.
/// Each screen owns one. A game subclasses it to add its own helpers (strings,
/// a back button) without the engine knowing them.
class UiBuilder {
  UiBuilder(
    this.world,
    this.colors, {
    required this.width,
    required this.height,
    this.dy = 0,
    this.fontFamily,
  });

  final World world;

  /// The colours new pieces are drawn in; a theme change replaces it.
  UiColors colors;
  final double width;
  final double height;

  /// How far every node and hit box this builder makes is moved down, for
  /// screens laid out for a shorter world.
  final double dy;

  /// Typeface for every label (null keeps the engine default).
  final String? fontFamily;

  /// [b] moved down by [dy], for a rect built by hand next to builder nodes.
  UiRect shift(UiRect b) => UiRect(b.x, b.y + dy, b.width, b.height);

  final List<UiButton> buttons = [];

  /// Called when a button is pressed (the screen plays its click here).
  void Function()? onPress;

  UiNode background() => UiNode.shapeNode(
    world,
    Shape(
      kind: ShapeKind.roundedRect,
      width: width * 2,
      height: height * 2,
      colorArgb: colors.background,
      zIndex: -10,
    ),
    x: width / 2,
    y: height / 2,
  );

  UiNode circle(
    double x,
    double y,
    double diameter,
    int color, {
    double stroke = 0,
    int z = 5,
  }) => UiNode.shapeNode(
    world,
    Shape(width: diameter, colorArgb: color, strokeWidth: stroke, zIndex: z),
    x: x,
    y: y + dy,
  );

  UiNode ring(
    double x,
    double y,
    double diameter,
    int color, {
    double stroke = 2.5,
    int z = 5,
  }) => UiNode.shapeNode(
    world,
    Shape(
      kind: ShapeKind.ring,
      width: diameter,
      colorArgb: color,
      strokeWidth: stroke,
      zIndex: z,
    ),
    x: x,
    y: y + dy,
  );

  UiNode rect(
    UiRect b,
    int color, {
    double stroke = 0,
    double radius = 10,
    int z = 5,
  }) => UiNode.shapeNode(
    world,
    Shape(
      kind: ShapeKind.roundedRect,
      width: b.width,
      height: b.height,
      cornerRadius: radius,
      strokeWidth: stroke,
      colorArgb: color,
      zIndex: z,
    ),
    x: b.centerX,
    y: b.centerY + dy,
  );

  UiNode text(
    String s,
    double x,
    double y, {
    double size = 16,
    int? color,
    int z = 6,
    double? maxWidth,
  }) => UiNode.textNode(
    world,
    Text(
      s,
      fontSize: size,
      colorArgb: color ?? colors.ink,
      zIndex: z,
      maxWidth: maxWidth,
    ),
    x: x,
    y: y + dy,
    fontFamily: fontFamily,
  );

  /// Adds a button over [box] showing [label], already registered for [tap].
  UiButton button(
    UiRect box,
    String label,
    void Function() onTap, {
    double size = 18,
    bool filled = false,
  }) {
    final b = UiButton(
      shift(box),
      rect(box, colors.ink, stroke: 2.5, radius: 14),
      text(label, box.centerX, box.centerY, size: size, z: 7),
      onTap,
    );
    b.style(colors, filled: filled);
    return b..setVisible(true);
  }

  /// Registers [b] for [tap].
  UiButton add(UiButton b) {
    buttons.add(b);
    return b;
  }

  /// Taps at ([x], [y]): runs the first visible, enabled button that contains
  /// the point. Returns whether one did.
  bool tap(double x, double y) {
    for (final b in buttons) {
      if (b.visible && b.enabled && b.box.contains(x, y)) {
        onPress?.call();
        b.onTap();
        return true;
      }
    }
    return false;
  }
}
