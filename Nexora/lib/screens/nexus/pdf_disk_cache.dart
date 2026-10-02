/// Platform-agnostic entry point for the Nexus document disk cache.
///
/// Imports the `dart:io` implementation on mobile/desktop and a no-op on web.
///
/// The PDF viewer is compiled for web as well as mobile, and `dart:io` is not
/// available in the browser (its stub throws `UnsupportedError` on
/// `Directory.systemTemp`). All filesystem access is therefore routed through
/// this conditional export.
library;

export 'pdf_disk_cache_io.dart'
    if (dart.library.js_interop) 'pdf_disk_cache_web.dart';