// Static per-shader cost report: `dart run tool/shader_cost.dart`.
//
// A GPU cannot be timed from Dart (and `flutter test` cannot run fragment
// shaders), so this ranks shaders by what dominates their per-pixel cost —
// transcendental calls and texture reads, weighted by the loops around them —
// to say which ones are worth profiling on a device first.
import 'dart:io';

/// What [analyzeShader] found in one fragment shader.
class ShaderCost {
  ShaderCost({
    required this.lines,
    required this.loops,
    required this.maxLoopDepth,
    required this.worstCaseIterations,
    required this.transcendentals,
    required this.weightedTranscendentals,
    required this.textureReads,
    required this.weightedTextureReads,
    required this.hasMediump,
  });

  final int lines;
  final int loops;
  final int maxLoopDepth;

  /// Largest product of nested loop trip counts.
  final int worstCaseIterations;

  /// Calls to sin/cos/pow/exp/log/atan/sqrt etc. written in the source.
  final int transcendentals;

  /// The same calls, each multiplied by its enclosing loops' trip counts —
  /// the number a pixel actually pays when no branch skips the work.
  final int weightedTranscendentals;
  final int textureReads;
  final int weightedTextureReads;
  final bool hasMediump;

  /// One sortable number: a texture read costs about four transcendentals.
  int get score => weightedTranscendentals + 4 * weightedTextureReads;
}

final _loop = RegExp(
  r'for\s*\(\s*int\s+\w+\s*=\s*(-?\d+)\s*;\s*\w+\s*(<=|<)\s*(-?\d+)\s*;',
);
final _trans = RegExp(
  r'\b(sin|cos|tan|atan|asin|acos|pow|exp|exp2|log|log2|sqrt|inversesqrt)\s*\(',
);

/// Estimates the cost of [source] (comments are ignored).
ShaderCost analyzeShader(String source) {
  final code = source.replaceAll(RegExp(r'//.*'), '');
  final lines = code.split('\n');
  // Each open brace remembers the trip count of the loop it belongs to (1 for
  // plain blocks), so a call's multiplier is the product over the stack.
  final stack = <int>[];
  var pending = 1;
  var loops = 0, maxDepth = 0, worst = 1;
  var depth = 0;
  var trans = 0, wTrans = 0, tex = 0, wTex = 0;
  for (final line in lines) {
    final m = _loop.firstMatch(line);
    if (m != null) {
      final a = int.parse(m.group(1)!), b = int.parse(m.group(3)!);
      pending = (m.group(2) == '<=' ? b - a + 1 : b - a).clamp(1, 1 << 20);
      loops++;
    }
    var mult = 1;
    for (final s in stack) {
      mult *= s;
    }
    if (m != null) mult *= pending;
    final t = _trans.allMatches(line).length;
    final x = line.contains('texture(') || line.contains('texture2D(') ? 1 : 0;
    trans += t;
    wTrans += t * mult;
    tex += x;
    wTex += x * mult;
    for (final ch in line.split('')) {
      if (ch == '{') {
        stack.add(m != null ? pending : 1);
        pending = 1;
        if (m != null) {
          depth++;
          if (depth > maxDepth) maxDepth = depth;
        }
      } else if (ch == '}') {
        if (stack.isNotEmpty) {
          final s = stack.removeLast();
          if (s > 1) depth--;
        }
      }
    }
    var cur = 1;
    for (final s in stack) {
      cur *= s;
    }
    if (cur > worst) worst = cur;
  }
  return ShaderCost(
    lines: lines.length,
    loops: loops,
    maxLoopDepth: maxDepth,
    worstCaseIterations: worst,
    transcendentals: trans,
    weightedTranscendentals: wTrans,
    textureReads: tex,
    weightedTextureReads: wTex,
    hasMediump: source.contains('mediump'),
  );
}

void main(List<String> args) {
  final dir = Directory(args.isEmpty ? 'shaders' : args.first);
  final rows = <(String, ShaderCost)>[
    for (final f in dir.listSync().whereType<File>())
      if (f.path.endsWith('.frag'))
        (f.uri.pathSegments.last, analyzeShader(f.readAsStringSync())),
  ]..sort((a, b) => b.$2.score.compareTo(a.$2.score));
  stdout.writeln(
    'shader                          score  lines loops depth worst  trans(w)  tex(w)',
  );
  for (final (name, c) in rows) {
    stdout.writeln(
      '${name.padRight(30)} ${'${c.score}'.padLeft(6)} ${'${c.lines}'.padLeft(6)} '
      '${'${c.loops}'.padLeft(5)} ${'${c.maxLoopDepth}'.padLeft(5)} '
      '${'${c.worstCaseIterations}'.padLeft(5)} '
      '${'${c.transcendentals}/${c.weightedTranscendentals}'.padLeft(9)} '
      '${'${c.textureReads}/${c.weightedTextureReads}'.padLeft(7)}',
    );
  }
}
