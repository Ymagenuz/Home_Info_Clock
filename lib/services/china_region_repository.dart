import 'package:city_picker_china/city_picker_china.dart';

import '../models/china_region.dart';

class ChinaRegionRepository {
  const ChinaRegionRepository();

  Future<List<ChinaRegion>> load() async {
    final nodes = await CityPicker.loadCityNodes();
    return nodes.map(_fromNode).toList(growable: false);
  }

  ChinaRegion _fromNode(CityNode node) {
    return ChinaRegion(
      name: node.name,
      code: node.code,
      children:
          node.children?.map(_fromNode).toList(growable: false) ??
          const <ChinaRegion>[],
    );
  }
}
