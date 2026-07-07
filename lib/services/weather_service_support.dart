Map<String, dynamic> asMap(Object? value, String field) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, mapValue) => MapEntry(key.toString(), mapValue));
  }
  throw FormatException('Expected object for $field');
}

List<dynamic> asList(Object? value, String field) {
  if (value is List<dynamic>) {
    return value;
  }
  if (value is List) {
    return value.cast<dynamic>();
  }
  throw FormatException('Expected list for $field');
}

int roundNum(Object? value, [int fallback = 0]) {
  if (value is num) {
    return value.round();
  }
  if (value is String && value.trim().isNotEmpty) {
    return num.parse(value.trim()).round();
  }
  return fallback;
}

int intValue(Object? value, [int fallback = 0]) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  if (value is String && value.trim().isNotEmpty) {
    return num.parse(value.trim()).round();
  }
  return fallback;
}

num numValue(Object? value, [num fallback = 0]) {
  if (value is num) {
    return value;
  }
  if (value is String && value.trim().isNotEmpty) {
    return num.parse(value.trim());
  }
  return fallback;
}

String stringValue(Object? value, [String fallback = '']) {
  if (value == null) {
    return fallback;
  }
  final result = value.toString().trim();
  return result.isEmpty ? fallback : result;
}

String? firstNonEmpty(Iterable<String?> values) {
  for (final value in values) {
    if (value != null) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
  }
  return null;
}

String formatHm(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String weatherDescription(int code) {
  if (code == 0) return '\u6674';
  if (code == 1 || code == 2) return '\u591a\u4e91';
  if (code == 3) return '\u9634';
  if (code == 45 || code == 48) return '\u96fe';
  if (code == 451) return '\u973e';
  if (code >= 51 && code <= 57) return '\u6bdb\u6bdb\u96e8';
  if (code >= 61 && code <= 67) return '\u96e8';
  if (code >= 71 && code <= 77) return '\u96ea';
  if (code >= 80 && code <= 82) return '\u9635\u96e8';
  if (code >= 85 && code <= 86) return '\u9635\u96ea';
  if (code >= 95) return '\u96f7\u96e8';
  return '\u5929\u6c14';
}

String weatherIcon(int code) {
  if (code == 0) return '\u2600';
  if (code == 1 || code == 2) return '\u25d0';
  if (code == 3) return '\u2601';
  if (code == 45 || code == 48) return '\u2261';
  if (code == 451) return '\u2261';
  if (code >= 51 && code <= 67) return '\u2614';
  if (code >= 71 && code <= 77) return '\u2744';
  if (code >= 80 && code <= 82) return '\u2614';
  if (code >= 95) return '\u26a1';
  return '\u2022';
}
