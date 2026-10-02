import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// Saves Nexus material files to the device's public Downloads folder.
///
/// Handles both single direct download URLs and multi-part chunked Hugging Face
/// materials (e.g. `file.pdf.part0?parts=5`), reassembling them seamlessly so
/// the complete document is saved.
class MaterialDownloadService {
  const MaterialDownloadService._();

  static const MethodChannel _channel =
      MethodChannel('com.nexora/material_download');

  /// Where a saved copy can be found, when the platform reports it.
  static String? lastKnownDirectory;

  /// Returns a human-readable destination path, or null when the platform
  /// cannot report one.
  static Future<String?> getDownloadDirectory() async {
    if (!Platform.isAndroid) return null;
    try {
      final dir = await _channel.invokeMethod<String>('getDownloadDirectory');
      lastKnownDirectory = dir;
      return dir;
    } on PlatformException catch (e) {
      debugPrint('[MaterialDownload] directory lookup failed: ${e.message}');
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Cleans and ensures a friendly, standard document file name (e.g. "OS notes C2.pdf").
  static String sanitizeFileName(String fileName, {String defaultName = 'material'}) {
    var clean = fileName.trim();
    if (clean.isEmpty) clean = defaultName;

    // Strip URL query parameters if present
    if (clean.contains('?')) {
      clean = clean.split('?').first;
    }

    // Strip multi-part chunk artifacts like .part0 or .part0.pdf
    clean = clean.replaceAll(RegExp(r'\.part\d+', caseSensitive: false), '');

    // Collapse multiple consecutive .pdf extensions (e.g. file.pdf.pdf -> file.pdf)
    clean = clean.replaceAll(RegExp(r'(\.pdf)+$', caseSensitive: false), '.pdf');

    // Strip illegal filesystem characters
    clean = clean.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();

    // Collapse multiple underscores
    clean = clean.replaceAll(RegExp(r'_{2,}'), '_').trim();

    if (clean.isEmpty || clean == '.pdf') {
      clean = defaultName;
    }

    // Ensure standard .pdf extension
    if (!clean.toLowerCase().endsWith('.pdf')) {
      clean = '$clean.pdf';
    }

    // Cap length to avoid OS filename limits
    if (clean.length > 104) {
      clean = '${clean.substring(0, 100)}.pdf';
    }

    return clean;
  }

  /// Saves raw [bytes] directly to the device Downloads folder.
  static Future<String> saveBytesToDownloads({
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (bytes.isEmpty) {
      throw const MaterialDownloadException('File content is empty.');
    }

    final safeFileName = sanitizeFileName(fileName);

    if (Platform.isAndroid) {
      try {
        final path = await _channel.invokeMethod<String>('saveBytesToDownloads', {
          'bytes': bytes,
          'fileName': safeFileName,
        });
        return path ?? 'Downloads/$safeFileName';
      } on PlatformException catch (e) {
        throw MaterialDownloadException(
          e.message ?? 'Failed to write file to Android Downloads.',
        );
      } on MissingPluginException {
        // Fall through to generic below.
      }
    }

    // Generic fallback for desktop / iOS / test
    final dir = Directory('${Directory.systemTemp.path}/Nexora/Downloads');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final target = File('${dir.path}/$safeFileName');
    await target.writeAsBytes(bytes, flush: true);
    return target.path;
  }

  /// Downloads [url] to device storage as [fileName].
  ///
  /// Reassembles chunked Hugging Face files automatically.
  /// Returns a description of where the file went, for the success message.
  /// Throws a [MaterialDownloadException] on failure.
  static Future<String> saveToDownloads({
    required String url,
    required String fileName,
  }) async {
    final rawUrl = url.trim();
    if (rawUrl.isEmpty) {
      throw const MaterialDownloadException('No document URL available.');
    }

    final safeFileName = sanitizeFileName(fileName);
    final partsMatch = RegExp(r'[?&]parts=(\d+)').firstMatch(rawUrl);
    final isChunked = partsMatch != null || rawUrl.contains('.part');

    if (isChunked) {
      final partsCount = partsMatch != null ? int.parse(partsMatch.group(1)!) : 0;
      if (partsCount <= 0) {
        throw const MaterialDownloadException(
          'This document has missing chunk information and cannot be downloaded.',
        );
      }
      final baseUrl = rawUrl.split('?')[0].replaceAll(RegExp(r'\.part\d+$'), '');

      final futures = <Future<MapEntry<int, Uint8List>>>[];
      for (var i = 0; i < partsCount; i++) {
        final partUrl = '$baseUrl.part$i';
        futures.add(() async {
          final res = await http.get(
            Uri.parse(partUrl),
            headers: {'User-Agent': 'Mozilla/5.0 (Linux; Android 10)'},
          ).timeout(const Duration(seconds: 45));

          if (res.statusCode != 200) {
            throw MaterialDownloadException(
              'Failed to download chunk $i of $partsCount (${res.statusCode})',
            );
          }
          return MapEntry(i, res.bodyBytes);
        }());
      }

      final results = await Future.wait(futures);
      results.sort((a, b) => a.key.compareTo(b.key));

      final builder = BytesBuilder(copy: false);
      for (final entry in results) {
        builder.add(entry.value);
      }
      final assembled = builder.takeBytes();
      return saveBytesToDownloads(bytes: assembled, fileName: safeFileName);
    }

    if (Platform.isAndroid) {
      try {
        await _channel.invokeMethod<int>('saveToDownloads', {
          'url': rawUrl,
          'fileName': safeFileName,
        });
        final dir = await getDownloadDirectory();
        return dir == null ? 'Downloads' : '$dir/$safeFileName';
      } on PlatformException catch (e) {
        throw MaterialDownloadException(
          e.message ?? 'The system download manager rejected the request.',
        );
      } on MissingPluginException {
        // Fall through to the generic path below.
      }
    }

    return _saveGeneric(rawUrl, safeFileName);
  }

  /// Non-Android fallback: stream the file into the app documents directory.
  static Future<String> _saveGeneric(String url, String fileName) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(url));
      request.headers.set('User-Agent', 'Mozilla/5.0 (Nexora)');
      final response = await request.close();

      if (response.statusCode != 200) {
        throw MaterialDownloadException(
          'Server returned HTTP ${response.statusCode}.',
        );
      }

      final dir = Directory('${Directory.systemTemp.path}/Nexora/Downloads');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      final target = File('${dir.path}/$fileName');

      final sink = target.openWrite();
      try {
        await for (final chunk in response) {
          sink.add(chunk);
        }
      } finally {
        await sink.close();
      }

      return target.path;
    } on SocketException catch (e) {
      throw MaterialDownloadException('Network error: ${e.message}');
    } on HttpException catch (e) {
      throw MaterialDownloadException('Download failed: ${e.message}');
    } finally {
      client.close();
    }
  }
}

class MaterialDownloadException implements Exception {
  final String message;

  const MaterialDownloadException(this.message);

  @override
  String toString() => message;
}
