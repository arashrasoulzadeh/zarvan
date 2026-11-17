import 'package:test/test.dart';
import 'package:zarvan_core/zarvan_core_quiz.dart';

// Goldens come from an independent JavaScript mulberry32 / FNV-1a reference,
// so a Dart implementation bug cannot agree with itself.
const _golden = {
  0: [1144304738, 1416247, 958946056, 627933444, 2007157716],
  1: [2693262067, 11749833, 2265367787, 4213581821, 4159151403],
  42: [2581720956, 1925393290, 3661312704, 2876485805, 750819978],
};

void main() {
  test('R-RNG-2: first five values match the reference for seeds 0, 1, 42', () {
    _golden.forEach((seed, expected) {
      final r = SeededRandom(seed);
      expect([for (var i = 0; i < 5; i++) r.nextUint32()], expected);
    });
  });

  test('R-RNG-3: seedOf is FNV-1a 32 over UTF-8', () {
    expect(seedOf(''), 2166136261);
    expect(seedOf('a'), 3826002220);
    expect(seedOf('daily:2026-11-17'), 401435570);
    expect(seedOf('شاعر'), 1792437532);
  });

  test('R-RNG-4: shuffle is deterministic and matches the reference', () {
    final a = [for (var i = 0; i < 10; i++) i];
    SeededRandom(42).shuffle(a);
    expect(a, [0, 7, 3, 5, 2, 1, 8, 9, 4, 6]);
    final b = [for (var i = 0; i < 10; i++) i];
    SeededRandom(42).shuffle(b);
    expect(b, a);
  });

  test(
    'R-RNG-4: nextInt stays in range, nextDouble in [0,1), pick from list',
    () {
      final r = SeededRandom(7);
      final seen = <int>{};
      for (var i = 0; i < 10000; i++) {
        final n = r.nextInt(5);
        expect(n, inInclusiveRange(0, 4));
        seen.add(n);
        final d = r.nextDouble();
        expect(d, greaterThanOrEqualTo(0));
        expect(d, lessThan(1));
      }
      expect(seen, {0, 1, 2, 3, 4});
      expect(['x', 'y', 'z'], contains(r.pick(['x', 'y', 'z'])));
    },
  );

  test(
    'nextInt rejects a non-positive bound and pick rejects an empty list',
    () {
      expect(() => SeededRandom(1).nextInt(0), throwsArgumentError);
      expect(() => SeededRandom(1).pick(<int>[]), throwsArgumentError);
    },
  );
}
