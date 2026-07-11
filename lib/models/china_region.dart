class ChinaRegion {
  const ChinaRegion({
    required this.name,
    required this.code,
    this.children = const <ChinaRegion>[],
  });

  final String name;
  final String code;
  final List<ChinaRegion> children;
}
