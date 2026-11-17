import 'package:test/test.dart';
import 'package:zarvan_core/zarvan_core_quiz.dart';

Map<String, dynamic> raw({
  int version = 1,
  List<Map<String, dynamic>>? items,
}) => {
  'version': version,
  'authors': [
    {'id': 'hafez', 'name': 'حافظ'},
    {'id': 'saadi', 'name': 'سعدی'},
  ],
  'items':
      items ??
      [
        {
          'id': 'hafez-2-0',
          'author': 'hafez',
          'tier': 'easy',
          'fame': 50,
          'lines': ['الف ب', 'ج د'],
          'meta': {'form': 'beyt', 'source': 'u'},
        },
        {
          'id': 'hafez-1-0',
          'author': 'hafez',
          'tier': 'easy',
          'fame': 50,
          'lines': ['ه و', 'ز ح'],
        },
        {
          'id': 'hafez-3-0',
          'author': 'hafez',
          'tier': 'easy',
          'fame': 90,
          'lines': ['ط ی', 'ک ل'],
        },
        {
          'id': 'saadi-1-0',
          'author': 'saadi',
          'tier': 'hard',
          'fame': 10,
          'lines': ['م ن', 'س ع'],
        },
      ],
};

void main() {
  test(
    'data-format §2: JSON round trip keeps authors, order and meta untouched',
    () {
      final bank = QuizBank.fromJson(raw());
      expect([for (final a in bank.authors) a.id], ['hafez', 'saadi']);
      expect(bank.authors.first.name, 'حافظ');
      final back = QuizBank.fromJson(bank.toJson());
      expect(back.toJson(), bank.toJson());
      expect(bank.byId('hafez-2-0')!.meta, {'form': 'beyt', 'source': 'u'});
      expect(bank.byId('hafez-2-0')!.tier, QuizTier.easy.level);
    },
  );

  test('R-MODE-S2: items filter by author and tier, fame desc then id asc', () {
    final bank = QuizBank.fromJson(raw());
    expect(
      [for (final i in bank.items(author: 'hafez', tier: QuizTier.easy)) i.id],
      ['hafez-3-0', 'hafez-1-0', 'hafez-2-0'],
    );
    expect([for (final i in bank.items(author: 'saadi')) i.id], ['saadi-1-0']);
    expect(bank.items(tier: QuizTier.literary), isEmpty);
    expect(bank.items().length, 4);
  });

  test('byId finds an item or returns null', () {
    final bank = QuizBank.fromJson(raw());
    expect(bank.byId('saadi-1-0')!.author, 'saadi');
    expect(bank.byId('nope'), isNull);
  });

  test('an unknown version is a clear FormatException', () {
    expect(
      () => QuizBank.fromJson(raw(version: 2)),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          allOf(contains('version 2'), contains('1')),
        ),
      ),
    );
  });

  test('an invalid tier names the item number and id', () {
    final items = raw()['items'] as List<Map<String, dynamic>>;
    items[2] = {...items[2], 'tier': 'legendary'};
    expect(
      () => QuizBank.fromJson(raw(items: items)),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          allOf(contains('#3'), contains('hafez-3-0'), contains('legendary')),
        ),
      ),
    );
  });

  test('QuizTier maps names to levels one to four', () {
    expect([for (final t in QuizTier.values) t.level], [1, 2, 3, 4]);
    expect(QuizTier.byName('hard'), QuizTier.hard);
    expect(QuizTier.byName('x'), isNull);
    expect(QuizTier.ofLevel(4), QuizTier.literary);
  });
}
