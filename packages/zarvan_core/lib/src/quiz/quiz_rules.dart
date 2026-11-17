/// Which word of a line is cut out.
enum BlankStrategy {
  /// The final word: easiest, and the natural one for rhymed text.
  lastWord,

  /// A random word that is not a stop word.
  randomContentWord,
}

/// Where wrong options come from.
enum DistractorStrategy {
  /// Any word from the bank.
  unrelated,

  /// Words with the same character length as the answer.
  sameLength,

  /// Words sharing the answer's ending ([QuizTierRules.rhymeSuffixLength]
  /// characters), the hardest to tell apart in rhymed text.
  sameRhyme,

  /// Words taken from other items by the same author.
  sameAuthor,
}

/// The data that defines how one difficulty tier builds a question.
class QuizTierRules {
  final BlankStrategy blank;
  final DistractorStrategy distractors;

  /// Total options shown, correct one included.
  final int optionCount;

  /// Ending length compared by [DistractorStrategy.sameRhyme].
  final int rhymeSuffixLength;

  const QuizTierRules({
    this.blank = BlankStrategy.lastWord,
    this.distractors = DistractorStrategy.unrelated,
    this.optionCount = 4,
    this.rhymeSuffixLength = 2,
  });

  factory QuizTierRules.fromJson(Map<String, dynamic> json) => QuizTierRules(
    blank: BlankStrategy.values.byName(json['blank'] as String? ?? 'lastWord'),
    distractors: DistractorStrategy.values.byName(
      json['distractors'] as String? ?? 'unrelated',
    ),
    optionCount: (json['optionCount'] as num?)?.toInt() ?? 4,
    rhymeSuffixLength: (json['rhymeSuffixLength'] as num?)?.toInt() ?? 2,
  );

  Map<String, dynamic> toJson() => {
    'blank': blank.name,
    'distractors': distractors.name,
    'optionCount': optionCount,
    'rhymeSuffixLength': rhymeSuffixLength,
  };
}
