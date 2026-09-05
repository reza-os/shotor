import 'package:flutter/material.dart';

import '../models/geo_area.dart';
import '../services/geo_area_service.dart';
import '../services/current_geo_area_service.dart';



class GeoAreaSelectionPage extends StatefulWidget {
  const GeoAreaSelectionPage({super.key});

  @override
  State<GeoAreaSelectionPage> createState() =>
      _GeoAreaSelectionPageState();
}


class _GeoAreaSelectionPageState
    extends State<GeoAreaSelectionPage> {

  String? selectedProvince;

  GeoArea? selectedArea;


  @override
  Widget build(BuildContext context) {

    final provinces =
        GeoAreaService.getProvinces();


    final areas =
        selectedProvince == null
            ? <GeoArea>[]
            : GeoAreaService.getByProvince(
                selectedProvince!,
              );


    return Directionality(

      textDirection: TextDirection.rtl,

      child: Scaffold(

        backgroundColor:
            const Color(0xFFF5F7FA),


        appBar: AppBar(

          title: const Text(
            'انتخاب محدوده فعالیت',
          ),

          centerTitle: true,

        ),


        body: ListView(

          padding:
              const EdgeInsets.all(16),


          children: [


            Container(

              padding:
                  const EdgeInsets.all(16),


              decoration: BoxDecoration(

                color: Colors.white,

                borderRadius:
                    BorderRadius.circular(20),

              ),


              child: Column(

                crossAxisAlignment:
                    CrossAxisAlignment.start,


                children: [


                  const Text(

                    'انتخاب استان',

                    style: TextStyle(

                      fontWeight:
                          FontWeight.bold,

                      fontSize: 16,

                    ),

                  ),


                  const SizedBox(height: 12),



                  DropdownButtonFormField<String>(

                    value:
                        selectedProvince,


                    decoration:
                        InputDecoration(

                      filled: true,

                      fillColor:
                          const Color(0xFFF5F7FA),


                      border:
                          OutlineInputBorder(

                        borderRadius:
                            BorderRadius.circular(14),

                        borderSide:
                            BorderSide.none,

                      ),

                    ),



                    hint:
                        const Text(
                          'استان را انتخاب کنید',
                        ),



                    items:
                        provinces.map((province){

                      return DropdownMenuItem(

                        value: province,

                        child:
                            Text(province),

                      );

                    }).toList(),



                    onChanged: (value){

                      setState(() {

                        selectedProvince =
                            value;

                        selectedArea =
                            null;

                      });

                    },


                  ),



                  const SizedBox(height: 25),



                  const Text(

                    'محدوده فعالیت',

                    style: TextStyle(

                      fontWeight:
                          FontWeight.bold,

                      fontSize: 16,

                    ),

                  ),



                  const SizedBox(height: 12),



                  if (selectedProvince == null)

                    Container(

                      width:
                          double.infinity,

                      padding:
                          const EdgeInsets.all(16),

                      decoration:
                          BoxDecoration(

                        color:
                            const Color(0xFFF5F7FA),

                        borderRadius:
                            BorderRadius.circular(14),

                      ),

                      child:
                          const Text(

                            'ابتدا استان را انتخاب کنید',

                            textAlign:
                                TextAlign.center,

                            style:
                                TextStyle(

                              color:
                                  Colors.black54,

                            ),

                          ),

                    )

                  else

                    ...areas.map((area){


                      final isSelected =
                          selectedArea?.id ==
                              area.id;


                      return Container(

                        margin:
                            const EdgeInsets.only(
                              bottom: 10,
                            ),


                        decoration:
                            BoxDecoration(

                          color:

                              isSelected

                                  ? const Color(
                                      0xFFEAF2FF,
                                    )

                                  : Colors.white,


                          borderRadius:
                              BorderRadius.circular(16),


                          border:
                              Border.all(

                            color:

                                isSelected

                                    ? const Color(
                                        0xFF086EBB,
                                      )

                                    : Colors.black12,

                          ),

                        ),



                        child:
                            ListTile(

                          leading:
                              const CircleAvatar(

                            backgroundColor:
                                Color(0xFFEAF2FF),

                            child:
                                Icon(

                              Icons.location_on_rounded,

                              color:
                                  Color(0xFF086EBB),

                            ),

                          ),


                          title:
                              Text(

                            area.name,

                            style:
                                const TextStyle(

                              fontWeight:
                                  FontWeight.bold,

                            ),

                          ),


                          subtitle:
                              Text(

                            '${area.city} - ${area.province}',

                          ),


                          trailing:

                              isSelected

                                  ? const Icon(

                                      Icons.check_circle,

                                      color:
                                          Colors.green,

                                    )

                                  : null,



                          onTap: (){

                            setState(() {

                              selectedArea =
                                  area;

                            });

                          },


                        ),

                      );


                    }),



                  const SizedBox(height: 20),



                 SizedBox(
                   width: double.infinity,
                   height: 52,
                   child: ElevatedButton(
                     onPressed: selectedArea == null
                         ? null
                         : () async {
                             await CurrentGeoAreaService.save(
                               selectedArea!,
                             );

                             if (!mounted) return;

                             Navigator.pop(
                               context,
                               selectedArea,
                             );
                           },
                     child: const Text(
                       'تایید محدوده',
                     ),
                   ),
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