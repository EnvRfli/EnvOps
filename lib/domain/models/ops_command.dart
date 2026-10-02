import '../../core/security/command_risk_analyzer.dart';

enum CommandCategory {
  system,
  docker,
  nginx,
  custom;

  String get label {
    switch (this) {
      case CommandCategory.system:
        return 'SYSTEM';
      case CommandCategory.docker:
        return 'DOCKER';
      case CommandCategory.nginx:
        return 'NGINX';
      case CommandCategory.custom:
        return 'CUSTOM';
    }
  }
}

class OpsCommand {
  final String id;
  final String name;
  final String description;
  final String command;
  final CommandRisk risk;
  final Duration timeout;
  final CommandCategory category;
  final String? serverId; // null if global, or server id if server-specific

  const OpsCommand({
    required this.id,
    required this.name,
    required this.description,
    required this.command,
    required this.risk,
    this.timeout = const Duration(seconds: 15),
    this.category = CommandCategory.custom,
    this.serverId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'command': command,
        'risk': risk.name,
        'timeoutMs': timeout.inMilliseconds,
        'category': category.name,
        'serverId': serverId,
      };

  factory OpsCommand.fromJson(Map<String, dynamic> json) => OpsCommand(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        command: json['command'] as String,
        risk: CommandRiskAnalyzer.analyze(
          json['command'] as String,
          CommandRisk.values.firstWhere(
            (r) => r.name == json['risk'],
            orElse: () => CommandRisk.readOnly,
          ),
        ),
        timeout: Duration(milliseconds: json['timeoutMs'] as int? ?? 15000),
        category: CommandCategory.values.firstWhere(
          (c) => c.name == json['category'],
          orElse: () => CommandCategory.custom,
        ),
        serverId: json['serverId'] as String?,
      );

  static List<OpsCommand> get defaultBuiltInCommands => [
        // System Commands
        const OpsCommand(
          id: 'sys_uptime',
          name: 'System Uptime & Load',
          description: 'Show how long the system has been running and load averages',
          command: 'uptime',
          risk: CommandRisk.readOnly,
          category: CommandCategory.system,
        ),
        const OpsCommand(
          id: 'sys_free',
          name: 'Memory Usage (free -h)',
          description: 'Display available and used RAM and Swap',
          command: 'free -h',
          risk: CommandRisk.readOnly,
          category: CommandCategory.system,
        ),
        const OpsCommand(
          id: 'sys_df',
          name: 'Disk Space (df -h)',
          description: 'Inspect free and occupied filesystem disk space',
          command: 'df -h',
          risk: CommandRisk.readOnly,
          category: CommandCategory.system,
        ),
        const OpsCommand(
          id: 'sys_df_inodes',
          name: 'Inode Usage (df -i)',
          description: 'Check inode exhaustion on mounted filesystems',
          command: 'df -i',
          risk: CommandRisk.readOnly,
          category: CommandCategory.system,
        ),
        const OpsCommand(
          id: 'sys_top_mem',
          name: 'Top Memory Processes',
          description: 'Top 20 processes sorted by resident memory %',
          command: 'ps aux --sort=-%mem | head -20',
          risk: CommandRisk.readOnly,
          category: CommandCategory.system,
        ),
        const OpsCommand(
          id: 'sys_top_cpu',
          name: 'Top CPU Processes',
          description: 'Top 20 processes sorted by CPU %',
          command: 'ps aux --sort=-%cpu | head -20',
          risk: CommandRisk.readOnly,
          category: CommandCategory.system,
        ),
        const OpsCommand(
          id: 'sys_listening_ports',
          name: 'Open Ports (ss -lntp)',
          description: 'List listening TCP sockets with process names',
          command: 'ss -lntp',
          risk: CommandRisk.readOnly,
          category: CommandCategory.system,
        ),

        // Docker Commands
        const OpsCommand(
          id: 'docker_ps',
          name: 'Docker Containers (docker ps)',
          description: 'List all running Docker containers',
          command: 'docker ps --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Image}}"',
          risk: CommandRisk.readOnly,
          category: CommandCategory.docker,
        ),
        const OpsCommand(
          id: 'docker_ps_all',
          name: 'All Containers (docker ps -a)',
          description: 'List all containers including stopped/exited',
          command: 'docker ps -a --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Image}}"',
          risk: CommandRisk.readOnly,
          category: CommandCategory.docker,
        ),
        const OpsCommand(
          id: 'docker_stats',
          name: 'Docker Stats (no-stream)',
          description: 'Snapshot of container CPU, RAM, Network, and Block I/O usage',
          command: 'docker stats --no-stream',
          risk: CommandRisk.readOnly,
          category: CommandCategory.docker,
        ),
        const OpsCommand(
          id: 'docker_system_df',
          name: 'Docker Disk Usage (system df)',
          description: 'Show space taken by images, containers, volumes, and build cache',
          command: 'docker system df',
          risk: CommandRisk.readOnly,
          category: CommandCategory.docker,
        ),
        const OpsCommand(
          id: 'docker_restarting',
          name: 'Restarting Containers',
          description: 'Filter containers caught in restart loops',
          command: 'docker ps --filter "status=restarting"',
          risk: CommandRisk.readOnly,
          category: CommandCategory.docker,
        ),
        const OpsCommand(
          id: 'docker_unhealthy',
          name: 'Unhealthy Containers',
          description: 'Filter containers failing health checks',
          command: 'docker ps --filter "health=unhealthy"',
          risk: CommandRisk.readOnly,
          category: CommandCategory.docker,
        ),

        // Nginx Commands
        const OpsCommand(
          id: 'nginx_test',
          name: 'Nginx Config Test (nginx -t)',
          description: 'Validate nginx configuration syntax',
          command: r'nginx -t 2>&1 || (docker ps -q -f name=nginx | head -1 | xargs -r docker exec -it $(cat) nginx -t)',
          risk: CommandRisk.readOnly,
          category: CommandCategory.nginx,
        ),
      ];
}
