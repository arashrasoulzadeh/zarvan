/// One word of a line with the punctuation that touched it, so a question can
/// be shown with the original marks restored.
class Token {
  const Token(this.text, {this.pre = '', this.post = ''});

  /// The word without surrounding punctuation, as written.
  final String text;

  /// Punctuation before and after the word.
  final String pre;
  final String post;

  @override
  String toString() => '$pre$text$post';
}

/// Text rules that are the same for every game: comparing, splitting and
/// blanking. No word lists live here, because the engine knows no language;
/// the game passes its stop words in.
abstract final class QuizText {
  static const _marks = '،؛؟!«»:."()';

  /// Folds spelling variants for comparing words (never for showing them):
  /// Arabic `ي`/`ك` to Persian `ی`/`ک`, no diacritics (U+064B..U+0652,
  /// U+0670), no kashida. The half-space (ZWNJ) is kept: it separates
  /// different words in Persian.
  static String normalize(String s) {
    final b = StringBuffer();
    for (final r in s.runes) {
      if ((r >= 0x064B && r <= 0x0652) || r == 0x0670 || r == 0x0640) continue;
      b.writeCharCode(switch (r) {
        0x064A => 0x06CC,
        0x0643 => 0x06A9,
        _ => r,
      });
    }
    return b.toString();
  }

  /// [normalize] applied to every word, for building a stop-word set that
  /// [isContent] can compare against.
  static Set<String> normalizeAll(Iterable<String> words) => {
    for (final w in words) normalize(w),
  };

  /// Splits [line] on whitespace and peels punctuation off both ends of each
  /// word. A piece that is only punctuation is dropped. Runs of spaces are
  /// not remembered: rendering joins with one space.
  static List<Token> tokenizeLine(String line) {
    final out = <Token>[];
    for (final raw in line.split(RegExp(r'\s+'))) {
      if (raw.isEmpty) continue;
      var start = 0;
      var end = raw.length;
      while (start < end && _marks.contains(raw[start])) {
        start++;
      }
      while (end > start && _marks.contains(raw[end - 1])) {
        end--;
      }
      if (start == end) continue;
      out.add(
        Token(
          raw.substring(start, end),
          pre: raw.substring(0, start),
          post: raw.substring(end),
        ),
      );
    }
    return out;
  }

  /// Whether [token] may be blanked or used as a wrong option: not a stop
  /// word and at least two letters once normalized. [stopWords] must already
  /// be normalized (see [normalizeAll]).
  static bool isContent(Token token, Set<String> stopWords) {
    final n = normalize(token.text);
    return n.runes.length >= 2 && !stopWords.contains(n);
  }

  /// [lines] with the token at `(lineIndex, tokenIndex)` replaced by
  /// [marker], keeping its punctuation. Every line comes back re-joined with
  /// single spaces.
  static List<String> renderWithBlank(
    List<String> lines,
    (int, int) blank, {
    String marker = '＿＿＿',
  }) {
    final (lineIndex, tokenIndex) = blank;
    RangeError.checkValidIndex(lineIndex, lines, 'lineIndex');
    final out = <String>[];
    for (var i = 0; i < lines.length; i++) {
      final tokens = tokenizeLine(lines[i]);
      if (i != lineIndex) {
        out.add(tokens.join(' '));
        continue;
      }
      RangeError.checkValidIndex(tokenIndex, tokens, 'tokenIndex');
      out.add(
        [
          for (var k = 0; k < tokens.length; k++)
            if (k == tokenIndex)
              '${tokens[k].pre}$marker${tokens[k].post}'
            else
              tokens[k].toString(),
        ].join(' '),
      );
    }
    return out;
  }
}
