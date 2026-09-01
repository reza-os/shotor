import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/herd_settings.dart';


class HerdSettingsService {

  static const String _key = 'herd_settings';


  static Future<HerdSettings> load() async {

    final prefs =
        await SharedPreferences.getInstance();


    final data = prefs.getString(_key);


    if(data == null){
      return const HerdSettings();
    }


    return HerdSettings.fromJson(
      jsonDecode(data),
    );

  }



  static Future<void> save(
      HerdSettings settings,
      ) async {

    final prefs =
        await SharedPreferences.getInstance();


    await prefs.setString(
      _key,
      jsonEncode(
        settings.toJson(),
      ),
    );

  }

}