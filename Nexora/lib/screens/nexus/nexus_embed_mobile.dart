import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../services/material_download_service.dart';
import 'nexus_pdf_viewer_screen.dart';

const _kPdfEngineScript = r'''
(function() {
  if (window.__nexora_pdf_bridge_installed__) return;
  window.__nexora_pdf_bridge_installed__ = true;

  // 1. Forward direct modal open calls to Flutter native PDF viewer
  window.nexusOpenPdfModal = function(url, title) {
    if (window.NexusPdfBridge && url && typeof url === 'string' && !url.startsWith('blob:')) {
      window.NexusPdfBridge.postMessage(JSON.stringify({
        url: url,
        title: title || 'Document Preview'
      }));
      return true;
    }
    return false;
  };

  // 2. Intercept window.open calls for PDFs and document URLs (ignore blob: URLs)
  var originalWindowOpen = window.open;
  window.open = function(url, target, features) {
    if (url && typeof url === 'string' && !url.startsWith('blob:')) {
      if (url.includes('.pdf') || url.includes('view=inline') || (url.includes('huggingface.co') && url.includes('/resolve/'))) {
        if (window.nexusOpenPdfModal(url, 'Document Preview')) {
          return { closed: false, close: function(){} };
        }
      }
    }
    return originalWindowOpen ? originalWindowOpen.apply(this, arguments) : null;
  };

  // 2b. Route the PWA's own download action to the native downloader.
  //
  // pwa-helper.js downloadFile() builds a blob: URL and calls a.click() with
  // a.download. A WebView cannot download a blob: URL (Android throws
  // "Can only download HTTP/HTTPS URIs" and iOS ignores it), so the tap
  // produced no file and no error. Hooking the function — rather than
  // intercepting anchor clicks — is the only reliable interception point,
  // because by the time the click fires the real http(s) URL has already been
  // replaced by the blob. We still have it here, so we forward it natively and
  // do the device download instead.
  //
  // This also lets us resolve the PWA's chunked Hugging Face URLs to the single
  // full-file URL, which the native downloader can stream directly.
  function hookDownload() {
    if (!window.pwaHelper || !window.pwaHelper.downloadFile) return;
    if (window.pwaHelper.downloadFile.__hooked_by_nexora__) return;
    window.pwaHelper.downloadFile.__hooked_by_nexora__ = true;

    var original = window.pwaHelper.downloadFile.bind(window.pwaHelper);
    window.pwaHelper.downloadFile = async function (fileUrl, filename, id, version, btn, assetId) {
      if (window.NexusDownloadBridge && fileUrl && typeof fileUrl === 'string' && fileUrl) {
        // Forward full fileUrl so chunked materials retain their chunk count
        // and let native reassemble them into the complete document.
        window.NexusDownloadBridge.postMessage(JSON.stringify({
          url: fileUrl,
          fileName: filename || '',
          title: filename || '',
          docId: id || '',
          version: version || 1
        }));

        if (btn) {
          btn.innerHTML = '<i data-lucide="download"></i> Saved to Downloads';
          btn.disabled = false;
          btn.style.opacity = '1';
        }
        return;
      }
      return original(fileUrl, filename, id, version, btn, assetId);
    };
  }

  // 3. Hook both window.viewFile and window.pwaHelper.viewFile
  function hookViewFunctions() {
    hookDownload();

    // Hook global window.viewFile from index.html
    if (typeof window.viewFile === 'function' && !window.viewFile.__hooked_by_nexora__) {
      var origView = window.viewFile;
      window.viewFile = async function(url, id, version, title, btn, githubAssetId) {
        if (window.NexusPdfBridge && url && typeof url === 'string' && !url.startsWith('blob:')) {
          window.NexusPdfBridge.postMessage(JSON.stringify({
            url: url,
            title: title || 'Document Preview',
            id: id,
            assetId: githubAssetId
          }));
          return;
        }
        return origView(url, id, version, title, btn, githubAssetId);
      };
      window.viewFile.__hooked_by_nexora__ = true;
    }

    // Hook window.pwaHelper.viewFile if present
    if (window.pwaHelper && window.pwaHelper.viewFile && !window.pwaHelper.__hooked_by_nexora__) {
      window.pwaHelper.__hooked_by_nexora__ = true;
      var origPwaView = window.pwaHelper.viewFile.bind(window.pwaHelper);
      window.pwaHelper.viewFile = async function(fileUrl, id, version, title, btn, githubAssetId) {
        if (window.NexusPdfBridge && fileUrl && typeof fileUrl === 'string' && !fileUrl.startsWith('blob:')) {
          window.NexusPdfBridge.postMessage(JSON.stringify({
            url: fileUrl,
            title: title || 'Document Preview',
            id: id,
            assetId: githubAssetId
          }));
          if (btn) {
            btn.innerHTML = '<i data-lucide="eye"></i> View';
            btn.disabled = false;
            btn.style.opacity = '1';
          }
          return;
        }
        return origPwaView(fileUrl, id, version, title, btn, githubAssetId);
      };
    }
  }

  hookViewFunctions();
  var checkCount = 0;
  var interval = setInterval(function() {
    checkCount++;
    hookViewFunctions();
    if (checkCount > 25) {
      clearInterval(interval);
    }
  }, 200);
})();
''';

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
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0A0A0A))
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
      )
      ..addJavaScriptChannel(
        'NexusDownloadBridge',
        onMessageReceived: (JavaScriptMessage message) {
          unawaited(_handleDownloadMessage(message.message));
        },
      )
      ..addJavaScriptChannel(
        'NexusPdfBridge',
        onMessageReceived: (JavaScriptMessage message) {
          try {
            final data = jsonDecode(message.message) as Map<String, dynamic>;
            final url = data['url']?.toString();
            final title = data['title']?.toString() ?? 'Document Preview';
            if (url != null && url.isNotEmpty && mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => NexusPdfViewerScreen(
                    title: title,
                    url: url,
                  ),
                ),
              );
            }
          } catch (e) {
            debugPrint('[NexusPdfBridge] Error parsing message: $e');
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            widget.onProgress?.call(progress);
          },
          onPageFinished: (_) {
            widget.onLoaded?.call();
            _injectPdfEngine();
            _injectUserBridge();
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint(
              '[NexusEmbed] WebResourceError: ${error.errorCode} - ${error.description} (failingUrl: ${error.url})',
            );
          },
          onNavigationRequest: (NavigationRequest request) {
            final uri = Uri.tryParse(request.url);
            final urlLower = request.url.toLowerCase();
            final isPdf = (uri != null && uri.path.toLowerCase().endsWith('.pdf')) ||
                urlLower.contains('.pdf') ||
                (urlLower.contains('huggingface.co') && urlLower.contains('/resolve/'));
            if (isPdf) {
              if (context.mounted) {
                String docTitle = 'Document Preview';
                final lastSegment = uri?.pathSegments.lastOrNull;
                if (lastSegment != null && lastSegment.isNotEmpty) {
                  docTitle = Uri.decodeComponent(lastSegment)
                      .replaceAll(RegExp(r'\.part\d+', caseSensitive: false), '')
                      .replaceAll(RegExp(r'(\.pdf)+$', caseSensitive: false), '')
                      .replaceAll(RegExp(r'[_\-]+'), ' ')
                      .trim();
                }
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => NexusPdfViewerScreen(
                      title: docTitle.isNotEmpty ? docTitle : 'Document Preview',
                      url: request.url,
                    ),
                  ),
                );
              }
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );

    if (_controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      final androidController = _controller.platform as AndroidWebViewController;
      androidController.setMediaPlaybackRequiresUserGesture(false);
    }

    _controller.loadRequest(Uri.parse(widget.url));
  }

  @override
  void didUpdateWidget(NexusEmbedView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user != widget.user) {
      _injectUserBridge();
    }
  }

  void _injectPdfEngine() {
    _controller.runJavaScript(_kPdfEngineScript);
  }

  /// Handles a download request forwarded from the embedded Nexus PWA.
  ///
  /// Surfaces progress and errors to the user; the previous behaviour was a
  /// silent no-op because a WebView cannot download a blob URL.
  Future<void> _handleDownloadMessage(String raw) async {
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final url = decoded['url']?.toString() ?? '';
      final fileName = (decoded['fileName']?.toString() ?? '').trim();
      final title = (decoded['title']?.toString() ?? '').trim();
      if (url.isEmpty) return;

      String candidate = '';
      if (title.isNotEmpty && title.toLowerCase() != 'untitled' && title.toLowerCase() != 'download') {
        candidate = title;
      } else if (fileName.isNotEmpty && fileName.toLowerCase() != 'untitled' && fileName.toLowerCase() != 'download') {
        candidate = fileName;
      } else {
        final pathSegment = Uri.tryParse(url)?.pathSegments.lastOrNull;
        if (pathSegment != null && pathSegment.isNotEmpty) {
          candidate = Uri.decodeComponent(pathSegment);
        }
      }

      final safeName = MaterialDownloadService.sanitizeFileName(
        candidate,
        defaultName: 'material',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Downloading $safeName…'),
          duration: const Duration(seconds: 2),
        ),
      );

      final destination = await MaterialDownloadService.saveToDownloads(
        url: url,
        fileName: safeName,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF10B981),
          content: Text('Saved to $destination'),
        ),
      );
    } on MaterialDownloadException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFEF4444),
          content: Text('Download failed: ${e.message}'),
        ),
      );
    } catch (e) {
      debugPrint('[NexusEmbed] download bridge error: $e');
    }
  }


  void _injectUserBridge() {
    if (widget.user == null) return;
    final u = widget.user!;
    final safeUid = jsonEncode(u.uid);
    final safeEmail = jsonEncode(u.email);
    final safeName = jsonEncode(u.name);
    final safePhoto = jsonEncode(u.photoUrl ?? '');
    final safeRole = jsonEncode(u.role);

    final script = '''
(function() {
  var u = {
    uid: $safeUid,
    email: $safeEmail,
    displayName: $safeName,
    name: $safeName,
    photoURL: $safePhoto,
    role: $safeRole
  };
  window.__nexora_user__ = u;
  try {
    // IMPORTANT: only write a role Nexus actually understands.
    //
    // Nexus's vocabulary is 'pending' | 'friend' | 'admin'. index.html reads
    // nexus_user_role_<uid> back as a fallback when Firestore is unreachable,
    // and admin.html reads it to recover the admin role. Writing Nexora's own
    // vocabulary ('student', 'superadmin') here means Nexus later reads an
    // unrecognised role: the user renders as pending, and the admin gate
    // (data.role !== 'admin') fails closed.
    //
    // Map instead of copying, and never invent a role Nexus does not have.
    var nexusRole = (u.role === 'superadmin' || u.role === 'admin') ? 'admin' : 'friend';
    localStorage.setItem('nexus_user_role_' + u.uid, nexusRole);
    localStorage.setItem('nexus_user_profile', JSON.stringify(u));
  } catch(e) {}

  function applyNexusBridge() {
    var loginLink = document.getElementById('login-link');
    if (loginLink) {
      loginLink.classList.add('hidden');
      loginLink.style.display = 'none';
    }
    var menuLogin = document.getElementById('menu-login');
    if (menuLogin) {
      menuLogin.classList.add('hidden');
      menuLogin.style.display = 'none';
    }

    // Render using Nexus's role vocabulary so the labels match the rest of the
    // PWA. 'student'/'superadmin' are Nexora-internal and would otherwise fall
    // through to role.toUpperCase(), rendering "STUDENT"/"SUPERADMIN".
    var role = (u.role === 'superadmin' || u.role === 'admin') ? 'admin' : 'friend';

    var userSection = document.getElementById('user-section');
    if (userSection && !userSection.querySelector('#user-chip')) {
      userSection.classList.remove('hidden');
      userSection.classList.add('flex');
      var isAdmin = (role === 'admin');
      var adminBadge = isAdmin
        ? '<span class="hidden items-center gap-1.5 rounded-full border border-violet/25 bg-violet/10 px-2.5 py-1 text-[10px] font-[700] tracking-[0.12em] text-violet md:inline-flex"><span class="h-1.5 w-1.5 rounded-full bg-violet shadow-[0_0_8px_#8b5cf6]"></span>ADMIN</span>' 
        : '';
      var photo = u.photoURL || ('https://api.dicebear.com/7.x/identicon/svg?seed=' + encodeURIComponent(u.name));
      var name = u.displayName || u.email || 'Student';

      userSection.innerHTML = adminBadge +
        '<div class="relative" id="user-menu-root">' +
          '<div id="user-chip" class="flex items-center gap-2 rounded-full border border-white/10 bg-white/[0.04] py-1 pl-1 pr-3 backdrop-blur-md">' +
            '<img src="' + photo + '" alt="" class="h-7 w-7 rounded-full object-cover">' +
            '<span class="flex flex-col items-start leading-none">' +
              '<span class="text-[12.5px] font-[600] text-white">' + name + '</span>' +
              '<span class="font-mono text-[10px] tracking-[0.12em] text-[#9D4EDD]">' + (role === 'admin' ? 'ADMIN' : (role === 'friend' ? 'MEMBER' : role.toUpperCase())) + '</span>' +
            '</span>' +
          '</div>' +
        '</div>';
    }

    var menuUserSection = document.getElementById('menu-user-section');
    if (menuUserSection && !menuUserSection.hasChildNodes()) {
      var photo = u.photoURL || ('https://api.dicebear.com/7.x/identicon/svg?seed=' + encodeURIComponent(u.name));
      var name = u.displayName || u.email || 'Student';
      menuUserSection.innerHTML =
        '<div class="flex items-center gap-3 rounded-2xl border border-white/10 bg-white/[0.04] p-3">' +
          '<img src="' + photo + '" class="h-10 w-10 rounded-full object-cover">' +
          '<div class="flex flex-col">' +
            '<span class="text-[14px] font-[600] text-white">' + name + '</span>' +
            '<span class="font-mono text-[11px] text-[#9D4EDD]">' + (role === 'admin' ? 'ADMIN' : 'MEMBER') + '</span>' +
          '</div>' +
        '</div>';
    }

    if (typeof window.showUploadButton === 'function') {
      try { window.showUploadButton(); } catch(e) {}
    }
  }

  applyNexusBridge();
  setTimeout(applyNexusBridge, 200);
  setTimeout(applyNexusBridge, 600);
  setTimeout(applyNexusBridge, 1500);
})();
''';
    _controller.runJavaScript(script);
  }

  void reload() {
    _controller.reload();
  }

  Future<bool> canGoBack() => _controller.canGoBack();

  Future<void> goBack() => _controller.goBack();

  void openExternal() {
    _controller.runJavaScript('window.open("${widget.url}", "_blank");');
  }

  @override
  Widget build(BuildContext context) {
    PlatformWebViewWidgetCreationParams params =
        PlatformWebViewWidgetCreationParams(
      controller: _controller.platform,
      layoutDirection: TextDirection.ltr,
      gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{
        Factory<OneSequenceGestureRecognizer>(
          EagerGestureRecognizer.new,
        ),
      },
    );

    if (WebViewPlatform.instance is AndroidWebViewPlatform) {
      params = AndroidWebViewWidgetCreationParams
          .fromPlatformWebViewWidgetCreationParams(
        params,
        displayWithHybridComposition: true,
      );
    }

    return SizedBox.expand(
      child: WebViewWidget.fromPlatformCreationParams(params: params),
    );
  }
}
