import 'dart:io';

import 'package:flutter/material.dart';

import '../models/camel_detail.dart';
import '../models/camel_profile.dart';
import '../services/camel_detail_service.dart';
import '../services/camel_profile_service.dart';
import 'camel_detail_info_page.dart';

class CamelTablePage extends StatefulWidget {
  const CamelTablePage({super.key});

  @override
  State<CamelTablePage> createState() => _CamelTablePageState();
}

class _CamelTablePageState extends State<CamelTablePage> {
  bool isLoading = true;

  List<CamelProfile> profiles = [];
  Map<String, CamelDetail> detailsByTagId = {};

  String expandedPhotoTagId = '';

  final searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadTable();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadTable() async {
    final loadedProfiles = await CamelProfileService.loadProfiles();
    final loadedDetails = await CamelDetailService.loadAllDetails(
      limit: 10000,
    );

    final map = <String, CamelDetail>{};

    for (final detail in loadedDetails) {
      map[detail.tagId] = detail;
    }

    if (!mounted) return;

    setState(() {
      profiles = loadedProfiles;
      detailsByTagId = map;
      isLoading = false;
    });
  }

  List<CamelProfile> get filteredProfiles {
    final query = searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      return profiles;
    }

    return profiles.where((profile) {
      final detail = detailsByTagId[profile.tagId];

      return profile.tagId.toLowerCase().contains(query) ||
          profile.camelNo.toLowerCase().contains(query) ||
          profile.camelName.toLowerCase().contains(query) ||
          (detail?.fatherName.toLowerCase().contains(query) ?? false) ||
          (detail?.motherName.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  void openInfoPage(CamelProfile profile) {
    final detail = detailsByTagId[profile.tagId] ??
        CamelDetail.emptyForTag(profile.tagId);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CamelDetailInfoPage(
          profile: profile,
          detail: detail,
        ),
      ),
    );
  }

  void togglePhoto(String tagId) {
    setState(() {
      if (expandedPhotoTagId == tagId) {
        expandedPhotoTagId = '';
      } else {
        expandedPhotoTagId = tagId;
      }
    });
  }

  Widget buildSearchBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: TextField(
        controller: searchController,
        onChanged: (_) {
          setState(() {});
        },
        decoration: InputDecoration(
          hintText: 'جستجو با نام، شماره، تگ، پدر یا مادر',
          prefixIcon: const Icon(Icons.search_rounded),
          filled: true,
          fillColor: const Color(0xFFF5F7FA),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget buildHeaderRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF062C5E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              'ID',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'نام شتر',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'عکس',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'اطلاعات',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildPhotoPreview(CamelDetail? detail) {
    if (detail == null || detail.photoPath.trim().isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Text(
          'برای این شتر هنوز عکسی ثبت نشده است.',
          style: TextStyle(
            color: Color(0xFF8A4B00),
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    final file = File(detail.photoPath);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.file(
        file,
        height: 220,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return const Padding(
            padding: EdgeInsets.all(14),
            child: Text(
              'فایل عکس پیدا نشد یا قابل نمایش نیست.',
              style: TextStyle(
                color: Color(0xFFD32F2F),
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget buildTableRow(CamelProfile profile) {
    final detail = detailsByTagId[profile.tagId];
    final isExpanded = expandedPhotoTagId == profile.tagId;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  profile.camelNo,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  profile.camelName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 3,
                child: TextButton(
                  onPressed: () {
                    togglePhoto(profile.tagId);
                  },
                  child: Text(
                    isExpanded ? 'بستن عکس' : 'مشاهده عکس',
                    style: const TextStyle(
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: TextButton(
                  onPressed: () {
                    openInfoPage(profile);
                  },
                  child: const Text(
                    'مشاهده اطلاعات',
                    style: TextStyle(
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (isExpanded) buildPhotoPreview(detail),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleProfiles = filteredProfiles;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text('جدول شترها'),
          centerTitle: true,
          actions: [
            IconButton(
              onPressed: loadTable,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  buildSearchBox(),
                  buildHeaderRow(),
                  if (visibleProfiles.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(
                        child: Text(
                          'شتری برای نمایش پیدا نشد.',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ),
                    )
                  else
                    ...visibleProfiles.map(buildTableRow),
                  const SizedBox(height: 30),
                ],
              ),
      ),
    );
  }
}