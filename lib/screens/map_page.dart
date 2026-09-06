import 'dart:async';
     import 'dart:convert';
     import 'dart:math' as math;

     import 'package:flutter/material.dart';
     import 'package:flutter/services.dart';

     import '../models/area_zone.dart';
     import '../models/geo_area.dart';
     import '../models/polygon_zone.dart';
     import '../models/tag_record.dart';
     import '../services/area_zone_service.dart';
     import '../services/current_geo_area_service.dart';
     import '../services/local_storage_service.dart';
     import '../services/location_service.dart';
     import '../services/polygon_zone_service.dart';
     import '../services/zone_check_service.dart';
     import 'geo_area_selection_page.dart';
     import 'polygon_zone_form_page.dart';
     import 'package:file_picker/file_picker.dart';
     import '../models/geo_point.dart';
     import '../services/kml_import_service.dart';
     import '../services/geo_area_service.dart';




     BoxDecoration _mapCardDecoration({
       Color color = Colors.white,
       double radius = 20,
       bool bordered = false,
     }) {
       return BoxDecoration(
         color: color,
         borderRadius: BorderRadius.circular(radius),
         border: bordered
             ? Border.all(
                 color: const Color(0xFFE5EAF0),
               )
             : null,
         boxShadow: [
           BoxShadow(
             color: Colors.black.withOpacity(0.06),
             blurRadius: 18,
             offset: const Offset(0, 8),
           ),
         ],
       );
     }

     class _MapAppHeader extends StatelessWidget {
       final String title;

       const _MapAppHeader({
         required this.title,
       });

       @override
       Widget build(BuildContext context) {
         return Container(
           width: double.infinity,
           padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
           decoration: const BoxDecoration(
             gradient: LinearGradient(
               colors: [
                 Color(0xFF062C5E),
                 Color(0xFF086EBB),
               ],
               begin: Alignment.topRight,
               end: Alignment.bottomLeft,
             ),
             borderRadius: BorderRadius.only(
               bottomLeft: Radius.circular(26),
               bottomRight: Radius.circular(26),
             ),
           ),
           child: SafeArea(
             bottom: false,
             child: Row(
               children: [
                 const Icon(
                   Icons.map_rounded,
                   color: Colors.white,
                 ),
                 const SizedBox(width: 10),
                 Expanded(
                   child: Text(
                     title,
                     style: const TextStyle(
                       color: Colors.white,
                       fontSize: 20,
                       fontWeight: FontWeight.bold,
                     ),
                   ),
                 ),
               ],
             ),
           ),
         );
       }
     }

     class _KmlPolygonZoneDraft {
       final String name;
       final PolygonZoneType type;

       const _KmlPolygonZoneDraft({
         required this.name,
         required this.type,
       });
     }

     class MapPage extends StatefulWidget {
       const MapPage({super.key});

       @override
       State<MapPage> createState() => _MapPageState();
     }

     class _MapPageState extends State<MapPage> {
       bool isLoading = true;
       List<TagRecord> records = [];
       List<AreaZone> zones = [];
       List<PolygonZone> polygonZones = [];

       Timer? mapRefreshTimer;
       GeoArea? currentArea;

       @override
       void initState() {
         super.initState();

         loadRecords();
         loadCurrentArea();
         loadPolygonZones();

         mapRefreshTimer = Timer.periodic(
           const Duration(minutes: 1),
           (_) {
             if (!mounted) return;
             setState(() {});
           },
         );
       }

       @override
       void dispose() {
         mapRefreshTimer?.cancel();
         super.dispose();
       }

     Future<void> loadCurrentArea() async {
       final savedArea = await CurrentGeoAreaService.load();

       final defaultAreas = GeoAreaService.getAll();

       final area = savedArea ??
           (defaultAreas.isNotEmpty ? defaultAreas.first : null);

       if (!mounted) return;

       setState(() {
         currentArea = area;
       });
     }


     Future<void> resetCurrentAreaBoundsToDefault() async {
       final area = currentArea;

       if (area == null) {
         showMapMessage(
           'محدوده کلی فعالی وجود ندارد.',
           isError: true,
         );
         return;
       }

       final accepted = await showDialog<bool>(
         context: context,
         builder: (context) {
           return Directionality(
             textDirection: TextDirection.rtl,
             child: AlertDialog(
               title: const Text('حذف محدوده کلی'),
               content: Text(
                 'مرز KML محدوده «${area.name}» حذف شود و محدوده به مقدار پیش‌فرض برگردد؟',
               ),
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
                   style: ElevatedButton.styleFrom(
                     backgroundColor: Colors.red,
                     foregroundColor: Colors.white,
                   ),
                   child: const Text('حذف'),
                 ),
               ],
             ),
           );
         },
       );

       if (accepted != true) {
         return;
       }

       GeoArea? defaultArea;

       for (final item in GeoAreaService.getAll()) {
         if (item.id == area.id) {
           defaultArea = item;
           break;
         }
       }

       if (defaultArea == null) {
         await CurrentGeoAreaService.clear();

         if (!mounted) return;

         setState(() {
           currentArea = null;
         });

         showMapMessage('محدوده کلی حذف شد.');
         return;
       }

       await CurrentGeoAreaService.save(defaultArea);

       if (!mounted) return;

       setState(() {
         currentArea = defaultArea;
       });

       showMapMessage(
         'محدوده کلی به حالت پیش‌فرض برگشت.',
       );
     }


     Future<void> loadPolygonZones() async {
       final loadedZones =
           await PolygonZoneService.loadActiveZones();

       if (!mounted) return;

       setState(() {
         polygonZones = loadedZones;
       });
     }



     Future<void> openPolygonZoneForm() async {
       if (currentArea == null) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(
             content: Text(
               'ابتدا محدوده کلی فعال را انتخاب کنید.',
               textDirection: TextDirection.rtl,
             ),
           ),
         );

         return;
       }

       final result = await Navigator.of(context).push<bool>(
         MaterialPageRoute(
           builder: (_) => const PolygonZoneFormPage(),
         ),
       );

       if (result == true) {
         await loadPolygonZones();
       }
     }





     Future<void> importKmlForCurrentArea() async {
       final area = currentArea;

       if (area == null) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(
             content: Text(
               'ابتدا محدوده کلی فعال را انتخاب کنید.',
               textDirection: TextDirection.rtl,
             ),
           ),
         );

         return;
       }

       try {
      final pickedResult = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'kml',
        ],
        allowMultiple: false,
      );

      if (pickedResult == null || pickedResult.files.isEmpty) {
        return;
      }

      final path = pickedResult.files.single.path;


         if (path == null || path.trim().isEmpty) {
           showMapMessage(
             'مسیر فایل KML دریافت نشد.',
             isError: true,
           );
           return;
         }

         final result =
             await KmlImportService.parseKmlFile(path);

         if (!result.isValid) {
           showMapMessage(
             'داخل فایل KML چندضلعی معتبر پیدا نشد. فایل باید حداقل ۳ نقطه داشته باشد.',
             isError: true,
           );
           return;
         }

         if (!mounted) return;

         final accepted =
             await showKmlImportConfirmDialog(result);

         if (accepted != true) {
           return;
         }

         final updatedArea =
             KmlImportService.applyResultToArea(
           area: area,
           result: result,
         );

         await CurrentGeoAreaService.save(
           updatedArea,
         );

         if (!mounted) return;

         setState(() {
           currentArea = updatedArea;
         });

         showMapMessage(
           'محدوده کلی ${area.name} از فایل KML به‌روزرسانی شد.',
         );
       } catch (e) {
         showMapMessage(
           'خطا در خواندن فایل KML: $e',
           isError: true,
         );
       }
     }


     String polygonZoneTypeLabelForPage(
       PolygonZoneType type,
     ) {
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

     Color polygonZoneTypeColorForPage(
       PolygonZoneType type,
     ) {
       switch (type) {
         case PolygonZoneType.grazing:
           return const Color(0xFF008B62);

         case PolygonZoneType.barn:
           return const Color(0xFF795548);

         case PolygonZoneType.forbidden:
           return const Color(0xFFD32F2F);

         case PolygonZoneType.water:
           return const Color(0xFF086EBB);

         case PolygonZoneType.custom:
           return const Color(0xFF6A1B9A);
       }
     }

     bool isPointInsideCurrentArea(
       GeoPoint point,
     ) {
       final area = currentArea;

       if (area == null) {
         return true;
       }

       return point.latitude >= area.southLatitude &&
           point.latitude <= area.northLatitude &&
           point.longitude >= area.westLongitude &&
           point.longitude <= area.eastLongitude;
     }

     int countPointsOutsideCurrentArea(
       List<GeoPoint> points,
     ) {
       int count = 0;

       for (final point in points) {
         if (!isPointInsideCurrentArea(point)) {
           count++;
         }
       }

       return count;
     }



     Future<bool?> showKmlImportConfirmDialog(
       KmlImportResult result,
     ) {
       return showDialog<bool>(
         context: context,
         builder: (context) {
           return Directionality(
             textDirection: TextDirection.rtl,
             child: AlertDialog(
               title: const Text(
                 'تایید وارد کردن KML',
               ),
               content: Column(
                 mainAxisSize: MainAxisSize.min,
                 crossAxisAlignment:
                     CrossAxisAlignment.start,
                 children: [
                   Text(
                     'نام فایل: ${result.fileName}',
                   ),

                   const SizedBox(height: 8),

                   Text(
                     'نام محدوده داخل KML: ${result.name}',
                   ),

                   const SizedBox(height: 8),

                   Text(
                     'تعداد نقاط: ${result.points.length}',
                   ),

                   const SizedBox(height: 12),

                   Text(
                     'شمال: ${result.northLatitude.toStringAsFixed(6)}',
                     textDirection: TextDirection.ltr,
                   ),

                   Text(
                     'جنوب: ${result.southLatitude.toStringAsFixed(6)}',
                     textDirection: TextDirection.ltr,
                   ),

                   Text(
                     'شرق: ${result.eastLongitude.toStringAsFixed(6)}',
                     textDirection: TextDirection.ltr,
                   ),

                   Text(
                     'غرب: ${result.westLongitude.toStringAsFixed(6)}',
                     textDirection: TextDirection.ltr,
                   ),

                   const SizedBox(height: 12),

                   const Text(
                     'این فایل، محدوده کلی فعال را به‌روزرسانی می‌کند.',
                     style: TextStyle(
                       color: Colors.black54,
                     ),
                   ),
                 ],
               ),
               actions: [
                 TextButton(
                   onPressed: () {
                     Navigator.pop(context, false);
                   },
                   child: const Text(
                     'لغو',
                   ),
                 ),

                 ElevatedButton(
                   onPressed: () {
                     Navigator.pop(context, true);
                   },
                   child: const Text(
                     'تایید و ذخیره',
                   ),
                 ),
               ],
             ),
           );
         },
       );
     }

     void showMapMessage(
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



     Future<void> importKmlAsInternalPolygonZone() async {
       if (currentArea == null) {
         showMapMessage(
           'ابتدا محدوده کلی فعال را انتخاب کنید.',
           isError: true,
         );
         return;
       }

       try {
         final pickedResult =
             await FilePicker.platform.pickFiles(
           type: FileType.custom,
           allowedExtensions: [
             'kml',
           ],
           allowMultiple: false,
           withData: true,
         );

         if (pickedResult == null ||
             pickedResult.files.isEmpty) {
           return;
         }

         final selectedFile =
             pickedResult.files.single;

         KmlImportResult result;

         final path =
             selectedFile.path;

         if (path != null && path.trim().isNotEmpty) {
           result =
               await KmlImportService.parseKmlFile(path);
         } else if (selectedFile.bytes != null) {
           result = KmlImportService.parseKmlText(
             utf8.decode(selectedFile.bytes!),
             fileName: selectedFile.name,
           );
         } else {
           showMapMessage(
             'فایل KML قابل خواندن نیست.',
             isError: true,
           );
           return;
         }

         if (!result.isValid) {
           showMapMessage(
             'داخل فایل KML چندضلعی معتبر پیدا نشد.',
             isError: true,
           );
           return;
         }

         if (!mounted) return;

         final draft =
             await showKmlPolygonZoneDialog(result);

         if (draft == null) {
           return;
         }

         final outsideCount =
             countPointsOutsideCurrentArea(result.points);

         if (outsideCount > 0) {
           final accepted =
               await showDialog<bool>(
             context: context,
             builder: (context) {
               return Directionality(
                 textDirection: TextDirection.rtl,
                 child: AlertDialog(
                   title: const Text(
                     'بخشی از محدوده خارج از محدوده کلی است',
                   ),
                   content: Text(
                     '$outsideCount نقطه از این KML خارج از محدوده کلی فعال قرار دارد. آیا باز هم ذخیره شود؟',
                   ),
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
                       child: const Text('ذخیره شود'),
                     ),
                   ],
                 ),
               );
             },
           );

           if (accepted != true) {
             return;
           }
         }

         final now = DateTime.now();

         final zone = PolygonZone(
           id: PolygonZoneService.createId(),
           name: draft.name,
           type: draft.type,
           points: result.points,
           isActive: true,
           createdAt: now,
           updatedAt: now,
         );

         await PolygonZoneService.addZone(zone);

         await loadPolygonZones();

         showMapMessage(
           'محدوده داخلی ${zone.name} از KML اضافه شد.',
         );
       } catch (e) {
         showMapMessage(
           'خطا در وارد کردن KML داخلی: $e',
           isError: true,
         );
       }
     }





     Future<_KmlPolygonZoneDraft?> showKmlPolygonZoneDialog(
       KmlImportResult result,
     ) async {
       final nameController = TextEditingController(
         text: result.name,
       );

       PolygonZoneType selectedType =
           PolygonZoneType.grazing;

       final dialogResult =
           await showDialog<_KmlPolygonZoneDraft>(
         context: context,
         builder: (context) {
           return Directionality(
             textDirection: TextDirection.rtl,
             child: StatefulBuilder(
               builder: (context, setDialogState) {
                 return AlertDialog(
                   title: const Text(
                     'وارد کردن محدوده داخلی',
                   ),
                   content: SingleChildScrollView(
                     child: Column(
                       mainAxisSize: MainAxisSize.min,
                       crossAxisAlignment:
                           CrossAxisAlignment.start,
                       children: [
                         Text(
                           'نام فایل: ${result.fileName}',
                         ),

                         const SizedBox(height: 8),

                         Text(
                           'تعداد نقاط: ${result.points.length}',
                         ),

                         const SizedBox(height: 12),

                         TextField(
                           controller: nameController,
                           decoration: const InputDecoration(
                             labelText: 'نام محدوده',
                             hintText: 'مثلاً چراگاه شمالی',
                           ),
                         ),

                         const SizedBox(height: 12),

                         DropdownButtonFormField<PolygonZoneType>(
                           value: selectedType,
                           decoration: const InputDecoration(
                             labelText: 'نوع محدوده',
                           ),
                           items: PolygonZoneType.values.map(
                             (type) {
                               return DropdownMenuItem(
                                 value: type,
                                 child: Text(
                                   polygonZoneTypeLabelForPage(type),
                                 ),
                               );
                             },
                           ).toList(),
                           onChanged: (value) {
                             if (value == null) return;

                             setDialogState(() {
                               selectedType = value;
                             });
                           },
                         ),

                         const SizedBox(height: 12),

                         Text(
                           'شمال: ${result.northLatitude.toStringAsFixed(6)}',
                           textDirection: TextDirection.ltr,
                         ),

                         Text(
                           'جنوب: ${result.southLatitude.toStringAsFixed(6)}',
                           textDirection: TextDirection.ltr,
                         ),

                         Text(
                           'شرق: ${result.eastLongitude.toStringAsFixed(6)}',
                           textDirection: TextDirection.ltr,
                         ),

                         Text(
                           'غرب: ${result.westLongitude.toStringAsFixed(6)}',
                           textDirection: TextDirection.ltr,
                         ),
                       ],
                     ),
                   ),
                   actions: [
                     TextButton(
                       onPressed: () {
                         Navigator.pop(context);
                       },
                       child: const Text('لغو'),
                     ),

                     ElevatedButton(
                       onPressed: () {
                         final name =
                             nameController.text.trim();

                         if (name.isEmpty) {
                           return;
                         }

                         Navigator.pop(
                           context,
                           _KmlPolygonZoneDraft(
                             name: name,
                             type: selectedType,
                           ),
                         );
                       },
                       child: const Text(
                         'ذخیره محدوده داخلی',
                       ),
                     ),
                   ],
                 );
               },
             ),
           );
         },
       );

       nameController.dispose();

       return dialogResult;
     }





     Future<void> deletePolygonZone(
       PolygonZone zone,
     ) async {
       final accepted =
           await showDialog<bool>(
         context: context,
         builder: (context) {
           return Directionality(
             textDirection: TextDirection.rtl,
             child: AlertDialog(
               title: const Text(
                 'حذف محدوده',
               ),
               content: Text(
                 'محدوده «${zone.name}» حذف شود؟',
               ),
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
                   style: ElevatedButton.styleFrom(
                     backgroundColor: Colors.red,
                     foregroundColor: Colors.white,
                   ),
                   child: const Text('حذف'),
                 ),
               ],
             ),
           );
         },
       );

       if (accepted != true) {
         return;
       }

       await PolygonZoneService.deleteZone(zone.id);

       await loadPolygonZones();

       showMapMessage(
         'محدوده حذف شد.',
       );
     }


     Widget buildPolygonZoneListItem(
       PolygonZone zone,
     ) {
       final color =
           polygonZoneTypeColorForPage(zone.type);

       return Container(
         margin: const EdgeInsets.only(top: 10),
         padding: const EdgeInsets.all(12),
         decoration: BoxDecoration(
           color: color.withOpacity(0.06),
           borderRadius: BorderRadius.circular(14),
           border: Border.all(
             color: color.withOpacity(0.25),
           ),
         ),
         child: Row(
           children: [
             Icon(
               Icons.polyline_rounded,
               color: color,
             ),

             const SizedBox(width: 10),

             Expanded(
               child: Column(
                 crossAxisAlignment:
                     CrossAxisAlignment.start,
                 children: [
                   Text(
                     zone.name,
                     style: const TextStyle(
                       fontWeight: FontWeight.bold,
                     ),
                   ),

                   const SizedBox(height: 3),

                   Text(
                     '${polygonZoneTypeLabelForPage(zone.type)} / ${zone.points.length} نقطه',
                     style: const TextStyle(
                       color: Colors.black54,
                       fontSize: 12,
                     ),
                   ),
                 ],
               ),
             ),

             IconButton(
               onPressed: () {
                 deletePolygonZone(zone);
               },
               icon: const Icon(
                 Icons.delete_rounded,
                 color: Colors.red,
               ),
             ),
           ],
         ),
       );
     }


     Widget buildPolygonZoneToolsCard() {
       return Container(
         padding: const EdgeInsets.all(14),
         decoration: _mapCardDecoration(),
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
                     'محدوده‌های داخلی: ${polygonZones.length}',
                     style: const TextStyle(
                       fontWeight: FontWeight.bold,
                     ),
                   ),
                 ),
               ],
             ),

             const SizedBox(height: 12),

             SizedBox(
               width: double.infinity,
               height: 48,
               child: ElevatedButton.icon(
                 onPressed: openPolygonZoneForm,
                 icon: const Icon(
                   Icons.add_location_alt_rounded,
                 ),
                 label: const Text(
                   'تعریف محدوده داخلی با GPS',
                 ),
               ),
             ),

             const SizedBox(height: 10),

             SizedBox(
               width: double.infinity,
               height: 48,
               child: OutlinedButton.icon(
                 onPressed: importKmlAsInternalPolygonZone,
                 icon: const Icon(
                   Icons.upload_file_rounded,
                 ),
                 label: const Text(
                   'وارد کردن KML به عنوان محدوده داخلی',
                 ),
               ),
             ),

             const SizedBox(height: 10),

             SizedBox(
               width: double.infinity,
               height: 48,
               child: OutlinedButton.icon(
                 onPressed: importKmlForCurrentArea,
                 icon: const Icon(
                   Icons.public_rounded,
                 ),
                 label: const Text(
                   'وارد کردن KML برای محدوده کلی فعال',
                 ),
               ),
             ),
             const SizedBox(height: 10),

             SizedBox(
               width: double.infinity,
               height: 48,
               child: OutlinedButton.icon(
                 onPressed: resetCurrentAreaBoundsToDefault,
                 icon: const Icon(
                   Icons.delete_outline_rounded,
                   color: Colors.red,
                 ),
                 label: const Text(
                   'حذف محدوده کلی واردشده با KML',
                   style: TextStyle(
                     color: Colors.red,
                   ),
                 ),
               ),
             ),

             if (polygonZones.isEmpty) ...[
               const SizedBox(height: 12),

               Container(
                 width: double.infinity,
                 padding: const EdgeInsets.all(12),
                 decoration: BoxDecoration(
                   color: const Color(0xFFF5F7FA),
                   borderRadius: BorderRadius.circular(14),
                 ),
                 child: const Text(
                   'هنوز محدوده داخلی ثبت نشده است.',
                   textAlign: TextAlign.center,
                   style: TextStyle(
                     color: Colors.black54,
                   ),
                 ),
               ),
             ] else ...[
               const SizedBox(height: 12),

               ...polygonZones.map(
                 buildPolygonZoneListItem,
               ),
             ],
           ],
         ),
       );
     }

       Future<void> loadRecords() async {
         final loadedRecords = await LocalStorageService.loadTagRecords();
         final loadedZones = await AreaZoneService.loadZones();

         if (!mounted) return;

         setState(() {
           records = loadedRecords;
           zones = loadedZones;
           isLoading = false;
         });
       }

       bool hasGps(TagRecord record) {
         return record.latitude != null && record.longitude != null;
       }

       DateTime? recordDateTime(TagRecord record) {
         final text = record.receivedDateTime.trim();

         if (text.isEmpty) return null;

         return DateTime.tryParse(text);
       }

       bool isSameDay(DateTime a, DateTime b) {
         return a.year == b.year && a.month == b.month && a.day == b.day;
       }

       List<TagRecord> getTodayRecords(List<TagRecord> source) {
         final now = DateTime.now();

         return source.where((record) {
           final parsed = recordDateTime(record);

           if (parsed == null) return false;

           return isSameDay(parsed, now);
         }).toList();
       }

       List<TagRecord> get gpsRecords {
         final todayRecords = getTodayRecords(records);

         return todayRecords.where(hasGps).toList();
       }

       List<TagRecord> get latestGpsRecordsByTag {
         final result = <TagRecord>[];
         final seenTags = <String>{};

         for (final record in gpsRecords) {
           if (seenTags.contains(record.tagId)) continue;

           seenTags.add(record.tagId);
           result.add(record);
         }

         return result;
       }

       String twoDigit(int value) {
         return value.toString().padLeft(2, '0');
       }

       String recordDateText(TagRecord record) {
         final date = DateTime.tryParse(record.receivedDateTime);

         if (date == null) {
           return record.receivedTime;
         }

         return '${date.year}/${twoDigit(date.month)}/${twoDigit(date.day)} - ${twoDigit(date.hour)}:${twoDigit(date.minute)}';
       }




       @override
       Widget build(BuildContext context) {
         final gpsList = latestGpsRecordsByTag;
         final activeMapZones = zones.where((zone) => zone.isActive).toList();

         final allGpsCount = gpsRecords.length;
         final uniqueCamelCount = gpsList.length;

         final lowBatteryCount = gpsList.where((record) {
           return record.isBatteryLow;
         }).length;

         final unlockedCount = gpsList.where((record) {
           return record.lock == 0;
         }).length;

         return Directionality(
           textDirection: TextDirection.rtl,
           child: Scaffold(
             backgroundColor: const Color(0xFFF5F7FA),
             body: Column(
               children: [
                 const _MapAppHeader(title: 'نقشه'),
                 Expanded(
                   child: Center(
                     child: ConstrainedBox(
                       constraints: const BoxConstraints(maxWidth: 430),
                       child: isLoading
                           ? const Center(child: CircularProgressIndicator())
                           : RefreshIndicator(
                               onRefresh: loadRecords,
                               child: ListView(
                                 padding: const EdgeInsets.all(14),
                                 children: [
                                   Row(
                                     children: [
                                       Expanded(
                                         child: MapSummaryCard(
                                           title: 'GPS امروز',
                                           value: allGpsCount.toString(),
                                           icon: Icons.gps_fixed_rounded,
                                           color: const Color(0xFF086EBB),
                                         ),
                                       ),
                                       const SizedBox(width: 10),
                                       Expanded(
                                         child: MapSummaryCard(
                                           title: 'شتر دارای موقعیت',
                                           value: uniqueCamelCount.toString(),
                                           icon: Icons.pets_rounded,
                                           color: const Color(0xFF008B62),
                                         ),
                                       ),
                                     ],
                                   ),

                                   const SizedBox(height: 10),

                                   Row(
                                     children: [
                                       Expanded(
                                         child: MapSummaryCard(
                                           title: 'باتری ضعیف',
                                           value: lowBatteryCount.toString(),
                                           icon: Icons.battery_alert_rounded,
                                           color: const Color(0xFFE87500),
                                         ),
                                       ),
                                       const SizedBox(width: 10),
                                       Expanded(
                                         child: MapSummaryCard(
                                           title: 'تگ باز',
                                           value: unlockedCount.toString(),
                                           icon: Icons.lock_open_rounded,
                                           color: const Color(0xFFD32F2F),
                                         ),
                                       ),
                                     ],
                                   ),

                                   const SizedBox(height: 14),


                                      const SizedBox(height: 14),
                                      buildPolygonZoneToolsCard(),
                                      const SizedBox(height: 14),
                                   Container(
                                     padding: const EdgeInsets.all(14),
                                     decoration: _mapCardDecoration(),
                                     child: Column(
                                       crossAxisAlignment: CrossAxisAlignment.start,
                                       children: [
                                         Row(
                                           children: [
                                             const Icon(
                                               Icons.map_rounded,
                                               color: Color(0xFF062C5E),
                                             ),
                                             const SizedBox(width: 8),
                                             const Expanded(
                                               child: Text(
                                                 'نمای ساده موقعیت‌های امروز',
                                                 style: TextStyle(
                                                   fontWeight: FontWeight.bold,
                                                   fontSize: 16,
                                                   color: Color(0xFF062C5E),
                                                 ),
                                               ),
                                             ),
                                             IconButton(
                                               onPressed: loadRecords,
                                               icon: const Icon(
                                                 Icons.refresh_rounded,
                                               ),
                                               tooltip: 'تازه‌سازی',
                                             ),
                                           ],
                                         ),

                                         const SizedBox(height: 10),

                                         SizedBox(
                                           width: double.infinity,
                                           child: OutlinedButton.icon(
                                             onPressed: () async {
                                               await Navigator.of(context).push(
                                                 MaterialPageRoute(
                                                   builder: (_) => AreaZonesPage(),
                                                 ),
                                               );

                                               await loadRecords();
                                             },
                                             icon: const Icon(Icons.layers_rounded),
                                             label: const Text('مدیریت محدوده‌ها'),
                                           ),
                                         ),

                                         const SizedBox(height: 10),

                                         if (gpsList.isEmpty &&
                                             activeMapZones.isEmpty)
                                           Container(
                                             width: double.infinity,
                                             padding: const EdgeInsets.all(18),
                                             decoration: BoxDecoration(
                                               color: const Color(0xFFFFF3E0),
                                               borderRadius:
                                                   BorderRadius.circular(16),
                                             ),
                                             child: const Column(
                                               children: [
                                                 Icon(
                                                   Icons.gps_not_fixed_rounded,
                                                   size: 54,
                                                   color: Color(0xFFE87500),
                                                 ),
                                                 SizedBox(height: 12),
                                                 Text(
                                                   'امروز هنوز موقعیت یا محدوده‌ای ثبت نشده است.',
                                                   textAlign: TextAlign.center,
                                                   style: TextStyle(
                                                     fontWeight: FontWeight.bold,
                                                     fontSize: 16,
                                                   ),
                                                 ),
                                                 SizedBox(height: 8),
                                                 Text(
                                                   'Location گوشی را روشن کن و از صفحه دریافت یک JSON پردازش کن یا از مدیریت محدوده‌ها یک محدوده بساز.',
                                                   textAlign: TextAlign.center,
                                                   style: TextStyle(
                                                     color: Colors.black54,
                                                     height: 1.7,
                                                   ),
                                                 ),
                                               ],
                                             ),
                                           )
                                         else
                                       SimpleGpsMap(
                                         records: gpsList,
                                         zones: activeMapZones,
                                         area: currentArea,
                                         polygonZones: polygonZones,
                                       )
                                       ],
                                     ),
                                   ),

                                   const SizedBox(height: 14),

                                   Row(
                                     children: [
                                       const Expanded(
                                         child: Text(
                                           'آخرین موقعیت شترهای امروز',
                                           style: TextStyle(
                                             fontWeight: FontWeight.bold,
                                             fontSize: 16,
                                             color: Color(0xFF062C5E),
                                           ),
                                         ),
                                       ),
                                       Text(
                                         '${gpsList.length} مورد',
                                         style: const TextStyle(
                                           color: Colors.black54,
                                           fontWeight: FontWeight.bold,
                                         ),
                                       ),
                                     ],
                                   ),

                                   const SizedBox(height: 10),

                                   if (gpsList.isEmpty)
                                     Container(
                                       padding: const EdgeInsets.all(18),
                                       decoration: _mapCardDecoration(),
                                       child: const Text(
                                         'امروز رکورد GPS برای نمایش در نقشه وجود ندارد.',
                                         textAlign: TextAlign.center,
                                         style: TextStyle(
                                           color: Colors.black54,
                                           height: 1.7,
                                         ),
                                       ),
                                     )
                                   else
                                     ...gpsList.map(
                                       (record) => GpsRecordCard(
                                         record: record,
                                         dateText: recordDateText(record),
                                         zones: activeMapZones,
                                       ),
                                     ),

                                   const SizedBox(height: 40),
                                 ],
                               ),
                             ),
                     ),
                   ),
                 ),
               ],
             ),
           ),
         );
       }
     }

     class MapSummaryCard extends StatelessWidget {
       final String title;
       final String value;
       final IconData icon;
       final Color color;

       const MapSummaryCard({
         super.key,
         required this.title,
         required this.value,
         required this.icon,
         required this.color,
       });

       @override
       Widget build(BuildContext context) {
         return Container(
           height: 104,
           padding: const EdgeInsets.all(10),
           decoration: _mapCardDecoration(),
           child: Column(
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
               Icon(
                 icon,
                 color: color,
                 size: 26,
               ),
               const SizedBox(height: 7),
               Text(
                 value,
                 style: TextStyle(
                   color: color,
                   fontWeight: FontWeight.bold,
                   fontSize: 22,
                   height: 1,
                 ),
               ),
               const SizedBox(height: 7),
               Text(
                 title,
                 maxLines: 1,
                 overflow: TextOverflow.ellipsis,
                 style: const TextStyle(
                   color: Colors.black54,
                   fontSize: 12,
                   fontWeight: FontWeight.bold,
                 ),
               ),
             ],
           ),
         );
       }
     }



     enum MapDetailLevel {

       low,

       medium,

       high,

     }


   class CamelCluster {

     final double latitude;

     final double longitude;

     final List<TagRecord> records;


     CamelCluster({

       required this.latitude,

       required this.longitude,

       required this.records,

     });


     int get count {
       return records.length;
     }

   }



     class SimpleGpsMap extends StatefulWidget {
       final List<TagRecord> records;
       final List<AreaZone> zones;
       final GeoArea? area;
       final List<PolygonZone> polygonZones;

       const SimpleGpsMap({
         super.key,
         required this.records,
         this.zones = const [],
         this.area,
         this.polygonZones = const [],
       });

       @override
       State<SimpleGpsMap> createState() => _SimpleGpsMapState();
     }

    class _SimpleGpsMapState
        extends State<SimpleGpsMap>
        with SingleTickerProviderStateMixin {
       static const double sceneWidth = 1200;
       static const double sceneHeight = 820;

       final TransformationController transformationController =
           TransformationController();

       TagRecord? selectedRecord;
       Size viewportSize = Size.zero;
       bool didFitInitialView = false;
       double currentMapScale = 1.0;


       bool get showClusters {

         return currentMapScale < 1.5;

       }


       MapDetailLevel get currentDetailLevel {

         if (currentMapScale < 0.8) {
           return MapDetailLevel.low;
         }


         if (currentMapScale < 2.2) {
           return MapDetailLevel.medium;
         }


         return MapDetailLevel.high;
       }






       double markerSizeForRecord(TagRecord record) {

         return zoneScaleForRecord(record);

       }


double zoneScaleForRecord(TagRecord record) {

  double bestSize = 24;


  for (final zone in activeZones) {

    final centerDistance =
        math.sqrt(
          math.pow(
            record.latitude! - zone.centerLatitude,
            2,
          ) +
          math.pow(
            record.longitude! - zone.centerLongitude,
            2,
          ),
        );


    if (centerDistance < 0.01) {

      final radius =
          zoneRadiusPixels(zone);


      bestSize =
          radius * 0.18;

      break;

    }

  }


  for (final polygon in activePolygonZones) {

    final points =
        polygon.points;


    if(points.isEmpty){
      continue;
    }


    final xs =
        points.map(
          (e) => e.latitude,
        );


    final ys =
        points.map(
          (e) => e.longitude,
        );


    final width =
        (xs.reduce(math.max) -
         xs.reduce(math.min))
        .abs();


    final height =
        (ys.reduce(math.max) -
         ys.reduce(math.min))
        .abs();


    final areaSize =
        ((width + height) * 5000);


    if(areaSize > 0){

      bestSize =
          areaSize * 0.08;

    }

  }


  return bestSize.clamp(
    14.0,
    36.0,
  );

}






       double get clusterDistance {

         if (currentMapScale < 0.8) {

           // نمای خیلی دور
           return 0.003;

         }


         if (currentMapScale < 2.0) {

           // نمای متوسط
           return 0.001;

         }


         // نمای نزدیک
         return 0.00025;

       }




       @override
       void initState() {
         super.initState();

         transformationController.addListener(updateCurrentScale);

         if (widget.records.isNotEmpty) {
           selectedRecord = widget.records.first;
         }
       }

     @override
     void didUpdateWidget(covariant SimpleGpsMap oldWidget) {
       super.didUpdateWidget(oldWidget);

       final areaChanged =
           oldWidget.area?.id != widget.area?.id ||
           oldWidget.area?.northLatitude != widget.area?.northLatitude ||
           oldWidget.area?.southLatitude != widget.area?.southLatitude ||
           oldWidget.area?.eastLongitude != widget.area?.eastLongitude ||
           oldWidget.area?.westLongitude != widget.area?.westLongitude;

       if (oldWidget.records != widget.records ||
           oldWidget.zones != widget.zones ||
           oldWidget.polygonZones != widget.polygonZones ||
           areaChanged) {
         selectedRecord = widget.records.isEmpty
             ? null
             : widget.records.first;

         didFitInitialView = false;
       }
     }


       @override
       void dispose() {
         transformationController.removeListener(updateCurrentScale);
         transformationController.dispose();
         super.dispose();
       }

     List<PolygonZone> get activePolygonZones {
       return widget.polygonZones
           .where(
             (zone) => zone.isActive && zone.isValid,
           )
           .toList();
     }

       List<TagRecord> get mapRecords {
         return widget.records.where((record) {
           return record.latitude != null && record.longitude != null;
         }).take(50).toList();
       }


       List<CamelCluster> get camelClusters {

         final distance = clusterDistance;

         final clusters =
             <CamelCluster>[];


         for (final record in mapRecords) {


           if (record.latitude == null ||
               record.longitude == null) {
             continue;
           }


           CamelCluster? target;


           for (final cluster in clusters) {

             final latDiff =
                 (cluster.latitude -
                         record.latitude!)
                     .abs();


             final lngDiff =
                 (cluster.longitude -
                         record.longitude!)
                     .abs();



             if (latDiff < distance &&
                 lngDiff < distance) {

               target = cluster;
               break;
             }

           }



           if (target == null) {

             clusters.add(

               CamelCluster(

                 latitude:
                     record.latitude!,

                 longitude:
                     record.longitude!,

                 records:[
                   record,
                 ],

               ),

             );

           }

           else {

             target.records.add(record);

           }


         }


         return clusters;

       }


       int get totalClusterCount {

         return camelClusters.length;

       }

       List<AreaZone> get activeZones {
         return widget.zones.where((zone) => zone.isActive).toList();
       }


      double getContainingZoneSize(
        TagRecord record,
      ) {
        double baseSize = 26;


        // اگر مختصات نداشت، اندازه امن بده
        if (record.latitude == null || record.longitude == null) {
          return 18;
        }


        // 1) اثر تعداد شترها
        // هرچه شترها بیشتر باشند، marker کوچک‌تر می‌شود.
        final camelCount =
            mapRecords.length;


        final densityFactor =
            camelCount <= 20
                ? 1.0
                : camelCount <= 60
                    ? 0.85
                    : camelCount <= 150
                        ? 0.70
                        : 0.55;



        // 2) اثر zoom
        // در zoom پایین کوچک‌تر، در zoom بالا کمی بزرگ‌تر
        final zoomFactor =
            currentMapScale < 0.8
                ? 0.65
                : currentMapScale < 1.5
                    ? 0.82
                    : currentMapScale < 2.8
                        ? 1.0
                        : 1.15;



        // 3) اثر محدوده دایره‌ای
        for (final zone in activeZones) {
          final distance =
              math.sqrt(
                math.pow(
                  record.latitude! - zone.centerLatitude,
                  2,
                ) +
                    math.pow(
                      record.longitude! - zone.centerLongitude,
                      2,
                    ),
              );

          if (distance < 0.01) {
            final radius =
                zoneRadiusPixels(zone);

            baseSize =
                (radius * 0.10).clamp(14.0, 30.0);
          }
        }



        // 4) اثر محدوده چندضلعی
        for (final polygon in activePolygonZones) {
          if (polygon.points.length < 3) {
            continue;
          }

          final offsets =
              polygon.points
                  .map(
                    (point) => positionForLatLng(
                      latitude: point.latitude,
                      longitude: point.longitude,
                    ),
                  )
                  .toList();

          final minX =
              offsets.map((e) => e.dx).reduce(math.min);

          final maxX =
              offsets.map((e) => e.dx).reduce(math.max);

          final minY =
              offsets.map((e) => e.dy).reduce(math.min);

          final maxY =
              offsets.map((e) => e.dy).reduce(math.max);

          final polygonVisualSize =
              math.min(
                maxX - minX,
                maxY - minY,
              );

          if (polygonVisualSize > 0) {
            baseSize =
                (polygonVisualSize * 0.08).clamp(13.0, 32.0);
          }
        }



        final finalSize =
            baseSize *
            densityFactor *
            zoomFactor;


        return finalSize.clamp(
          10.0,
          34.0,
        );
      }



       void updateCurrentScale() {
         final nextScale = transformationController.value.getMaxScaleOnAxis();

         if ((nextScale - currentMapScale).abs() < 0.03) return;

         setState(() {
           currentMapScale = nextScale;
         });
       }

       bool isSameRecord(TagRecord a, TagRecord b) {
         return a.tagId == b.tagId &&
             a.receivedDateTime == b.receivedDateTime &&
             a.receivedTime == b.receivedTime;
       }

       double metersToLatitudeDegree(double meters) {
         return meters / 111320.0;
       }

       double metersToLongitudeDegree({
         required double meters,
         required double latitude,
       }) {
         final latitudeRadians = latitude * math.pi / 180.0;
         final metersPerDegree = 111320.0 * math.cos(latitudeRadians).abs();

         if (metersPerDegree < 1) {
           return meters / 111320.0;
         }

         return meters / metersPerDegree;
       }

       List<_GpsPoint> zoneBoundaryPoints(AreaZone zone) {
         final latDelta = metersToLatitudeDegree(zone.radiusMeters);
         final lngDelta = metersToLongitudeDegree(
           meters: zone.radiusMeters,
           latitude: zone.centerLatitude,
         );

         return [
           _GpsPoint(
             latitude: zone.centerLatitude,
             longitude: zone.centerLongitude,
           ),
           _GpsPoint(
             latitude: zone.centerLatitude + latDelta,
             longitude: zone.centerLongitude,
           ),
           _GpsPoint(
             latitude: zone.centerLatitude - latDelta,
             longitude: zone.centerLongitude,
           ),
           _GpsPoint(
             latitude: zone.centerLatitude,
             longitude: zone.centerLongitude + lngDelta,
           ),
           _GpsPoint(
             latitude: zone.centerLatitude,
             longitude: zone.centerLongitude - lngDelta,
           ),
         ];
       }

      List<_GpsPoint> mapBoundaryPoints() {
        final points = <_GpsPoint>[];

        final area = widget.area;

        if (area != null) {
          points.add(
            _GpsPoint(
              latitude: area.northLatitude,
              longitude: area.westLongitude,
            ),
          );

          points.add(
            _GpsPoint(
              latitude: area.northLatitude,
              longitude: area.eastLongitude,
            ),
          );

          points.add(
            _GpsPoint(
              latitude: area.southLatitude,
              longitude: area.westLongitude,
            ),
          );

          points.add(
            _GpsPoint(
              latitude: area.southLatitude,
              longitude: area.eastLongitude,
            ),
          );

          points.add(
            _GpsPoint(
              latitude: area.centerLatitude,
              longitude: area.centerLongitude,
            ),
          );
        }

        for (final record in mapRecords) {
          points.add(
            _GpsPoint(
              latitude: record.latitude!,
              longitude: record.longitude!,
            ),
          );
        }

        for (final zone in activeZones) {
          points.addAll(
            zoneBoundaryPoints(zone),
          );
        }

        for (final polygonZone in activePolygonZones) {
          for (final point in polygonZone.points) {
            points.add(
              _GpsPoint(
                latitude: point.latitude,
                longitude: point.longitude,
              ),
            );
          }
        }

        return points;
      }

      _GpsBounds boundsForMap() {
        final points = mapBoundaryPoints();

       if(points.isEmpty){

         final area = widget.area;

         if(area != null){
           return _GpsBounds(
             minLat: area.southLatitude,
             maxLat: area.northLatitude,
             minLng: area.westLongitude,
             maxLng: area.eastLongitude,
           ).withPadding(0.15);
         }


         return const _GpsBounds(
           minLat: 31.0,
           maxLat: 32.0,
           minLng: 54.0,
           maxLng: 55.0,
         );
       }

        var minLat = points.first.latitude;
        var maxLat = points.first.latitude;
        var minLng = points.first.longitude;
        var maxLng = points.first.longitude;

        for (final point in points) {
          if (point.latitude < minLat) minLat = point.latitude;
          if (point.latitude > maxLat) maxLat = point.latitude;
          if (point.longitude < minLng) minLng = point.longitude;
          if (point.longitude > maxLng) maxLng = point.longitude;
        }

        final padding = widget.area == null ? 0.25 : 0.06;

        return _GpsBounds(
          minLat: minLat,
          maxLat: maxLat,
          minLng: minLng,
          maxLng: maxLng,
        ).withPadding(padding);
      }

       Offset positionForLatLng({
         required double latitude,
         required double longitude,
       }) {
         final bounds = boundsForMap();

         const margin = 90.0;

         final usableWidth = sceneWidth - margin * 2;
         final usableHeight = sceneHeight - margin * 2;

         final x = margin +
             ((longitude - bounds.minLng) / bounds.lngRange) * usableWidth;

         final y = margin +
             ((bounds.maxLat - latitude) / bounds.latRange) * usableHeight;

         return Offset(x, y);
       }

       Offset positionFor(TagRecord record) {
         return positionForLatLng(
           latitude: record.latitude!,
           longitude: record.longitude!,
         );
       }

       Color zoneColor(AreaZone zone) {
         switch (zone.type) {
           case AreaZoneType.stable:
             return const Color(0xFF7B3FB3);
           case AreaZoneType.pasture:
             return const Color(0xFF008B62);
           case AreaZoneType.water:
             return const Color(0xFF086EBB);
           case AreaZoneType.route:
             return const Color(0xFFE87500);
           case AreaZoneType.forbidden:
             return const Color(0xFFD32F2F);
         }
       }

       double zoneRadiusPixels(AreaZone zone) {
         final center = positionForLatLng(
           latitude: zone.centerLatitude,
           longitude: zone.centerLongitude,
         );

         final latOffset = metersToLatitudeDegree(zone.radiusMeters);
         final lngOffset = metersToLongitudeDegree(
           meters: zone.radiusMeters,
           latitude: zone.centerLatitude,
         );

         final northPoint = positionForLatLng(
           latitude: zone.centerLatitude + latOffset,
           longitude: zone.centerLongitude,
         );

         final eastPoint = positionForLatLng(
           latitude: zone.centerLatitude,
           longitude: zone.centerLongitude + lngOffset,
         );

         final radiusY = (northPoint.dy - center.dy).abs();
         final radiusX = (eastPoint.dx - center.dx).abs();

         return ((radiusX + radiusY) / 2).clamp(18.0, 520.0).toDouble();
       }

      Widget buildZoneShape(AreaZone zone) {

        final center =
            positionForLatLng(
              latitude: zone.centerLatitude,
              longitude: zone.centerLongitude,
            );


        final radius =
            zoneRadiusPixels(zone);


        final color =
            zoneColor(zone);



        return Positioned(

          left: center.dx - radius,

          top: center.dy - radius,


          child: IgnorePointer(

            child: Container(

              width: radius * 2,

              height: radius * 2,


              decoration: BoxDecoration(

                shape: BoxShape.circle,


                color:
                    color.withOpacity(0.08),


                border: Border.all(

                  color:
                      color.withOpacity(0.55),

                  width: 1.4,

                ),

              ),

            ),

          ),

        );

      }




   Widget buildAreaZoneLabel(
     AreaZone zone,
   ) {

     final center =
         positionForLatLng(
           latitude: zone.centerLatitude,
           longitude: zone.centerLongitude,
         );


     final detail =
         currentDetailLevel;



     if (detail == MapDetailLevel.low) {

       return const SizedBox.shrink();

     }



     final text =
         detail == MapDetailLevel.high
             ? zone.name
             : zone.typeText;



     return Positioned(

       left: center.dx - 45,

       top: center.dy - 15,


       child: IgnorePointer(

         child: Container(

           constraints:
               const BoxConstraints(
                 maxWidth: 100,
               ),


           padding:
               const EdgeInsets.symmetric(
                 horizontal: 6,
                 vertical: 3,
               ),


           decoration:
               BoxDecoration(

                 color:
                     Colors.white.withOpacity(0.85),


                 borderRadius:
                     BorderRadius.circular(8),


                 border:
                     Border.all(
                       color:
                           zoneColor(zone)
                               .withOpacity(0.25),
                     ),

               ),


           child: Text(

             text,

             maxLines: 1,

             overflow:
                 TextOverflow.ellipsis,


             textAlign:
                 TextAlign.center,


             style:
                 TextStyle(

               color:
                   zoneColor(zone),


               fontWeight:
                   FontWeight.bold,


               fontSize:
                   detail == MapDetailLevel.high
                       ? 7
                       : 5,

             ),

           ),

         ),

       ),

     );

   }





     Widget buildSelectedAreaShape() {
       final area = widget.area;

       if (area == null) {
         return const SizedBox.shrink();
       }

       final northWest = positionForLatLng(
         latitude: area.northLatitude,
         longitude: area.westLongitude,
       );

       final southEast = positionForLatLng(
         latitude: area.southLatitude,
         longitude: area.eastLongitude,
       );

       final left = math.min(
         northWest.dx,
         southEast.dx,
       );

       final top = math.min(
         northWest.dy,
         southEast.dy,
       );

       final width = (southEast.dx - northWest.dx).abs();
       final height = (southEast.dy - northWest.dy).abs();

       return Positioned(
         left: left,
         top: top,
         child: IgnorePointer(
           child: Container(
             width: width,
             height: height,
             decoration: BoxDecoration(
               color: const Color(0xFF008B62).withOpacity(0.018),
               borderRadius: BorderRadius.circular(10),
               border: Border.all(
                 color: const Color(0xFF008B62).withOpacity(0.35),
                 width: 1.1,
               ),
             ),
           ),
         ),
       );
     }


      Color polygonZoneColor(
        PolygonZoneType type,
      ) {
        switch (type) {
          case PolygonZoneType.grazing:
            return const Color(0xFF008B62);

          case PolygonZoneType.barn:
            return const Color(0xFF795548);

          case PolygonZoneType.forbidden:
            return const Color(0xFFD32F2F);

          case PolygonZoneType.water:
            return const Color(0xFF086EBB);

          case PolygonZoneType.custom:
            return const Color(0xFF6A1B9A);
        }
      }



      String polygonZoneLabel(
        PolygonZoneType type,
      ) {
        switch (type) {
          case PolygonZoneType.grazing:
            return 'چراگاه';

          case PolygonZoneType.barn:
            return 'آغل';

          case PolygonZoneType.forbidden:
            return 'ممنوع';

          case PolygonZoneType.water:
            return 'آبشخور';

          case PolygonZoneType.custom:
            return 'سفارشی';
        }
      }



     Widget buildPolygonZoneShape(
       PolygonZone zone,
     ) {

       if (!zone.isValid) {
         return const SizedBox.shrink();
       }


       final offsets =
           zone.points
               .map(
                 (point) => positionForLatLng(
                   latitude: point.latitude,
                   longitude: point.longitude,
                 ),
               )
               .toList();



       final minX =
           offsets
               .map((e) => e.dx)
               .reduce(math.min);


       final maxX =
           offsets
               .map((e) => e.dx)
               .reduce(math.max);



       final minY =
           offsets
               .map((e) => e.dy)
               .reduce(math.min);


       final maxY =
           offsets
               .map((e) => e.dy)
               .reduce(math.max);



              const padding = 20.0;



      final localPoints =
          offsets.map(
            (point) => Offset(
              point.dx - minX + padding,
              point.dy - minY + padding,
            ),
          ).toList();



    return Positioned(

      left: minX - padding,

      top: minY - padding,


      width:
          (maxX - minX) + (padding * 2),


      height:
          (maxY - minY) + (padding * 2),


      child: GestureDetector(

        onTap: () {

          zoomToPolygonZone(zone);

        },


        child: SizedBox(

          width:
              (maxX - minX) + (padding * 2),


          height:
              (maxY - minY) + (padding * 2),


          child: CustomPaint(

            painter: _PolygonZonePainter(

              offsets: localPoints,

              color:
                  polygonZoneColor(
                    zone.type,
                  ),

            ),

          ),

        ),

      ),

    );

    }


    Widget buildPolygonZoneLabel(
      PolygonZone zone,
    ) {

      final offsets = zone.points
          .map(
            (point) => positionForLatLng(
              latitude: point.latitude,
              longitude: point.longitude,
            ),
          )
          .toList();


      if (offsets.isEmpty) {
        return const SizedBox.shrink();
      }



      double centerX = 0;
      double centerY = 0;


      for (final point in offsets) {

        centerX += point.dx;
        centerY += point.dy;

      }


      final center = Offset(
        centerX / offsets.length,
        centerY / offsets.length,
      );



      final detail =
          currentDetailLevel;



      // در Zoom کم هیچ متنی نداریم

      if (detail == MapDetailLevel.low) {

        return const SizedBox.shrink();

      }



      String text;



      if(detail == MapDetailLevel.medium){

        text =
            polygonZoneLabel(
              zone.type,
            );

      }

      else {

        text =
            zone.name;

      }



      return Positioned(

        left: center.dx - 50,

        top: center.dy - 18,


        child: IgnorePointer(

          child: Container(

            constraints:
                const BoxConstraints(
                 maxWidth: 80,
                ),


            padding:
                const EdgeInsets.symmetric(
                 horizontal: 4,
                 vertical: 2,
                ),


            decoration:
                BoxDecoration(

                  color:
                      Colors.white.withOpacity(
                        0.88,
                      ),

                  borderRadius:
                      BorderRadius.circular(10),


                  border:
                      Border.all(
                        color:
                            polygonZoneColor(
                              zone.type,
                            ).withOpacity(.25),
                      ),

                ),


            child: Text(

              text,

              maxLines: 1,

              overflow:
                  TextOverflow.ellipsis,


              textAlign:
                  TextAlign.center,


              style:
                  TextStyle(

               fontSize:
                   detail == MapDetailLevel.high
                       ? 8
                       : 6,


                fontWeight:
                    FontWeight.bold,


                color:
                    polygonZoneColor(
                      zone.type,
                    ),

              ),

            ),

          ),

        ),

      );

    }


      void fitAll(Size size) {
      if (size.width <= 0 ||
              size.height <= 0) {
        return;
      }

        final scaleX = size.width / sceneWidth;
        final scaleY = size.height / sceneHeight;
        final baseScale = scaleX < scaleY ? scaleX : scaleY;
        final scale = baseScale * 0.96;

        final dx = (size.width - sceneWidth * scale) / 2;
        final dy = (size.height - sceneHeight * scale) / 2;

        transformationController.value = Matrix4.identity()
          ..translate(dx, dy)
          ..scale(scale);

        currentMapScale = scale;
      }

       void scheduleFitAll(Size size) {
         if (didFitInitialView) return;

         didFitInitialView = true;

         WidgetsBinding.instance.addPostFrameCallback((_) {
           if (!mounted) return;
           fitAll(size);
         });
       }

       void zoomToRecord(TagRecord record) {
         if (viewportSize.width <= 0 || viewportSize.height <= 0) return;

         final point = positionFor(record);
         const zoomScale = 3.4;

         final dx = viewportSize.width / 2 - point.dx * zoomScale;
         final dy = viewportSize.height / 2 - point.dy * zoomScale;

         setState(() {
           selectedRecord = record;
           transformationController.value = Matrix4.identity()
             ..translate(dx, dy)
             ..scale(zoomScale);

           currentMapScale = zoomScale;
         });
       }





        void zoomToPolygonZone(
          PolygonZone zone,
        ) {

          if (zone.points.isEmpty) {
            return;
          }


          final points =
              zone.points
                  .map(
                    (point) =>
                        positionForLatLng(
                          latitude: point.latitude,
                          longitude: point.longitude,
                        ),
                  )
                  .toList();



          final minX =
              points.map((e) => e.dx).reduce(math.min);

          final maxX =
              points.map((e) => e.dx).reduce(math.max);


          final minY =
              points.map((e) => e.dy).reduce(math.min);


          final maxY =
              points.map((e) => e.dy).reduce(math.max);



          final centerX =
              (minX + maxX) / 2;


          final centerY =
              (minY + maxY) / 2;



          final polygonWidth =
              maxX - minX;


          final polygonHeight =
              maxY - minY;



          if (viewportSize.width <= 0 ||
              viewportSize.height <= 0) {
            return;
          }



          final scaleX =
              viewportSize.width /
              polygonWidth;


          final scaleY =
              viewportSize.height /
              polygonHeight;



          final targetScale =
              math.min(scaleX, scaleY) * 0.65;



          final scale =
              targetScale.clamp(
                1.2,
                5.0,
              );



          final dx =
              viewportSize.width / 2 -
              centerX * scale;


          final dy =
              viewportSize.height / 2 -
              centerY * scale;



          transformationController.value =
              Matrix4.identity()
                ..translate(dx, dy)
                ..scale(scale);



          currentMapScale = scale;

        }



      void zoomToCluster(
        CamelCluster cluster,
      ) {

        final center =
            positionForLatLng(
              latitude: cluster.latitude,
              longitude: cluster.longitude,
            );


        const zoomScale = 2.8;


        final dx =
            viewportSize.width / 2 -
            center.dx * zoomScale;


        final dy =
            viewportSize.height / 2 -
            center.dy * zoomScale;



        transformationController.value =
            Matrix4.identity()
              ..translate(dx, dy)
              ..scale(zoomScale);



        setState(() {

          currentMapScale = zoomScale;

        });

      }



      void changeZoom(double factor) {
        if (viewportSize.width <= 0 || viewportSize.height <= 0) return;

        final currentScale =
            transformationController.value.getMaxScaleOnAxis();

        final nextScale =
            (currentScale * factor).clamp(0.20, 8.0).toDouble();

        final center = Offset(
          viewportSize.width / 2,
          viewportSize.height / 2,
        );

        final sceneCenter =
            transformationController.toScene(center);

        final dx = center.dx - sceneCenter.dx * nextScale;
        final dy = center.dy - sceneCenter.dy * nextScale;

        transformationController.value = Matrix4.identity()
          ..translate(dx, dy)
          ..scale(nextScale);

        currentMapScale = nextScale;
      }

       Future<void> copySelectedGps(BuildContext context) async {
         final record = selectedRecord;

         if (record == null || record.latitude == null || record.longitude == null) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(
               content: Text('مختصاتی برای کپی وجود ندارد.'),
             ),
           );
           return;
         }

         final text =
             '${record.latitude!.toStringAsFixed(6)},${record.longitude!.toStringAsFixed(6)}';

         await Clipboard.setData(
           ClipboardData(text: text),
         );

         if (!context.mounted) return;

         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(
             content: Text('مختصات GPS کپی شد.'),
           ),
         );
       }

       Widget buildTagMarker(TagRecord record) {

         final point = positionFor(record);


         final isLowBattery =
             record.isBatteryLow;


         final isUnlocked =
             record.lock == 0;



         final color = isUnlocked
             ? const Color(0xFFD32F2F)
             : isLowBattery
                 ? const Color(0xFFE87500)
                 : const Color(0xFF008B62);



         final detail =
             currentDetailLevel;


        final markerSize =
             detail == MapDetailLevel.high
                 ? 30.0
              : detail == MapDetailLevel.medium
                  ? 24.0
                  : 18.0;


final bool showCamelNumber =
    currentMapScale > 2.0;





         return Positioned(

           left: point.dx - markerSize / 2,

           top: point.dy - markerSize / 2,


           child: GestureDetector(

             onTap: () {

               zoomToRecord(record);

             },


             child: Column(

               mainAxisSize:
                   MainAxisSize.min,


               children: [


                 Container(

                   width: markerSize,

                   height: markerSize,


                   decoration: BoxDecoration(

                     color: color,

                     shape:
                         BoxShape.circle,


                     border: Border.all(

                       color: Colors.white,

                       width: detail ==
                               MapDetailLevel.high
                           ? 3
                           : 1.5,

                     ),


                     boxShadow: [

                       BoxShadow(

                         color:
                             color.withOpacity(0.35),

                         blurRadius: 8,

                       )

                     ],

                   ),


                   child: detail ==
                           MapDetailLevel.low

                       ? null

                       : Icon(

                           isUnlocked
                               ? Icons.lock_open_rounded
                               : Icons.pets_rounded,


                           color:
                               Colors.white,


                           size:
                               detail ==
                                       MapDetailLevel.high
                                   ? 18
                                   : 12,

                         ),

                 ),



                 if (showCamelNumber)

                   Container(

                     margin:
                         const EdgeInsets.only(
                           top: 2,
                         ),


                     padding:
                         const EdgeInsets.symmetric(
                           horizontal: 3,
                         ),


                     decoration:
                         BoxDecoration(

                           color:
                               Colors.white.withOpacity(
                                 0.85,
                               ),

                           borderRadius:
                               BorderRadius.circular(5),

                         ),


                     child: showCamelNumber

                         ? Text(
                             record.camelNo,

                             style: TextStyle(
                               color: const Color(0xFF062C5E),
                               fontWeight: FontWeight.bold,
                               fontSize:
                                   detail == MapDetailLevel.high
                                       ? 9
                                       : 7,
                             ),

                           )

                         : const SizedBox.shrink(),
                   ),

               ],

             ),

           ),

         );

       }






       Widget buildClusterMarker(
         CamelCluster cluster,
       ) {

         final point =
             positionForLatLng(

               latitude:
                   cluster.latitude,

               longitude:
                   cluster.longitude,

             );

             final clusterSize =
                 currentMapScale < 1
                     ? 28.0
                     : currentMapScale < 2
                         ? 34.0
                         : 42.0;


         return Positioned(

        left: point.dx - clusterSize / 2,
        top: point.dy - clusterSize / 2,


           child: GestureDetector(

             onTap: () {

               zoomToCluster(cluster);

             },


             child: Container(

           width: clusterSize,
           height: clusterSize,

               decoration: BoxDecoration(

                 color:
                     const Color(0xFF086EBB),


                 shape:
                     BoxShape.circle,


                 border:
                     Border.all(
                       color: Colors.white,
                       width: 3,
                     ),


                 boxShadow: [

                   BoxShadow(

                     color:
                         Colors.black.withOpacity(.25),

                     blurRadius: 10,

                   )

                 ],

               ),


               child: Center(

                 child: Text(

                   cluster.count.toString(),


                   style:
                       const TextStyle(

                     color:
                         Colors.white,

                     fontWeight:
                         FontWeight.bold,

                     fontSize: 14,

                   ),

                 ),

               ),

             ),

           ),

         );

       }




       Widget buildSelectedRecordPanel(BuildContext context) {
         final record = selectedRecord;

         if (record == null) {
           return Container(
             width: double.infinity,
             padding: const EdgeInsets.all(12),
             decoration: BoxDecoration(
               color: const Color(0xFFF5F7FA),
               borderRadius: BorderRadius.circular(14),
             ),
             child: const Text(
               'برای دیدن جزئیات، روی یک تگ روی نقشه بزن.',
               textAlign: TextAlign.center,
               style: TextStyle(
                 color: Colors.black54,
                 fontWeight: FontWeight.bold,
               ),
             ),
           );
         }

         final gpsText =
             '${record.latitude!.toStringAsFixed(6)}, ${record.longitude!.toStringAsFixed(6)}';

         return Container(
           width: double.infinity,
           padding: const EdgeInsets.all(12),
           decoration: BoxDecoration(
             color: const Color(0xFFEAF8F2),
             borderRadius: BorderRadius.circular(14),
             border: Border.all(
               color: const Color(0xFFC8EBDD),
             ),
           ),
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Row(
                 children: [
                   CircleAvatar(
                     radius: 20,
                     backgroundColor: const Color(0xFF008B62),
                     child: Text(
                       record.camelNo,
                       style: const TextStyle(
                         color: Colors.white,
                         fontWeight: FontWeight.bold,
                       ),
                     ),
                   ),
                   const SizedBox(width: 10),
                   Expanded(
                     child: Text(
                       record.camelName,
                       maxLines: 1,
                       overflow: TextOverflow.ellipsis,
                       style: const TextStyle(
                         color: Color(0xFF062C5E),
                         fontWeight: FontWeight.bold,
                         fontSize: 16,
                       ),
                     ),
                   ),
                   IconButton(
                     onPressed: () {
                       copySelectedGps(context);
                     },
                     icon: const Icon(Icons.copy_rounded),
                     tooltip: 'کپی مختصات',
                   ),
                   IconButton(
                     onPressed: () {
                       Navigator.of(context).push(
                         MaterialPageRoute(
                           builder: (_) =>_MapTagDetailPage(record: record)
                         ),
                       );
                     },
                     icon: const Icon(Icons.open_in_new_rounded),
                     tooltip: 'جزئیات تگ',
                   ),
                 ],
               ),
               const SizedBox(height: 8),
               Directionality(
                 textDirection: TextDirection.ltr,
                 child: Text(
                   gpsText,
                   maxLines: 1,
                   overflow: TextOverflow.ellipsis,
                   style: const TextStyle(
                     color: Color(0xFF008B62),
                     fontWeight: FontWeight.bold,
                     fontSize: 12,
                   ),
                 ),
               ),
               const SizedBox(height: 6),
               Text(
                 '${record.locationName} / باتری: ${record.batteryText}',
                 maxLines: 1,
                 overflow: TextOverflow.ellipsis,
                 style: const TextStyle(
                   color: Colors.black54,
                   fontSize: 12,
                 ),
               ),
             ],
           ),
         );
       }

       Widget buildZoomChip(TagRecord record) {
         final isSelected =
             selectedRecord != null && isSameRecord(selectedRecord!, record);

         return Padding(
           padding: const EdgeInsets.only(left: 8),
           child: ChoiceChip(
             selected: isSelected,
             avatar: CircleAvatar(
               backgroundColor:
                   isSelected ? const Color(0xFF062C5E) : const Color(0xFFF3E8D6),
               child: Text(
                 record.camelNo,
                 style: TextStyle(
                   color: isSelected ? Colors.white : const Color(0xFF062C5E),
                   fontSize: 10,
                   fontWeight: FontWeight.bold,
                 ),
               ),
             ),
             label: Text(
               record.camelName,
               maxLines: 1,
               overflow: TextOverflow.ellipsis,
             ),
             onSelected: (_) {
               zoomToRecord(record);
             },
           ),
         );
       }

       @override
       Widget build(BuildContext context) {
     if (mapRecords.isEmpty &&
         activeZones.isEmpty &&
         activePolygonZones.isEmpty &&
         widget.area == null) {
       return const SizedBox.shrink();
     }

         return Column(
           children: [
             SingleChildScrollView(
               scrollDirection: Axis.horizontal,
               child: Row(
                 children: [
                   OutlinedButton.icon(
                     onPressed: () {
                       fitAll(viewportSize);
                     },
                     icon: const Icon(Icons.center_focus_strong_rounded),
                     label: const Text('نمای همه'),
                   ),
                   const SizedBox(width: 8),
                   ...mapRecords.map(buildZoomChip),
                 ],
               ),
             ),
             const SizedBox(height: 10),
             SizedBox(
             height:
                 math.min(
                   MediaQuery.of(context).size.height * 0.55,
                   560,
                 ),
               width: double.infinity,
               child: LayoutBuilder(
                 builder: (context, constraints) {
                   viewportSize = Size(
                     constraints.maxWidth,
                     constraints.maxHeight,
                   );

                   scheduleFitAll(viewportSize);

                   return Stack(
                     children: [
                       Container(
                         decoration: BoxDecoration(
                           color: const Color(0xFFEAF2FF),
                           borderRadius: BorderRadius.circular(18),
                           border: Border.all(
                             color: const Color(0xFFD3E2F7),
                           ),
                         ),
                         clipBehavior: Clip.hardEdge,
                         child: InteractiveViewer(
                           transformationController: transformationController,
                           minScale: 0.25,
                           maxScale: 6,
                           boundaryMargin: const EdgeInsets.all(900),
                           constrained: false,
                           child: SizedBox(
                             width: sceneWidth,
                             height: sceneHeight,
                             child: Stack(
                               clipBehavior: Clip.none,
                              children: [
                                Positioned.fill(
                                   child: CustomPaint(
                                     painter: _MapGridOnlyPainter(),
                                   ),
                                 ),

                                buildSelectedAreaShape(),

                                ...activePolygonZones.map(buildPolygonZoneShape),

                                ...activePolygonZones.map(buildPolygonZoneLabel),

                                ...activeZones.map(buildZoneShape),

                                ...activeZones.map(buildAreaZoneLabel),



                              if (showClusters)

                                ...camelClusters.map(
                                  buildClusterMarker,
                                )

                              else

                                ...mapRecords.map(
                                  buildTagMarker,
                                ),
                              ],
                             ),
                           ),
                         ),
                       ),
                       Positioned(
                         top: 10,
                         right: 10,
                         child: Container(
                           padding: const EdgeInsets.symmetric(
                             horizontal: 9,
                             vertical: 6,
                           ),
                           decoration: BoxDecoration(
                             color: Colors.white.withOpacity(0.92),
                             borderRadius: BorderRadius.circular(12),
                           ),
                           child: Text(
                            '${mapRecords.length} شتر • ${activePolygonZones.length} محدوده داخلی',
                             style: const TextStyle(
                               color: Color(0xFF062C5E),
                               fontWeight: FontWeight.bold,
                               fontSize: 12,
                             ),
                           ),
                         ),
                       ),
                       Positioned(
                         top: 10,
                         left: 10,
                         child: Column(
                           children: [
                             _MapControlButton(
                               icon: Icons.add_rounded,
                               onTap: () {
                                 changeZoom(1.25);
                               },
                             ),
                             const SizedBox(height: 6),
                             _MapControlButton(
                               icon: Icons.remove_rounded,
                               onTap: () {
                                 changeZoom(0.8);
                               },
                             ),
                             const SizedBox(height: 6),
                             _MapControlButton(
                               icon: Icons.center_focus_strong_rounded,
                               onTap: () {
                                 fitAll(viewportSize);
                               },
                             ),
                           ],
                         ),
                       ),
                       const Positioned(
                         bottom: 10,
                         left: 10,
                         child: Text(
                           'با دو انگشت زوم کن / روی تگ بزن',
                           style: TextStyle(
                             color: Colors.black45,
                             fontWeight: FontWeight.bold,
                             fontSize: 11,
                           ),
                         ),
                       ),
                     ],
                   );
                 },
               ),
             ),
             const SizedBox(height: 10),
             buildSelectedRecordPanel(context),
           ],
         );
       }
     }

     class _GpsBounds {
       final double minLat;
       final double maxLat;
       final double minLng;
       final double maxLng;

       const _GpsBounds({
         required this.minLat,
         required this.maxLat,
         required this.minLng,
         required this.maxLng,
       });

       double get latRange {
         final value = maxLat - minLat;
         if (value.abs() < 0.000001) return 0.000001;
         return value;
       }

       double get lngRange {
         final value = maxLng - minLng;
         if (value.abs() < 0.000001) return 0.000001;
         return value;
       }

       _GpsBounds withPadding(double percent) {
         final latPad = latRange * percent;
         final lngPad = lngRange * percent;

         return _GpsBounds(
           minLat: minLat - latPad,
           maxLat: maxLat + latPad,
           minLng: minLng - lngPad,
           maxLng: maxLng + lngPad,
         );
       }
     }

     class _GpsPoint {
       final double latitude;
       final double longitude;

       const _GpsPoint({
         required this.latitude,
         required this.longitude,
       });
     }

     class _MapControlButton extends StatelessWidget {

       final IconData icon;
       final VoidCallback onTap;


       const _MapControlButton({
         required this.icon,
         required this.onTap,
       });


       @override
       Widget build(BuildContext context) {

         return GestureDetector(

           onTap: onTap,

           child: Container(

             width: 46,
             height: 46,


             decoration: BoxDecoration(

               color: Colors.white.withOpacity(0.92),

               borderRadius:
                   BorderRadius.circular(16),


               boxShadow: [

                 BoxShadow(

                   color:
                       Colors.black.withOpacity(0.12),

                   blurRadius: 14,

                   offset:
                       const Offset(0,4),
                 )

               ],
             ),


             child: Icon(
               icon,
               color:
                   const Color(0xFF062C5E),
               size:22,
             ),

           ),

         );
       }
     }

    class _PolygonZonePainter extends CustomPainter {
      final List<Offset> offsets;
      final Color color;


      const _PolygonZonePainter({
        required this.offsets,
        required this.color,
      });

      @override
      void paint(
        Canvas canvas,
        Size size,
      ) {
        if (offsets.length < 3) {
          return;
        }

        final path = Path()
          ..moveTo(
            offsets.first.dx,
            offsets.first.dy,
          );

        for (int i = 1; i < offsets.length; i++) {
          path.lineTo(
            offsets[i].dx,
            offsets[i].dy,
          );
        }

        path.close();


        final fillPaint = Paint()
          ..color = color.withOpacity(0.075)
          ..style = PaintingStyle.fill;


        final borderPaint = Paint()
          ..color = color.withOpacity(0.70)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6;


        canvas.drawPath(
          path,
          fillPaint,
        );

        canvas.drawPath(
          path,
          borderPaint,
        );


        for (final point in offsets) {

          canvas.drawCircle(
            point,
            2.6,
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.fill,
          );


          canvas.drawCircle(
            point,
            2.6,
            Paint()
              ..color = color.withOpacity(0.85)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2,
          );
        }

      }



      Rect _calculateBounds() {

        double minX = offsets.first.dx;
        double maxX = offsets.first.dx;

        double minY = offsets.first.dy;
        double maxY = offsets.first.dy;


        for (final point in offsets) {

          if (point.dx < minX) {
            minX = point.dx;
          }

          if (point.dx > maxX) {
            maxX = point.dx;
          }

          if (point.dy < minY) {
            minY = point.dy;
          }

          if (point.dy > maxY) {
            maxY = point.dy;
          }

        }


        return Rect.fromLTRB(
          minX,
          minY,
          maxX,
          maxY,
        );

      }




      Offset _calculateCenter() {

        double totalX = 0;
        double totalY = 0;


        for (final point in offsets) {

          totalX += point.dx;
          totalY += point.dy;

        }


        return Offset(

          totalX / offsets.length,

          totalY / offsets.length,

        );

      }




      String _shortText(
        String text,
        int maxLength,
      ) {

        final clean =
            text.trim();


        if (clean.length <= maxLength) {

          return clean;

        }


        return '${clean.substring(0, maxLength)}…';

      }




     @override
     bool shouldRepaint(
       covariant _PolygonZonePainter oldDelegate,
     ) {

       return oldDelegate.offsets != offsets ||
           oldDelegate.color != color;

     }
    }



