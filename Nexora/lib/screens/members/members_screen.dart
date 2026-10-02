import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/cache/cache_service.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/member_card.dart';
import '../../widgets/nx_card.dart';
import '../../widgets/nexora_logo.dart';
import '../../widgets/status_screens.dart';
import '../admin/admin_portal_screen.dart';
import '../profile/profile_edit_screen.dart';
import 'pokemon_card_screen.dart';

/// The verified student directory.
///
/// Features instant Hive caching with 15-minute TTL, background silent refresh,
/// and pagination with a real Firestore document cursor.
class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  static const int _pageSize = 100;

  final List<UserModel> _users = [];
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<List<UserModel>>? _subscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSubscription;

  UserModel? _currentUser;
  DocumentSnapshot<Map<String, dynamic>>? _cursor;
  bool _loadingMore = false;
  bool _hasMore = false;
  bool _receivedFirstPage = false;
  bool _isUpdating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFromCache();
    _loadCurrentUser();
    _startBackgroundSync();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _userSubscription?.cancel();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  /// Immediately resolves the current user's profile from cache and live Firestore stream.
  void _loadCurrentUser() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final cached = CacheService().getUserProfile(uid);
    if (cached != null) {
      _currentUser = UserModel.fromMap(cached, uid);
    }

    _userSubscription?.cancel();
    _userSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen(
      (docSnap) {
        if (!mounted) return;
        if (docSnap.exists && docSnap.data() != null) {
          final liveUser = UserModel.fromFirestore(docSnap);
          setState(() {
            _currentUser = liveUser;
          });
          CacheService().saveUserProfile(uid, docSnap.data()!);
        }
      },
      onError: (err) {
        debugPrint('[MembersScreen] current user sync error: $err');
      },
    );
  }

  /// Synchronously loads cached directory members from Hive for instant tab entry.
  void _loadFromCache() {
    final cached = CacheService().getMembers();
    if (cached != null && cached.isNotEmpty) {
      final members = cached
          .map((m) => UserModel.fromMap(m, (m['uid'] ?? '').toString()))
          .toList();
      setState(() {
        _users.clear();
        _users.addAll(members);
        _receivedFirstPage = true;
        _hasMore = members.length >= _pageSize;
      });
    }
  }

  /// Starts background sync against Firestore.
  void _startBackgroundSync() {
    final isStale = CacheService().isMembersCacheStale || _users.isEmpty;
    if (isStale) {
      setState(() => _isUpdating = true);
    }

    _subscription?.cancel();
    _subscription = FirestoreService()
        .streamVerifiedUsers(limit: _pageSize)
        .listen(
      (freshUsers) {
        if (!mounted) return;
        setState(() {
          _users.clear();
          _users.addAll(freshUsers);
          _receivedFirstPage = true;
          _isUpdating = false;
          _errorMessage = null;
          _hasMore = freshUsers.length >= _pageSize;
        });

        // Persist to Hive cache silently in background
        CacheService().saveMembers(freshUsers.map((u) => u.toMap()).toList());
      },
      onError: (err) {
        if (!mounted) return;
        setState(() {
          _isUpdating = false;
          if (_users.isEmpty) {
            _errorMessage = authErrorMessage(err);
          }
        });
        debugPrint('[MembersScreen] sync error: $err');
      },
    );
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  /// Appends the next directory page.
  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || !_receivedFirstPage) return;
    setState(() => _loadingMore = true);
    try {
      final snap = await FirestoreService().loadMoreUsers(
        after: _cursor,
        limit: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        if (snap.docs.isEmpty) {
          _hasMore = false;
        } else {
          _cursor = snap.docs.last;
          if (snap.docs.length < _pageSize) {
            _hasMore = false;
          } else {
            _hasMore = true;
          }
        }
        _users.addAll(snap.docs.map(UserModel.fromFirestore));
        _loadingMore = false;
      });

      // Update cache with all loaded pages
      CacheService().saveMembers(_users.map((u) => u.toMap()).toList());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
        _hasMore = false;
      });
      debugPrint('[MembersScreen] load more failed: $e');
    }
  }

  static void _openEditor(BuildContext context, UserModel user) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => ProfileEditScreen(user: user)),
    );
  }

  static void _openPokemonCard(
    BuildContext context,
    UserModel user, {
    required bool isSelf,
    required bool isViewerAdmin,
    VoidCallback? onEditProfile,
  }) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, __, ___) => PokemonCardScreen(
          user: user,
          isSelf: isSelf,
          isViewerAdmin: isViewerAdmin,
          onEditProfile: onEditProfile,
        ),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 280),
      ),
    );
  }

  static void _openAdminPortal(BuildContext context, UserModel admin) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminPortalScreen(currentAdmin: admin),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: NexoraTheme.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: NexoraTheme.border),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'Sign Out',
              style: GoogleFonts.syne(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: NexoraTheme.textPrimary,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to sign out of Nexora? You will need to sign in again to access materials and community features.',
          style: GoogleFonts.inter(
            color: NexoraTheme.textSecondary,
            fontSize: 13.5,
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: NexoraTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(
              'Sign Out',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await AuthService().signOut();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Sign out failed: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final selfUser = _currentUser ?? (uid != null ? _users.where((u) => u.uid == uid).firstOrNull : null);
    final adminUser = (selfUser != null && selfUser.isAdmin) ? selfUser : null;

    if (_users.isEmpty && _isUpdating && selfUser == null) {
      return Scaffold(
        backgroundColor: NexoraTheme.scaffold,
        appBar: AppBar(
          title: Text(
            'Members',
            style: GoogleFonts.syne(fontWeight: FontWeight.w700, fontSize: 20),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_users.isEmpty && _errorMessage != null && selfUser == null) {
      return Scaffold(
        backgroundColor: NexoraTheme.scaffold,
        appBar: AppBar(
          title: Text(
            'Members',
            style: GoogleFonts.syne(fontWeight: FontWeight.w700, fontSize: 20),
          ),
        ),
        body: MessageScreen(
          compact: true,
          icon: Icons.cloud_off_rounded,
          title: 'Directory unavailable',
          message: _errorMessage!,
        ),
      );
    }

    final peers = <UserModel>[];
    for (final user in _users) {
      if (uid == null || user.uid != uid) {
        peers.add(user);
      }
    }
    peers.sort((a, b) => a.uid.hashCode.compareTo(b.uid.hashCode));

    final body = <Widget>[
      NxSectionLabel('Your Profile'),
      if (selfUser != null) ...[
        MemberCard(
          user: selfUser,
          isSelf: true,
          onTap: () => _openPokemonCard(
            context,
            selfUser,
            isSelf: true,
            isViewerAdmin: adminUser != null,
            onEditProfile: () => _openEditor(context, selfUser),
          ),
          onSwipeToEdit: () => _openEditor(context, selfUser),
        ),
      ] else ...[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: NexoraTheme.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: NexoraTheme.border),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: NexoraTheme.primary),
                ),
                const SizedBox(width: 14),
                Text(
                  'Loading your profile...',
                  style: GoogleFonts.inter(color: NexoraTheme.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ],
      const SizedBox(height: 10),
      NxSectionLabel('Verified directory  •  ${peers.length + (selfUser != null || uid != null ? 1 : 0)}'),
      if (peers.isEmpty && !_isUpdating)
        const _EmptyDirectory()
      else
        ...peers.map((user) => MemberCard(
              user: user,
              isSelf: false,
              onTap: () => _openPokemonCard(
                context,
                user,
                isSelf: false,
                isViewerAdmin: adminUser != null,
              ),
            )),
      if (_loadingMore)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
    ];

    return Scaffold(
      backgroundColor: NexoraTheme.scaffold,
      appBar: AppBar(
        title: Row(
          children: [
            const NexoraLogo(size: 22, showWordmark: false),
            const SizedBox(width: 10),
            Text(
              'Members',
              style: GoogleFonts.syne(
                fontWeight: FontWeight.w700,
                fontSize: 20,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        actions: [
          if (adminUser != null)
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('pendingUsers')
                  .snapshots(),
              builder: (context, pendingSnap) {
                if (pendingSnap.hasError) {
                  debugPrint('[MembersScreen] pending users stream error: ${pendingSnap.error}');
                }
                final pendingCount = pendingSnap.data?.docs.length ?? 0;
                final iconBtn = IconButton(
                  tooltip: pendingCount > 0
                      ? 'Admin portal ($pendingCount pending approval)'
                      : 'Admin portal',
                  onPressed: () => _openAdminPortal(context, adminUser),
                  icon: const Icon(Icons.admin_panel_settings_outlined, color: NexoraTheme.primary),
                );

                if (pendingCount > 0) {
                  return Badge(
                    label: Text(
                      '$pendingCount',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    backgroundColor: const Color(0xFF9D4EDD),
                    alignment: const AlignmentDirectional(0.7, -0.6),
                    child: iconBtn,
                  );
                }
                return iconBtn;
              },
            ),
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout_rounded, color: Colors.white70, size: 20),
            onPressed: () => _confirmSignOut(context),
          ),
          const SizedBox(width: 4),
        ],
        bottom: _isUpdating
            ? const PreferredSize(
                preferredSize: Size.fromHeight(24),
                child: _UpdatingIndicator(),
              )
            : null,
      ),
      body: ListView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        padding: const EdgeInsets.only(top: 10, bottom: 40),
        children: body,
      ),
    );
  }
}

class _UpdatingIndicator extends StatelessWidget {
  const _UpdatingIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 24,
      color: NexoraTheme.card,
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 11,
            height: 11,
            child: CircularProgressIndicator(
              strokeWidth: 1.6,
              color: NexoraTheme.primary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Updating directory...',
            style: GoogleFonts.inter(
              color: NexoraTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyDirectory extends StatelessWidget {
  const _EmptyDirectory();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Container(
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          color: NexoraTheme.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: NexoraTheme.border),
        ),
        child: Column(
          children: [
            const Icon(Icons.groups_outlined, size: 32, color: NexoraTheme.textSecondary),
            const SizedBox(height: 12),
            Text(
              'No other members yet',
              textAlign: TextAlign.center,
              style: GoogleFonts.syne(
                color: NexoraTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'You are the first vouched identity in the community. Peer cards '
              'appear the moment admins approve more students.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: NexoraTheme.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
