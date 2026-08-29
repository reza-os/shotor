import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path_helper;
import 'package:path_provider/path_provider.dart';

import '../models/camel_detail.dart';
import '../models/camel_profile.dart';
import '../services/camel_detail_service.dart';
import '../services/camel_profile_service.dart';

class CamelDetailFormPage extends StatefulWidget {
  const CamelDetailFormPage({super.key});

  @override
  State<CamelDetailFormPage> createState() => _CamelDetailFormPageState();
}

class _CamelDetailFormPageState extends State<CamelDetailFormPage> {
  bool isLoading = true;
  bool isSaving = false;

  List<CamelProfile> profiles = [];
  CamelProfile? selectedProfile;

  final searchController = TextEditingController();

  final fatherController = TextEditingController();
  final motherController = TextEditingController();
  final ageController = TextEditingController();
  final weightController = TextEditingController();
  final colorController = TextEditingController();
  final breedController = TextEditingController();
  final healthController = TextEditingController();
  final descriptionController = TextEditingController();
  final ImagePicker imagePicker = ImagePicker();

  String photoPath = '';

  @override
  void initState() {
    super.initState();
    loadProfiles();
  }

  @override
  void dispose() {
    searchController.dispose();
    fatherController.dispose();
    motherController.dispose();
    ageController.dispose();
    weightController.dispose();
    colorController.dispose();
    breedController.dispose();
    healthController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> loadProfiles() async {
    final loadedProfiles = await CamelProfileService.loadProfiles();

    if (!mounted) return;

    setState(() {
      profiles = loadedProfiles;
      isLoading = false;
    });
  }

  List<CamelProfile> get filteredProfiles {
    final query = searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      return profiles;
    }

    return profiles.where((profile) {
      return profile.tagId.toLowerCase().contains(query) ||
          profile.camelNo.toLowerCase().contains(query) ||
          profile.camelName.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> selectProfile(CamelProfile profile) async {
    final detail = await CamelDetailService.getDetailByTagId(profile.tagId) ??
        CamelDetail.emptyForTag(profile.tagId);

    if (!mounted) return;

    setState(() {
      selectedProfile = profile;

      fatherController.text = detail.fatherName;
      motherController.text = detail.motherName;
      ageController.text = detail.ageYears?.toString() ?? '';
      weightController.text = detail.weightKg?.toString() ?? '';
      colorController.text = detail.color;
      breedController.text = detail.breed;
      healthController.text = detail.healthStatus;
      descriptionController.text = detail.description;
      photoPath = detail.photoPath;
    });
  }

  Future<void> saveForm() async {
    final profile = selectedProfile;

    if (profile == null) {
      showMessage('اول یک شتر را انتخاب کن.');
      return;
    }

    setState(() {
      isSaving = true;
    });

    final now = DateTime.now();

    final detail = CamelDetail(
      tagId: profile.tagId,
      fatherName: fatherController.text.trim(),
      motherName: motherController.text.trim(),
      ageYears: int.tryParse(ageController.text.trim()),
      weightKg: double.tryParse(weightController.text.trim()),
      color: colorController.text.trim(),
      breed: breedController.text.trim(),
      healthStatus: healthController.text.trim(),
      description: descriptionController.text.trim(),
      photoPath: photoPath,
      createdAt: now,
      updatedAt: now,
    );

    await CamelDetailService.saveDetail(detail);

    if (!mounted) return;

    setState(() {
      isSaving = false;
    });

    showMessage('اطلاعات شتر ذخیره شد.');
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  Future<void> showPhotoSourceSheet() async {
    final profile = selectedProfile;

    if (profile == null) {
      showMessage('اول یک شتر را انتخاب کن.');
      return;
    }

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'انتخاب عکس شتر',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFEAF2FF),
                      child: Icon(
                        Icons.photo_library_rounded,
                        color: Color(0xFF086EBB),
                      ),
                    ),
                    title: const Text('انتخاب از گالری'),
                    onTap: () {
                      Navigator.of(context).pop();
                      pickCamelPhoto(ImageSource.gallery);
                    },
                  ),
                  ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFEAF8F2),
                      child: Icon(
                        Icons.camera_alt_rounded,
                        color: Color(0xFF008B62),
                      ),
                    ),
                    title: const Text('گرفتن عکس با دوربین'),
                    onTap: () {
                      Navigator.of(context).pop();
                      pickCamelPhoto(ImageSource.camera);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> pickCamelPhoto(ImageSource source) async {
    final profile = selectedProfile;

    if (profile == null) {
      showMessage('اول یک شتر را انتخاب کن.');
      return;
    }

    try {
      final pickedFile = await imagePicker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 1400,
      );

      if (pickedFile == null) {
        return;
      }

      final savedPath = await saveImageToAppFolder(
        pickedFile: pickedFile,
        tagId: profile.tagId,
      );

      if (!mounted) return;

      setState(() {
        photoPath = savedPath;
      });

      showMessage('عکس انتخاب شد. برای ثبت نهایی، دکمه ذخیره اطلاعات شتر را بزن.');
    } catch (error) {
      showMessage('خطا در انتخاب عکس: $error');
    }
  }

