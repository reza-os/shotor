import 'package:flutter/foundation.dart';

/// In-process invalidation signal. The database remains the source of truth.
/// Subscribers may reload their lists when records change.
class TagRecordsEvents {
  TagRecordsEvents._();

  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static void changed() {
    revision.value += 1;
  }
}
