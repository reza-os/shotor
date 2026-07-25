enum UsbLogType {
  connected,
  disconnected,
  received,
  duplicate,
  invalidJson,
  error,
  info,
}

class UsbLog {
  final String id;
  final UsbLogType type;
  final String title;
  final String message;
  final String dateTime;

  const UsbLog({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.dateTime,
  });

  String get timeText {
    final parsed = DateTime.tryParse(dateTime);

    if (parsed == null) return '-';

    final hour = parsed.hour.toString().padLeft(2, '0');
    final minute = parsed.minute.toString().padLeft(2, '0');
    final second = parsed.second.toString().padLeft(2, '0');

    return '$hour:$minute:$second';
  }

  String get dateText {
    final parsed = DateTime.tryParse(dateTime);

    if (parsed == null) return '-';

    final month = parsed.month.toString().padLeft(2, '0');
    final day = parsed.day.toString().padLeft(2, '0');

    return '${parsed.year}/$month/$day';
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

  factory UsbLog.fromJson(Map<String, dynamic> json) {
    return UsbLog(
      id: json['id'] ?? '',
      type: UsbLogType.values.firstWhere(
        (type) => type.name == json['type'],
        orElse: () => UsbLogType.info,
      ),
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      dateTime: json['dateTime'] ?? '',
    );
  }
}