import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/camel_detail.dart';
import '../models/camel_profile.dart';
import 'camel_detail_service.dart';
import 'camel_profile_service.dart';

/// Portable ZIP export is intentionally limited to registered camels, their
/// manual details, and photos. GPS telemetry, passwords and WiFi credentials
/// are NOT exported. No raw absolute photo paths are included.
class CamelBackupService {
  static const _channel = MethodChannel('saraban/portable_storage');
  static const _format = 'saraban.camel.backup';
  static const _version = 1;
  static const _maxArchiveBytes = 120 * 1024 * 1024;
  static const _maxImageBytes = 15 * 1024 * 1024;
  static const _maxTotalImages = 110 * 1024 * 1024;
  static const _maxCamels = 10000;
  static const _imageFilePattern = r'^photos/[0-9]{1,5}\.(?:jpg|jpeg|png|webp)$';
  static bool _busy = false;

  static Future<bool> hasSelectedFolder() async =>
      (await _channel.invokeMethod<bool>('hasFolder')) ?? false;

  /// Android SAF: the user selects a permitted parent folder (e.g. Documents).
  /// The app creates Shotor/عکس‌ها and Shotor/فایل‌های بک‌آپ there.
  static Future<bool> selectFolder() async =>
      (await _channel.invokeMethod<bool>('selectFolder')) ?? false;

  static Future<String> _publishFile(
      File source, String folder, String name) async {
    final uri = await _channel.invokeMethod<String>('copyFile', {
      'folder': folder,
      'name': name,
      'path': source.path,
    });
    if (uri == null) throw StateError('فایل در پوشه انتخاب‌شده ذخیره نشد.');
    return uri;
  }

  static String _safeExt(String path) {
    final ext = p.extension(path).toLowerCase();
    return const ['.jpg', '.jpeg', '.png', '.webp'].contains(ext)
        ? ext : '.jpg';
  }

  static String _safeTag(String tag) =>
      tag.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

  /// Store a visible extra photo copy in the user's file manager folder, if
  /// permission was granted earlier. Original private photo remains untouched.
  static Future<void> mirrorPhoto(String tagId, String path) async {
    if (!await hasSelectedFolder()) return;
    final file = File(path);
    if (!await file.exists()) return;
    await _publishFile(file, 'photos',
        '${_safeTag(tagId)}${_safeExt(path)}');
  }

  static Future<BackupInspection> inspect(File zipFile) async {
    final bundle = await _parse(zipFile);
    return BackupInspection(bundle.profiles.length,
        bundle.details.where((e) => e.photoPath.isNotEmpty).length,
        bundle.details.length, bundle.createdAt);
  }

