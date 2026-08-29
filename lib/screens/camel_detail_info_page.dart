import 'package:flutter/material.dart';

import '../models/camel_detail.dart';
import '../models/camel_profile.dart';

class CamelDetailInfoPage extends StatelessWidget {
  final CamelProfile? profile;
  final CamelDetail detail;

  final String? camelName;
  final String? camelNo;
  final String? tagId;

  const CamelDetailInfoPage({
    super.key,
    required CamelProfile this.profile,
    required this.detail,
  })  : camelName = null,
        camelNo = null,
        tagId = null;

  const CamelDetailInfoPage.byValues({
    super.key,
    required this.detail,
    required this.camelName,
    required this.camelNo,
    required this.tagId,
  }) : profile = null;

  @override
  Widget build(BuildContext context) {
    final displayCamelName =
        profile?.camelName ?? camelName ?? 'شتر';

    final displayCamelNo =
        profile?.camelNo ?? camelNo ?? '-';

    final displayTagId =
        profile?.tagId ?? tagId ?? detail.tagId;

    final lines = detail.toDescriptionLines(
      camelName: displayCamelName,
      camelNo: displayCamelNo,
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text('توضیحات شتر'),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: Color(0xFFEAF2FF),
                    child: Icon(
                      Icons.pets_rounded,
                      color: Color(0xFF086EBB),
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayCamelName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$displayTagId / شماره $displayCamelNo',
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'شرح اطلاعات ثبت‌شده',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF062C5E),
                    ),
                  ),

                  const SizedBox(height: 12),

                  ...lines.map(
                    (line) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '• ',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                line,
                                style: const TextStyle(
                                  height: 1.8,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
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