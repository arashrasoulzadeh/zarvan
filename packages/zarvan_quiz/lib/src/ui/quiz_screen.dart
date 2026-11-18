import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:zarvan_core/zarvan_core_quiz.dart'
    show QuizRound, defaultBlankMarker;
import 'package:zarvan_core/zarvan_core.dart'
    show EntityId, GameState, Position, UiRect, World;
import 'package:zarvan_flutter/zarvan_flutter.dart' as eng;
import 'package:zarvan_flutter/zarvan_flutter.dart'
    show
        Scene,
        SceneController,
        SceneTransitionConfig,
        SceneTransitionType,
        ShaderEffect,
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

  /// Adds an entity that is not a node (a shader light) to the group.
  void addId(EntityId id) => _ids.add(id);

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
/// The transition kind that turns the screen like a page: a snapshot curls
/// away from the right over the next screen (the engine's `pageTurn`).
const quizPageTurnTransition = 'page';

/// The transition kind in which paper lanterns lift the screen up and away
/// (the engine's `lanterns`).
const quizLanternsTransition = 'lanterns';

/// The transition kind in which a drop falls where the player touched and
/// rings spread over the screen like water (the engine's `ripple`).
const quizRippleTransition = 'ripple';

/// The name of the transition kind that swirls the poems' own words over an
/// ink wash (the others are engine `ShaderEffect` kinds).
const quizVerseTransition = 'verse';

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

  /// Height the screen has beyond the authored [worldHeight]: a tall phone
  /// shows more world, which the layout spreads over instead of padding.
  double get extra =>
      world.height > worldHeight ? world.height - worldHeight : 0;

  /// Added to every y the helpers place, so a section of the layout moves down
  /// as one piece. Screens set it with [spread] before building each section.
  double yShift = 0;

  /// Moves the sections built after this by [fraction] of the spare height
  /// (0 stays at the top, 1 sits at the bottom).
  void spread(double fraction) => yShift = extra * fraction;

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
      height: world.height,
      fontFamily: theme.fontFamily,
    );
    ui.background();
    build();
    yShift = 0;
  }

  @override
  void handleTap(World world, SceneController scenes, Offset worldPosition) {
    if (veiled || kit.inputGrace > 0) return;
    _lastTap = Offset(
      (worldPosition.dx / worldWidth).clamp(0.0, 1.0),
      (worldPosition.dy / world.height).clamp(0.0, 1.0),
    );
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
    String? fontFamily,
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
    y: y + yShift,
    fontFamily: fontFamily ?? theme.fontFamily,
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
    y: b.centerY + yShift,
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
    final btn = ui.add(
      ui.button(
        UiRect(b.x, b.y + yShift, b.width, b.height),
        text,
        onTap,
        size: size,
      ),
    );
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
  void titleBar(String text, {void Function()? onBack, bool showTitle = true}) {
    if (showTitle) label(text, worldWidth / 2, 36, size: 22);
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

  /// Starts [round] on the session and opens the game screen, under the veil
  /// when the kit has transitions on.
  void play(QuizRound round, Scene Function() gameScreen) {
    kit.session.begin(round);
    navigate(gameScreen());
  }

  // The transition veil: a full-screen shader that spreads from a point until
  // it covers the screen, then the next scene loads and its own veil shrinks
  // away. Driven from [update].
  static const veilSeconds = 0.6;
  EntityId? _veil;
  double _veilProgress = 0;
  double _veilDirection = 0;
  Scene? _veilNext;
  eng.WordSwarm? _swarm;

  /// Where the player last touched, as fractions of the screen.
  Offset _lastTap = const Offset(0.5, 0.5);

  /// Moves on to [next] under the transition when the kit has them on, or at
  /// once when not. [returning] picks the kit's transition for going back to
  /// the menu rather than the one for going into a game.
  void navigate(Scene next, {bool returning = false}) {
    if (!kit.transitions) {
      goTo(next);
      return;
    }
    final kind = returning ? kit.returnTransitionKind : kit.transitionKind;
    // These two are snapshots of this screen that the engine carries over the
    // next one, which is already loaded underneath: no cover phase, no pause.
    final snapshot = switch (kind) {
      quizPageTurnTransition => (SceneTransitionType.pageTurn, 0.9),
      quizLanternsTransition => (SceneTransitionType.lanterns, 1.2),
      quizRippleTransition => (SceneTransitionType.ripple, 1.3),
      _ => null,
    };
    if (snapshot != null) {
      scenes.loadSceneWithTransition(
        next,
        transition: SceneTransitionConfig(
          type: snapshot.$1,
          duration: snapshot.$2,
          // The drop falls where the player last touched.
          originX: _lastTap.dx,
          originY: _lastTap.dy,
        ),
      );
    } else {
      kit.veilKind = kind;
      veilTo(next);
    }
  }

  /// Whether a transition is running (taps are ignored meanwhile).
  bool get veiled => _veilDirection != 0;

  /// Words of the bank's poems for the verse transition.
  List<String> _poemWords() {
    final out = <String>[];
    for (final item in kit.bank.items().take(80)) {
      for (final line in item.lines) {
        out.addAll(line.split(RegExp(r'\s+')).where((w) => w.length > 1));
      }
    }
    return out;
  }

  EntityId _spawnVeil(double progress, double x, double y) {
    final kind = kit.veilKind ?? kit.transitionKind;
    final verse = kind == quizVerseTransition;
    if (verse) {
      _swarm = eng.WordSwarm(
        world,
        _poemWords(),
        width: worldWidth,
        height: world.height,
        fontFamily: theme.fontFamily ?? '',
        color: 0xFFF3E6C4,
        accentColor: 0xFFE3C477,
        rtl: rtl,
      )..apply(progress, originX: x, originY: y);
    }
    final id = world.spawn();
    world.componentsOf<Position>().set(
      id,
      Position(worldWidth / 2, world.height / 2),
    );
    world.componentsOf<ShaderEffect>().set(
      id,
      ShaderEffect(
        kind: verse ? ShaderEffect.ink : kind,
        width: worldWidth,
        height: world.height,
        zIndex: 100,
        rimArgb: 0xFFE3C477,
        armArgb: switch (kind) {
          ShaderEffect.ink => 0xFFE8A0AA,
          ShaderEffect.kashi => 0xFF1F7A6E,
          ShaderEffect.curtain => 0xFFBFD4F0,
          _ => theme.accent,
        },
        coreArgb: switch (kind) {
          ShaderEffect.ink => 0xFF0C1A30,
          ShaderEffect.curtain => 0xFF1B2D5A,
          _ => 0xFF0B2420,
        },
        params: [progress, x, y],
      ),
    );
    return id;
  }

  /// Loads [next] once a veil spread from ([x], [y]) (fractions of the
  /// screen) has covered this screen.
  void veilTo(Scene next, {double x = 0.5, double y = 0.5}) {
    if (veiled) return;
    kit.veilPending = true;
    _veilNext = next;
    _veilProgress = 0;
    _veilDirection = 1;
    _veil = _spawnVeil(0, x, y);
  }

  /// Starts this screen covered and lets the veil shrink away from the
  /// middle: the other half of [veilTo].
  void openVeil({double x = 0.5, double y = 0.5}) {
    if (!kit.transitions || !kit.veilPending) return;
    kit.veilPending = false;
    _veilProgress = 1;
    _veilDirection = -1;
    _veil = _spawnVeil(1, x, y);
  }

  void _stepVeil(double dt) {
    if (kit.inputGrace > 0) kit.inputGrace = math.max(0, kit.inputGrace - dt);
    if (_veilDirection == 0) return;
    _veilProgress += _veilDirection * dt / veilSeconds;
    final done = _veilDirection > 0 ? _veilProgress >= 1 : _veilProgress <= 0;
    _veilProgress = _veilProgress.clamp(0.0, 1.0);
    final fx = world.componentsOf<ShaderEffect>().get(_veil!);
    if (fx != null) {
      fx.params = [_veilProgress, fx.params[1], fx.params[2]];
      _swarm?.apply(
        _veilProgress,
        originX: fx.params[1],
        originY: fx.params[2],
      );
    }
    if (!done) return;
    final next = _veilNext;
    final closing = _veilDirection > 0;
    _veilDirection = 0;
    _swarm?.dispose();
    _swarm = null;
    if (closing && next != null) {
      _veilNext = null;
      goTo(next);
    } else if (_veil != null) {
      world.destroy(_veil!);
      _veil = null;
      // A tap meant for the screen that left must not land on this one.
      kit.inputGrace = QuizKit.inputGraceSeconds;
    }
  }

  @override
  void update(double dt, World world) => _stepVeil(dt);
}
