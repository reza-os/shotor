import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:saraban_app/models/camel_profile.dart';
import 'package:saraban_app/services/camel_profile_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('deleting camel keeps tag retired until explicit registration', () async {
    SharedPreferences.setMockInitialValues({});
    const tagId = 'T-DELETE-TEST-V14';
    final created = await CamelProfileService.getOrCreateProfile(tagId);
    expect(created.tagId, tagId);
    expect((await CamelProfileService.loadProfiles())
        .any((p) => p.tagId == tagId), isTrue);

    await CamelProfileService.deleteProfile(tagId);
    expect((await CamelProfileService.loadProfiles())
        .any((p) => p.tagId == tagId), isFalse);

    final afterReceipt = await CamelProfileService.getOrCreateProfile(tagId);
    expect(afterReceipt.isActive, isFalse);
    expect((await CamelProfileService.loadProfiles())
        .any((p) => p.tagId == tagId), isFalse);

    await CamelProfileService.updateProfile(
      const CamelProfile(tagId: tagId, camelNo: '15', camelName: 'آزمایشی'));
    expect((await CamelProfileService.loadProfiles())
        .any((p) => p.tagId == tagId), isTrue);
  });
}
