import 'package:flutter/foundation.dart';

/// Invalidates the map when geofences or camel profile images change.
class MapDataEvents {
  MapDataEvents._();
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);
  static void changed() => revision.value++;
}
