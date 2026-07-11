import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_info_clock/models/china_region.dart';
import 'package:home_info_clock/models/manual_location.dart';
import 'package:home_info_clock/widgets/manual_location_dialog.dart';

void main() {
  testWidgets(
    'manual location dialog shows three China wheels and global input',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(700, 360));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: ManualLocationDialog(
            loadRegions: _loadRegions,
            resolveChinaLocation: _resolveChinaLocation,
            resolveLocation: (_) async => const ManualLocation(
              label: '新加坡',
              latitude: 1.3521,
              longitude: 103.8198,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);
      expect(
        find.byKey(const ValueKey('china-province-wheel')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('china-city-wheel')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('china-district-wheel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('global-location-input')),
        findsOneWidget,
      );
      expect(find.text('使用所选地区'), findsOneWidget);
      expect(find.text('AI 解析并使用'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('China wheel confirmation does not call the AI resolver', (
    tester,
  ) async {
    String? chinaQuery;
    var aiCalls = 0;
    ManualLocation? result;
    await _pumpHost(tester);
    final dialog = showDialog<ManualLocation>(
      context: _hostContext,
      builder: (_) => ManualLocationDialog(
        loadRegions: _loadRegions,
        resolveChinaLocation: (value) async {
          chinaQuery = value;
          return const ManualLocation(
            label: '解析名称',
            latitude: 22.5431,
            longitude: 114.0579,
          );
        },
        resolveLocation: (_) async {
          aiCalls += 1;
          throw StateError('AI location parsing is not configured');
        },
      ),
    );
    dialog.then((value) => result = value);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('use-china-location')));
    await tester.pumpAndSettle();

    expect(chinaQuery, '广东省 深圳市 南山区');
    expect(aiCalls, 0);
    expect(result?.label, '广东省 深圳市 南山区');
    expect(result?.latitude, 22.5431);
  });

  testWidgets('global confirmation uses the AI-resolved location', (
    tester,
  ) async {
    String? query;
    ManualLocation? result;
    await _pumpHost(tester);
    final dialog = showDialog<ManualLocation>(
      context: _hostContext,
      builder: (_) => ManualLocationDialog(
        loadRegions: _loadRegions,
        resolveChinaLocation: _resolveChinaLocation,
        resolveLocation: (value) async {
          query = value;
          return const ManualLocation(
            label: '日本 东京',
            latitude: 35.6762,
            longitude: 139.6503,
          );
        },
      ),
    );
    dialog.then((value) => result = value);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('global-location-input')),
      '东京涩谷',
    );
    await tester.tap(find.byKey(const ValueKey('use-global-location')));
    await tester.pumpAndSettle();

    expect(query, '东京涩谷');
    expect(result?.label, '日本 东京');
    expect(result?.longitude, 139.6503);
  });

  testWidgets('parse failure stays in the dialog and shows an inline error', (
    tester,
  ) async {
    await _pumpHost(tester);
    showDialog<ManualLocation>(
      context: _hostContext,
      builder: (_) => ManualLocationDialog(
        loadRegions: _loadRegions,
        resolveChinaLocation: _resolveChinaLocation,
        resolveLocation: (_) async =>
            throw StateError('AI location parsing is not configured'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('global-location-input')),
      '新加坡',
    );
    await tester.tap(find.byKey(const ValueKey('use-global-location')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('manual-location-dialog')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('location-dialog-error')), findsOneWidget);
    expect(find.text('未配置 AI 地点解析'), findsOneWidget);
  });
}

late BuildContext _hostContext;

Future<void> _pumpHost(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(900, 520));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          _hostContext = context;
          return const SizedBox();
        },
      ),
    ),
  );
}

Future<List<ChinaRegion>> _loadRegions() async {
  return const <ChinaRegion>[
    ChinaRegion(
      name: '广东省',
      code: '440000',
      children: <ChinaRegion>[
        ChinaRegion(
          name: '深圳市',
          code: '440300',
          children: <ChinaRegion>[
            ChinaRegion(name: '南山区', code: '440305'),
            ChinaRegion(name: '福田区', code: '440304'),
          ],
        ),
      ],
    ),
  ];
}

Future<ManualLocation> _resolveChinaLocation(String value) async {
  return ManualLocation(label: value, latitude: 22.5431, longitude: 114.0579);
}
