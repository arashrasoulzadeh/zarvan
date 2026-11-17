import 'dart:convert';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:zarvan_cli/src/ops_cli.dart';
import 'package:zarvan_core/zarvan_core_ops.dart';
import 'package:zarvan_core/zarvan_core_quiz.dart';
import 'package:test/test.dart';

String word(int n) {
  const letters = 'ابتثجحخدذرزسشصضطظعغفقکگلمنهی';
  final b = letters.length;
  return letters[n % b] + letters[(n ~/ b) % b] + letters[(n ~/ (b * b)) % b];
}

Map<String, dynamic> bank({bool duplicate = false}) {
  var w = 0;
  final items = [
    for (var i = 0; i < 6; i++)
      {
        'id': duplicate && i == 1 ? 'i0' : 'i$i',
        'author': 'a',
        'tier': 'easy',
        'fame': 10 - i,
        'lines': ['${word(w++)} ${word(w++)}', '${word(w++)} ${word(w++)}'],
      },
  ];
  return {
    'version': 1,
    'authors': [
      {'id': 'a', 'name': 'A'},
    ],
    'items': items,
  };
}

void main() {
  late Directory project;
  setUp(() {
    project = Directory.systemTemp.createTempSync('quiz_cli');
    File(
      '${project.path}/pubspec.yaml',
    ).writeAsStringSync('name: demo\nversion: 1.0.0\n');
    Directory('${project.path}/assets/levels').createSync(recursive: true);
    Directory('${project.path}/assets/quiz').createSync(recursive: true);
  });
  tearDown(() => project.deleteSync(recursive: true));

  void put(String name, Object json) => File(
    '${project.path}/assets/quiz/$name',
  ).writeAsStringSync(jsonEncode(json));

  Future<(int, Map<String, dynamic>?)> run(List<String> args) async {
    final out = StringBuffer(), err = StringBuffer();
    final runner = CommandRunner<int>('zarvan', 'test');
    addOperationCommands(
      runner,
      buildRegistry(),
      io: CliIo(out: out, err: err, stdinStream: const Stream.empty()),
    );
    final code = await runner.run(['--project', project.path, ...args]) ?? 0;
    final text = out.toString();
    return (
      code,
      text.trim().startsWith('{')
          ? jsonDecode(text) as Map<String, dynamic>
          : null,
    );
  }

  test(
    'quiz validate-bank exits 0 for a sound bank and 1 with errors',
    () async {
      put('bank.json', bank());
      put('stopwords.json', {
        'version': 1,
        'words': ['از'],
      });
      final good = await run([
        'quiz',
        'validate-bank',
        '--bank',
        'assets/quiz/bank.json',
        '--stopwords',
        'assets/quiz/stopwords.json',
        '--json',
      ]);
      expect(good.$1, 0);
      expect(good.$2!['data']['ok'], isTrue);

      put('bad.json', bank(duplicate: true));
      final bad = await run([
        'quiz',
        'validate-bank',
        '--bank',
        'assets/quiz/bad.json',
        '--json',
      ]);
      expect(bad.$1, 1);
      expect(
        (bad.$2!['data']['errors'] as List).join(),
        contains('duplicate id'),
      );
    },
  );

  test('quiz generate prints the same question the factory makes', () async {
    put('bank.json', bank());
    final r = await run([
      'quiz',
      'generate',
      '--bank',
      'assets/quiz/bank.json',
      '--item-id',
      'i2',
      '--tier',
      'easy',
      '--seed',
      '42',
      '--json',
    ]);
    expect(r.$1, 0);
    final direct = QuestionFactory(
      QuizBank.fromJson(bank()),
      const {},
    ).create('i2', QuizTier.easy, 42)!;
    expect(jsonEncode(r.$2!['data']), jsonEncode(direct.toJson()));
    final missing = await run([
      'quiz',
      'generate',
      '--bank',
      'assets/quiz/bank.json',
      '--item-id',
      'nope',
      '--json',
    ]);
    expect(missing.$1, ErrorCode.notFound.exit);
  });

  test('quiz simulate runs from the command line', () async {
    put('bank.json', bank());
    final r = await run([
      'quiz',
      'simulate',
      '--bank',
      'assets/quiz/bank.json',
      '--mode',
      'stage',
      '--policy',
      'always_correct',
      '--runs',
      '3',
      '--json',
    ]);
    expect(r.$1, 0);
    expect(r.$2!['data']['correctRate'], 1.0);
  });
}
