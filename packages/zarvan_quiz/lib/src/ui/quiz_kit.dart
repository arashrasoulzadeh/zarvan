import 'dart:async';
import 'dart:convert';

import 'package:zarvan_core/zarvan_core.dart' show KeyValueStore;
import 'package:zarvan_core/zarvan_core_quiz.dart';
import 'package:zarvan_flutter/zarvan_flutter.dart' show ShareOutcome;

import '../quiz_session.dart';
import 'quiz_strings.dart';
import 'quiz_screen.dart' show quizRippleTransition;
import 'quiz_theme.dart';

/// The player's quiz settings, saved under [key] in a [KeyValueStore] and
/// listened to by the screens. Kept apart from progress: they belong to the
/// app, not to the genre's rules.
class QuizSettings {
  QuizSettings._(this._store, this._themeMode, this._sound, this._haptics);

  /// Where the settings are saved.
  static const key = 'quiz.settings';

  final KeyValueStore _store;
  QuizThemeMode _themeMode;
  bool _sound;
  bool _haptics;
  final List<void Function()> _listeners = [];

  QuizThemeMode get themeMode => _themeMode;
  bool get sound => _sound;
  bool get haptics => _haptics;

  /// Loads the saved settings; nothing saved, or a save that cannot be read,
  /// gives the defaults (settings are never worth stopping the game for).
  static Future<QuizSettings> load(KeyValueStore store) async {
    var mode = QuizThemeMode.system;
    var sound = true;
    var haptics = true;
    try {
      final raw = await store.getString(key);
      if (raw != null) {
        final json = jsonDecode(raw) as Map<String, dynamic>;
        mode = QuizThemeMode.values.asNameMap()[json['themeMode']] ?? mode;
        sound = json['sound'] as bool? ?? sound;
        haptics = json['haptics'] as bool? ?? haptics;
      }
    } on Object {
      // The defaults stay.
    }
    return QuizSettings._(store, mode, sound, haptics);
  }

  void addListener(void Function() l) => _listeners.add(l);
  void removeListener(void Function() l) => _listeners.remove(l);

  void setThemeMode(QuizThemeMode mode) =>
      _set(() => _themeMode = mode, _themeMode != mode);
  void setSound(bool on) => _set(() => _sound = on, _sound != on);
  void setHaptics(bool on) => _set(() => _haptics = on, _haptics != on);

  void _set(void Function() apply, bool changed) {
    if (!changed) return;
    apply();
    unawaited(
      _store.setString(
        key,
        jsonEncode({
          'themeMode': _themeMode.name,
          'sound': _sound,
          'haptics': _haptics,
        }),
      ),
    );
    for (final l in List.of(_listeners)) {
      l();
    }
  }
}

/// What an author wears on their head in a portrait.
enum QuizHeadwear {
  /// A turban with a tail hanging at one side.
  turbanTail,
  turban,

  /// A tall felt cap.
  sikke,
  skullCap,
  headband,
  dervishHat,

  /// A scarf falling to the shoulders.
  scarf,
}

/// A small emblem that says what an author is known for.
enum QuizEmblem {
  cup,
  rose,
  reedFlute,
  jug,
  book,
  crown,
  bird,
  lute,
  staff,
  quill,
}

/// How one author's line portrait looks: the engine's `portrait` shader
/// draws the face, and these pick what varies between people.
class QuizPortraitStyle {
  const QuizPortraitStyle({
    this.beard = 0,
    this.beardSpread = 1,
    this.headwear = QuizHeadwear.turbanTail,
    this.closedEyes = false,
    this.feather = false,
    this.collar = false,
    this.woman = false,
    this.emblem,
    this.epithet,
  });

  /// How far the beard hangs below the chin (0 for none).
  final double beard;

  /// How wide it flares.
  final double beardSpread;

  final QuizHeadwear headwear;
  final bool closedEyes;

  /// A quill on the cap.
  final bool feather;

  /// A V-shaped collar.
  final bool collar;
  final bool woman;

  /// What the author is known for, drawn as a small icon on their card and
  /// on their medal.
  final QuizEmblem? emblem;

