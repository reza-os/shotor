import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/camel_profile.dart';

class CamelProfileService {
  static const String _camelProfilesKey = 'camel_profiles';

  static Future<List<CamelProfile>> loadProfiles() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_camelProfilesKey);

    if (jsonString == null || jsonString.isEmpty) {
      return [];
    }

    final decoded = jsonDecode(jsonString);

    if (decoded is! List) {
      return [];
    }

    return decoded.map((item) {
      return CamelProfile.fromJson(
        Map<String, dynamic>.from(item as Map),
      );
    }).toList();
  }

  static Future<void> saveProfiles(List<CamelProfile> profiles) async {
    final prefs = await SharedPreferences.getInstance();

    final jsonList = profiles.map((profile) => profile.toJson()).toList();
    final jsonString = jsonEncode(jsonList);

    await prefs.setString(_camelProfilesKey, jsonString);
  }

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
    final profiles = await loadProfiles();

    for (final profile in profiles) {
      if (profile.tagId == tagId) {
        return profile;
      }
    }

    final nextNumber = profiles.length + 1;
    final camelNo = _toPersianNumber(nextNumber);

    final newProfile = CamelProfile(
      tagId: tagId,
      camelNo: camelNo,
      camelName: 'شتر شماره $camelNo',
    );

    profiles.add(newProfile);
    await saveProfiles(profiles);

    return newProfile;
  }

  static Future<void> updateProfile(CamelProfile updatedProfile) async {
    final profiles = await loadProfiles();

    final index = profiles.indexWhere(
      (profile) => profile.tagId == updatedProfile.tagId,
    );

    if (index == -1) {
      profiles.add(updatedProfile);
    } else {
      profiles[index] = updatedProfile;
    }

    await saveProfiles(profiles);
  }

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