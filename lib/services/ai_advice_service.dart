import 'dart:convert';

import '../models/app_config.dart';
import '../models/weather.dart';
import 'http_json_client.dart';
import 'weather_service_support.dart';

class AiAdviceService {
  const AiAdviceService({required this.client, required this.config});

  final JsonHttpClient client;
  final AppConfig config;

  Uri get chatUri {
    var baseUrl = config.gptsApiBaseUrl.trim();
    while (baseUrl.endsWith('/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    }
    return Uri.parse('$baseUrl/chat/completions');
  }

  static String? cleanAdvice(String? value) {
    final cleaned = value?.trim().replaceAll('\n', ' ').replaceAll('\r', ' ');
    if (cleaned == null || cleaned.isEmpty) {
      return null;
    }
    final compact = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    final withoutPeriod = compact.replaceAll('\u3002', '');
    final capped = withoutPeriod.length > 24
        ? withoutPeriod.substring(0, 24)
        : withoutPeriod;
    return capped.isEmpty ? null : '$capped\u3002';
  }

  Future<WeatherSnapshot> applyAdvice(WeatherSnapshot snapshot) async {
    if (!config.hasGptsApiKey || snapshot.tomorrow == null) {
      return snapshot;
    }

    final tomorrow = snapshot.tomorrow!;
    final weather = <String, Object?>{
      'location': snapshot.locationLabel,
      'date': tomorrow.date,
      'condition': tomorrow.description,
      'high_celsius': tomorrow.high,
      'low_celsius': tomorrow.low,
      'precipitation_probability_percent': tomorrow.precipitation,
      'uv_index': tomorrow.uv,
      'wind_kmh': tomorrow.windKmh,
      'wind_direction': tomorrow.windDirection ?? '',
    };

    try {
      final response = await client.postJson(
        chatUri,
        <String, Object?>{
          'model': config.gptsApiModel,
          'messages': [
            {
              'role': 'system',
              'content':
                  '\u4f60\u662f\u5bb6\u5ead\u4fe1\u606f\u5c4f\u7684\u5929\u6c14\u751f\u6d3b\u5efa\u8bae\u52a9\u624b\u3002\u53ea\u8f93\u51fa\u4e25\u683c JSON\uff0c\u4e0d\u8981 Markdown\u3002\u5b57\u6bb5\u5fc5\u987b\u662f clothing\u3001umbrella\u3001travel\u3002\u6bcf\u6761\u6700\u591a 8 \u4e2a\u6c49\u5b57\uff0c\u53ea\u5199\u4e00\u53e5\u5177\u4f53\u5efa\u8bae\uff0c\u4e0d\u8981\u89e3\u91ca\u3002',
            },
            {
              'role': 'user',
              'content':
                  '\u8bf7\u57fa\u4e8e\u660e\u65e5\u5929\u6c14\u7ed9\u51fa\u7a7f\u8863\u3001\u5e26\u4f1e\u3001\u51fa\u884c\u4e09\u6761\u5efa\u8bae\u3002\u5929\u6c14\u6570\u636e\uff1a${jsonEncode(weather)}',
            },
          ],
          'max_tokens': 120,
        },
        headers: {'Authorization': 'Bearer ${config.gptsApiKey.trim()}'},
      );

      final choices = response['choices'] as List<dynamic>? ?? const [];
      if (choices.isEmpty) {
        return snapshot;
      }

      final message = asMap(
        asMap(choices.first, 'choice')['message'],
        'message',
      );
      final content = stringValue(message['content']);
      final advice = asMap(jsonDecode(_extractJsonObject(content)), 'advice');

      final clothing = cleanAdvice(advice['clothing'] as String?);
      final umbrella = cleanAdvice(advice['umbrella'] as String?);
      final travel = cleanAdvice(advice['travel'] as String?);
      var updatedTomorrow = tomorrow;
      var applied = false;

      if (clothing != null) {
        updatedTomorrow = updatedTomorrow.copyWith(clothingTip: clothing);
        applied = true;
      }
      if (umbrella != null) {
        updatedTomorrow = updatedTomorrow.copyWith(umbrellaTip: umbrella);
        applied = true;
      }
      if (travel != null) {
        updatedTomorrow = updatedTomorrow.copyWith(travelTip: travel);
        applied = true;
      }

      if (!applied) {
        return snapshot;
      }

      final days = [...snapshot.days];
      days[1] = updatedTomorrow;
      return snapshot.copyWith(
        days: days,
        sourceLabel: _appendSource(snapshot.sourceLabel, 'AI\u5efa\u8bae'),
      );
    } catch (_) {
      return snapshot;
    }
  }

  static String _extractJsonObject(String content) {
    final value = content.trim();
    final start = value.indexOf('{');
    final end = value.lastIndexOf('}');
    if (start >= 0 && end > start) {
      return value.substring(start, end + 1);
    }
    return value;
  }

  static String _appendSource(String current, String addition) {
    if (current.trim().isEmpty) return addition;
    if (current.contains(addition)) return current;
    return '$current+$addition';
  }
}