  /// The title they are known by, written under their name on the medal.
  final String? epithet;

  /// The numbers the shader reads (beard, spread, headwear, flags).
  List<double> get params => [
    beard,
    beardSpread,
    headwear.index.toDouble(),
    (closedEyes ? 1 : 0) +
        (feather ? 2 : 0) +
        (collar ? 4 : 0) +
        (woman ? 8 : 0),
  ];
}

/// Line portraits of the authors, drawn by the engine's `portrait` shader from
/// a [QuizPortraitStyle] each: the shelf card of an author with a style shows
/// their face in place of the plain diamond. No image files are involved.
class QuizPortraits {
  const QuizPortraits(this.styles);

  /// The style of each author that has a portrait, by author id.
  final Map<String, QuizPortraitStyle> styles;

  bool has(String authorId) => styles.containsKey(authorId);
}

/// What the quiz screens need from the app for rewarded ads, without the
/// engine knowing which ad network is used.
abstract interface class QuizAdGate {
  /// Whether a rewarded ad can be shown right now.
  bool get isRewardedReady;

  /// Shows one; true only when it was watched to the end.
  Future<bool> showRewarded(String placement);
}

/// Text about the game for the About screen.
class QuizAbout {
  const QuizAbout({required this.lines, this.link, this.version = ''});

  /// Lines of text (source, license note, credits).
  final List<String> lines;

  /// An address shown as text so it can be copied.
  final String? link;
  final String version;
}

/// Everything a quiz screen needs, gathered once by the game and passed to
/// every screen: the session and content, the language, the look, the
/// settings and the app's own hooks (ads, share, the clock).
class QuizKit {
  QuizKit({
    required this.session,
    required this.factory,
    required this.strings,
    required this.themes,
    required this.settings,
    this.about = const QuizAbout(lines: []),
    this.ads,
    this.share,
    this.shareText,
    this.stageMode = const StageMode(),
    this.portraits,
    this.transitions = true,
    this.transitionKind = quizRippleTransition,
    this.returnTransitionKind = quizRippleTransition,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now;

  final QuizSession session;
  final QuestionFactory factory;
  final QuizStrings strings;
  final QuizThemes themes;
  final QuizSettings settings;
  final QuizAbout about;
  final QuizAdGate? ads;

  /// Shares a text and says what happened (shared, copied or failed). Null
  /// hides the share button.
  final Future<ShareOutcome> Function(String text)? share;

  /// Builds the text shared after a daily from its date and results; null
  /// shares a plain default.
  final String Function(String date, List<bool> results)? shareText;
  final StageMode stageMode;

  /// The authors' portraits, or null for none.
  final QuizPortraits? portraits;

  /// Whether leaving the menu for a game plays the veil transition.
  final bool transitions;

  /// How leaving a screen for another looks: `page` (default), the screen
  /// itself curling away from the right over the next one; or, by the name of
  /// an engine `ShaderEffect` kind, an overlay drawn over it: `curtain`,
  /// `kashi`, `ink`, `veil`; or `verse`, poem words swirling in over ink.
  final String transitionKind;

  /// The same, for going back to the menu (default `lanterns`, the screen
  /// carried up on paper lanterns).
  final String returnTransitionKind;

  /// The overlay kind of the transition now running, so the screen that opens
  /// lifts it in the same style; set by the screen that starts one.
  String? veilKind;

  /// How long the screen takes no taps once a transition has ended.
  static const inputGraceSeconds = 0.1;

  /// Seconds of that grace still to run; counted down by the open screen.
  double inputGrace = 0;

  /// Set when a screen is leaving under a transition, so the next one knows
  /// to lift it instead of appearing bare.
  bool veilPending = false;
  final DateTime Function() now;

  QuizBank get bank => factory.bank;

  /// The theme in force for the current settings.
  QuizTheme get theme => themes.resolve(settings.themeMode);

  /// `2026-11-17`: today's local date, as the daily challenge keys it.
  String get today {
    final t = now();
    return '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }
}
