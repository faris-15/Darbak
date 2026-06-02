import 'dart:io';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart run tool/lcov_file_miss.dart auth_screens.dart');
    exit(64);
  }
  final needle = args.first.replaceAll('\\', '/');
  final file = File('coverage/lcov.info');
  String? current;
  final missed = <int>[];
  var total = 0;
  for (final line in file.readAsLinesSync()) {
    if (line.startsWith('SF:')) {
      current = line.substring(3).replaceAll('\\', '/');
    } else if (line.startsWith('DA:') && current != null && current.contains(needle)) {
      final parts = line.substring(3).split(',');
      final ln = int.tryParse(parts[0]) ?? 0;
      final hit = int.tryParse(parts[1]) ?? 0;
      total++;
      if (hit == 0) missed.add(ln);
    }
  }
  stdout.writeln('Missed ${missed.length}/$total lines in *$needle*');
  if (missed.isEmpty) return;
  missed.sort();
  var start = missed.first;
  var prev = start;
  for (var i = 1; i < missed.length; i++) {
    final ln = missed[i];
    if (ln == prev + 1) {
      prev = ln;
      continue;
    }
    stdout.writeln(start == prev ? '$start' : '$start-$prev');
    start = ln;
    prev = ln;
  }
  stdout.writeln(start == prev ? '$start' : '$start-$prev');
}
