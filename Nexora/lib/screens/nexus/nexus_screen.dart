import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/cache/cache_service.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../services/material_download_service.dart';
import '../../services/nexus_service.dart';
import '../../services/notification_service.dart';
import '../notes/note_notifications_sheet.dart';
import 'nexus_embed.dart';
import 'nexus_pdf_viewer_screen.dart';

/// A material row, normalised from either a live Firestore document or the
/// offline Hive cache.
///
/// Field names come from the live Nexus project (verified against the
/// `nexus-e7a36` Firestore `materials` collection): `title`, `subject`,
/// `fileUrl`, `fileType`, `uploaderName`, `version`, `createdAt`, plus
/// `githubAssetId`/`uploaderId` written by the Nexus PWA uploader. The PWA
/// orders by `createdAt` descending with no limit, and so does this feed —
/// they are the same collection, so the two surfaces cannot disagree.
class _Material {
  final Map<String, dynamic> data;

  const _Material(this.data);

  factory _Material.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = Map<String, dynamic>.from(doc.data() ?? const <String, dynamic>{});
    d['docId'] = doc.id;
    return _Material(d);
  }

  factory _Material.fromCache(Map<dynamic, dynamic> cached) =>
      _Material(cached.map((k, v) => MapEntry(k.toString(), v)));

  String get docId => (data['docId'] ?? '').toString();
  String get title => (data['title'] ?? 'Untitled').toString();
  String get subject {
    final raw = (data['subject'] ?? 'NOTES').toString().trim();
    return raw.isEmpty ? 'NOTES' : raw.toUpperCase();
  }

  String get fileType {
    final raw = (data['fileType'] ?? 'PDF').toString().trim();
    return raw.isEmpty ? 'PDF' : raw.toUpperCase();
  }

  String get uploaderName => (data['uploaderName'] ?? 'Community').toString();
  String? get fileUrl => data['fileUrl']?.toString();
  int get version => int.tryParse(data['version']?.toString() ?? '') ?? 1;
}

/// Full-screen bridge to Nexus materials and the live Nexus Progressive Web App.
///
/// Offers a native Flutter materials feed with in-app PDF viewing and a cache
/// first offline tier, plus a segmented switch to the live embedded PWA.
class NexusScreen extends StatefulWidget {
  const NexusScreen({super.key});

  @override
  State<NexusScreen> createState() => _NexusScreenState();
}

class _NexusScreenState extends State<NexusScreen> {
  final GlobalKey<NexusEmbedViewState> _embedKey = GlobalKey<NexusEmbedViewState>();
  final ValueNotifier<int> _progressNotifier = ValueNotifier<int>(0);
  final ScrollController _scrollController = ScrollController();

  // Paging state. `_materialsStream` is the first page; `_pagedMaterials`
  // accumulates every subsequent page.
  Stream<QuerySnapshot<Map<String, dynamic>>>? _materialsStream;
  final List<_Material> _pagedMaterials = [];
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _loadMoreError;

  /// Offline fallback shown while the first page is in flight.
  List<_Material> _cachedMaterials = const [];

  /// Guards against writing the cache on every single rebuild.
  bool _cacheWriteInFlight = false;

  int _activeViewIndex = 0; // 0 = Native Materials, 1 = Live Nexus Web
  String _selectedSubject = 'ALL';

