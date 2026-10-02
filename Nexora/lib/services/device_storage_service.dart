import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

/// WhatsApp-style local device storage (not Firebase, not ImgBB, not cloud).
/// Stores images/documents/files directly in app-local directories.
class DeviceStorageService {
  const DeviceStorageService._();

  /// Saves [bytes] to the app's local documents directory under [folder]/[fileName].
  /// Returns the absolute file path (e.g. /data/user/0/.../files/note_123.jpg).
  /// Works for images, PDFs, DOCX, TXT, any file type.
  static Future<String> saveFile({
    required Uint8List bytes,
    required String folder,
    required String fileName,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final targetDir = Directory('${dir.path}/$folder');
    if (!await targetDir.exists()) await targetDir.create(recursive: true);
    final file = File('${targetDir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  /// Reads file from device storage by absolute path.
  static Future<Uint8List> readFile(String absolutePath) async {
    return await File(absolutePath).readAsBytes();
  }

  /// Deletes file from device storage by absolute path.
  static Future<void> deleteFile(String absolutePath) async {
    final file = File(absolutePath);
    if (await file.exists()) await file.delete();
  }
}
