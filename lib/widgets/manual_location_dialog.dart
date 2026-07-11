import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/china_region.dart';
import '../models/manual_location.dart';

typedef ChinaRegionLoader = Future<List<ChinaRegion>> Function();
typedef ManualLocationResolver = Future<ManualLocation> Function(String text);

class ManualLocationDialog extends StatefulWidget {
  const ManualLocationDialog({
    super.key,
    required this.loadRegions,
    required this.resolveChinaLocation,
    required this.resolveLocation,
    this.currentLabel,
  });

  final ChinaRegionLoader loadRegions;
  final ManualLocationResolver resolveChinaLocation;
  final ManualLocationResolver resolveLocation;
  final String? currentLabel;

  @override
  State<ManualLocationDialog> createState() => _ManualLocationDialogState();
}

class _ManualLocationDialogState extends State<ManualLocationDialog> {
  final _provinceController = FixedExtentScrollController();
  final _cityController = FixedExtentScrollController();
  final _districtController = FixedExtentScrollController();
  final _globalController = TextEditingController();

  List<ChinaRegion> _provinces = const <ChinaRegion>[];
  var _provinceIndex = 0;
  var _cityIndex = 0;
  var _districtIndex = 0;
  var _isLoadingRegions = true;
  var _isResolving = false;
  String? _errorMessage;

  List<ChinaRegion> get _cities => _provinces.isEmpty
      ? const <ChinaRegion>[]
      : _provinces[_provinceIndex].children;

  List<ChinaRegion> get _districts =>
      _cities.isEmpty ? const <ChinaRegion>[] : _cities[_cityIndex].children;

  @override
  void initState() {
    super.initState();
    _loadRegions();
  }

  @override
  void dispose() {
    _provinceController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _globalController.dispose();
    super.dispose();
  }

  Future<void> _loadRegions() async {
    try {
      final regions = await widget.loadRegions();
      if (!mounted) return;
      setState(() {
        _provinces = regions;
        _isLoadingRegions = false;
        _errorMessage = regions.isEmpty ? '中国地区数据不可用' : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingRegions = false;
        _errorMessage = '中国地区数据加载失败';
      });
    }
  }

  void _selectProvince(int index) {
    setState(() {
      _provinceIndex = index;
      _cityIndex = 0;
      _districtIndex = 0;
      _errorMessage = null;
    });
    _resetController(_cityController);
    _resetController(_districtController);
  }

  void _selectCity(int index) {
    setState(() {
      _cityIndex = index;
      _districtIndex = 0;
      _errorMessage = null;
    });
    _resetController(_districtController);
  }

