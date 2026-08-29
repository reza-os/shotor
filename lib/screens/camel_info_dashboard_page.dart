import 'package:flutter/material.dart';

import 'camel_detail_form_page.dart';
import 'camel_table_page.dart';

class CamelInfoDashboardPage extends StatelessWidget {
  const CamelInfoDashboardPage({super.key});

  Widget buildOptionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Widget page,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => page,
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        margin: const EdgeInsets.only(bottom: 14),
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
            CircleAvatar(
              radius: 28,
              backgroundColor: color.withOpacity(0.12),
              child: Icon(
                icon,
                color: color,
                size: 30,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.black54,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_left_rounded),
          ],
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
          title: const Text('اطلاعات شترها'),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF2FF),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'در این بخش اطلاعات تکمیلی هر شتر ثبت می‌شود. هر شتر یک فرم اختصاصی و یک عکس اصلی خواهد داشت.',
                style: TextStyle(
                  color: Color(0xFF003B7A),
                  fontWeight: FontWeight.bold,
                  height: 1.8,
                ),
              ),
            ),
            buildOptionCard(
              context: context,
              title: 'ثبت و ویرایش شتر',
              subtitle: 'انتخاب شتر، تکمیل فرم و ذخیره اطلاعات',
              icon: Icons.edit_note_rounded,
              color: const Color(0xFF086EBB),
              page: const CamelDetailFormPage(),
            ),
            buildOptionCard(
              context: context,
              title: 'جدول شترها',
              subtitle: 'مشاهده لیست شترها، عکس و توضیحات ثبت‌شده',
              icon: Icons.table_chart_rounded,
              color: const Color(0xFF008B62),
              page: const CamelTablePage(),
            ),
          ],
        ),
      ),
    );
  }
}