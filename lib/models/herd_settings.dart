class HerdSettings {
  final String herdId;
  final String herdName;
  final int camelCount;

  const HerdSettings({
    this.herdId = '',
    this.herdName = '',
    this.camelCount = 0,
  });


  HerdSettings copyWith({
    String? herdId,
    String? herdName,
    int? camelCount,
  }) {
    return HerdSettings(
      herdId: herdId ?? this.herdId,
      herdName: herdName ?? this.herdName,
      camelCount: camelCount ?? this.camelCount,
    );
  }


  Map<String, dynamic> toJson() {
    return {
      'herdId': herdId,
      'herdName': herdName,
      'camelCount': camelCount,
    };
  }


  factory HerdSettings.fromJson(
      Map<String, dynamic> json,
      ) {
    return HerdSettings(
      herdId: json['herdId'] ?? '',
      herdName: json['herdName'] ?? '',
      camelCount: json['camelCount'] ?? 0,
    );
  }
}