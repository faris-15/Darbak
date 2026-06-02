import 'dart:io';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart run tool/check_lcov_min.dart coverage/lcov.info --min=90');
    exit(64);
  }

  final path = args.first;
  final minArg = args.firstWhere(
    (arg) => arg.startsWith('--min='),
    orElse: () => '--min=90',
  );
  final min = double.tryParse(minArg.substring('--min='.length));
  if (min == null || min < 0 || min > 100) {
    stderr.writeln('Invalid coverage minimum: $minArg');
    exit(64);
  }

  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('Coverage file not found: $path');
    exit(66);
  }

  var found = 0;
  var hit = 0;
  for (final line in file.readAsLinesSync()) {
    if (!line.startsWith('DA:')) continue;
    final parts = line.substring(3).split(',');
    if (parts.length != 2) continue;
    found += 1;
    final count = int.tryParse(parts[1]) ?? 0;
    if (count > 0) hit += 1;
  }

  final percent = found == 0 ? 0.0 : (hit / found) * 100;
  stdout.writeln(
    'Flutter line coverage: ${percent.toStringAsFixed(2)}% '
    '($hit/$found lines, minimum ${min.toStringAsFixed(2)}%)',
  );

  if (percent < min) {
    stderr.writeln('Coverage threshold failed.');
    exit(1);
  }
}
