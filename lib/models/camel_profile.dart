class CamelProfile {
  final String tagId;
  final String camelNo;
  final String camelName;
  final bool isActive;
  final String note;

  const CamelProfile({
    required this.tagId,
    required this.camelNo,
    required this.camelName,
    this.isActive = true,
    this.note = '',
  });

  CamelProfile copyWith({
    String? tagId,
    String? camelNo,
    String? camelName,
    bool? isActive,
    String? note,
  }) {
    return CamelProfile(
      tagId: tagId ?? this.tagId,
      camelNo: camelNo ?? this.camelNo,
      camelName: camelName ?? this.camelName,
      isActive: isActive ?? this.isActive,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tagId': tagId,
      'camelNo': camelNo,
      'camelName': camelName,
      'isActive': isActive,
      'note': note,
    };
  }

  factory CamelProfile.fromJson(Map<String, dynamic> json) {
    return CamelProfile(
      tagId: json['tagId'] ?? '',
      camelNo: json['camelNo'] ?? '-',
      camelName: json['camelName'] ?? 'شتر ثبت‌نشده',
      isActive: json['isActive'] ?? true,
      note: json['note'] ?? '',
    );
  }
}