class _MapGridOnlyPainter extends CustomPainter {


  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {


    // رنگ پایه خاکی نقشه

    final backgroundPaint =
        Paint()
          ..color =
              const Color(0xFFF4F1E8)
          ..style =
              PaintingStyle.fill;


    canvas.drawRect(
      Offset.zero & size,
      backgroundPaint,
    );



    // خطوط خیلی نرم مسیر

    final roadPaint =
        Paint()
          ..color =
              const Color(0xFFD8D2C3)
          ..strokeWidth = 1
          ..style =
              PaintingStyle.stroke;



    const step = 90.0;



    for (
      double x = 0;
      x < size.width;
      x += step
    ) {

      canvas.drawLine(
        Offset(x,0),
        Offset(
          x,
          size.height,
        ),
        roadPaint,
      );

    }



    for (
      double y = 0;
      y < size.height;
      y += step
    ) {

      canvas.drawLine(
        Offset(0,y),
        Offset(
          size.width,
          y,
        ),
        roadPaint,
      );

    }




    // چند مسیر منحنی تزئینی

    final pathPaint =
        Paint()
          ..color =
              const Color(0xFFC8C0AF)
          ..strokeWidth = 2
          ..style =
              PaintingStyle.stroke;


    final path = Path();


    path.moveTo(
      0,
      size.height * 0.65,
    );


    path.quadraticBezierTo(
      size.width * 0.35,
      size.height * 0.45,
      size.width,
      size.height * 0.55,
    );


    canvas.drawPath(
      path,
      pathPaint,
    );

  }



