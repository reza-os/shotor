import 'package:flutter_test/flutter_test.dart';
import 'package:saraban_app/models/live_herd_status.dart';
import 'package:saraban_app/services/live_herd_status_service.dart';

void main() {
  LiveCamelLevel level({
    bool seen = true,
    bool forbidden = false,
    bool outside = false,
    bool unlocked = false,
    bool batteryLow = false,
  }) => LiveHerdStatusService.levelFor(
    seenToday: seen,
    insideForbidden: forbidden,
    outsideAllowed: outside,
    tagUnlocked: unlocked,
    lowBattery: batteryLow,
  );

  test('expired tag is unseen, including previously active/danger tags', () {
    expect(level(seen: false), LiveCamelLevel.unseen);
    expect(level(seen: false, unlocked: true), LiveCamelLevel.unseen);
  });

  test('fresh tag becomes normal or current warning based on packet', () {
    expect(level(), LiveCamelLevel.normal);
    expect(level(batteryLow: true), LiveCamelLevel.warning);
    expect(level(outside: true), LiveCamelLevel.danger);
    expect(level(forbidden: true), LiveCamelLevel.danger);
    expect(level(unlocked: true), LiveCamelLevel.danger);
  });

  test('unseen label no longer claims no reception in entire day', () {
    expect(LiveHerdStatusService.statusTextFor(
      seenToday: false,
      insideForbidden: false,
      outsideAllowed: false,
      tagUnlocked: false,
      lowBattery: false,
      hasGps: false,
    ), 'در بازه اخیر دیده نشده');
  });
}
