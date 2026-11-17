import 'dart:ui' show Offset;

import 'package:zarvan_core/zarvan_core_quiz.dart'
    show QuizRound, defaultBlankMarker;
import 'package:zarvan_core/zarvan_core.dart'
    show EntityId, GameState, UiRect, World;
import 'package:zarvan_flutter/zarvan_flutter.dart' as eng;
import 'package:zarvan_flutter/zarvan_flutter.dart'
    show
        Scene,
        SceneController,
        Shape,
        ShapeKind,
        TextAlignment,
        UiBuilder,
        UiButton,
        UiNode;

import 'quiz_kit.dart';
import 'quiz_theme.dart';

/// How a button looks.
enum QuizButtonStyle {
  /// A solid accent block: the main action.
  primary,

  /// An outlined block: a quieter action.
  outline,

  /// A soft surface block: an answer option.
  option,
}

/// A set of drawn things that can be thrown away together, so a screen can
/// redraw the part that changes (a new question) without rebuilding the rest.
class QuizGroup {
  QuizGroup(this._screen);

  final QuizScreen _screen;
  final List<EntityId> _ids = [];
  final List<UiButton> _buttons = [];

  void addNode(UiNode n) => _ids.add(n.id);

  void addButton(UiButton b) {
    _ids
      ..add(b.bg.id)
      ..add(b.label.id);
    _buttons.add(b);
  }

  /// Removes everything in the group from the world and from tap handling.
  void clear() {
    for (final id in _ids) {
      _screen.world.destroy(id);
    }
    for (final b in _buttons) {
      _screen.ui.buttons.remove(b);
    }
    _ids.clear();
    _buttons.clear();
  }
}

/// The base of every quiz screen: an engine [Scene] that draws only with the
/// engine's own shapes and text (no Flutter widgets) in the game's
/// [QuizTheme], and turns taps into button presses.
///
/// The world is laid out for a portrait [worldWidth] x [worldHeight]; the
/// game's viewport scales it to the device.
abstract class QuizScreen extends Scene {
  QuizScreen(this.kit);

  final QuizKit kit;

  late World world;
  late SceneController scenes;
  late UiBuilder ui;

  static const worldWidth = 360.0;
  static const worldHeight = 640.0;

  /// Side margin of the layout.
  static const margin = 20.0;

  /// Height of a standard button.
  static const buttonHeight = 48.0;

  QuizTheme get theme => kit.theme;

  bool get rtl => kit.strings.rtl;

  /// Builds the screen's pieces. Called once the world is ready.
  void build();

  @override
  bool get showOnScreenControls => false;

  @override
  double? get ambientBrightness => 1.0;

  @override
  Future<void> populate(
    World world,
    SceneController scenes,
    GameState state,
  ) async {
    this.world = world;
    this.scenes = scenes;
    ui = UiBuilder(
      world,
      theme,
      width: worldWidth,
      height: worldHeight,
      fontFamily: theme.fontFamily,
    );
    ui.background();
    build();
  }

  @override
  void handleTap(World world, SceneController scenes, Offset worldPosition) {
    ui.tap(worldPosition.dx, worldPosition.dy);
  }

  /// A piece of text at ([x], [y]), centred on that point.
  UiNode label(
    String s,
    double x,
    double y, {
    double size = 16,
    int? color,
    double? maxWidth,
    TextAlignment align = TextAlignment.center,
    int z = 6,
  }) => UiNode.textNode(
    world,
    eng.Text(
      s,
      fontSize: size,
      colorArgb: color ?? theme.ink,
      zIndex: z,
      maxWidth: maxWidth,
      align: align,
      rtl: rtl,
    ),
    x: x,
    y: y,
    fontFamily: theme.fontFamily,
  );

  /// A rounded box.
  UiNode box(
    UiRect b,
    int color, {
    double stroke = 0,
    double radius = 14,
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
    y: b.centerY,
  );

  /// A button over [b] showing [text]; it is also added to [group] when given.
  UiButton button(
    UiRect b,
    String text,
    void Function() onTap, {
    QuizButtonStyle style = QuizButtonStyle.primary,
    double size = 18,
    QuizGroup? group,
  }) {
    final btn = ui.add(ui.button(b, text, onTap, size: size));
    btn.label.text!.rtl = rtl;
    switch (style) {
      case QuizButtonStyle.primary:
        btn.bg.shape!
          ..colorArgb = theme.accent
          ..strokeWidth = 0;
        btn.label.text!.colorArgb = theme.onAccent;
      case QuizButtonStyle.outline:
        btn.bg.shape!
          ..colorArgb = theme.accent
          ..strokeWidth = 2;
        btn.label.text!.colorArgb = theme.accent;
      case QuizButtonStyle.option:
        btn.bg.shape!
          ..colorArgb = theme.surface
          ..strokeWidth = 0;
        btn.label.text!.colorArgb = theme.ink;
    }
    group?.addButton(btn);
    return btn;
  }

  /// The title bar: [text] centred at the top, and (when [onBack] is given) a
  /// back button on the reading-start side.
  void titleBar(String text, {void Function()? onBack}) {
    label(text, worldWidth / 2, 36, size: 22);
    if (onBack != null) {
      final x = rtl ? worldWidth - margin - 36 : margin;
      final b = button(
        UiRect(x, 18, 36, 36),
        rtl ? '→' : '←',
        onBack,
        style: QuizButtonStyle.outline,
        size: 20,
      );
      b.label.text!.rtl = false;
    }
  }

  /// How the blank is drawn: plain underscores. The core marker is three
  /// full-width underscores, which a line may break between (splitting the gap
  /// over two lines) and which some fonts lack; ASCII underscores never break
  /// and every font has them.
  static const blank = '______';

  /// [line] with the blank marker replaced by [blank].
  String keepBlankTogether(String line) =>
      line.replaceAll(defaultBlankMarker, blank);

  /// A new group for things that change.
  QuizGroup group() => QuizGroup(this);

  /// A standard full-width button rectangle whose top is [y].
  UiRect row(double y, {double height = buttonHeight}) =>
      UiRect(margin, y, worldWidth - 2 * margin, height);

  /// Moves on to [next], dropping this screen.
  void goTo(Scene next) => scenes.loadScene(next);

  /// Starts [round] on the session and opens the game screen.
  void play(QuizRound round, Scene Function() gameScreen) {
    kit.session.begin(round);
    goTo(gameScreen());
  }
}
