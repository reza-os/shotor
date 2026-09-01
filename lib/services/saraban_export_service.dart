import 'dart:convert';

import '../models/herd_settings.dart';
import '../models/tag_record.dart';


class SarabanExportService {


  static String createJson({

    required HerdSettings herd,

    required String shepherdName,

    required String shepherdId,

    required String deviceId,

    required List<TagRecord> records,

  }) {


    final data = {

      "herdInfo": {

        "herdId": herd.herdId,

        "herdName": herd.herdName,

        "camelCount": herd.camelCount,

      },


      "shepherdInfo": {

        "id": shepherdId,

        "name": shepherdName,

      },


      "deviceInfo": {

        "deviceId": deviceId,

        "exportTime":
            DateTime.now().toIso8601String(),

      },


      "summary": {

        "totalRecords":
            records.length,

        "seenCamels":
            records.map((e)=>e.tagId).toSet().length,

      },


      "records":

      records.map((record){

        return {

          "tagId":
              record.tagId,

          "camelName":
              record.camelName,

          "camelNo":
              record.camelNo,

          "battery":
              record.batteryPercent,

          "lock":
              record.lock,

          "counterLock":
              record.counterLock,

          "latitude":
              record.latitude,

          "longitude":
              record.longitude,

          "receivedAt":
              record.receivedDateTime,

        };

      }).toList(),


    };


    return const JsonEncoder.withIndent('  ')
        .convert(data);

  }

}