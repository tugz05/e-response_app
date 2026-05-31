/// Parses [GoogleSignInAccount.displayName] (unstructured) into parts used by
/// NEMSU registration (first / middle / last / suffix). Google does not always
/// provide separate fields; this is a best-effort split for prepopulation only.
class GoogleParsedName {
  const GoogleParsedName({
    this.firstName = '',
    this.middleName = '',
    this.lastName = '',
    this.suffix = '',
  });

  final String firstName;
  final String middleName;
  final String lastName;

  /// Normalized suffix token (e.g. `Jr`, `III`) or empty.
  final String suffix;

  static const Set<String> _suffixTokens = {
    'jr',
    'jr.',
    'sr',
    'sr.',
    'ii',
    'iii',
    'iv',
  };

  static GoogleParsedName fromDisplayName(String? raw) {
    final trimmed = (raw ?? '').trim();
    if (trimmed.isEmpty) {
      return const GoogleParsedName();
    }

    var parts =
        trimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) {
      return const GoogleParsedName();
    }

    var suffix = '';
    final lastNorm = parts.last.toLowerCase().replaceAll('.', '');
    if (_suffixTokens.contains(parts.last.toLowerCase()) ||
        _suffixTokens.contains(lastNorm)) {
      suffix = _normalizeSuffix(parts.removeLast());
    }

    if (parts.isEmpty) {
      return GoogleParsedName(suffix: suffix);
    }
    if (parts.length == 1) {
      return GoogleParsedName(firstName: parts.single, suffix: suffix);
    }

    final first = parts.first;
    final last = parts.last;
    final middle =
        parts.length > 2 ? parts.sublist(1, parts.length - 1).join(' ') : '';

    return GoogleParsedName(
      firstName: first,
      middleName: middle,
      lastName: last,
      suffix: suffix,
    );
  }

  static String _normalizeSuffix(String s) {
    final lower = s.toLowerCase().replaceAll('.', '');
    switch (lower) {
      case 'jr':
        return 'Jr';
      case 'sr':
        return 'Sr';
      case 'ii':
        return 'II';
      case 'iii':
        return 'III';
      case 'iv':
        return 'IV';
      default:
        return s;
    }
  }

  /// Full display line for [name] preference when API does not provide one.
  static String composeFullName(
    String first,
    String middle,
    String last,
    String suffix,
  ) {
    final buf = StringBuffer();
    if (first.isNotEmpty) {
      buf.write(first);
    }
    if (middle.isNotEmpty) {
      if (buf.isNotEmpty) {
        buf.write(' ');
      }
      buf.write(middle);
    }
    if (last.isNotEmpty) {
      if (buf.isNotEmpty) {
        buf.write(' ');
      }
      buf.write(last);
    }
    if (suffix.isNotEmpty) {
      if (buf.isNotEmpty) {
        buf.write(' ');
      }
      buf.write(suffix);
    }
    return buf.toString().trim();
  }
}