  @override
  bool shouldRepaint(
    covariant CustomPainter oldDelegate,
  ) {

    return false;

  }

}


class GpsRecordCard extends StatelessWidget {
  final TagRecord record;
  final String dateText;
  final List<AreaZone> zones;

  const GpsRecordCard({
    super.key,
    required this.record,
    required this.dateText,
    this.zones = const [],
  });

  bool get hasGps {
    return record.latitude != null && record.longitude != null;
  }

  ZoneCheckResult? get zoneResult {
    if (!hasGps || zones.isEmpty) {
      return null;
    }

    return ZoneCheckService.checkRecord(
      record: record,
      zones: zones,
    );
  }

  Future<void> copyGps(BuildContext context) async {
    if (!hasGps) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('برای این رکورد GPS ثبت نشده است.'),
        ),
      );
      return;
    }

    final text =
        '${record.latitude!.toStringAsFixed(6)},${record.longitude!.toStringAsFixed(6)}';

    await Clipboard.setData(
      ClipboardData(text: text),
    );

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('مختصات GPS کپی شد.'),
      ),
    );
  }

  String get gpsText {
    if (!hasGps) return 'GPS ثبت نشده';

    return '${record.latitude!.toStringAsFixed(5)}, ${record.longitude!.toStringAsFixed(5)}';
  }

  Color get mainStatusColor {
    final result = zoneResult;

    if (record.lock == 0) {
      return const Color(0xFFD32F2F);
    }

    if (result?.isInsideForbiddenZone == true) {
      return const Color(0xFFD32F2F);
    }

    if (result?.isOutsideAllowedZones == true) {
      return const Color(0xFFE87500);
    }

    if (record.isBatteryLow) {
      return const Color(0xFFE87500);
    }

    return const Color(0xFF008B62);
  }

  IconData get mainStatusIcon {
    final result = zoneResult;

    if (record.lock == 0) {
      return Icons.lock_open_rounded;
    }

    if (result?.isInsideForbiddenZone == true) {
      return Icons.block_rounded;
    }

    if (result?.isOutsideAllowedZones == true) {
      return Icons.warning_rounded;
    }

    return Icons.gps_fixed_rounded;
  }

  String zoneStatusText(ZoneCheckResult? result) {
    if (!hasGps) {
      return 'GPS برای این تگ ثبت نشده است.';
    }

    if (zones.isEmpty) {
      return 'هنوز محدوده‌ای تعریف نشده است.';
    }

    if (result == null) {
      return 'وضعیت محدوده نامشخص است.';
    }

    if (result.isInsideForbiddenZone) {
      final names = result.forbiddenZones.map((zone) => zone.name).join('، ');
      return 'داخل منطقه ممنوع: $names';
    }

    if (result.isOutsideAllowedZones) {
      return 'خارج از محدوده مجاز';
    }

    if (result.insideZones.isNotEmpty) {
      return 'داخل محدوده: ${result.insideZonesText}';
    }

    return 'خارج از محدوده‌های تعریف‌شده';
  }

  Color zoneStatusColor(ZoneCheckResult? result) {
    if (!hasGps) {
      return Colors.grey;
    }

    if (zones.isEmpty) {
      return const Color(0xFF086EBB);
    }

    if (result?.isInsideForbiddenZone == true) {
      return const Color(0xFFD32F2F);
    }

    if (result?.isOutsideAllowedZones == true) {
      return const Color(0xFFE87500);
    }

    if (result?.insideZones.isNotEmpty == true) {
      return const Color(0xFF008B62);
    }

    return Colors.grey;
  }

  IconData zoneStatusIcon(ZoneCheckResult? result) {
    if (!hasGps) {
      return Icons.gps_off_rounded;
    }

    if (zones.isEmpty) {
      return Icons.layers_clear_rounded;
    }

    if (result?.isInsideForbiddenZone == true) {
      return Icons.block_rounded;
    }

    if (result?.isOutsideAllowedZones == true) {
      return Icons.warning_rounded;
    }

    if (result?.insideZones.isNotEmpty == true) {
      return Icons.check_circle_rounded;
    }

    return Icons.help_outline_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final result = zoneResult;
    final isLowBattery = record.isBatteryLow;
    final isUnlocked = record.lock == 0;

    final zoneColor = zoneStatusColor(result);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _MapTagDetailPage(record: record)
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: mainStatusColor.withOpacity(0.22),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: mainStatusColor.withOpacity(0.12),
                  child: Text(
                    record.camelNo,
                    style: TextStyle(
                      color: mainStatusColor,
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
                        record.camelName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          record.tagId,
                          style: const TextStyle(
                            color: Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: mainStatusColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    mainStatusIcon,
                    color: mainStatusColor,
                    size: 22,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _GpsCardMiniBadge(
                    icon: Icons.battery_full_rounded,
                    text: record.batteryText,
                    color: isLowBattery
                        ? const Color(0xFFD32F2F)
                        : const Color(0xFF008B62),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _GpsCardMiniBadge(
                    icon: isUnlocked
                        ? Icons.lock_open_rounded
                        : Icons.lock_rounded,
                    text: record.lockText,
                    color: isUnlocked
                        ? const Color(0xFFD32F2F)
                        : const Color(0xFF008B62),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                color: hasGps
                    ? const Color(0xFFEAF8F2)
                    : const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    hasGps
                        ? Icons.my_location_rounded
                        : Icons.gps_not_fixed_rounded,
                    size: 18,
                    color: hasGps
                        ? const Color(0xFF008B62)
                        : const Color(0xFFE87500),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        gpsText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: hasGps
                              ? const Color(0xFF008B62)
                              : const Color(0xFFE87500),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: hasGps
                        ? () {
                            copyGps(context);
                          }
                        : null,
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text(
                      'کپی',
                      style: TextStyle(fontSize: 11),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: const Size(0, 30),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: zoneColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: zoneColor.withOpacity(0.20),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    zoneStatusIcon(result),
                    color: zoneColor,
                    size: 19,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      zoneStatusText(result),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: zoneColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: Text(
                    record.locationName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  dateText,
                  style: const TextStyle(
                    color: Colors.black45,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GpsCardMiniBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _GpsCardMiniBadge({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 17,
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}




class AreaZonesPage extends StatefulWidget {
  const AreaZonesPage({super.key});

  @override
  State<AreaZonesPage> createState() => _AreaZonesPageState();
}

class _AreaZonesPageState extends State<AreaZonesPage> {
  bool isLoading = true;
  List<AreaZone> zones = [];

  @override
  void initState() {
    super.initState();
    loadZones();
  }

  Future<void> loadZones() async {
    final loadedZones = await AreaZoneService.loadZones();

    if (!mounted) return;

    setState(() {
      zones = loadedZones;
      isLoading = false;
    });
  }

  Color zoneColor(AreaZoneType type) {
    switch (type) {
      case AreaZoneType.stable:
        return const Color(0xFF7B3FB3);
      case AreaZoneType.pasture:
        return const Color(0xFF008B62);
      case AreaZoneType.water:
        return const Color(0xFF086EBB);
      case AreaZoneType.route:
        return const Color(0xFFE87500);
      case AreaZoneType.forbidden:
        return const Color(0xFFD32F2F);
    }
  }

  String zoneTypeText(AreaZoneType type) {
    switch (type) {
      case AreaZoneType.stable:
        return 'آغل';
      case AreaZoneType.pasture:
        return 'چراگاه';
      case AreaZoneType.water:
        return 'آبشخور';
      case AreaZoneType.route:
        return 'مسیر';
      case AreaZoneType.forbidden:
        return 'منطقه ممنوع';
    }
  }

  Future<void> showAddZoneDialog() async {
    final nameController = TextEditingController();
    final radiusController = TextEditingController(text: '300');

    AreaZoneType selectedType = AreaZoneType.pasture;
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                title: const Text('تعریف محدوده جدید'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'مرکز محدوده از GPS فعلی گوشی گرفته می‌شود. برای تعریف محدوده، داخل همان محل بایست و دکمه ذخیره را بزن.',
                        style: TextStyle(
                          color: Colors.black54,
                          height: 1.7,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'نام محدوده',
                          hintText: 'مثلاً آغل اصلی',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<AreaZoneType>(
                        value: selectedType,
                        decoration: const InputDecoration(
                          labelText: 'نوع محدوده',
                          border: OutlineInputBorder(),
                        ),
                        items: AreaZoneType.values.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(zoneTypeText(type)),
                          );
                        }).toList(),
                        onChanged: isSaving
                            ? null
                            : (value) {
                                if (value == null) return;

                                setDialogState(() {
                                  selectedType = value;
                                });
                              },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: radiusController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'شعاع محدوده بر حسب متر',
                          hintText: 'مثلاً 300',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (isSaving) ...[
                        const SizedBox(height: 14),
                        const LinearProgressIndicator(),
                        const SizedBox(height: 8),
                        const Text(
                          'در حال دریافت GPS و ذخیره محدوده...',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isSaving
                        ? null
                        : () {
                            Navigator.of(dialogContext).pop();
                          },
                    child: const Text('انصراف'),
                  ),
                  ElevatedButton.icon(
                    onPressed: isSaving
                        ? null
                        : () async {
                            final name = nameController.text.trim();
                            final radiusText = radiusController.text.trim();
                            final radius = double.tryParse(radiusText);

                            if (name.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('نام محدوده را وارد کن.'),
                                ),
                              );
                              return;
                            }

                            if (radius == null || radius <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('شعاع محدوده معتبر نیست.'),
                                ),
                              );
                              return;
                            }

                            setDialogState(() {
                              isSaving = true;
                            });

                            final locationResult =
                                await LocationService.getCurrentLocation();

                            if (!locationResult.success ||
                                locationResult.latitude == null ||
                                locationResult.longitude == null) {
                              setDialogState(() {
                                isSaving = false;
                              });

                              if (!mounted) return;

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(locationResult.message),
                                ),
                              );
                              return;
                            }

                            final now = DateTime.now();

                            final zone = AreaZone(
                              id: 'zone-${now.millisecondsSinceEpoch}',
                              name: name,
                              type: selectedType,
                              centerLatitude: locationResult.latitude!,
                              centerLongitude: locationResult.longitude!,
                              radiusMeters: radius,
                              isActive: true,
                              createdAt: now.toIso8601String(),
                            );

                            await AreaZoneService.addZone(zone);

                            if (!mounted) return;

                            Navigator.of(dialogContext).pop();

                            await loadZones();

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('محدوده جدید ذخیره شد.'),
                              ),
                            );
                          },
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('ذخیره محدوده'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
    radiusController.dispose();
  }

  Future<void> deleteZone(AreaZone zone) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('حذف محدوده'),
            content: Text('آیا محدوده «${zone.name}» حذف شود؟'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
                child: const Text('انصراف'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
                icon: const Icon(Icons.delete_rounded),
                label: const Text('حذف'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    );

    if (confirm != true) return;

    await AreaZoneService.deleteZone(zone.id);

    await loadZones();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('محدوده حذف شد.'),
      ),
    );
  }

  Future<void> toggleZone(AreaZone zone) async {
    final updatedZone = zone.copyWith(
      isActive: !zone.isActive,
    );

    await AreaZoneService.updateZone(updatedZone);

    await loadZones();
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = zones.where((zone) => zone.isActive).length;
    final forbiddenCount = zones
        .where((zone) => zone.type == AreaZoneType.forbidden)
        .length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text('مدیریت محدوده‌ها'),
          centerTitle: true,
          backgroundColor: const Color(0xFF062C5E),
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              onPressed: loadZones,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: showAddZoneDialog,
          backgroundColor: const Color(0xFF008B62),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_location_alt_rounded),
          label: const Text('محدوده جدید'),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: loadZones,
                    child: ListView(
                      padding: const EdgeInsets.all(14),
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: MapSummaryCard(
                                title: 'کل محدوده‌ها',
                                value: zones.length.toString(),
                                icon: Icons.layers_rounded,
                                color: const Color(0xFF086EBB),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: MapSummaryCard(
                                title: 'فعال',
                                value: activeCount.toString(),
                                icon: Icons.check_circle_rounded,
                                color: const Color(0xFF008B62),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: MapSummaryCard(
                                title: 'ممنوعه',
                                value: forbiddenCount.toString(),
                                icon: Icons.block_rounded,
                                color: const Color(0xFFD32F2F),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: MapSummaryCard(
                                title: 'GPS',
                                value: 'مرکز',
                                icon: Icons.gps_fixed_rounded,
                                color: const Color(0xFF7B3FB3),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: _mapCardDecoration(),
                          child: const Text(
                            'برای تعریف محدوده جدید، داخل محل موردنظر بایست و دکمه «محدوده جدید» را بزن. مرکز محدوده از GPS گوشی ذخیره می‌شود.',
                            style: TextStyle(
                              color: Colors.black54,
                              height: 1.7,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (zones.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: _mapCardDecoration(),
                            child: const Column(
                              children: [
                                Icon(
                                  Icons.layers_clear_rounded,
                                  size: 54,
                                  color: Color(0xFF086EBB),
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'هنوز محدوده‌ای تعریف نشده است.',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'با دکمه محدوده جدید، آغل، چراگاه، آبشخور یا منطقه ممنوع را ثبت کن.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.black54,
                                    height: 1.7,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ...zones.map(
                            (zone) => AreaZoneCard(
                              zone: zone,
                              color: zoneColor(zone.type),
                              onToggle: () {
                                toggleZone(zone);
                              },
                              onDelete: () {
                                deleteZone(zone);
                              },
                            ),
                          ),
                        const SizedBox(height: 90),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class AreaZoneCard extends StatelessWidget {
  final AreaZone zone;
  final Color color;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const AreaZoneCard({
    super.key,
    required this.zone,
    required this.color,
    required this.onToggle,
    required this.onDelete,
  });

  String get gpsText {
    return '${zone.centerLatitude.toStringAsFixed(6)}, ${zone.centerLongitude.toStringAsFixed(6)}';
  }

  IconData get zoneIcon {
    switch (zone.type) {
      case AreaZoneType.stable:
        return Icons.home_work_rounded;
      case AreaZoneType.pasture:
        return Icons.grass_rounded;
      case AreaZoneType.water:
        return Icons.water_drop_rounded;
      case AreaZoneType.route:
        return Icons.alt_route_rounded;
      case AreaZoneType.forbidden:
        return Icons.block_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: _mapCardDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withOpacity(0.12),
                child: Icon(
                  zoneIcon,
                  color: color,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      zone.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${zone.typeText} / شعاع ${zone.radiusMeters.toStringAsFixed(0)} متر',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: zone.isActive,
                onChanged: (_) {
                  onToggle();
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 9,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.my_location_rounded,
                  size: 18,
                  color: Color(0xFF086EBB),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      gpsText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF086EBB),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red,
                  ),
                  tooltip: 'حذف محدوده',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}



class _MapTagDetailPage extends StatelessWidget {
  final TagRecord record;

  const _MapTagDetailPage({
    required this.record,
  });

  @override
  Widget build(BuildContext context) {
    final isLowBattery = record.isBatteryLow;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: Text('جزئیات تگ ${record.tagId}'),
          centerTitle: true,
          backgroundColor: const Color(0xFF062C5E),
          foregroundColor: Colors.white,
        ),
        body: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: _mapCardDecoration(),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 38,
                    backgroundColor: const Color(0xFFF3E8D6),
                    child: Text(
                      record.camelNo,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    record.tagId,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF062C5E),
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    record.camelName,
                    style: const TextStyle(
                      color: Colors.black54,
                    ),
                  ),

                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isLowBattery
                          ? Colors.red.withOpacity(0.10)
                          : Colors.green.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isLowBattery
                          ? 'نیازمند بررسی باتری'
                          : 'وضعیت عادی',
                      style: TextStyle(
                        color: isLowBattery
                            ? Colors.red
                            : Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            Container(
              decoration: _mapCardDecoration(),
              child: Column(
                children: [
                  _MapDetailRow(
                    icon: Icons.battery_full_rounded,
                    title: 'وضعیت شارژ باتری',
                    value: record.batteryText,
                    valueColor: isLowBattery
                        ? Colors.red
                        : Colors.green,
                  ),

                  _MapDetailRow(
                    icon: Icons.access_time_rounded,
                    title: 'آخرین زمان دریافت',
                    value: record.receivedTime,
                  ),

                  _MapDetailRow(
                    icon: Icons.pets_rounded,
                    title: 'آخرین محل ثبت‌شده',
                    value: record.locationName,
                  ),

                  _MapDetailRow(
                    icon: Icons.network_check_rounded,
                    title: 'قدرت سیگنال',
                    value: '${record.signalPower} از ۵',
                  ),

                  if (record.state != null)
                    _MapDetailRow(
                      icon: Icons.sensors_rounded,
                      title: 'State خام دستگاه',
                      value: record.state.toString(),
                    ),

                  if (record.lock != null)
                    _MapDetailRow(
                      icon: Icons.lock_rounded,
                      title: 'وضعیت بسته بودن تگ',
                      value: record.lockText,
                    ),

                  if (record.counterLock != null)
                    _MapDetailRow(
                      icon: Icons.confirmation_number_rounded,
                      title: 'تعداد باز و بسته شدن تگ',
                      value: record.counterLock.toString(),
                    ),

                  if (record.count != null)
                    _MapDetailRow(
                      icon: Icons.numbers_rounded,
                      title: 'Count خام دستگاه',
                      value: record.count.toString(),
                    ),

                  _MapDetailRow(
                    icon: Icons.cloud_upload_rounded,
                    title: 'وضعیت ارسال',
                    value: record.sendStatusText,
                    valueColor: record.isGood
                        ? Colors.green
                        : Colors.orange,
                  ),

                  _MapDetailRow(
                    icon: Icons.my_location_rounded,
                    title: 'عرض جغرافیایی',
                    value: record.latitude == null
                        ? 'ثبت نشده'
                        : record.latitude!.toStringAsFixed(6),
                  ),

                  _MapDetailRow(
                    icon: Icons.explore_rounded,
                    title: 'طول جغرافیایی',
                    value: record.longitude == null
                        ? 'ثبت نشده'
                        : record.longitude!.toStringAsFixed(6),
                  ),

                  _MapDetailRow(
                    icon: Icons.gps_fixed_rounded,
                    title: 'دقت GPS',
                    value: record.accuracy == null
                        ? 'ثبت نشده'
                        : '${record.accuracy!.toStringAsFixed(1)} متر',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapDetailRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color? valueColor;

  const _MapDetailRow({
    required this.icon,
    required this.title,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Color(0xFFE8EDF3),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: const Color(0xFF062C5E),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}


