import 'dart:io';
import 'dart:typed_data';

/// Mobile/desktop implementation: real files under the system temp directory.
///
/// Note: `Directory.systemTemp` on Android/iOS maps to the app cache directory,
/// which the OS may purge under storage pressure. That is acceptable — a miss
/// simply falls back to the network.
class PdfDiskCache {
  const PdfDiskCache._();

  /// Maximum number of cached documents retained on disk.
  static const int maxDiskFiles = 40;

  static Future<Directory> _dir() async {
    final dir = Directory('${Directory.systemTemp.path}/nexus_docs');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Reads a cached document, returning null when absent or implausible.
  static Future<Uint8List?> read(String key) async {    try {
      final dir = await _dir();
      final file = File('${dir.path}/${_safe(key)}.pdf');
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      // Guard against truncated or non-PDF payloads.
      if (bytes.length <= 500) return null;
      if (bytes[0] != 0x25 || bytes[1] != 0x50 || bytes[2] != 0x44 || bytes[3] != 0x46) {
        return null;
      }
      return bytes;
    } catch (_) {
      return null;
    }
  }

  /// Writes bytes and prunes the cache back to [maxDiskFiles] entries.
  static Future<bool> write(String key, Uint8List bytes) async {
    try {
      final dir = await _dir();
      await File('${dir.path}/${_safe(key)}.pdf').writeAsBytes(bytes, flush: true);
      await _prune(dir);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Removes a single cached document.
  static Future<void> delete(String key) async {
    try {
      final dir = await _dir();
      final file = File('${dir.path}/${_safe(key)}.pdf');
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  /// Drops every cached version of [docId] except [currentKeyOrVersion].
  static Future<void> evictOlderVersions(String docId, dynamic currentKeyOrVersion) async {
    if (docId.isEmpty) return;
    try {
      final dir = await _dir();
      final needle = '${_safe(docId)}_v';
      final keepName = currentKeyOrVersion is int
          ? '${_safe(docId)}_v$currentKeyOrVersion.pdf'
          : '${_safe(currentKeyOrVersion.toString())}.pdf';
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        final name = entity.path.split(Platform.pathSeparator).last;
        if (!name.contains(needle)) continue;
        if (name == keepName) continue;
        try {
          await entity.delete();
        } catch (_) {}
      }
    } catch (_) {}
  }

  /// Removes cached documents whose key prefix matches [prefix].
  static Future<void> deleteMatching(String prefix) async {
    if (prefix.isEmpty) return;
    try {
      final dir = await _dir();
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        if (entity.path.contains(prefix)) {
          try {
            await entity.delete();
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  static Future<void> _prune(Directory dir) async {
    try {
      final entries = <MapEntry<File, DateTime>>[];
      await for (final entity in dir.list()) {
        if (entity is! File) continue;
        if (!entity.path.toLowerCase().endsWith('.pdf')) continue;
        try {
          entries.add(MapEntry(entity, await entity.lastModified()));
        } catch (_) {}
      }
      if (entries.length <= maxDiskFiles) return;
      entries.sort((a, b) => a.value.compareTo(b.value));
      final excess = entries.length - maxDiskFiles;
      for (var i = 0; i < excess; i++) {
        try {
          await entries[i].key.delete();
        } catch (_) {}
      }
    } catch (_) {}
  }

  static String _safe(String key) => key.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
}