  /// Maximum number of materials kept for pagination continuity.
  static const int _maxPagedItems = 200;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadCachedMaterials();
    _initMaterials();
  }

  /// Reads the offline cache once, in initState.
  ///
  /// This used to run inside `build()` and call `setState()`, which is a
  /// framework error ("setState() called during build"). It also ignored the
  /// computed staleness flag, so stale data would have been shown forever.
  void _loadCachedMaterials() {
    final cached = CacheService().getFreshMaterials();
    _cachedMaterials = cached.map(_Material.fromCache).toList(growable: false);
  }

  void _initMaterials() {
    final service = NexusService();
    if (service.firestore == null) {
      service.initialize().then((_) {
        if (!mounted) return;
        setState(_bindFirstPage);
      });
    } else {
      _bindFirstPage();
    }
  }

  void _bindFirstPage() {
    _materialsStream = NexusService().watchMaterials();
    _pagedMaterials.clear();
    _lastCursor = null;
    _hasMore = true;
    _loadMoreError = null;
  }

  /// Cross-checks the number of rows rendered by the native feed against the
  /// total in the Nexus collection, so a divergence is visible rather than
  /// silent.
  ///
  /// Both surfaces read the same `nexus-e7a36` Firestore `materials` collection
  /// ordered by `createdAt` descending, so a mismatch means the feed is stale —
  /// most often a cached page that has not been revalidated.
  Future<void> _verifyFeedParity(int visibleCount) async {
    try {
      if (!NexusService().isReady) return;
      final live = await NexusService().countMaterials();
      if (live == visibleCount) return;
      if (!mounted) return;
      debugPrint(
        '[NexusScreen] feed parity mismatch: showing $visibleCount, '
        'Nexus has $live — rebinding',
      );
      setState(_bindFirstPage);
    } catch (e) {
      debugPrint('[NexusScreen] parity check failed: $e');
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _progressNotifier.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Dynamic subject palette matching the Nexus PWA design
  // ---------------------------------------------------------------------------

  Color _subjectBgColor(String subject) {
    switch (subject.toUpperCase()) {
      case 'DB':
      case 'OS':
        return const Color(0xFF251A38);
      case 'COA':
        return const Color(0xFF16243C);
      case 'DAA':
        return const Color(0xFF142820);
      case 'SAS':
        return const Color(0xFF332014);
      default:
        return const Color(0xFF1F1E2E);
    }
  }

  Color _subjectTextColor(String subject) {
    switch (subject.toUpperCase()) {
      case 'DB':
      case 'OS':
        return const Color(0xFFA78BFA);
      case 'COA':
        return const Color(0xFF60A5FA);
      case 'DAA':
        return const Color(0xFF34D399);
      case 'SAS':
        return const Color(0xFFFB923C);
      default:
        return const Color(0xFFC4B5FD);
    }
  }

  /// Formats a Firestore Timestamp, a DateTime, or an ISO string (the shape the
  /// Hive cache restores) as "d MMM yyyy".
  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '';
    DateTime? dt;
    if (timestamp is Timestamp) {
      dt = timestamp.toDate();
    } else if (timestamp is DateTime) {
      dt = timestamp;
    } else if (timestamp is String) {
      dt = DateTime.tryParse(timestamp);
    }
    if (dt == null) return timestamp.toString();
    return DateFormat('d MMM yyyy').format(dt);
  }

  /// View URL preserves the full raw URL for seamless chunk reassembly.
  String _resolveViewUrl(String rawUrl) => rawUrl.trim();

  /// Whether a material should be opened in the in-app PDF viewer.
  bool _isPdf(_Material m) {
    final url = m.fileUrl ?? '';
    final declared = (m.data['fileType'] ?? '').toString().toLowerCase();
    if (declared == 'pdf') return true;
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
    return path.endsWith('.pdf');
  }

  // ---------------------------------------------------------------------------
  // Opening / downloading
  // ---------------------------------------------------------------------------

  Future<void> _openMaterial(_Material m) async {
    final rawUrl = (m.fileUrl ?? '').trim();
    if (rawUrl.isEmpty) {
      _toast('Document URL is not available');
      return;
    }

    if (_isPdf(m)) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => NexusPdfViewerScreen(
            title: m.title,
            url: rawUrl,
            docId: m.docId.isEmpty ? null : m.docId,
            version: m.version,
          ),
        ),
      );
      return;
    }

    final uri = Uri.tryParse(_resolveViewUrl(rawUrl));
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) _toast('Could not open document: $e');
    }
  }

  /// Saves a material to the device's public Downloads folder.
  ///
  /// Reassembles chunked Hugging Face files automatically via MaterialDownloadService.
  Future<void> _downloadMaterial(_Material m) async {
    final rawUrl = (m.fileUrl ?? '').trim();
    if (rawUrl.isEmpty) {
      _toast('Document URL is not available');
      return;
    }

    final fileName = _downloadFileName(m, rawUrl);
    _showDownloadSheet(m, rawUrl, fileName);
  }

  /// Builds a safe, descriptive filename for the saved copy using the document's original title.
  static String _downloadFileName(_Material m, String url) {
    String candidate = m.title.trim();
    if (candidate.isEmpty || candidate.toLowerCase() == 'untitled') {
      final path = Uri.tryParse(url)?.path;
      final last = path?.split('/').where((s) => s.isNotEmpty).lastOrNull;
      if (last != null && last.isNotEmpty) {
        candidate = Uri.decodeComponent(last);
      }
    }
    return MaterialDownloadService.sanitizeFileName(
      candidate,
      defaultName: 'material',
    );
  }

  /// Progress-aware download sheet with retry and "open folder" affordance.
  void _showDownloadSheet(_Material m, String url, String fileName) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF14141E),
      isDismissible: true,
      builder: (sheetContext) => _DownloadSheet(
        title: m.title,
        fileName: fileName,
        url: url,
      ),
    );
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // ---------------------------------------------------------------------------
  // Pagination
  // ---------------------------------------------------------------------------

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 320) {
      _loadMore();
    }
  }

  /// Appends the next page. Uses the real cursor from the last document seen
  /// rather than re-issuing the same first-page query.
  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    if (!NexusService().isReady) return;

    setState(() {
      _isLoadingMore = true;
      _loadMoreError = null;
    });

    try {
      // The cursor is the last document already consumed: the final doc of the
      // first page, or the final doc of the most recently appended page.
      final cursor = _lastCursor;
      if (cursor == null) {
        if (mounted) setState(() => _hasMore = false);
        return;
      }

      final page = await NexusService().loadMoreMaterials(after: cursor);
      if (page.isNotEmpty) _lastCursor = page.last;

      if (!mounted) return;
      setState(() {
        if (page.isEmpty) {
          _hasMore = false;
        } else {
          _pagedMaterials.addAll(page.map(_Material.fromDoc));
          while (_pagedMaterials.length > _maxPagedItems) {
            _pagedMaterials.removeAt(0);
          }
        }
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingMore = false;
        _loadMoreError = e.toString();
      });
    }
  }

  /// First-page snapshot used as the pagination cursor, cached by the stream.
  /// Last document consumed by the feed, used as the pagination cursor.
  DocumentSnapshot<Map<String, dynamic>>? _lastCursor;

  // ---------------------------------------------------------------------------
  // Feed assembly
  // ---------------------------------------------------------------------------

  /// Whether [incoming] is the same first page already on screen, compared by
  /// document id + version. A version bump means the material was re-uploaded,
  /// so the cached bytes are stale and must be refreshed.
  bool _samePageAsRendered(List<_Material> incoming) {
    final rendered = _lastRenderedIds;
    if (rendered.isEmpty || rendered.length != incoming.length) return false;
    for (var i = 0; i < incoming.length; i++) {
      if (rendered[i] != incoming[i].docId) return false;
      if (_lastRenderedVersions[i] != incoming[i].version) return false;
    }
    return true;
  }

  List<String> _lastRenderedIds = const [];
  List<int> _lastRenderedVersions = const [];

  /// Persists the first page to Hive so the feed has an offline tier.
  ///
  /// Firestore `Timestamp` values cannot be serialised by Hive, so this is the
  /// call site that previously threw on every rebuild; [CacheService] now
  /// normalises the payload.
  Future<void> _persistMaterialsCache(List<_Material> materials) async {
    if (_cacheWriteInFlight || materials.isEmpty) return;
    _cacheWriteInFlight = true;
    try {
      await CacheService().saveMaterials(materials.map((m) => m.data).toList());
      _loadCachedMaterials();
    } finally {
      _cacheWriteInFlight = false;
    }
  }

  /// The rows actually rendered: cached rows while the stream is cold, then the
  /// live first page plus any paged extras.
  List<_Material> _visibleMaterials(QuerySnapshot<Map<String, dynamic>>? snapshot) {
    if (snapshot != null && snapshot.docs.isNotEmpty) {
      return [
        ...snapshot.docs.map(_Material.fromDoc),
        ..._pagedMaterials,
      ];
    }
    return _cachedMaterials;
  }

  List<_Material> _filterBySubject(List<_Material> items) {
    if (_selectedSubject == 'ALL') return items;
    return items.where((m) => m.subject == _selectedSubject).toList();
  }

  Map<String, int> _subjectCounts(List<_Material> items) {
    final counts = <String, int>{'ALL': items.length};
    for (final m in items) {
      counts[m.subject] = (counts[m.subject] ?? 0) + 1;
    }
    return counts;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_activeViewIndex == 1) {
          final embedState = _embedKey.currentState;
          if (embedState != null && await embedState.canGoBack()) {
            await embedState.goBack();
            return;
          }
        }
        if (!context.mounted) return;
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D12),
        body: SafeArea(
          top: true,
          bottom: false,
          child: Column(
            children: [
              _buildTopNavBar(),
              Expanded(
                child: _activeViewIndex == 0
                    ? _buildNativeMaterialsFeed()
                    : _buildWebViewEmbed(),
              ),
            ],
          ),
        ),
        floatingActionButton: _activeViewIndex == 0
            ? FloatingActionButton(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: const CircleBorder(),
                elevation: 4,
                onPressed: () {
                  setState(() {
                    _activeViewIndex = 1;
                    _progressNotifier.value = 0;
                    _embedKey.currentState?.reload();
                  });
                },
                child: const Icon(Icons.add, size: 28),
              )
            : null,
      ),
    );
  }

  /// Header with NX branding and segment switch between Materials and Live Web
  Widget _buildTopNavBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D12),
        border: Border(
          bottom: BorderSide(color: Color(0xFF1E1E28), width: 0.8),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Text(
                  'NX',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Nexus',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          Row(
            children: [
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: const Color(0xFF181822),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF282838), width: 0.8),
                ),
                child: Row(
                  children: [
                    _buildSegmentButton('Materials', 0),
                    _buildSegmentButton('Live Web', 1),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton(String label, int index) {
    final isSelected = _activeViewIndex == index;
    return GestureDetector(
      onTap: () {
        if (_activeViewIndex == index) return;
        setState(() {
          _activeViewIndex = index;
          if (index == 1) {
            _progressNotifier.value = 0;
            _embedKey.currentState?.reload();
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white60,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  /// Native materials feed backed by the Nexus Firestore, with an offline
  /// Hive tier, subject filters and real cursor pagination.
  Widget _buildNativeMaterialsFeed() {
    final service = NexusService();
    final stream = _materialsStream;

    if (stream == null) {
      // Nexus Firestore never initialised — say so instead of showing
      // "No materials found", which is what used to happen.
      return _NexusUnavailableState(
        message: service.initializationError ??
            'Nexus materials backend is unavailable. Pull to retry.',
        onRetry: () {
          setState(_initMaterials);
        },
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs;

        if (docs != null && docs.isNotEmpty) {
          final arrived = docs.map(_Material.fromDoc).toList();
          if (!_samePageAsRendered(arrived)) {
            // Firestore emitted a genuinely new page (the PWA or another uploader
            // added/removed a material). Let it re-render, then revalidate the
            // cache so the offline tier matches.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              unawaited(_persistMaterialsCache(arrived));
              unawaited(_verifyFeedParity(arrived.length));
            });
          }
          _lastCursor = docs.last;
        }

        if (snapshot.hasError && docs == null) {
          return _NexusUnavailableState(
            message: '${snapshot.error}',
            onRetry: () async {
              setState(_initMaterials);
              await Future<void>.delayed(const Duration(milliseconds: 300));
            },
          );
        }

        final isColdStream = snapshot.connectionState == ConnectionState.waiting && docs == null;
        if (isColdStream && _cachedMaterials.isEmpty) {
          return const _MaterialsSkeleton();
        }

        final all = _visibleMaterials(snapshot.data);
        final counts = _subjectCounts(all);
        final filtered = _filterBySubject(all);
        final usingCache = docs == null || docs.isEmpty;

        if (!usingCache) {
          final firstPage = snapshot.data!.docs.map(_Material.fromDoc).toList();
          _lastRenderedIds = firstPage.map((m) => m.docId).toList(growable: false);
          _lastRenderedVersions =
              firstPage.map((m) => m.version).toList(growable: false);
        }

        // Verify this surface against the shared Nexus collection.
        if (!usingCache && all.isNotEmpty) {
          unawaited(_verifyFeedParity(all.length));
        }

        if (all.isEmpty && !isColdStream) {
          return const Center(
            child: Text(
              'No materials found',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          );
        }

        final subjectKeys = counts.keys.toList();

        return RefreshIndicator(
          color: Colors.white,
          backgroundColor: const Color(0xFF191922),
          onRefresh: _refreshFeed,
          child: CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              if (usingCache && _cachedMaterials.isNotEmpty)
                SliverToBoxAdapter(child: _CacheBanner(onRefresh: _refreshFeed)),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SizedBox(
                    height: 42,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: subjectKeys.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final key = subjectKeys[index];
                        final count = counts[key] ?? 0;
                        final isSelected = _selectedSubject == key;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedSubject = key),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white : const Color(0xFF191922),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: isSelected ? Colors.white : const Color(0xFF282838),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  key == 'ALL' ? 'All' : key,
                                  style: TextStyle(
                                    color: isSelected ? Colors.black : Colors.white70,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFFE5E7EB)
                                        : const Color(0xFF262634),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '$count',
                                    style: TextStyle(
                                      color: isSelected ? Colors.black : Colors.white60,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
                  child: Text(
                    'Showing ${filtered.length} materials',
                    style: const TextStyle(
                      color: Color(0xFF88889C),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) => _buildMaterialCard(filtered[index]),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
                  child: _buildLoadMoreFooter(usingCache: usingCache),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadMoreFooter({required bool usingCache}) {
    if (usingCache) return const SizedBox.shrink();
    if (_isLoadingMore) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(8),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
          ),
        ),
      );
    }
    if (_loadMoreError != null) {
      return Column(
        children: [
          Text(
            'Could not load more materials',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _loadMore,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Try again'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFF323244)),
            ),
          ),
        ],
      );
    }
    if (!_hasMore) {
      return Center(
        child: Text(
          'You have reached the end',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 12),
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: _loadMore,
      icon: const Icon(Icons.expand_more_rounded, size: 18),
      label: const Text('Load more'),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Color(0xFF323244)),
      ),
    );
  }

  /// Rebuilds the first page and clears any accumulated pages.
  Future<void> _refreshFeed() async {
    setState(_bindFirstPage);
    // Give the new stream a chance to deliver before the indicator disappears.
    await _materialsStream?.first;
  }

  Widget _buildMaterialCard(_Material m) {
    final subjBg = _subjectBgColor(m.subject);
    final subjText = _subjectTextColor(m.subject);
    final dateStr = _formatDate(m.data['createdAt']);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF13131A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF232330), width: 1.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C161D),
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.2), width: 0.8),
                ),
                child: Text(
                  m.fileType,
                  style: const TextStyle(
                    color: Color(0xFFEF4444),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: subjBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: subjText.withValues(alpha: 0.2), width: 0.8),
                ),
                child: Text(
                  m.subject,
                  style: TextStyle(
                    color: subjText,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            m.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${m.uploaderName} • $dateStr • ${m.fileType}',
            style: const TextStyle(
              color: Color(0xFF7A7A8E),
              fontSize: 12.5,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    onPressed: () => _openMaterial(m),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text(
                      'View',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: m.fileUrl == null ? null : () => _downloadMaterial(m),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E1E28),
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF323244), width: 1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text(
                      'Download',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Live Embedded Webview PWA view with isolated progress listener
  Widget _buildWebViewEmbed() {
    final fbUser = FirebaseAuth.instance.currentUser;

    Widget buildView(NexusUserBridgeData? bridgeUser) {
      return SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            NexusEmbedView(
              key: _embedKey,
              url: NexusConfig.url,
              user: bridgeUser,
              onProgress: (p) => _progressNotifier.value = p,
              onLoaded: () => _progressNotifier.value = 100,
            ),
            ValueListenableBuilder<int>(
              valueListenable: _progressNotifier,
              builder: (context, progress, _) {
                if (progress > 0 && progress < 100) {
                  return Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LinearProgressIndicator(
                      value: progress / 100.0,
                      backgroundColor: Colors.transparent,
                      valueColor: const AlwaysStoppedAnimation<Color>(NexoraTheme.primary),
                      minHeight: 2.5,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      );
    }

    if (fbUser == null) return buildView(null);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(fbUser.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          // The bridge must not silently downgrade a user to "student".
          debugPrint('[NexusEmbed] identity read failed: ${snapshot.error}');
          return buildView(
            NexusUserBridgeData(
              uid: fbUser.uid,
              email: fbUser.email ?? '',
              name: fbUser.displayName ?? 'Student',
              photoUrl: fbUser.photoURL,
              role: 'student',
            ),
          );
        }
        final data = snapshot.data?.data();
        return buildView(
          NexusUserBridgeData(
            uid: fbUser.uid,
            email: fbUser.email ?? '',
            name: (data?['name'] ?? fbUser.displayName ?? 'Student').toString(),
            photoUrl: (data?['photoUrl'] ?? fbUser.photoURL)?.toString(),
            role: (data?['role'] ?? 'student').toString(),
          ),
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// Supporting widgets
// -----------------------------------------------------------------------------

/// Modal that downloads a material to device storage and reports the result.
class _DownloadSheet extends StatefulWidget {
  final String title;
  final String fileName;
  final String url;

  const _DownloadSheet({
    required this.title,
    required this.fileName,
    required this.url,
  });

  @override
  State<_DownloadSheet> createState() => _DownloadSheetState();
}

class _DownloadSheetState extends State<_DownloadSheet> {
  bool _busy = false;
  bool _done = false;
  String? _error;
  String? _destination;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _busy = true;
      _error = null;
      _done = false;
    });
    try {
      final destination = await MaterialDownloadService.saveToDownloads(
        url: widget.url,
        fileName: widget.fileName,
      );
      if (!mounted) return;
      setState(() {
        _destination = destination;
        _done = true;
        _busy = false;
      });
    } on MaterialDownloadException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Save to device',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              widget.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 13.5),
            ),
            const SizedBox(height: 4),
            Text(
              widget.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF7A7A8E),
                fontSize: 11.5,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 20),
            if (_busy) ...[
              const LinearProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                backgroundColor: Color(0xFF232330),
                minHeight: 5,
              ),
              const SizedBox(height: 12),
              const Text(
                'Downloading…',
                style: TextStyle(color: Colors.white60, fontSize: 12.5),
              ),
            ] else if (_done) ...[
              Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF34D399), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Saved to $_destination',
                      style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Close'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF323244)),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C161D),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: Color(0xFFEF4444), size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _error ?? 'Download failed',
                        style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Close'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF323244)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _start,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Retry'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shown when the Nexus backend cannot be reached, with a retry affordance.
class _NexusUnavailableState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _NexusUnavailableState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: Colors.white38, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Nexus materials unavailable',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFF323244)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Banner shown when the feed is being served from the offline Hive cache.
class _CacheBanner extends StatelessWidget {
  final Future<void> Function() onRefresh;

  const _CacheBanner({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A24),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2A38)),
      ),
      child: Row(
        children: [
          const Icon(Icons.offline_bolt_outlined, color: Color(0xFFF5A524), size: 16),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Showing saved materials',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: onRefresh,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text('Refresh', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

/// Cold-start skeleton for the materials feed.
class _MaterialsSkeleton extends StatelessWidget {
  const _MaterialsSkeleton();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 240,
        height: 160,
        child: Card(
          color: const Color(0xFF13131A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(width: 200, height: 18, color: const Color(0xFF232330)),
                const SizedBox(height: 8),
                Container(
                  width: 160,
                  height: 12,
                  color: const Color(0xFF232330).withValues(alpha: 0.6),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Container(width: 80, height: 36, color: const Color(0xFF232330)),
                    Container(width: 80, height: 36, color: const Color(0xFF232330)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}