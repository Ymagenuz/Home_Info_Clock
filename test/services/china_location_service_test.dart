import 'package:flutter_test/flutter_test.dart';
import 'package:home_info_clock/services/china_location_service.dart';
import 'package:home_info_clock/services/http_json_client.dart';

class _FakeJsonHttpClient extends JsonHttpClient {
  _FakeJsonHttpClient(this.onGet);

  final Future<Map<String, dynamic>> Function(Uri uri) onGet;

  @override
  Future<Map<String, dynamic>> getJson(
    Uri uri, {
    Map<String, String> headers = const {},
  }) {
    return onGet(uri);
  }
}

void main() {
  test(
    'resolves and disambiguates a selected China district without a key',
    () async {
      Uri? requestedUri;
      final service = ChinaLocationService(
        client: _FakeJsonHttpClient((uri) async {
          requestedUri = uri;
          return <String, dynamic>{
            'results': [
              {
                'name': '南山',
                'latitude': 28.80344,
                'longitude': 118.08541,
                'country_code': 'CN',
                'admin1': '江西',
                'admin2': '上饶市',
              },
              {
                'name': '南山',
                'latitude': 22.538,
                'longitude': 113.93889,
                'country_code': 'CN',
                'admin1': '广东',
                'admin2': '深圳',
              },
            ],
          };
        }),
      );

      final location = await service.resolve('广东省 深圳市 南山区');

      expect(requestedUri?.host, 'geocoding-api.open-meteo.com');
      expect(requestedUri?.queryParameters['name'], '南山');
      expect(requestedUri?.queryParameters['countryCode'], 'CN');
      expect(requestedUri?.queryParameters['language'], 'zh');
      expect(location.label, '广东省 深圳市 南山区');
      expect(location.latitude, 22.538);
      expect(location.longitude, 113.93889);
    },
  );

  test(
    'falls back to the selected city when a district has no match',
    () async {
      final queries = <String>[];
      final service = ChinaLocationService(
        client: _FakeJsonHttpClient((uri) async {
          final query = uri.queryParameters['name']!;
          queries.add(query);
          if (query == '深圳') {
            return <String, dynamic>{
              'results': [
                {
                  'name': '深圳',
                  'latitude': 22.54554,
                  'longitude': 114.0683,
                  'country_code': 'CN',
                  'admin1': '广东',
                  'admin2': '深圳',
                },
              ],
            };
          }
          return <String, dynamic>{'results': <dynamic>[]};
        }),
      );

      final location = await service.resolve('广东省 深圳市 不存在区');

      expect(queries, ['不存在', '深圳']);
      expect(location.label, '广东省 深圳市 不存在区');
      expect(location.latitude, 22.54554);
      expect(location.longitude, 114.0683);
    },
  );
}
