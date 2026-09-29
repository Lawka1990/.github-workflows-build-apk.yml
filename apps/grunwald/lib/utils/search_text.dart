abstract final class SearchText {
  static String normalize(String value) {
    const replacements = <String, String>{
      'ą': 'a',
      'ć': 'c',
      'ę': 'e',
      'ł': 'l',
      'ń': 'n',
      'ó': 'o',
      'ś': 's',
      'ź': 'z',
      'ż': 'z',
    };
    var normalized = value.toLowerCase().trim();
    for (final replacement in replacements.entries) {
      normalized = normalized.replaceAll(replacement.key, replacement.value);
    }
    return normalized.replaceAll(RegExp(r'\s+'), ' ');
  }
}
