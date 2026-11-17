/// A generated fill-in-the-blank question; plain data so an agent can
/// store, send and replay it.
class QuizQuestion {
  final String itemId;
  final int tier;

  /// The item's lines with the blanked word replaced by [blankMarker].
  final List<String> lines;
  final int blankLine;
  final String answer;

  /// Shuffled options; [correctIndex] points at [answer].
  final List<String> options;
  final int correctIndex;

  const QuizQuestion({
    required this.itemId,
    required this.tier,
    required this.lines,
    required this.blankLine,
    required this.answer,
    required this.options,
    required this.correctIndex,
  });

  /// Placeholder left in the blanked line.
  static const blankMarker = '____';

  bool isCorrect(int optionIndex) => optionIndex == correctIndex;

  factory QuizQuestion.fromJson(Map<String, dynamic> json) => QuizQuestion(
        itemId: json['itemId'] as String,
        tier: (json['tier'] as num).toInt(),
        lines: (json['lines'] as List).cast<String>(),
        blankLine: (json['blankLine'] as num).toInt(),
        answer: json['answer'] as String,
        options: (json['options'] as List).cast<String>(),
        correctIndex: (json['correctIndex'] as num).toInt(),
      );

  Map<String, dynamic> toJson() => {
        'itemId': itemId,
        'tier': tier,
        'lines': lines,
        'blankLine': blankLine,
        'answer': answer,
        'options': options,
        'correctIndex': correctIndex,
      };
}
