import 'dart:convert';

import '../models/app_config.dart';
import '../models/manual_location.dart';
import 'http_json_client.dart';
import 'weather_service_support.dart';

class AiLocationService {
  const AiLocationService({required this.client, required this.config});

  final JsonHttpClient client;
  final AppConfig config;

  Uri get chatUri {
    var baseUrl = config.gptsApiBaseUrl.trim();
    while (baseUrl.endsWith('/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    }
    return Uri.parse('$baseUrl/chat/completions');
  }

  Future<ManualLocation> resolve(String text) async {
    final input = text.trim();
    if (input.isEmpty) {
      throw const FormatException('Location text is empty');
    }
    if (!config.hasGptsApiKey) {
      throw StateError('AI location parsing is not configured');
    }
    final response = await client.postJson(
      chatUri,
      <String, Object?>{
        'model': config.gptsApiModel,
        'messages': [
          {
            'role': 'system',
            'content':
                '你是地理位置解析器。只输出严格 JSON，不要 Markdown。'
                '必须包含 label、latitude、longitude三个字段。'
                'label 使用简洁、可识别的中文或当地地名；'
                '纬度范围 -90 到 90，经度范围 -180 到 180。',
          },
          {'role': 'user', 'content': '请解析这个地点：$input'},
        ],
        'max_tokens': 120,
      },
      headers: {'Authorization': 'Bearer ${config.gptsApiKey.trim()}'},
    );
    final choices = response['choices'] as List<dynamic>? ?? const [];
    if (choices.isEmpty) {
      throw const FormatException('Location response has no choices');
    }
    final message = asMap(asMap(choices.first, 'choice')['message'], 'message');
    final content = stringValue(message['content']);
    final decoded = asMap(jsonDecode(_extractJsonObject(content)), 'location');
    final label = stringValue(decoded['label']);
    final latitude = _doubleValue(decoded['latitude'], 'latitude');
    final longitude = _doubleValue(decoded['longitude'], 'longitude');
    if (label.isEmpty || latitude < -90 || latitude > 90) {
      throw const FormatException('Invalid location response');
    }
    if (longitude < -180 || longitude > 180) {
      throw const FormatException('Invalid location response');
    }
    return ManualLocation(
      label: label,
      latitude: latitude,
      longitude: longitude,
    );
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

  static double _doubleValue(Object? value, String field) {
    final parsed = switch (value) {
      num number => number.toDouble(),
      String text => double.tryParse(text.trim()),
      _ => null,
    };
    if (parsed == null || !parsed.isFinite) {
      throw FormatException('Invalid $field');
    }
    return parsed;
  }
}
