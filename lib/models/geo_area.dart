class GeoArea {
  final int id;

  final String name;
  final String province;
  final String city;


  // محدوده واقعی جغرافیایی
  final double northLatitude;
  final double southLatitude;

  final double eastLongitude;
  final double westLongitude;


  // مرکز فعلی برای باز کردن اولیه نقشه
  final double centerLatitude;
  final double centerLongitude;


  final double defaultZoom;

  final String mapImagePath;


  const GeoArea({

    required this.id,

    required this.name,
    required this.province,
    required this.city,


    required this.northLatitude,
    required this.southLatitude,

    required this.eastLongitude,
    required this.westLongitude,


    required this.centerLatitude,
    required this.centerLongitude,


    required this.defaultZoom,

    required this.mapImagePath,

  });



  factory GeoArea.fromMap(
      Map<String, dynamic> map,
      ) {

    return GeoArea(

      id: map['id'] ?? 0,


      name:
          map['name'] ?? '',

      province:
          map['province'] ?? '',

      city:
          map['city'] ?? '',



      northLatitude:
          (map['northLatitude'] ?? 0)
              .toDouble(),

      southLatitude:
          (map['southLatitude'] ?? 0)
              .toDouble(),


      eastLongitude:
          (map['eastLongitude'] ?? 0)
              .toDouble(),

      westLongitude:
          (map['westLongitude'] ?? 0)
              .toDouble(),



      centerLatitude:
          (map['centerLatitude'] ?? 0)
              .toDouble(),


      centerLongitude:
          (map['centerLongitude'] ?? 0)
              .toDouble(),



      defaultZoom:
          (map['defaultZoom'] ?? 12)
              .toDouble(),


      mapImagePath:
          map['mapImagePath'] ?? '',

    );

  }



  Map<String, dynamic> toMap() {

    return {

      'id': id,


      'name': name,
      'province': province,
      'city': city,


      'northLatitude': northLatitude,
      'southLatitude': southLatitude,


      'eastLongitude': eastLongitude,
      'westLongitude': westLongitude,


      'centerLatitude': centerLatitude,
      'centerLongitude': centerLongitude,


      'defaultZoom': defaultZoom,


      'mapImagePath': mapImagePath,

    };

  }
}