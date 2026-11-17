/// One bank entry the quiz draws questions from: a few lines of text plus
/// free-form metadata. Nothing here knows the language or genre of the
/// text, so the same model serves poetry, vocabulary or trivia banks.
class QuizItem {
  /// Stable identifier, kept in saves and agent calls instead of the text.
  final String id;

  /// The text, one entry per line; a blank is cut out of exactly one line.
  final List<String> lines;

  /// Difficulty tier; selects the [QuizTierRules] used to build the question.
  final int tier;

  /// Source attribution, used to draw distractors from the same author.
  final String? author;

  /// How well known the item is (higher first when a stage lists items);
  /// 0 when the bank has no such notion.
  final int fame;

  /// Optional extra data (era, chapter, ...) carried through untouched.
  final Map<String, String> meta;

  const QuizItem({
    required this.id,
    required this.lines,
    this.tier = 1,
    this.author,
    this.fame = 0,
    this.meta = const {},
  });

  factory QuizItem.fromJson(Map<String, dynamic> json) => QuizItem(
    id: json['id'] as String,
    lines: (json['lines'] as List).cast<String>(),
    tier: _tierOf(json['tier']),
    author: json['author'] as String?,
    fame: (json['fame'] as num?)?.toInt() ?? 0,
    meta: ((json['meta'] as Map?) ?? const {}).cast<String, String>(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'lines': lines,
    'tier': tier,
    if (author != null) 'author': author,
    if (fame != 0) 'fame': fame,
    if (meta.isNotEmpty) 'meta': meta,
  };

  /// A tier given as a level number or as a [QuizTier] name; anything else
  /// is a [FormatException] so a bad bank fails loudly.
  static int _tierOf(Object? v) {
    if (v == null) return 1;
    if (v is num) return v.toInt();
    final t = v is String ? QuizTier.byName(v) : null;
    if (t == null) throw FormatException('unknown tier "$v"');
    return t.level;
  }
}

/// The four difficulty tiers a bank can name, with the level number the
/// generator keys its [QuizTierRules] by.
enum QuizTier {
  easy(1),
  medium(2),
  hard(3),
  literary(4);

  const QuizTier(this.level);

  /// The number [QuizItem.tier] holds.
  final int level;

  /// The tier called [name], or null.
  static QuizTier? byName(String name) {
    for (final t in values) {
      if (t.name == name) return t;
    }
    return null;
  }

  /// The tier of [level] (1..4), or null.
  static QuizTier? ofLevel(int level) {
    for (final t in values) {
      if (t.level == level) return t;
    }
    return null;
  }
}
