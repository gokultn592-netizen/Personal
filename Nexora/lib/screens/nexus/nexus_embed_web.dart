import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import 'nexus_pdf_viewer_screen.dart';

/// Serialises a bridge payload to JSON for transport over `postMessage`.
String _encodeBridgePayload(Map<String, Object?> payload) =>
    jsonEncode(payload);

/// Parses an inbound message into a Dart map, or null when it is not one of
/// ours (the listener is attached to the whole window).
Map<String, Object?>? _decodeBridgePayload(JSAny? data) {
  final text = data.dartify();
  if (text is! String || !text.startsWith('{')) return null;
  try {
    final decoded = jsonDecode(text);
    if (decoded is Map) {
      return decoded.map((k, v) => MapEntry(k.toString(), v));
    }
  } catch (_) {}
  return null;
}

/// Identity handed from Nexora to the embedded Nexus PWA.
///
/// Nexus and Nexora are separate Firebase projects with separate Auth UIDs, so
/// the bridge is informational only — it lets the PWA render the verified
/// student's name/role instead of its own anonymous state.
class NexusUserBridgeData {
  final String uid;
  final String email;
  final String name;
  final String? photoUrl;
  final String role;

  const NexusUserBridgeData({
    required this.uid,
    required this.email,
    required this.name,
    this.photoUrl,
    required this.role,
  });
}

/// Web implementation of the Nexus embed.
///
/// The mobile implementation relies on `webview_flutter` (Android WebView), which
/// has no web equivalent, so on web this renders the Nexus PWA in a plain
/// `<iframe>` and communicates with it over `postMessage`.
class NexusEmbedView extends StatefulWidget {
  final String url;
  final NexusUserBridgeData? user;
  final VoidCallback? onLoaded;
  final ValueChanged<int>? onProgress;

  const NexusEmbedView({
    super.key,
    required this.url,
    this.user,
    this.onLoaded,
    this.onProgress,
  });

  @override
  State<NexusEmbedView> createState() => NexusEmbedViewState();
}

class NexusEmbedViewState extends State<NexusEmbedView> {
  static int _frameCounter = 0;
  late final String _viewType;
  late final web.HTMLIFrameElement _iframe;
  StreamSubscription<web.MessageEvent>? _messageSub;

  @override
  void initState() {
    super.initState();
    _viewType = 'nexus-frame-${_frameCounter++}';
    _iframe = web.HTMLIFrameElement()
      ..src = widget.url
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.backgroundColor = '#0A0A0A'
      ..allow =
          'fullscreen; camera; microphone; geolocation; clipboard-read; clipboard-write; autoplay; downloads; encrypted-media'
      ..setAttribute(
        'sandbox',
        'allow-scripts allow-same-origin allow-popups allow-popups-to-escape-sandbox allow-forms allow-downloads allow-modals',
      );

    _iframe.onLoad.listen((_) {
      widget.onProgress?.call(100);
      widget.onLoaded?.call();
      // The document is ready, so the identity bridge can be delivered.
      _pushUserBridge();
    });

    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _iframe,
    );

    // Listen for messages from the embedded PWA (progress + PDF open requests).
    _messageSub = web.window.onMessage.listen((event) {
      final payload = _decodeBridgePayload(event.data);
      if (payload == null) return;

      switch (payload['type']) {
        case 'nexora_progress':
          final progress = payload['progress'];
          if (progress is num) widget.onProgress?.call(progress.toInt());
        case 'open_pdf':
          final url = payload['url']?.toString() ?? '';
          if (url.isEmpty || url.startsWith('blob:')) return;
          final title = payload['title']?.toString() ?? 'Document Preview';
          if (!mounted) return;
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => NexusPdfViewerScreen(title: title, url: url),
            ),
          );
      }
    });
  }

  @override
  void didUpdateWidget(NexusEmbedView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user?.uid != widget.user?.uid ||
        oldWidget.user?.role != widget.user?.role) {
      _pushUserBridge();
    }
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    super.dispose();
  }

  /// Sends the verified Nexora identity into the iframe.
  ///
  /// Target origin is derived from the Nexus URL rather than wildcarded. The
  /// message is only accepted by a frame on the matching Nexus origin, so no
  /// credentials or tokens are sent to third-party origins.
  void _pushUserBridge() {
    final u = widget.user;
    if (u == null) return;
    final origin = Uri.tryParse(widget.url)?.origin;
    if (origin == null) return;

    final encoded = _encodeBridgePayload({
      'type': 'nexora_user',
      'user': {
        'uid': u.uid,
        'email': u.email,
        'displayName': u.name,
        'name': u.name,
        'photoURL': u.photoUrl ?? '',
        'role': u.role,
      },
    }).toJS;

    try {
      // Both `message` and `targetOrigin` are typed JSAny in the DOM bindings.
      _iframe.contentWindow?.postMessage(encoded, origin.toJS);
    } catch (e) {
      debugPrint('[NexusEmbedWeb] identity bridge failed: $e');
    }
  }

  void reload() {
    _iframe.src = widget.url;
  }

  /// An iframe has no navigable history exposed to the host page, so the embed
  /// never claims it can go back; the host then falls through to its own
  /// back handling.
  Future<bool> canGoBack() async => false;

  Future<void> goBack() async {}

  void openExternal() {
    web.window.open(widget.url, '_blank');
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}