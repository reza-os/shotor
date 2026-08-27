class LiveHerdSettings {
  final int seenRefreshMinutes;
  final int missingCheckMinutes;
  final int missingAfterMinutes;
  final int criticalMissingAfterMinutes;
  final int recentSeenMinutes;
  final int antennaSilentMinutes;

  const LiveHerdSettings({
    this.seenRefreshMinutes = 1,
    this.missingCheckMinutes = 5,
    this.missingAfterMinutes = 5,
    this.criticalMissingAfterMinutes = 15,
    this.recentSeenMinutes = 3,
    this.antennaSilentMinutes = 10,
  });

  LiveHerdSettings copyWith({
    int? seenRefreshMinutes,
    int? missingCheckMinutes,
    int? missingAfterMinutes,
    int? criticalMissingAfterMinutes,
    int? recentSeenMinutes,
    int? antennaSilentMinutes,
  }) {
    return LiveHerdSettings(
      seenRefreshMinutes: seenRefreshMinutes ?? this.seenRefreshMinutes,
      missingCheckMinutes: missingCheckMinutes ?? this.missingCheckMinutes,
      missingAfterMinutes: missingAfterMinutes ?? this.missingAfterMinutes,
      criticalMissingAfterMinutes:
          criticalMissingAfterMinutes ?? this.criticalMissingAfterMinutes,
      recentSeenMinutes: recentSeenMinutes ?? this.recentSeenMinutes,
      antennaSilentMinutes: antennaSilentMinutes ?? this.antennaSilentMinutes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'seenRefreshMinutes': seenRefreshMinutes,
      'missingCheckMinutes': missingCheckMinutes,
      'missingAfterMinutes': missingAfterMinutes,
      'criticalMissingAfterMinutes': criticalMissingAfterMinutes,
      'recentSeenMinutes': recentSeenMinutes,
      'antennaSilentMinutes': antennaSilentMinutes,
    };
  }

  factory LiveHerdSettings.fromJson(Map<String, dynamic> json) {
    return LiveHerdSettings(
      seenRefreshMinutes:
          int.tryParse(json['seenRefreshMinutes']?.toString() ?? '') ?? 1,
      missingCheckMinutes:
          int.tryParse(json['missingCheckMinutes']?.toString() ?? '') ?? 5,
      missingAfterMinutes:
          int.tryParse(json['missingAfterMinutes']?.toString() ?? '') ?? 5,
      criticalMissingAfterMinutes:
          int.tryParse(json['criticalMissingAfterMinutes']?.toString() ?? '') ??
              15,
      recentSeenMinutes:
          int.tryParse(json['recentSeenMinutes']?.toString() ?? '') ?? 3,
      antennaSilentMinutes:
          int.tryParse(json['antennaSilentMinutes']?.toString() ?? '') ?? 10,
    );
  }
}