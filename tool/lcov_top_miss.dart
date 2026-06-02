import 'dart:io';

void main() {
  final file = File('coverage/lcov.info');
  if (!file.existsSync()) {
    stderr.writeln('Missing coverage/lcov.info');
    exit(66);
  }
  String? current;
  final stats = <String, List<int>>{};
  for (final line in file.readAsLinesSync()) {
    if (line.startsWith('SF:')) {
      current = line.substring(3).replaceAll('\\', '/');
      stats.putIfAbsent(current, () => [0, 0]);
    } else if (line.startsWith('DA:') && current != null) {
      final parts = line.substring(3).split(',');
      stats[current]![0]++;
      if ((int.tryParse(parts[1]) ?? 0) > 0) stats[current]![1]++;
    }
  }
  final rows = stats.entries
      .where((e) => e.key.contains('lib') && e.key.endsWith('.dart'))
      .map((e) {
        final total = e.value[0];
        final hit = e.value[1];
        final miss = total - hit;
        final pct = total == 0 ? 100.0 : hit / total * 100;
        return (miss, pct, total, e.key);
      })
      .toList()
    ..sort((a, b) => b.$1.compareTo(a.$1));
  for (final r in rows.take(30)) {
    final name = r.$4.split(RegExp(r'[\\/]')).last;
    stdout.writeln(
      '${r.$1} miss ${r.$2.toStringAsFixed(1)}% (${r.$3} lines) $name',
    );
  }
}
