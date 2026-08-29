class CamelDetail {
  final int? id;

  final String tagId;

  final String fatherName;
  final String motherName;

  final int? ageYears;
  final double? weightKg;

  final String color;
  final String breed;
  final String healthStatus;
  final String description;

  final String photoPath;

  final DateTime createdAt;
  final DateTime updatedAt;

  const CamelDetail({
    this.id,
    required this.tagId,
    required this.fatherName,
    required this.motherName,
    required this.ageYears,
    required this.weightKg,
    required this.color,
    required this.breed,
    required this.healthStatus,
    required this.description,
    required this.photoPath,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get hasPhoto {
    return photoPath.trim().isNotEmpty;
  }

  CamelDetail copyWith({
    int? id,
    String? tagId,
    String? fatherName,
    String? motherName,
    int? ageYears,
    double? weightKg,
    String? color,
    String? breed,
    String? healthStatus,
    String? description,
    String? photoPath,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CamelDetail(
      id: id ?? this.id,
      tagId: tagId ?? this.tagId,
      fatherName: fatherName ?? this.fatherName,
      motherName: motherName ?? this.motherName,
      ageYears: ageYears ?? this.ageYears,
      weightKg: weightKg ?? this.weightKg,
      color: color ?? this.color,
      breed: breed ?? this.breed,
      healthStatus: healthStatus ?? this.healthStatus,
      description: description ?? this.description,
      photoPath: photoPath ?? this.photoPath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tagId': tagId,
      'fatherName': fatherName,
      'motherName': motherName,
      'ageYears': ageYears,
      'weightKg': weightKg,
      'color': color,
      'breed': breed,
      'healthStatus': healthStatus,
      'description': description,
      'photoPath': photoPath,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory CamelDetail.fromMap(Map<String, dynamic> map) {
    return CamelDetail(
      id: map['id'] as int?,
      tagId: map['tagId']?.toString() ?? '',
      fatherName: map['fatherName']?.toString() ?? '',
      motherName: map['motherName']?.toString() ?? '',
      ageYears: _toInt(map['ageYears']),
      weightKg: _toDouble(map['weightKg']),
      color: map['color']?.toString() ?? '',
      breed: map['breed']?.toString() ?? '',
      healthStatus: map['healthStatus']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      photoPath: map['photoPath']?.toString() ?? '',
      createdAt: DateTime.tryParse(
            map['createdAt']?.toString() ?? '',
          ) ??
          DateTime.now(),
      updatedAt: DateTime.tryParse(
            map['updatedAt']?.toString() ?? '',
          ) ??
          DateTime.now(),
    );
  }

  factory CamelDetail.emptyForTag(String tagId) {
    final now = DateTime.now();

    return CamelDetail(
      tagId: tagId,
      fatherName: '',
      motherName: '',
      ageYears: null,
      weightKg: null,
      color: '',
      breed: '',
      healthStatus: '',
      description: '',
      photoPath: '',
      createdAt: now,
      updatedAt: now,
    );
  }

  List<String> toDescriptionLines({
    required String camelName,
    required String camelNo,
  }) {
    final lines = <String>[];

    lines.add('نام این شتر $camelName است.');
    lines.add('شناسه این شتر $camelNo است.');

    if (fatherName.trim().isNotEmpty) {
      lines.add('پدر این شتر $fatherName است.');
    }

    if (motherName.trim().isNotEmpty) {
      lines.add('مادر این شتر $motherName است.');
    }

    if (ageYears != null) {
      lines.add('سن این شتر $ageYears سال است.');
    }

    if (weightKg != null) {
      lines.add('وزن این شتر $weightKg کیلوگرم است.');
    }

    if (color.trim().isNotEmpty) {
      lines.add('رنگ این شتر $color است.');
    }

    if (breed.trim().isNotEmpty) {
      lines.add('نژاد این شتر $breed است.');
    }

    if (healthStatus.trim().isNotEmpty) {
      lines.add('وضعیت سلامت این شتر: $healthStatus');
    }

    if (description.trim().isNotEmpty) {
      lines.add('توضیحات: $description');
    }

    if (lines.length <= 2) {
      lines.add('هنوز اطلاعات تکمیلی برای این شتر ثبت نشده است.');
    }

    return lines;
  }

  static int? _toInt(dynamic value) {
    if (value == null) return null;

    if (value is int) return value;

    if (value is num) return value.toInt();

    return int.tryParse(value.toString());
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;

    if (value is double) return value;

    if (value is num) return value.toDouble();

    return double.tryParse(value.toString());
  }
}