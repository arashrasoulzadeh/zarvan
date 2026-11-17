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

  /// Optional extra data (era, chapter, ...) carried through untouched.
  final Map<String, String> meta;

  const QuizItem({
    required this.id,
    required this.lines,
    this.tier = 1,
    this.author,
    this.meta = const {},
  });

  factory QuizItem.fromJson(Map<String, dynamic> json) => QuizItem(
    id: json['id'] as String,
    lines: (json['lines'] as List).cast<String>(),
    tier: (json['tier'] as num?)?.toInt() ?? 1,
    author: json['author'] as String?,
    meta: ((json['meta'] as Map?) ?? const {}).cast<String, String>(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'lines': lines,
    'tier': tier,
    if (author != null) 'author': author,
    if (meta.isNotEmpty) 'meta': meta,
  };
}
