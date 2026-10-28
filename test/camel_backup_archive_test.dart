import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saraban_app/services/camel_backup_service.dart';

void main() {
  late Directory directory;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('camel_archive_test');
  });
  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  Future<File> fixture({String photoFile = 'photos/0.jpg',
    String? extraneousFile}) async {
    final manifest = {
      'format': 'saraban.camel.backup',
      'version': 1,
      'createdAtUtc': '2026-10-26T10:00:00Z',
      'profiles': [
        {'tagId': 'TAG-1', 'camelNo': '۱', 'camelName': 'شتر روشن',
          'isActive': true, 'note': ''},
      ],
      'details': [{
        'tagId': 'TAG-1', 'fatherName': 'پدر', 'motherName': '',
        'color': '', 'breed': '', 'healthStatus': '', 'description': '',
        'createdAt': '2026-10-26T10:00:00Z',
        'updatedAt': '2026-10-26T10:00:00Z',
        'photoFile': photoFile,
      }],
    };
    final archive = Archive();
    final json = utf8.encode(jsonEncode(manifest));
    archive.addFile(ArchiveFile('manifest.json', json.length, json));
    archive.addFile(ArchiveFile('photos/0.jpg', 4, [0xFF, 0xD8, 0xFF, 0xD9]));
    if (extraneousFile != null) {
      archive.addFile(ArchiveFile(extraneousFile, 3, [1, 2, 3]));
    }
    final file = File('${directory.path}/example.zip');
    await file.writeAsBytes(ZipEncoder().encode(archive)!);
    return file;
  }

  test('reads registered camels, details and photo from valid ZIP', () async {
    final info = await CamelBackupService.inspect(await fixture());
    expect(info.camelCount, 1);
    expect(info.photoCount, 1);
    expect(info.detailCount, 1);
  });

  test('rejects unknown archive entry even if manifest is valid', () async {
    expect(() async => CamelBackupService.inspect(
        await fixture(extraneousFile: '../escape.txt')),
        throwsFormatException);
  });

  test('rejects photo path traversal in manifest', () async {
    expect(() async => CamelBackupService.inspect(
        await fixture(photoFile: '../escape.jpg')),
        throwsFormatException);
  });
}