  static Future<BackupExportResult> exportBackup() async {
    if (_busy) throw StateError('عملیات پشتیبان‌گیری دیگری در حال اجراست.');
    _busy = true;
    try {
      if (!await hasSelectedFolder()) {
        throw StateError('ابتدا محل پوشه بک‌آپ را در فایل‌منیجر انتخاب کنید.');
      }
      final profiles = await CamelProfileService.loadProfiles();
      if (profiles.length > _maxCamels) {
        throw StateError('تعداد شترهای ثبت‌شده بیش از سقف مجاز است.');
      }
      final ids = profiles.map((e) => e.tagId).toSet();
      final details = <CamelDetail>[];
      // Use bounded database paging, not an unbounded query.
      for (var offset = 0;; offset += 250) {
        final page = await CamelDetailService.loadAllDetails(limit: 250,
            offset: offset);
        details.addAll(page.where((d) => ids.contains(d.tagId)));
        if (page.length < 250) break;
      }
      final tmp = await getTemporaryDirectory();
      final stamp = DateTime.now().toUtc().toIso8601String()
          .replaceAll(RegExp(r'[^0-9]'), '').substring(0, 17);
      final name = 'shotor_camels_$stamp.zip';
      final zipPath = p.join(tmp.path, name);
      final encoder = ZipFileEncoder();
      encoder.create(zipPath);
      var done = false;
      var photoCount = 0;
      var totalPhotoBytes = 0;
      final exportedDetails = <Map<String, dynamic>>[];
      final photoCopies = <({String tagId, String path})>[];
      try {
        for (var i = 0; i < details.length; i++) {
          final detail = details[i];
          final data = detail.toMap()..remove('id')..remove('photoPath');
          String? relativePhoto;
          final candidate = File(detail.photoPath);
          if (detail.photoPath.isNotEmpty && !await candidate.exists()) {
            throw StateError('عکس شتر ${detail.tagId} یافت نشد. '
                'ابتدا عکس را اصلاح یا حذف کنید، سپس بک‌آپ بگیرید.');
          }
          if (detail.photoPath.isNotEmpty) {
            final bytes = await candidate.length();
            if (bytes > _maxImageBytes || bytes <= 0 ||
                totalPhotoBytes + bytes > _maxTotalImages) {
              throw StateError('حجم عکس شتر ${detail.tagId} بیش از حد مجاز است.');
            }
            relativePhoto = 'photos/$i${_safeExt(detail.photoPath)}';
            await encoder.addFile(candidate, relativePhoto);
            photoCopies.add((tagId: detail.tagId, path: candidate.path));
            photoCount++;
            totalPhotoBytes += bytes;
          }
          data['photoFile'] = relativePhoto;
          exportedDetails.add(data);
        }
        final manifest = {
          'format': _format,
          'version': _version,
          'createdAtUtc': DateTime.now().toUtc().toIso8601String(),
          'profiles': profiles.map((e) => e.toJson()).toList(),
          'details': exportedDetails,
        };
        final manifestFile = File(p.join(tmp.path, 'shotor_manifest_$stamp.json'));
        try {
          await manifestFile.writeAsString(jsonEncode(manifest), flush: true);
          await encoder.addFile(manifestFile, 'manifest.json');
        } finally {
          if (await manifestFile.exists()) await manifestFile.delete();
        }
        done = true;
      } finally {
        encoder.closeSync();
        if (!done) {
          final file = File(zipPath);
          if (await file.exists()) await file.delete();
        }
      }
      final archiveFile = File(zipPath);
      if (await archiveFile.length() > _maxArchiveBytes) {
        await archiveFile.delete();
        throw StateError('حجم فایل بک‌آپ از حد مجاز بیشتر است.');
      }
      try {
        final uri = await _publishFile(archiveFile, 'backups', name);
        // Photos are separately browseable in the public pictures directory.
        // A mirroring failure must not invalidate the complete ZIP backup.
        var mirrored = 0;
        for (final photo in photoCopies) {
          try {
            await mirrorPhoto(photo.tagId, photo.path);
            mirrored++;
          } catch (_) { /* Full ZIP remains the authoritative backup. */ }
        }
        return BackupExportResult(profiles.length, photoCount, mirrored, uri);
      } finally {
        if (await archiveFile.exists()) await archiveFile.delete();
      }
    } finally {
      _busy = false;
    }
  }

  static Future<BackupRestoreResult> importBackup(File source) async {
    if (_busy) throw StateError('عملیات پشتیبان‌گیری دیگری در حال اجراست.');
    _busy = true;
    try {
      final parsed = await _parse(source); // validate BEFORE any database edits
      final app = await getApplicationDocumentsDirectory();
      final photoDir = Directory(p.join(app.path, 'camel_photos'));
      await photoDir.create(recursive: true);
      final converted = <CamelDetail>[];
      final importedPaths = <String>[];
      var detailsCommitted = false;
      try {
        for (final detail in parsed.details) {
          final relative = detail.photoPath;
          if (relative.isEmpty) {
            converted.add(detail);
            continue;
          }
          final file = parsed.photos[relative]!;
          final ext = p.extension(relative);
          final safeName = _safeTag(detail.tagId);
          final destination = File(p.join(photoDir.path,
              'restored_${safeName}_${DateTime.now().microsecondsSinceEpoch}$ext'));
          final bytes = file.content as List<int>;
          await destination.writeAsBytes(bytes, flush: true);
          importedPaths.add(destination.path);
          converted.add(detail.copyWith(photoPath: destination.path));
        }
        await CamelDetailService.restoreImportedDetails(converted);
        detailsCommitted = true;
        await CamelProfileService.restoreImportedProfiles(parsed.profiles);
      } catch (_) {
        // Only remove freshly copied images on a failed import. Existing files
        // and unrelated database records are never touched by this cleanup.
        if (!detailsCommitted) {
          for (final path in importedPaths) {
            final file = File(path);
            if (await file.exists()) await file.delete();
          }
        }
        rethrow;
      }
      var mirrored = 0;
      for (final detail in converted) {
        if (detail.photoPath.isEmpty) continue;
        try {
          await mirrorPhoto(detail.tagId, detail.photoPath);
          mirrored++;
        } catch (_) { /* Public mirror is optional. */ }
      }
      return BackupRestoreResult(parsed.profiles.length, converted.length,
          mirrored);
    } finally {
      _busy = false;
    }
  }

