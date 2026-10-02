import 'dart:convert';

class DockerContainer {
  final String id;
  final String names;
  final String image;
  final String state; // running, restarting, exited, paused, etc.
  final String status; // Up 3 hours, Restarting (1) 2 minutes ago
  final String ports;
  final String created;

  const DockerContainer({
    required this.id,
    required this.names,
    required this.image,
    required this.state,
    required this.status,
    this.ports = '',
    this.created = '',
  });

  bool get isRunning => state.toLowerCase() == 'running';
  bool get isRestarting =>
      state.toLowerCase() == 'restarting' || status.toLowerCase().contains('restarting');
  bool get isUnhealthy => status.toLowerCase().contains('unhealthy');
  bool get isExited => state.toLowerCase() == 'exited';

  /// Primary clean container name (strips leading slash if present)
  String get primaryName {
    final raw = names.split(',').first.trim();
    return raw.startsWith('/') ? raw.substring(1) : raw;
  }

  /// Parses Docker inspect / ps JSON format:
  /// docker ps -a --format '{"ID":"{{.ID}}","Names":"{{.Names}}","Image":"{{.Image}}","State":"{{.State}}","Status":"{{.Status}}","Ports":"{{.Ports}}","CreatedAt":"{{.CreatedAt}}"}'
  static List<DockerContainer> parseJsonLines(String output) {
    final List<DockerContainer> containers = [];
    final lines = const LineSplitter().convert(output);
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      try {
        final Map<String, dynamic> data = jsonDecode(trimmed) as Map<String, dynamic>;
        containers.add(DockerContainer(
          id: data['ID'] as String? ?? '',
          names: data['Names'] as String? ?? '',
          image: data['Image'] as String? ?? '',
          state: data['State'] as String? ?? '',
          status: data['Status'] as String? ?? '',
          ports: data['Ports'] as String? ?? '',
          created: data['CreatedAt'] as String? ?? '',
        ));
      } catch (_) {
        // Fallback or ignore non-JSON line
      }
    }
    return containers;
  }

  /// Parses standard table output if docker json format is unavailable
  static List<DockerContainer> parseTableOutput(String output) {
    final List<DockerContainer> containers = [];
    final lines = const LineSplitter().convert(output);
    if (lines.length <= 1) return containers;

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final parts = line.split(RegExp(r'\s{2,}'));
      if (parts.length >= 3) {
        final id = parts[0];
        final names = parts.length >= 4 ? parts[parts.length - 1] : parts[1];
        final status = parts.length >= 4 ? parts[parts.length - 2] : parts[2];
        final image = parts[1];
        final state = status.toLowerCase().startsWith('up') ? 'running' : 'exited';

        containers.add(DockerContainer(
          id: id,
          names: names,
          image: image,
          state: state,
          status: status,
        ));
      }
    }
    return containers;
  }
}