  void _resetController(FixedExtentScrollController controller) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controller.hasClients) {
        controller.jumpToItem(0);
      }
    });
  }

  Future<void> _useChinaSelection() async {
    if (_provinces.isEmpty || _cities.isEmpty || _districts.isEmpty) return;
    final selected = <String>[];
    for (final region in <ChinaRegion>[
      _provinces[_provinceIndex],
      _cities[_cityIndex],
      _districts[_districtIndex],
    ]) {
      if (!selected.contains(region.name)) {
        selected.add(region.name);
      }
    }
    final label = selected.join(' ');
    await _resolve(
      label,
      resolver: widget.resolveChinaLocation,
      labelOverride: label,
    );
  }

  Future<void> _useGlobalInput() async {
    await _resolve(_globalController.text);
  }

  Future<void> _resolve(
    String value, {
    ManualLocationResolver? resolver,
    String? labelOverride,
  }) async {
    if (_isResolving) return;
    final query = value.trim();
    if (query.isEmpty) {
      setState(() => _errorMessage = '请输入地区或地标名称');
      return;
    }
    setState(() {
      _isResolving = true;
      _errorMessage = null;
    });
    try {
      final parsed = await (resolver ?? widget.resolveLocation)(query);
      final result = labelOverride == null
          ? parsed
          : ManualLocation(
              label: labelOverride,
              latitude: parsed.latitude,
              longitude: parsed.longitude,
            );
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } on StateError catch (error) {
      if (!mounted) return;
      final notConfigured = error.message.toString().contains('not configured');
      setState(() {
        _errorMessage = notConfigured ? '未配置 AI 地点解析' : '地点解析失败，请稍后重试';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = '无法解析该地点，请换一种写法');
    } finally {
      if (mounted) {
        setState(() => _isResolving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.sizeOf(context);
    final width = math.min(940.0, mediaSize.width * 0.94);
    final height = math.min(560.0, mediaSize.height * 0.92);
    return Dialog(
      key: const ValueKey('manual-location-dialog'),
      insetPadding: const EdgeInsets.all(12),
      backgroundColor: const Color(0xFF0D1B22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0x447DD3FC)),
      ),
      child: SizedBox(
        width: width,
        height: height,
        child: Column(
          children: [
            _DialogHeader(
              currentLabel: widget.currentLabel,
              onClose: () => Navigator.of(context).pop(),
            ),
            const Divider(height: 1, color: Color(0x22FFFFFF)),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 3, child: _buildChinaPanel(context)),
                  const VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: Color(0x22FFFFFF),
                  ),
                  Expanded(flex: 2, child: _buildGlobalPanel(context)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChinaPanel(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '中国地区快捷选择',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: _isLoadingRegions
                ? const Center(child: CircularProgressIndicator())
                : Row(
                    children: [
                      _RegionWheel(
                        key: const ValueKey('china-province-wheel'),
                        label: '省',
                        controller: _provinceController,
                        values: _provinces,
                        onSelected: _selectProvince,
                      ),
                      _RegionWheel(
                        key: const ValueKey('china-city-wheel'),
                        label: '市',
                        controller: _cityController,
                        values: _cities,
                        onSelected: _selectCity,
                      ),
                      _RegionWheel(
                        key: const ValueKey('china-district-wheel'),
                        label: '区',
                        controller: _districtController,
                        values: _districts,
                        onSelected: (index) {
                          setState(() {
                            _districtIndex = index;
                            _errorMessage = null;
                          });
                        },
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const ValueKey('use-china-location'),
            onPressed: _isResolving || _isLoadingRegions || _districts.isEmpty
                ? null
                : _useChinaSelection,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('使用所选地区'),
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalPanel(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '全球地区',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '输入城市、区域或地标，由现有 AI API 解析。',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: const Color(0xAAFFFFFF)),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('global-location-input'),
            controller: _globalController,
            enabled: !_isResolving,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _useGlobalInput(),
            decoration: const InputDecoration(
              labelText: '例如：东京涩谷、新加坡、Paris',
              prefixIcon: Icon(Icons.public),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          if (_isResolving) const LinearProgressIndicator(minHeight: 2),
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              key: const ValueKey('location-dialog-error'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFFFF8A80)),
            ),
          ],
          const Spacer(),
          FilledButton.icon(
            key: const ValueKey('use-global-location'),
            onPressed: _isResolving ? null : _useGlobalInput,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('AI 解析并使用'),
          ),
        ],
      ),
    );
  }
}

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({required this.currentLabel, required this.onClose});

  final String? currentLabel;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final current = currentLabel?.trim() ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 8, 8),
      child: Row(
        children: [
          const Icon(
            Icons.edit_location_alt_outlined,
            color: Color(0xFF7DD3FC),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '选择天气地点',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (current.isNotEmpty)
                  Text(
                    '当前：$current',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xAAFFFFFF)),
                  ),
              ],
            ),
          ),
          IconButton(
            key: const ValueKey('close-location-dialog'),
            tooltip: '关闭',
            onPressed: onClose,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _RegionWheel extends StatelessWidget {
  const _RegionWheel({
    super.key,
    required this.label,
    required this.controller,
    required this.values,
    required this.onSelected,
  });

  final String label;
  final FixedExtentScrollController controller;
  final List<ChinaRegion> values;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xAAFFFFFF),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: CupertinoPicker.builder(
              scrollController: controller,
              itemExtent: 38,
              selectionOverlay: const CupertinoPickerDefaultSelectionOverlay(
                background: Color(0x227DD3FC),
              ),
              onSelectedItemChanged: onSelected,
              childCount: values.length,
              itemBuilder: (context, index) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      values[index].name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, color: Colors.white),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
