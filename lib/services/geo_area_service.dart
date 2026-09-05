import '../models/geo_area.dart';

class GeoAreaService {
  static final List<GeoArea> areas = [
   GeoArea(
     id: 1,
     name: 'ساغند',
     province: 'یزد',
     city: 'اردکان',

     northLatitude: 32.45,
     southLatitude: 32.15,

     eastLongitude: 55.40,
     westLongitude: 54.90,

     centerLatitude: 32.313,
     centerLongitude: 55.159,

     defaultZoom: 12,
     mapImagePath: '',
   ),

    GeoArea(
      id: 2,
      name: 'شهر یزد',
      province: 'یزد',
      city: 'یزد',

      northLatitude: 32.05,
      southLatitude: 31.75,

      eastLongitude: 54.55,
      westLongitude: 54.20,

      centerLatitude: 31.897,
      centerLongitude: 54.367,

      defaultZoom: 12,
      mapImagePath: '',
    ),
  ];

  static List<GeoArea> getAll() {
    return areas;
  }

  static List<String> getProvinces() {
    return areas.map((e) => e.province).toSet().toList();
  }

  static List<GeoArea> getByProvince(
    String province,
  ) {
    return areas.where((e) => e.province == province).toList();
  }
}