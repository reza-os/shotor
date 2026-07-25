import '../models/camel_profile.dart';

const List<CamelProfile> camelProfiles = [
  CamelProfile(
    tagId: 'T-926877721',
    camelNo: '۱',
    camelName: 'شتر شماره ۱',
    note: 'نمونه تستی',
  ),
];

CamelProfile? findCamelProfileByTagId(String tagId) {
  for (final camel in camelProfiles) {
    if (camel.tagId == tagId) {
      return camel;
    }
  }

  return null;
}