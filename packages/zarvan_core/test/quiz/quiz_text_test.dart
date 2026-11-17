import 'package:test/test.dart';
import 'package:zarvan_core/zarvan_core_quiz.dart';

void main() {
  test(
    'R-TEXT-1: normalize folds ي/ك, drops diacritics and kashida, keeps ZWNJ',
    () {
      expect(QuizText.normalize('كيف'), 'کیف');
      expect(QuizText.normalize('مُحَمَّد'), 'محمد');
      expect(QuizText.normalize('عـشـق'), 'عشق');
      expect(QuizText.normalize('می‌رود'), 'می‌رود');
      expect(QuizText.normalize('أٰ'), 'أ');
    },
  );

  test(
    'R-TEXT-2: punctuation splits off both ends and is kept as pre/post',
    () {
      final t = QuizText.tokenizeLine('«سلام،  جهان»؟ دوست.');
      expect([for (final x in t) x.text], ['سلام', 'جهان', 'دوست']);
      expect(t[0].pre, '«');
      expect(t[0].post, '،');
      expect(t[1].pre, '');
      expect(t[1].post, '»؟');
      expect(t[2].post, '.');
    },
  );

  test('R-TEXT-2: a token that is only punctuation is dropped', () {
    expect(QuizText.tokenizeLine('الف ، ب').map((t) => t.text), ['الف', 'ب']);
    expect(QuizText.tokenizeLine('   '), isEmpty);
  });

  test('R-TEXT-3: one-letter words are not content, nor are stop words', () {
    final stop = QuizText.normalizeAll({'كه', 'از'});
    Token t(String s) => QuizText.tokenizeLine(s).single;
    expect(QuizText.isContent(t('و'), stop), isFalse);
    expect(
      QuizText.isContent(t('که'), stop),
      isFalse,
    ); // ك in the list, ک in the text
    expect(QuizText.isContent(t('از'), stop), isFalse);
    expect(QuizText.isContent(t('عشق'), stop), isTrue);
    expect(QuizText.isContent(t('عشق'), const {}), isTrue);
  });

  test(
    'R-TEXT-5: render swaps the target for the marker and restores marks',
    () {
      final lines = ['الا یا ایها الساقی', '«که عشق» آسان'];
      final out = QuizText.renderWithBlank(lines, (1, 0), marker: '＿＿＿');
      expect(out, ['الا یا ایها الساقی', '«＿＿＿ عشق» آسان']);
    },
  );

  test('R-TEXT-5: marker defaults and marks around the blank survive', () {
    final out = QuizText.renderWithBlank(['الف «ب»، ج'], (0, 1));
    expect(out.single, 'الف «＿＿＿»، ج');
  });

  test('renderWithBlank rejects an index outside the lines', () {
    expect(() => QuizText.renderWithBlank(['الف'], (3, 0)), throwsRangeError);
    expect(() => QuizText.renderWithBlank(['الف'], (0, 4)), throwsRangeError);
  });
}
