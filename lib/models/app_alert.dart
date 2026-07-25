enum AlertType {
  forbiddenZone,
  routeExit,
  missingTag,
  lowBattery,
  syncFailed,
  antennaError,
  tagUnlocked,
}

enum AlertLevel {
  urgent,
  warning,
  info,
}

class AppAlert {
  final String id;
  final String title;
  final String subtitle;
  final String time;
  final String locationName;
  final String? relatedTagId;
  final AlertType type;
  final AlertLevel level;
  final bool messageSent;
  final bool reviewed;

const AppAlert({
  required this.id,
  required this.title,
  required this.subtitle,
  required this.time,
  required this.locationName,
  this.relatedTagId,
  required this.type,
  required this.level,
  this.messageSent = false,
  this.reviewed = false,
});

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'time': time,
      'locationName': locationName,
      'relatedTagId': relatedTagId,
      'type': type.name,
      'level': level.name,
      'messageSent': messageSent,
      'reviewed': reviewed,
    };
  }

  factory AppAlert.fromJson(Map<String, dynamic> json) {
    return AppAlert(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      time: json['time']?.toString() ?? '',
      locationName: json['locationName']?.toString() ?? '',
      relatedTagId: json['relatedTagId']?.toString(),
      type: AlertType.values.firstWhere(
        (item) => item.name == json['type'],
        orElse: () => AlertType.antennaError,
      ),
      level: AlertLevel.values.firstWhere(
        (item) => item.name == json['level'],
        orElse: () => AlertLevel.info,
      ),
      messageSent: json['messageSent'] == true,
      reviewed: json['reviewed'] == true,
    );
  }

  AppAlert copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? time,
    String? locationName,
    String? relatedTagId,
    AlertType? type,
    AlertLevel? level,
    bool? messageSent,
    bool? reviewed,
  }) {
    return AppAlert(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      time: time ?? this.time,
      locationName: locationName ?? this.locationName,
      relatedTagId: relatedTagId ?? this.relatedTagId,
      type: type ?? this.type,
      level: level ?? this.level,
      messageSent: messageSent ?? this.messageSent,
      reviewed: reviewed ?? this.reviewed,
    );
  }
}