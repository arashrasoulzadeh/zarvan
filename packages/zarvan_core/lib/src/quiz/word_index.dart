import 'quiz_bank.dart';
import 'quiz_text.dart';

/// One distinct word of a bank, as the wrong-option picker needs it.
class WordEntry {
  WordEntry._(this.word, this.display, this.length, this.ending);

  /// The normalized form: what words are compared and de-duplicated by.
  final String word;

  /// The spelling to show, taken from the first place the word appears.
  final String display;

  /// Letters in [word].
  final int length;

  /// The last two letters of [word], for rhyme matching.
  final String ending;

  /// Authors whose items contain the word.
  final Set<String> authors = {};
}

/// Every content word of a bank, indexed by length and ending. Built once per
/// bank (it walks every line) so making each question stays cheap.
class WordIndex {
  WordIndex._(this.all) {
    for (final e in all) {
      (_byLength[e.length] ??= []).add(e);
      (_byEnding[e.ending] ??= []).add(e);
    }
  }

  /// Walks [bank] and indexes the words that [QuizText.isContent] accepts
  /// given [stopWords] (raw words; they are normalized here).
  factory WordIndex.build(QuizBank bank, Set<String> stopWords) {
    final stop = QuizText.normalizeAll(stopWords);
    final entries = <String, WordEntry>{};
    for (final item in bank.items()) {
      for (final line in item.lines) {
        for (final token in QuizText.tokenizeLine(line)) {
          if (!QuizText.isContent(token, stop)) continue;
          final n = QuizText.normalize(token.text);
          final runes = n.runes.toList();
          final entry = entries.putIfAbsent(
            n,
            () => WordEntry._(
              n,
              token.text,
              runes.length,
              String.fromCharCodes(runes.sublist(runes.length - 2)),
            ),
          );
          final author = item.author;
          if (author != null) entry.authors.add(author);
        }
      }
    }
    return WordIndex._(List.unmodifiable(entries.values));
  }

  /// All words, in the order they first appear in [QuizBank.items] (fame
  /// order), so the same bank always gives the same list.
  final List<WordEntry> all;
  final Map<int, List<WordEntry>> _byLength = {};
  final Map<String, List<WordEntry>> _byEnding = {};

  /// Words with exactly [n] letters.
  List<WordEntry> byLength(int n) => _byLength[n] ?? const [];

  /// Words ending in [suffix] (two letters), optionally only those that
  /// appear in an item by [author].
  List<WordEntry> byEnding(String suffix, {String? author}) {
    final list = _byEnding[suffix] ?? const <WordEntry>[];
    if (author == null) return list;
    return [
      for (final e in list)
        if (e.authors.contains(author)) e,
    ];
  }
}
