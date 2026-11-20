import 'package:zarvan_core/zarvan_core.dart';
import 'package:test/test.dart';

void main() {
  test(
    'forEachNearbyPair finds entities inserted into the same/adjacent cells',
    () {
      final hash = SpatialHash(cellSize: 10, worldWidth: 100);
      hash.insert(1, 0, 0);
      hash.insert(2, 5, 0);

      final pairs = <Set<int>>[];
      hash.forEachNearbyPair((a, b) => pairs.add({a, b}));

      expect(pairs.any((p) => p.containsAll({1, 2})), isTrue);
    },
  );

  test(
    'clear removes all inserted entities so no pairs are found afterward',
    () {
      final hash = SpatialHash(cellSize: 10, worldWidth: 100);
      hash.insert(1, 0, 0);
      hash.insert(2, 5, 0);

      hash.clear();

      var pairCount = 0;
      hash.forEachNearbyPair((a, b) => pairCount++);
      expect(pairCount, 0);
    },
  );

  test(
    'the same SpatialHash instance works correctly across repeated clear()+insert() '
    'cycles into the same cells -- regression for clear() now emptying buckets in '
    'place (reusing their List objects, for CollisionSystem to reuse one SpatialHash '
    'across ticks) instead of dropping map entries entirely',
    tags: ['regression'],
    () {
      final hash = SpatialHash(cellSize: 10, worldWidth: 100);

      hash.insert(1, 0, 0);
      hash.insert(2, 5, 0);
      var pairs = <Set<int>>[];
      hash.forEachNearbyPair((a, b) => pairs.add({a, b}));
      expect(pairs, [
        {1, 2},
      ]);

      // A full clear+reinsert cycle with entirely different entity ids in
      // the exact same cells -- the old ids must not linger.
      hash.clear();
      hash.insert(10, 0, 0);
      hash.insert(20, 5, 0);
      hash.insert(30, 6, 0);
      pairs = <Set<int>>[];
      hash.forEachNearbyPair((a, b) => pairs.add({a, b}));

      expect(
        pairs.any((p) => p.contains(1) || p.contains(2)),
        isFalse,
        reason:
            'entities from before the clear() must not leak into this cycle\'s results',
      );
      expect(
        pairs.length,
        3,
        reason: '10/20/30 are all mutually adjacent -- 3 pairs',
      );

      // A third cycle, again reusing the same cells, to rule out any
      // one-clear-only fluke.
      hash.clear();
      var thirdCycleCount = 0;
      hash.forEachNearbyPair((a, b) => thirdCycleCount++);
      expect(thirdCycleCount, 0);
    },
  );

  test(
    'entities outside [0, worldWidth) never share a cell with unrelated ones '
    '-- regression: the flat row-major key aliased any x past the world width '
    'into the next row, so a level wider than World.width made one bucket '
    'swallow whole rows and broad-phase cost exploded (55x at 5k entities)',
    tags: ['regression'],
    () {
      // worldWidth 100 / cell 10 -> 11 columns. (cx=11, cy=0) used to share a
      // key with (cx=0, cy=1), and (cx=-1, cy=1) with (cx=10, cy=0).
      final hash = SpatialHash(cellSize: 10, worldWidth: 100);
      hash.insert(1, 115, 5); // cell (11, 0)
      hash.insert(2, 5, 15); // cell (0, 1): five cells away in x
      hash.insert(3, -5, 15); // cell (-1, 1)
      hash.insert(4, 105, 5); // cell (10, 0)

      final pairs = <Set<int>>[];
      hash.forEachNearbyPair((a, b) => pairs.add({a, b}));

      bool paired(int a, int b) => pairs.any((p) => p.containsAll({a, b}));
      expect(paired(1, 2), isFalse);
      expect(paired(3, 4), isFalse);
      expect(paired(1, 4), isTrue); // genuinely adjacent cells
      expect(paired(2, 3), isTrue); // genuinely adjacent cells
    },
  );

  test('negative coordinates and a wide scene still find every real pair', () {
    final hash = SpatialHash(cellSize: 10, worldWidth: 100);
    hash.insert(1, -1, -1); // cell (-1, -1)
    hash.insert(2, 1, 1); // cell (0, 0): diagonal neighbour
    hash.insert(3, 5000, 5000);
    hash.insert(4, 5003, 5003);

    final pairs = <Set<int>>[];
    hash.forEachNearbyPair((a, b) => pairs.add({a, b}));

    expect(pairs.any((p) => p.containsAll({1, 2})), isTrue);
    expect(pairs.any((p) => p.containsAll({3, 4})), isTrue);
    expect(pairs.length, 2);
  });
}
