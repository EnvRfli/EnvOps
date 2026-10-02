class ShellEscaper {
  ShellEscaper._();

  static final RegExp _safeContainerNameRegex = RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9_.-]{0,127}$');
  static final RegExp _safeServiceNameRegex = RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9_.-]{0,127}$');

  /// Validates whether a container name conforms to Docker's standard naming pattern.
  static bool isValidContainerName(String name) {
    return _safeContainerNameRegex.hasMatch(name.trim());
  }

  /// Validates whether a service name conforms to standard systemd / service naming patterns.
  static bool isValidServiceName(String name) {
    return _safeServiceNameRegex.hasMatch(name.trim());
  }

  /// Escapes a string to be safely passed as a single bash/sh argument.
  /// Encloses in single quotes and escapes any embedded single quotes.
  static String escapeArg(String arg) {
    if (arg.isEmpty) return "''";
    // Replace single quote ' with '\''
    return "'${arg.replaceAll("'", "'\\''")}'";
  }

  /// Safely sanitizes a container name or throws an ArgumentError if invalid.
  static String sanitizeContainerName(String raw) {
    final clean = raw.trim();
    if (!isValidContainerName(clean)) {
      throw ArgumentError('Invalid container name "$raw". Must contain only alphanumeric, ., -, or _ characters.');
    }
    return clean;
  }
}
