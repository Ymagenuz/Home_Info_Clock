import 'package:flutter_test/flutter_test.dart';
import 'package:home_info_clock/models/manual_location.dart';

void main() {
  test('ManualLocation round trips persisted fields', () {
    const location = ManualLocation(
      label: '中国 上海市 浦东新区',
      latitude: 31.2304,
      longitude: 121.4737,
    );

    final restored = ManualLocation.fromJson(location.toJson());

    expect(restored.label, location.label);
    expect(restored.latitude, location.latitude);
    expect(restored.longitude, location.longitude);
  });
}
