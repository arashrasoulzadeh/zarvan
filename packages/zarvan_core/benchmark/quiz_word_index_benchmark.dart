import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:zarvan_core/zarvan_core_quiz.dart';

/// `WordIndex.build` walks every line of the bank once, so its cost grows
/// with bank size; a game builds it at load, not per question. 1000 items
/// of two lines of five words is the size of Shaer's bank.
class WordIndexBuildBenchmark extends BenchmarkBase {
  WordIndexBuildBenchmark(this.itemCount)
    : super('WordIndex.build(n=$itemCount)');

  final int itemCount;
  late QuizBank bank;

  @override
  void setup() {
    bank = QuizBank(
      authors: const [QuizAuthor(id: 'a', name: 'A')],
      items: [
        for (var i = 0; i < itemCount; i++)
          QuizItem(
            id: 'i$i',
            author: 'a',
            lines: [
              for (var l = 0; l < 2; l++)
                [
                  for (var w = 0; w < 5; w++)
                    'کلمه${(i * 7 + l * 3 + w) % 1500}',
                ].join(' '),
            ],
          ),
      ],
    );
  }

  // One run() per measurement, so the reported RunTime is per call, not
  // per the harness default of ten.
  @override
  void exercise() => run();

  @override
  void run() => WordIndex.build(bank, const {'و', 'از'});
}

void main() {
  WordIndexBuildBenchmark(1000).report();
}