  static Future<File?> pickBackup() async {
    final selection = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      allowMultiple: false,
      withData: false,
    );
    if (selection == null || selection.files.isEmpty) return null;
    final path = selection.files.single.path;
    if (path == null) throw StateError('دسترسی به فایل انتخاب‌شده ممکن نیست.');
    return File(path);
  }

  static Future<_ParsedBackup> _parse(File source) async {
    if (!await source.exists() ||
        await source.length() > _maxArchiveBytes) {
      throw const FormatException('فایل بک‌آپ پیدا نشد یا بسیار بزرگ است.');
    }
    // The ZIP never gets automatically extracted. Only exact manifest-listed
    // image entries are read, to prevent zip-slip and archive injection.
    final archive = ZipDecoder().decodeBytes(await source.readAsBytes(),
        verify: true);
    final entries = <String, ArchiveFile>{};
    var totalSize = 0;
    for (final item in archive.files) {
      if (!item.isFile && item.name == 'photos/') continue;
      if (!item.isFile || entries.containsKey(item.name)) {
        throw const FormatException('ساختار فایل ZIP معتبر نیست.');
      }
      totalSize += item.size;
      if (totalSize > _maxTotalImages + 8 * 1024 * 1024) {
        throw const FormatException('حجم محتویات فایل غیرمجاز است.');
      }
      entries[item.name] = item;
    }
    final manifestEntry = entries['manifest.json'];
    if (manifestEntry == null || manifestEntry.size > 8 * 1024 * 1024) {
      throw const FormatException('فایل اطلاعات بک‌آپ موجود نیست.');
    }
    final decoded = jsonDecode(utf8.decode(manifestEntry.content as List<int>));
    if (decoded is! Map || decoded['format'] != _format ||
        decoded['version'] != _version) {
      throw const FormatException('فرمت یا نسخه فایل بک‌آپ پشتیبانی نمی‌شود.');
    }
    final rawProfiles = decoded['profiles'];
    final rawDetails = decoded['details'];
    if (rawProfiles is! List || rawDetails is! List ||
        rawProfiles.length > _maxCamels || rawDetails.length > _maxCamels) {
      throw const FormatException('فهرست شترها در بک‌آپ معتبر نیست.');
    }
    final profiles = <CamelProfile>[];
    final tagIds = <String>{};
    for (final item in rawProfiles) {
      if (item is! Map) throw const FormatException('رکورد پروفایل معتبر نیست.');
      final p = CamelProfile.fromJson(Map<String, dynamic>.from(item));
      if (p.tagId.trim().isEmpty || p.tagId.length > 256 ||
          !tagIds.add(p.tagId)) {
        throw const FormatException('شناسه تگ تکراری یا نامعتبر است.');
      }
      profiles.add(p);
    }
    final details = <CamelDetail>[];
    final photos = <String, ArchiveFile>{};
    final detailIds = <String>{};
    final imageNames = <String>{};
    for (final item in rawDetails) {
      if (item is! Map) throw const FormatException('اطلاعات شتر نامعتبر است.');
      final map = Map<String, dynamic>.from(item);
      final tagId = map['tagId']?.toString() ?? '';
      if (!tagIds.contains(tagId) || !detailIds.add(tagId)) {
        throw const FormatException('شتر خارج از فهرست یا تکراری است.');
      }
      final photoFile = map['photoFile']?.toString() ?? '';
      if (photoFile.isNotEmpty) {
        if (!RegExp(_imageFilePattern).hasMatch(photoFile) ||
            !imageNames.add(photoFile)) {
          throw const FormatException('آدرس عکس نامعتبر یا تکراری است.');
        }
        final photo = entries[photoFile];
        if (photo == null || photo.size <= 0 ||
            photo.size > _maxImageBytes) {
          throw const FormatException('یکی از عکس‌های بک‌آپ نامعتبر است.');
        }
        photos[photoFile] = photo;
      }
      map['photoPath'] = photoFile;
      details.add(CamelDetail.fromMap(map));
    }
    if (entries.keys.any((name) => name != 'manifest.json' &&
        !imageNames.contains(name))) {
      throw const FormatException('فایل ناشناخته داخل بک‌آپ وجود دارد.');
    }
    return _ParsedBackup(profiles, details, photos,
        decoded['createdAtUtc']?.toString() ?? '');
  }
}

class BackupInspection {
  final int camelCount;
  final int photoCount;
  final int detailCount;
  final String createdAt;
  const BackupInspection(this.camelCount, this.photoCount,
      this.detailCount, this.createdAt);
}

class BackupExportResult {
  final int camels;
  final int photosInZip;
  final int photosMirrored;
  final String location;
  const BackupExportResult(this.camels, this.photosInZip,
      this.photosMirrored, this.location);
}

class BackupRestoreResult {
  final int camels;
  final int details;
  final int photosMirrored;
  const BackupRestoreResult(this.camels, this.details, this.photosMirrored);
}

class _ParsedBackup {
  final List<CamelProfile> profiles;
  final List<CamelDetail> details;
  final Map<String, ArchiveFile> photos;
  final String createdAt;
  const _ParsedBackup(this.profiles, this.details, this.photos,
      this.createdAt);
}
