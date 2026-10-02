class ServerHealth {
  final String hostname;
  final String uptime;
  final String loadAvg;
  final String memorySummary;
  final String memoryUsed;
  final String memoryTotal;
  final String memoryAvailable;
  final String diskSummary;
  final String diskUsedPercent;
  final int dockerRunning;
  final int dockerRestarting;
  final int dockerUnhealthy;
  final int dockerTotal;
  final bool dockerAvailable;
  final DateTime checkedAt;

  const ServerHealth({
    this.hostname = '',
    this.uptime = '',
    this.loadAvg = '',
    this.memorySummary = '',
    this.memoryUsed = '',
    this.memoryTotal = '',
    this.memoryAvailable = '',
    this.diskSummary = '',
    this.diskUsedPercent = '',
    this.dockerRunning = 0,
    this.dockerRestarting = 0,
    this.dockerUnhealthy = 0,
    this.dockerTotal = 0,
    this.dockerAvailable = true,
    required this.checkedAt,
  });

  factory ServerHealth.empty() => ServerHealth(checkedAt: DateTime.now());
}
