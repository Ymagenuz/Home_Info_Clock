import 'package:flutter_test/flutter_test.dart';
import 'package:home_info_clock/services/china_region_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'ChinaRegionRepository loads 34 offline province-level divisions',
    () async {
      final regions = await const ChinaRegionRepository().load();

      expect(regions, hasLength(34));
      expect(
        regions.map((region) => region.name),
        containsAll(<String>['台湾省', '澳门', '香港']),
      );
      expect(
        regions.every(
          (province) =>
              province.children.isNotEmpty &&
              province.children.every((city) => city.children.isNotEmpty),
        ),
        isTrue,
      );
    },
  );
}
