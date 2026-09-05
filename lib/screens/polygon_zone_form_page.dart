import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/geo_area.dart';
import '../models/geo_point.dart';
import '../models/polygon_zone.dart';
import '../services/current_geo_area_service.dart';
import '../services/polygon_zone_service.dart';

class PolygonZoneFormPage extends StatefulWidget {
  const PolygonZoneFormPage({super.key});

  @override
  State<PolygonZoneFormPage> createState() => _PolygonZoneFormPageState();
}

class _PolygonZoneFormPageState extends State<PolygonZoneFormPage> {
  final TextEditingController nameController = TextEditingController();

  PolygonZoneType selectedType = PolygonZoneType.grazing;

  final List<GeoPoint> points = [];

  bool isGettingLocation = false;
  bool isSaving = false;

  GeoArea? currentArea;

  double? lastAccuracy;

  @override
  void initState() {
    super.initState();
    loadCurrentArea();
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  Future<void> loadCurrentArea() async {
    final area = await CurrentGeoAreaService.load();

    if (!mounted) return;

    setState(() {
      currentArea = area;
    });
  }

  String zoneTypeLabel(PolygonZoneType type) {
    switch (type) {
      case PolygonZoneType.grazing:
        return 'چراگاه';

      case PolygonZoneType.barn:
        return 'آغل';

      case PolygonZoneType.forbidden:
        return 'محدوده ممنوع';

      case PolygonZoneType.water:
        return 'آبشخور';

      case PolygonZoneType.custom:
        return 'سفارشی';
    }
  }

  IconData zoneTypeIcon(PolygonZoneType type) {
    switch (type) {
      case PolygonZoneType.grazing:
        return Icons.grass_rounded;

      case PolygonZoneType.barn:
        return Icons.home_work_rounded;

      case PolygonZoneType.forbidden:
        return Icons.warning_rounded;

      case PolygonZoneType.water:
        return Icons.water_drop_rounded;

      case PolygonZoneType.custom:
        return Icons.polyline_rounded;
    }
  }

  bool isPointInsideCurrentArea(GeoPoint point) {
    final area = currentArea;

    if (area == null) {
      return true;
    }

    final insideLat =
        point.latitude >= area.southLatitude &&
        point.latitude <= area.northLatitude;

    final insideLng =
        point.longitude >= area.westLongitude &&
        point.longitude <= area.eastLongitude;

    return insideLat && insideLng;
  }

  Future<bool> showConfirmDialog({
    required String title,
    required String message,
    required String confirmText,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context, false);
                },
                child: const Text('لغو'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, true);
                },
                child: Text(confirmText),
              ),
            ],
          ),
        );
      },
    );

    return result ?? false;
  }

  Future<Position?> readCurrentPosition() async {
    final serviceEnabled =
        await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      showMessage(
        'GPS گوشی خاموش است. ابتدا Location را روشن کنید.',
        isError: true,
      );
      return null;
    }

    LocationPermission permission =
        await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission =
          await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      showMessage(
        'اجازه دسترسی به موقعیت داده نشد.',
        isError: true,
      );
      return null;
    }

    if (permission == LocationPermission.deniedForever) {
      showMessage(
        'دسترسی موقعیت برای برنامه مسدود شده است. از تنظیمات گوشی اجازه بدهید.',
        isError: true,
      );
      return null;
    }

    final position =
        await Geolocator.getCurrentPosition();

    return position;
  }

  Future<void> addCurrentPoint() async {
    if (isGettingLocation) return;

    setState(() {
      isGettingLocation = true;
    });

    try {
      final position =
          await readCurrentPosition();

      if (position == null) {
        return;
      }

      final point = GeoPoint(
        latitude: position.latitude,
        longitude: position.longitude,
      );

      final accuracy = position.accuracy;

      if (!mounted) return;

      final insideArea =
          isPointInsideCurrentArea(point);

      if (!insideArea) {
        final acceptOutside =
            await showConfirmDialog(
          title: 'نقطه خارج از محدوده کلی است',
          message:
              'این نقطه داخل محدوده کلی انتخاب‌شده نیست. آیا با همین وضعیت ثبت شود؟',
          confirmText: 'ثبت شود',
        );

        if (!acceptOutside) {
          return;
        }
      }

      if (accuracy > 20) {
        final acceptLowAccuracy =
            await showConfirmDialog(
          title: 'دقت GPS پایین است',
          message:
              'دقت فعلی GPS حدود ${accuracy.toStringAsFixed(1)} متر است. بهتر است کمی صبر کنید. آیا همین نقطه ثبت شود؟',
          confirmText: 'ثبت شود',
        );

        if (!acceptLowAccuracy) {
          return;
        }
      }

      if (!mounted) return;

      setState(() {
        points.add(point);
        lastAccuracy = accuracy;
      });

      showMessage(
        'نقطه ${points.length} ثبت شد.',
      );
    } catch (e) {
      showMessage(
        'خطا در دریافت موقعیت: $e',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          isGettingLocation = false;
        });
      }
    }
  }

  void removeLastPoint() {
    if (points.isEmpty) return;

    setState(() {
      points.removeLast();
    });

    showMessage(
      'آخرین نقطه حذف شد.',
    );
  }

  Future<void> finishZone() async {
    if (isSaving) return;

    final name =
        nameController.text.trim();

    if (name.isEmpty) {
      showMessage(
        'نام محدوده را وارد کنید.',
        isError: true,
      );
      return;
    }

    if (points.length < 3) {
      showMessage(
        'برای ساخت محدوده چندضلعی حداقل ۳ نقطه لازم است.',
        isError: true,
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final now = DateTime.now();

      final zone = PolygonZone(
        id: PolygonZoneService.createId(),
        name: name,
        type: selectedType,
        points: List<GeoPoint>.from(points),
        isActive: true,
        createdAt: now,
        updatedAt: now,
      );

      await PolygonZoneService.addZone(zone);

      if (!mounted) return;

      showMessage(
        'محدوده چندضلعی ذخیره شد.',
      );

      Navigator.pop(context, true);
    } catch (e) {
      showMessage(
        'خطا در ذخیره محدوده: $e',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  void showMessage(
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textDirection: TextDirection.rtl,
        ),
        backgroundColor:
            isError ? Colors.red : const Color(0xFF008B62),
      ),
    );
  }

  Widget buildCurrentAreaCard() {
    final area = currentArea;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.black12,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.location_on_rounded,
            color: Color(0xFF008B62),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'محدوده کلی فعال',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  area == null
                      ? 'محدوده کلی انتخاب نشده'
                      : '${area.name} - ${area.city}',
                  style: const TextStyle(
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildPointItem(
    GeoPoint point,
    int index,
  ) {
    final inside =
        isPointInsideCurrentArea(point);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: inside
            ? Colors.white
            : const Color(0xFFFFF1F1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: inside
              ? Colors.black12
              : Colors.red.withOpacity(0.5),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: inside
                ? const Color(0xFFEAF7F1)
                : const Color(0xFFFFDCDC),
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: inside
                    ? const Color(0xFF008B62)
                    : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Latitude: ${point.latitude.toStringAsFixed(6)}',
                  style: const TextStyle(
                    fontSize: 12,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  'Longitude: ${point.longitude.toStringAsFixed(6)}',
                  style: const TextStyle(
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          Icon(
            inside
                ? Icons.check_circle_rounded
                : Icons.warning_rounded,
            color: inside
                ? const Color(0xFF008B62)
                : Colors.red,
          ),
        ],
      ),
    );
  }

  Widget buildPointsCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.black12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.polyline_rounded,
                color: Color(0xFF086EBB),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: Text(
                  'نقاط محدوده: ${points.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              if (lastAccuracy != null)
                Text(
                  'دقت: ${lastAccuracy!.toStringAsFixed(1)} متر',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          if (points.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'هنوز نقطه‌ای ثبت نشده است. به گوشه اول محدوده بروید و دکمه ثبت نقطه فعلی را بزنید.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black54,
                ),
              ),
            )
          else
            ...points.asMap().entries.map(
                  (entry) => buildPointItem(
                    entry.value,
                    entry.key,
                  ),
                ),
        ],
      ),
    );
  }

  Widget buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.black12,
        ),
      ),
      child: Column(
        children: [
          TextField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: 'نام محدوده',
              hintText: 'مثلاً چراگاه شمالی',
              filled: true,
              fillColor: const Color(0xFFF5F7FA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 12),

          DropdownButtonFormField<PolygonZoneType>(
            value: selectedType,
            decoration: InputDecoration(
              labelText: 'نوع محدوده',
              filled: true,
              fillColor: const Color(0xFFF5F7FA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            items: PolygonZoneType.values.map(
              (type) {
                return DropdownMenuItem(
                  value: type,
                  child: Row(
                    children: [
                      Icon(
                        zoneTypeIcon(type),
                        size: 20,
                        color: const Color(0xFF086EBB),
                      ),

                      const SizedBox(width: 8),

                      Text(
                        zoneTypeLabel(type),
                      ),
                    ],
                  ),
                );
              },
            ).toList(),
            onChanged: (value) {
              if (value == null) return;

              setState(() {
                selectedType = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed:
                isGettingLocation ? null : addCurrentPoint,
            icon: isGettingLocation
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(
                    Icons.my_location_rounded,
                  ),
            label: Text(
              isGettingLocation
                  ? 'در حال دریافت GPS...'
                  : 'ثبت نقطه فعلی',
            ),
          ),
        ),

        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed:
                    points.isEmpty ? null : removeLastPoint,
                icon: const Icon(
                  Icons.undo_rounded,
                ),
                label: const Text(
                  'حذف آخرین نقطه',
                ),
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: ElevatedButton.icon(
                onPressed:
                    points.length >= 3 && !isSaving
                        ? finishZone
                        : null,
                icon: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.check_circle_rounded,
                      ),
                label: const Text(
                  'پایان محدوده',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget buildHelpCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Text(
        'برای تعریف محدوده چندضلعی، دور محدوده حرکت کنید و در هر گوشه دکمه «ثبت نقطه فعلی» را بزنید. بعد از ثبت حداقل ۳ نقطه، دکمه «پایان محدوده» فعال می‌شود و برنامه نقطه آخر را به نقطه اول وصل می‌کند.',
        style: TextStyle(
          color: Color(0xFF1B3A57),
          height: 1.7,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text(
            'تعریف محدوده چندضلعی',
          ),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            buildCurrentAreaCard(),

            const SizedBox(height: 12),

            buildHelpCard(),

            const SizedBox(height: 12),

            buildFormCard(),

            const SizedBox(height: 12),

            buildPointsCard(),

            const SizedBox(height: 16),

            buildActionButtons(),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}