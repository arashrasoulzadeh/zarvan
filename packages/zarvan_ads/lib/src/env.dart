/// Parses `.env` text: `KEY=value` lines, `#` comments, optional single or double quotes around values.
Map<String, String> parseEnv(String contents) {
  final values = <String, String>{};
  for (final raw in contents.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final eq = line.indexOf('=');
    if (eq <= 0) continue;
    var v = line.substring(eq + 1).trim();
    if (v.length >= 2 &&
        (v.startsWith('"') && v.endsWith('"') ||
            v.startsWith("'") && v.endsWith("'"))) {
      v = v.substring(1, v.length - 1);
    }
    values[line.substring(0, eq).trim()] = v;
  }
  return values;
}