  Future<String> saveImageToAppFolder({
    required XFile pickedFile,
    required String tagId,
  }) async {
    final appDir = await getApplicationDocumentsDirectory();

    final photosDir = Directory(
      path_helper.join(
        appDir.path,
        'camel_photos',
      ),
    );

    if (!await photosDir.exists()) {
      await photosDir.create(
        recursive: true,
      );
    }

    final cleanTagId = tagId.replaceAll(
      RegExp(r'[^a-zA-Z0-9_-]'),
      '_',
    );

    final extension = path_helper.extension(pickedFile.path).isEmpty
        ? '.jpg'
        : path_helper.extension(pickedFile.path);

    final fileName =
        '${cleanTagId}_${DateTime.now().millisecondsSinceEpoch}$extension';

    final savedFile = File(
      path_helper.join(
        photosDir.path,
        fileName,
      ),
    );

    await File(pickedFile.path).copy(savedFile.path);

    return savedFile.path;
  }

  void removeSelectedPhoto() {
    setState(() {
      photoPath = '';
    });

    showMessage('عکس از فرم حذف شد. برای ثبت نهایی، ذخیره را بزن.');
  }

  Widget buildProfileSelector() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'انتخاب شتر',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: searchController,
            onChanged: (_) {
              setState(() {});
            },
            decoration: InputDecoration(
              hintText: 'جستجو با نام، شماره یا تگ',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: const Color(0xFFF5F7FA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 230,
            child: filteredProfiles.isEmpty
                ? const Center(
                    child: Text(
                      'شتری پیدا نشد.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredProfiles.length,
                    itemBuilder: (context, index) {
                      final profile = filteredProfiles[index];
                      final isSelected =
                          selectedProfile?.tagId == profile.tagId;

                      return ListTile(
                        selected: isSelected,
                        selectedTileColor: const Color(0xFFEAF2FF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        leading: CircleAvatar(
                          backgroundColor: isSelected
                              ? const Color(0xFF086EBB)
                              : const Color(0xFFEAF2FF),
                          child: Icon(
                            Icons.pets_rounded,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF086EBB),
                          ),
                        ),
                        title: Text(
                          profile.camelName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          '${profile.tagId} / شماره ${profile.camelNo}',
                          textDirection: TextDirection.ltr,
                        ),
                        onTap: () {
                          selectProfile(profile);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget buildTextInput({
    required String title,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: title,
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

  Widget buildPhotoSection() {
    final hasPhoto = photoPath.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'عکس شتر',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF062C5E),
            ),
          ),
          const SizedBox(height: 10),
          if (hasPhoto)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.file(
                File(photoPath),
                width: double.infinity,
                height: 220,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    color: const Color(0xFFFFEBEE),
                    child: const Text(
                      'فایل عکس پیدا نشد یا قابل نمایش نیست.',
                      style: TextStyle(
                        color: Color(0xFFD32F2F),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'هنوز عکسی برای این شتر انتخاب نشده است.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: showPhotoSourceSheet,
                  icon: const Icon(Icons.add_a_photo_rounded),
                  label: Text(
                    hasPhoto ? 'تغییر عکس' : 'افزودن عکس',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF086EBB),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              if (hasPhoto) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: removeSelectedPhoto,
                  icon: const Icon(
                    Icons.delete_rounded,
                    color: Color(0xFFD32F2F),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget buildFormCard() {
    final profile = selectedProfile;

    if (profile == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: cardDecoration(),
        child: const Text(
          'برای ثبت اطلاعات، ابتدا یک شتر را از لیست بالا انتخاب کن.',
          style: TextStyle(
            color: Colors.black54,
            height: 1.7,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'فرم اطلاعات ${profile.camelName}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Color(0xFF062C5E),
            ),
          ),
          const SizedBox(height: 12),
          buildTextInput(
            title: 'نام پدر',
            controller: fatherController,
          ),
          buildTextInput(
            title: 'نام مادر',
            controller: motherController,
          ),
          buildTextInput(
            title: 'سن / سال',
            controller: ageController,
            keyboardType: TextInputType.number,
          ),
          buildTextInput(
            title: 'وزن / کیلوگرم',
            controller: weightController,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
            ),
          ),
          buildTextInput(
            title: 'رنگ',
            controller: colorController,
          ),
          buildTextInput(
            title: 'نژاد',
            controller: breedController,
          ),
          buildTextInput(
            title: 'وضعیت سلامت',
            controller: healthController,
          ),
          buildTextInput(
            title: 'توضیحات',
            controller: descriptionController,
            maxLines: 3,
          ),
         buildPhotoSection(),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: isSaving ? null : saveForm,
              icon: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded),
              label: const Text('ذخیره اطلاعات شتر'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF086EBB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          title: const Text('ثبت و ویرایش شتر'),
          centerTitle: true,
        ),
        body: isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  buildProfileSelector(),
                  const SizedBox(height: 14),
                  buildFormCard(),
                  const SizedBox(height: 30),
                ],
              ),
      ),
    );
  }
}