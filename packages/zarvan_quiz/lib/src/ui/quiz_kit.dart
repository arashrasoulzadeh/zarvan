import 'dart:async';
import 'dart:convert';

import 'package:zarvan_core/zarvan_core.dart' show KeyValueStore;
import 'package:zarvan_core/zarvan_core_quiz.dart';
import 'package:zarvan_flutter/zarvan_flutter.dart' show ShareOutcome;

import '../quiz_session.dart';
import 'quiz_strings.dart';
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

/// Line portraits of the authors, packed in one sprite sheet the game
/// registers (as its packed atlas): the shelf card of an author with a
/// region named after their id shows it in place of the plain diamond.
class QuizPortraits {
  const QuizPortraits({required this.atlasId, required this.authors});

  /// The id the sheet is registered under.
  final String atlasId;

  /// The author ids that have a region in the sheet.
  final Set<String> authors;

  /// Size of one region, in pixels (all are the same).
  static const regionWidth = 160.0;
  static const regionHeight = 200.0;

  bool has(String authorId) => authors.contains(authorId);
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
