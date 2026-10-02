import 'dart:typed_data';

/// Web implementation: no filesystem is available in the browser, so the disk
/// tier is a no-op and the viewer falls back to its in-memory cache and then to
/// the network. Every method returns the "cache miss" answer rather than
/// throwing, so the viewer degrades cleanly instead of crashing.
class PdfDiskCache {
  const PdfDiskCache._();

  static const int maxDiskFiles = 0;

  static Future<Uint8List?> read(String key) async => null;

  static Future<bool> write(String key, Uint8List bytes) async => false;

  static Future<void> delete(String key) async {}

  static Future<void> evictOlderVersions(String docId, dynamic currentKeyOrVersion) async {}

  static Future<void> deleteMatching(String prefix) async {}
}