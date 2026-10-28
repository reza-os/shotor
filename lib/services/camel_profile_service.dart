import 'dart:convert';
import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/camel_profile.dart';
import 'map_data_events.dart';

class CamelProfileService {
  static const String _camelProfilesKey = 'camel_profiles';
  static const String _deletedProfilesKey = 'removed_camel_tag_ids_v14';
  static Set<String>? _deletedCache;
  static Future<void> _writeQueue = Future<void>.value();

  static Future<T> _serialized<T>(Future<T> Function() action) async {
    final previous = _writeQueue;
    final completed = Completer<void>();
    _writeQueue = completed.future;
    await previous;
    try {
      return await action();
    } finally {
      completed.complete();
    }
  }
  static List<CamelProfile>? _memoryCache;
  static Future<List<CamelProfile>>? _loadingProfiles;

  static Future<List<CamelProfile>> loadProfiles() async {
    final cached = _memoryCache;
    if (cached != null) return List<CamelProfile>.of(cached);
    if (_loadingProfiles != null) {
      return List<CamelProfile>.of(await _loadingProfiles!);
    }
    final future = _readFromDisk();
    _loadingProfiles = future;
    try {
      final profiles = await future;
      _memoryCache = List<CamelProfile>.of(profiles);
      return List<CamelProfile>.of(profiles);
    } finally {
      _loadingProfiles = null;
    }
  }

  static Future<List<CamelProfile>> _readFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_camelProfilesKey);
    if (jsonString == null || jsonString.isEmpty) return [];
    final decoded = jsonDecode(jsonString);
    if (decoded is! List) return [];
    return decoded.map((item) => CamelProfile.fromJson(
      Map<String, dynamic>.from(item as Map))).toList();
  }

  static Future<void> saveProfiles(List<CamelProfile> profiles) async {
    final prefs = await SharedPreferences.getInstance();

    final jsonList = profiles.map((profile) => profile.toJson()).toList();
    final jsonString = jsonEncode(jsonList);

    await prefs.setString(_camelProfilesKey, jsonString);
    _memoryCache = List<CamelProfile>.of(profiles);
  }

  /// Deletion removes the registration, not the audit trail of antenna events.
  /// A tombstone prevents the high-rate receive pipeline from silently
  /// recreating a deleted camel with the next inbound packet.
  static Future<Set<String>> _deletedTags() async {
    if (_deletedCache != null) return _deletedCache!;
    final prefs = await SharedPreferences.getInstance();
    _deletedCache = prefs.getStringList(_deletedProfilesKey)?.toSet() ?? <String>{};
    return _deletedCache!;
  }

  static Future<void> deleteProfile(String tagId) => _serialized(() async {
    final cleanId = tagId.trim();
    if (cleanId.isEmpty) throw ArgumentError('Invalid tagId');
    final prefs = await SharedPreferences.getInstance();
    final deleted = await _deletedTags();
    deleted.add(cleanId);
    await prefs.setStringList(_deletedProfilesKey, deleted.toList());
    final profiles = await loadProfiles();
    profiles.removeWhere((profile) => profile.tagId == cleanId);
    await saveProfiles(profiles);
    MapDataEvents.changed();
  });

  /// Merge restored registrations without dropping unrelated camels.
  /// Re-registering an imported tag also removes its deletion tombstone.
  static Future<void> restoreImportedProfiles(List<CamelProfile> incoming) =>
      _serialized(() async {
        final existing = await loadProfiles();
        final byTag = <String, CamelProfile>{for (final p in existing) p.tagId: p};
        final deleted = await _deletedTags();
        for (final p in incoming) {
          byTag[p.tagId] = p;
          deleted.remove(p.tagId);
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(_deletedProfilesKey, deleted.toList());
        await saveProfiles(byTag.values.toList());
        MapDataEvents.changed();
      });

  static Future<CamelProfile?> findByTagId(String tagId) async {
    final profiles = await loadProfiles();

    for (final profile in profiles) {
      if (profile.tagId == tagId) {
        return profile;
      }
    }

    return null;
  }

  static Future<CamelProfile> getOrCreateProfile(String tagId) async {
    if ((await _deletedTags()).contains(tagId)) {
      return CamelProfile(tagId: tagId, camelNo: '-',
          camelName: 'تگ حذف‌شده', isActive: false);
    }
    final profiles = await loadProfiles();
    for (final profile in profiles) {
      if (profile.tagId == tagId) return profile;
    }
    return _serialized(() async {
      if ((await _deletedTags()).contains(tagId)) {
        return CamelProfile(tagId: tagId, camelNo: '-',
            camelName: 'تگ حذف‌شده', isActive: false);
      }
      final current = await loadProfiles();
      for (final profile in current) {
        if (profile.tagId == tagId) return profile;
      }
      // Never recycle a number while another registration owns it.
      var next = 1;
      while (current.any((p) => p.camelNo == next.toString() ||
          p.camelNo == _toPersianNumber(next))) {
        next++;
      }
      final no = _toPersianNumber(next);
      final profile = CamelProfile(tagId: tagId, camelNo: no,
          camelName: 'شتر شماره $no');
      current.add(profile);
      await saveProfiles(current);
      MapDataEvents.changed();
      return profile;
    });
  }

  static Future<void> updateProfile(CamelProfile updatedProfile) =>
      _serialized(() async {
    // An explicit manual registration unarchives a previously deleted tag.
    final deleted = await _deletedTags();
    if (deleted.remove(updatedProfile.tagId)) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_deletedProfilesKey, deleted.toList());
    }
    final profiles = await loadProfiles();
    final index = profiles.indexWhere((p) => p.tagId == updatedProfile.tagId);
    if (index == -1) {
      profiles.add(updatedProfile);
    } else {
      profiles[index] = updatedProfile;
    }
    await saveProfiles(profiles);
    MapDataEvents.changed();
  });

  static String _toPersianNumber(int value) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];

    var text = value.toString();

    for (var i = 0; i < english.length; i++) {
      text = text.replaceAll(english[i], persian[i]);
    }

    return text;
  }
}