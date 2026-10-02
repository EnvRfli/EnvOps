class CommandResult {
  final String stdout;
  final String stderr;
  final int exitCode;
  final DateTime startedAt;
  final DateTime finishedAt;
  final Duration duration;

  const CommandResult({
    required this.stdout,
    required this.stderr,
    required this.exitCode,
    required this.startedAt,
    required this.finishedAt,
    required this.duration,
  });

  bool get isSuccess => exitCode == 0;

  String get outputCombined {
    if (stderr.isEmpty) return stdout;
    if (stdout.isEmpty) return stderr;
    return '$stdout\n$stderr';
  }
}
