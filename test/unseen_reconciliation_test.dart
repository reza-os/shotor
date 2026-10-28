import 'package:flutter_test/flutter_test.dart';
import 'package:saraban_app/services/unseen_reconciliation.dart';

void main() {
  final now = DateTime.utc(2026, 10, 26, 10, 0);

  test('fresh tag is seen immediately, even after being unseen', () {
    expect(UnseenReconciliation.isFresh(
      receivedAt: now.subtract(const Duration(hours: 1)),
      now: now, intervalMinutes: 5,
    ), false);
    expect(UnseenReconciliation.isFresh(
      receivedAt: now, now: now, intervalMinutes: 5,
    ), true);
  });

  test('tag expires precisely at configured interval without new packet', () {
    final last = now;
    expect(UnseenReconciliation.isFresh(
      receivedAt: last,
      now: now.add(const Duration(minutes: 4, seconds: 59)),
      intervalMinutes: 5,
    ), true);
    expect(UnseenReconciliation.isFresh(
      receivedAt: last,
      now: now.add(const Duration(minutes: 5)),
      intervalMinutes: 5,
    ), false);
  });

  test('freshness is not based on any record earlier today', () {
    expect(UnseenReconciliation.isFresh(
      receivedAt: DateTime.utc(2026, 10, 26, 7, 0),
      now: now, intervalMinutes: 30,
    ), false);
  });

  test('next expiry is earliest active tag deadline', () {
    expect(UnseenReconciliation.nextExpiry(
      seenReceivedTimes: [
        now.subtract(const Duration(minutes: 2)),
        now.subtract(const Duration(minutes: 4)),
      ], now: now, intervalMinutes: 5,
    ), now.add(const Duration(minutes: 1)));
  });

  test('invalid intervals revert to 5 and future timestamps are rejected', () {
    expect(UnseenReconciliation.normalizeInterval(9), 5);
    expect(UnseenReconciliation.normalizeInterval(15), 15);
    expect(UnseenReconciliation.isFresh(
      receivedAt: now.add(const Duration(minutes: 7)),
      now: now, intervalMinutes: 5,
    ), false);
  });
}
