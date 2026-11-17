import 'blank_picker.dart';
import 'distractors.dart';
import 'quiz_bank.dart';
import 'quiz_item.dart';
import 'quiz_text.dart';
import 'seeded_random.dart';
import 'word_index.dart';

/// The text shown in place of the hidden word.
const defaultBlankMarker = '＿＿＿';

/// One question: an item with a hidden word and four options. Plain data,
/// the same for the UI, an agent and tests; it is rebuilt exactly from its
/// own JSON.
class Question {
  const Question({
    required this.itemId,
    required this.tier,
    required this.seed,
    required this.lines,
    required this.blankLine,
    required this.blankToken,
    required this.options,
    required this.answerIndex,
    this.removedByHint = const [],
  });

  final String itemId;
  final QuizTier tier;

  /// The seed this question was made from; also the source of its hint.
  final int seed;

  /// The item's lines as tokens; the hidden one's text is the blank marker,
  /// so the answer is not in the data a player's screen is built from.
  final List<List<Token>> lines;
  final int blankLine;
  final int blankToken;
  final List<String> options;
  final int answerIndex;

  /// Option indexes a hint took away (empty until [applyHint]).
  final List<int> removedByHint;

  /// Whether option [choice] is the right one.
  bool isCorrect(int choice) => choice == answerIndex;

  /// The lines as strings with the gap shown, marks restored.
  List<String> render() => [for (final line in lines) line.join(' ')];

  /// A copy with two wrong options removed. The pick comes from the
  /// question's own seed, so an agent and a replay remove the same two.
  /// Only one hint per question (R-SCORE-5): a second call is a
  /// [StateError].
  Question applyHint() {
    if (removedByHint.isNotEmpty) {
      throw StateError('This question already used its hint.');
    }
    final wrong = [
      for (var i = 0; i < options.length; i++)
        if (i != answerIndex) i,
    ];
    SeededRandom(seedOf('hint:$itemId:$seed')).shuffle(wrong);
    return Question(
      itemId: itemId,
      tier: tier,
      seed: seed,
      lines: lines,
      blankLine: blankLine,
      blankToken: blankToken,
      options: options,
      answerIndex: answerIndex,
      removedByHint: (wrong.take(2).toList())..sort(),
    );
  }

  factory Question.fromJson(Map<String, dynamic> json) {
    final blank = (json['blank'] as Map).cast<String, dynamic>();
    return Question(
      itemId: json['itemId'] as String,
      tier: QuizTier.byName(json['tier'] as String)!,
      seed: (json['seed'] as num).toInt(),
      lines: [
        for (final line in (json['lines'] as List))
          [
            for (final t in (line as List))
              Token(
                t['text'] as String,
                pre: t['pre'] as String? ?? '',
                post: t['post'] as String? ?? '',
              ),
          ],
      ],
      blankLine: (blank['line'] as num).toInt(),
      blankToken: (blank['token'] as num).toInt(),
      options: (json['options'] as List).cast<String>(),
      answerIndex: (json['answerIndex'] as num).toInt(),
      removedByHint: ((json['removedByHint'] as List?) ?? const [])
          .cast<num>()
          .map((n) => n.toInt())
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'itemId': itemId,
    'tier': tier.name,
    'seed': seed,
    'lines': [
      for (final line in lines)
        [
          for (final t in line) {'text': t.text, 'pre': t.pre, 'post': t.post},
        ],
    ],
    'blank': {'line': blankLine, 'token': blankToken},
    'options': options,
    'answerIndex': answerIndex,
    'removedByHint': removedByHint,
  };
}

/// Makes [Question]s from a bank. Holds the word index, built on first use,
/// so each question costs little; make one factory per bank and reuse it.
class QuestionFactory {
  QuestionFactory(
    this.bank,
    Set<String> stopWords, {
    this.marker = defaultBlankMarker,
  }) : _stop = QuizText.normalizeAll(stopWords),
       _rawStop = stopWords;

  final QuizBank bank;
  final String marker;
  final Set<String> _stop;
  final Set<String> _rawStop;
  late final WordIndex _index = WordIndex.build(bank, _rawStop);

  /// The question for [itemId] at [tier] from [seed]: the same arguments
  /// always give the same question. Null when the item has no word that can
  /// be hidden. Throws [ArgumentError] for an unknown id, and [StateError]
  /// when the bank has fewer than three other words to use as wrong options.
  Question? create(String itemId, QuizTier tier, int seed) {
    final item = bank.byId(itemId);
    if (item == null)
      throw ArgumentError.value(itemId, 'itemId', 'not in the bank');
    final rng = SeededRandom(seed);
    final blank = BlankPicker.pick(item, tier, rng, _stop);
    if (blank == null) return null;
    final lines = [for (final l in item.lines) QuizText.tokenizeLine(l)];
    final answerToken = lines[blank.line][blank.token];
    final result = Distractors.pick(
      item: item,
      answer: answerToken.text,
      tier: tier,
      index: _index,
      rng: rng,
    );
    if (result.words.length < 3) {
      throw StateError(
        'Item $itemId needs 3 wrong options but the bank only has ${result.words.length} other words.',
      );
    }
    final options = [answerToken.text, ...result.words.map((w) => w.display)];
    rng.shuffle(options);
    lines[blank.line][blank.token] = Token(
      marker,
      pre: answerToken.pre,
      post: answerToken.post,
    );
    return Question(
      itemId: itemId,
      tier: tier,
      seed: seed,
      lines: lines,
      blankLine: blank.line,
      blankToken: blank.token,
      options: options,
      answerIndex: options.indexOf(answerToken.text),
    );
  }
}
