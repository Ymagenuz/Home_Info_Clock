class ManualLocation {
  const ManualLocation({
    required this.label,
    required this.latitude,
    required this.longitude,
  });

  factory ManualLocation.fromJson(Map<String, dynamic> json) {
    return ManualLocation(
      label: json['label'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }

  final String label;
  final double latitude;
  final double longitude;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'label': label,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}
