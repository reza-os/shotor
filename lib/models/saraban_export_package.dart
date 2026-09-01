class SarabanExportPackage {
  final Map<String, dynamic> herdInfo;
  final Map<String, dynamic> shepherdInfo;
  final Map<String, dynamic> deviceInfo;
  final Map<String, dynamic> report;
  final List<Map<String, dynamic>> records;


  const SarabanExportPackage({
    required this.herdInfo,
    required this.shepherdInfo,
    required this.deviceInfo,
    required this.report,
    required this.records,
  });


  Map<String, dynamic> toJson() {
    return {
      'herdInfo': herdInfo,
      'shepherdInfo': shepherdInfo,
      'deviceInfo': deviceInfo,
      'report': report,
      'records': records,
    };
  }
}