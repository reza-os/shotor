enum AntennaLogType {
  connected,
  disconnected,
  received,
  duplicate,
  invalidJson,
  error,
  info,
}

class AntennaLog {
  final String id;
  final AntennaLogType type;
  final String title;
  final String message;
  final String dateTime;

  const AntennaLog({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.dateTime,
  });



  String get dateText {
    final parsed = DateTime.tryParse(dateTime);

    if (parsed == null) {
      return '-';
    }

    final year = parsed.year.toString().padLeft(4, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    final day = parsed.day.toString().padLeft(2, '0');

    return '$year/$month/$day';
  }

  String get timeText {
    final parsed = DateTime.tryParse(dateTime);

    if (parsed == null) {
      return '-';
    }

    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'message': message,
      'dateTime': dateTime,
    };
  }

  factory AntennaLog.fromJson(Map<String, dynamic> json) {
    return AntennaLog(
      id: json['id']?.toString() ?? '',
      type: AntennaLogType.values.firstWhere(
        (item) => item.name == json['type'],
        orElse: () => AntennaLogType.info,
      ),
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      dateTime: json['dateTime']?.toString() ?? '',
    );
  }
}