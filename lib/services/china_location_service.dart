import '../models/manual_location.dart';
import 'http_json_client.dart';

class ChinaLocationService {
  const ChinaLocationService({required this.client});

  final JsonHttpClient client;

  Future<ManualLocation> resolve(String label) async {
    final value = label.trim();
    final parts = value
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    if (parts.isEmpty) {
      throw const FormatException('China location is empty');
    }

    final province = parts.first;
    final city = parts.length >= 3 ? parts[parts.length - 2] : province;
    final district = parts.last;
    final countryCode = _countryCodeFor(province);
    final searches = <({String name, bool requireCity})>[
      (name: _searchName(district), requireCity: true),
      (name: _searchName(city), requireCity: false),
      (name: _searchName(province), requireCity: false),
    ];
    final attempted = <String>{};

    for (final search in searches) {
      if (search.name.length < 2 || !attempted.add(search.name)) {
        continue;
      }
      final root = await client.getJson(
        Uri.https(
          'geocoding-api.open-meteo.com',
          '/v1/search',
          <String, String>{
            'name': search.name,
            'count': '20',
            'language': 'zh',
            'format': 'json',
            'countryCode': countryCode,
          },
        ),
      );
      final match = _bestMatch(
        root['results'],
        countryCode: countryCode,
        province: province,
        city: city,
        district: district,
        query: search.name,
        requireCity: search.requireCity,
      );
      if (match != null) {
        return ManualLocation(
          label: value,
          latitude: _coordinate(match['latitude'])!,
          longitude: _coordinate(match['longitude'])!,
        );
      }
    }

    throw const FormatException('China location could not be resolved');
  }

  Map<String, dynamic>? _bestMatch(
    Object? rawResults, {
    required String countryCode,
    required String province,
    required String city,
    required String district,
    required String query,
    required bool requireCity,
  }) {
    if (rawResults is! List<dynamic>) {
      return null;
    }
    Map<String, dynamic>? best;
    var bestScore = -1;
    for (final raw in rawResults) {
      if (raw is! Map<String, dynamic>) {
        continue;
      }
      final latitude = _coordinate(raw['latitude']);
      final longitude = _coordinate(raw['longitude']);
      final resultCountry = raw['country_code']?.toString().toUpperCase();
      if (latitude == null ||
          longitude == null ||
          latitude < -90 ||
          latitude > 90 ||
          longitude < -180 ||
          longitude > 180 ||
          (resultCountry != null && resultCountry != countryCode)) {
        continue;
      }
      final provinceMatches = _matchesArea(raw, province);
      final cityMatches = _matchesArea(raw, city);
      if (!provinceMatches || (requireCity && !cityMatches)) {
        continue;
      }
      final score =
          (_matchesArea(raw, query) ? 100 : 0) +
          (provinceMatches ? 30 : 0) +
          (cityMatches ? 20 : 0) +
          (_matchesArea(raw, district) ? 10 : 0);
      if (score > bestScore) {
        best = raw;
        bestScore = score;
      }
    }
    return best;
  }

  bool _matchesArea(Map<String, dynamic> result, String area) {
    final expected = _normalizeAreaName(area);
    if (expected.isEmpty) {
      return false;
    }
    for (final key in const <String>[
      'name',
      'admin1',
      'admin2',
      'admin3',
      'admin4',
      'country',
    ]) {
      if (_normalizeAreaName(result[key]?.toString() ?? '') == expected) {
        return true;
      }
    }
    return false;
  }

  String _searchName(String value) {
    final normalized = _normalizeAreaName(value);
    return normalized.length >= 2 ? normalized : value.trim();
  }

  String _normalizeAreaName(String value) {
    var normalized = value.trim().replaceAll('臺', '台');
    for (final suffix in const <String>[
      '维吾尔自治区',
      '壮族自治区',
      '回族自治区',
      '特别行政区',
      '自治区',
      '自治州',
      '自治县',
      '自治旗',
      '地区',
      '林区',
      '矿区',
      '新区',
      '省',
      '市',
      '区',
      '县',
      '盟',
      '旗',
      '州',
      '乡',
      '镇',
    ]) {
      if (normalized.endsWith(suffix) &&
          normalized.length - suffix.length >= 2) {
        normalized = normalized.substring(0, normalized.length - suffix.length);
        break;
      }
    }
    return normalized;
  }

  String _countryCodeFor(String province) {
    if (province.contains('香港')) return 'HK';
    if (province.contains('澳门')) return 'MO';
    if (province.contains('台湾') || province.contains('臺灣')) return 'TW';
    return 'CN';
  }

  double? _coordinate(Object? value) {
    return switch (value) {
      num number => number.toDouble(),
      String text => double.tryParse(text.trim()),
      _ => null,
    };
  }
}
