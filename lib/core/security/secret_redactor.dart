class SecretRedactor {
  SecretRedactor._();

  static const String disclaimer = '⚠️ Review output before sharing: Automated redaction is a safety assistant, not an absolute guarantee.';

  static final List<_RedactionRule> _rules = [
    // Private keys
    _RedactionRule(
      RegExp(r'-----BEGIN [A-Z ]+PRIVATE KEY-----[\s\S]*?-----END [A-Z ]+PRIVATE KEY-----', multiLine: true),
      '[REDACTED PRIVATE KEY]',
    ),
    // Passwords in key=value or key: value
    _RedactionRule(
      RegExp(r'''(password|passwd|pwd)\s*[:=]\s*['"]?[^\s'"\n]+['"]?''', caseSensitive: false),
      r'$1=[REDACTED]',
      isReplacerWithGroup: true,
    ),
    // Secrets and API tokens
    _RedactionRule(
      RegExp(r'''(secret|api[_-]?key|access[_-]?token|auth[_-]?token|bearer[_-]?token)\s*[:=]\s*['"]?[^\s'"\n]+['"]?''', caseSensitive: false),
      r'$1=[REDACTED]',
      isReplacerWithGroup: true,
    ),
    // Authorization headers
    _RedactionRule(
      RegExp(r'(authorization\s*:\s*bearer\s+)[^\s\n]+', caseSensitive: false),
      r'$1[REDACTED]',
      isReplacerWithGroup: true,
    ),
    _RedactionRule(
      RegExp(r'(authorization\s*:\s*basic\s+)[^\s\n]+', caseSensitive: false),
      r'$1[REDACTED]',
      isReplacerWithGroup: true,
    ),
    // Database connection strings
    _RedactionRule(
      RegExp(r'(postgres(?:ql)?|mysql|mariadb|mongodb|redis|amqp)://([^:]+):([^@]+)@([^\s/]+)', caseSensitive: false),
      r'$1://$2:[REDACTED]@$4',
      isReplacerWithGroup: true,
    ),
    // Generic URL passwords
    _RedactionRule(
      RegExp(r'(https?://[^:]+:)([^@]+)(@[^\s]+)', caseSensitive: false),
      r'$1[REDACTED]$3',
      isReplacerWithGroup: true,
    ),
    // JWT tokens
    _RedactionRule(
      RegExp(r'eyJ[a-zA-Z0-9_-]{10,}\.eyJ[a-zA-Z0-9_-]{10,}\.[a-zA-Z0-9_-]{10,}'),
      '[REDACTED JWT TOKEN]',
    ),
  ];

  /// Redacts sensitive information from the input text.
  static String redact(String input) {
    if (input.isEmpty) return input;
    String result = input;
    for (final rule in _rules) {
      if (rule.isReplacerWithGroup) {
        result = result.replaceAllMapped(rule.pattern, (match) {
          String replacement = rule.replacement;
          for (int i = 1; i <= match.groupCount; i++) {
            replacement = replacement.replaceAll('\$$i', match.group(i) ?? '');
          }
          return replacement;
        });
      } else {
        result = result.replaceAll(rule.pattern, rule.replacement);
      }
    }
    return result;
  }
}

class _RedactionRule {
  final RegExp pattern;
  final String replacement;
  final bool isReplacerWithGroup;

  const _RedactionRule(this.pattern, this.replacement, {this.isReplacerWithGroup = false});
}
