import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../core/models/nexora_models.dart';
import '../../screens/profile/profile_edit_screen.dart';

class MembersScreen extends StatelessWidget {
  const MembersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<NexoraUser>>(
      stream: context.read<FirestoreService>().streamVerifiedUsers(),
      builder: (context, snapshot) {
        final auth = context.watch<AuthService>();
        final isAdmin = auth.currentUser?.role == 'admin' || auth.currentUser?.role == 'approver';
        if (!snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(
              title: isAdmin ? Text('Admin Engine') : const Text('Members'),
            ),
            body: isAdmin
                ? const AdminDashboard()
                : const Center(child: CircularProgressIndicator()),
          );
        }
        final users = snapshot.data!;
        final currentUser = auth.currentUser;
        return Scaffold(
          appBar: AppBar(
            title: isAdmin
                ? Text('Admin Engine')
                : Text('Members (${users.length})'),
          ),
          body: isAdmin
              ? const AdminDashboard()
              : MembersDirectoryPaginated(
                  allUsers: users,
                  currentUser: currentUser,
                ),
        );
      },
    );
  }
}

class MembersDirectoryPaginated extends StatefulWidget {
  final List<NexoraUser> allUsers;
  final NexoraUser? currentUser;

  const MembersDirectoryPaginated({
    super.key,
    required this.allUsers,
    required this.currentUser,
  });

  @override
  State<MembersDirectoryPaginated> createState() => _MembersDirectoryPaginatedState();
}

class _MembersDirectoryPaginatedState extends State<MembersDirectoryPaginated> {
  static const _pageSize = 20;
  late final ScrollController _scrollController;
  List<NexoraUser> _displayedUsers = [];
  int _loadedPages = 0;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _loadInitialPage();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore) {
        _loadMore();
      }
    }
  }

  Future<void> _loadInitialPage() async {
    setState(() {
      _displayedUsers = [];
      _loadedPages = 1;
      _isLoadingMore = true;
    });

    final peers = widget.allUsers
        .where((u) => widget.currentUser != null && u.uid != widget.currentUser!.uid)
        .toList();

    setState(() {
      _displayedUsers.addAll(peers.take(_pageSize));
      _loadedPages = 1;
      _isLoadingMore = false;
      _hasMore = peers.length > _pageSize;
    });
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    final peers = widget.allUsers
        .where((u) => widget.currentUser != null && u.uid != widget.currentUser!.uid)
        .toList();

    final startIndex = _loadedPages * _pageSize;
    final endIndex = startIndex + _pageSize;
    final newUsers = peers.skip(startIndex).take(_pageSize).toList();

    setState(() {
      _displayedUsers.addAll(newUsers);
      _loadedPages++;
      _isLoadingMore = false;
      _hasMore = endIndex < peers.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final peers = widget.allUsers
        .where((u) => widget.currentUser != null && u.uid != widget.currentUser!.uid)
        .toList();

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // Self pinned card
        SliverToBoxAdapter(
          child: widget.currentUser != null
              ? _SelfProfileCard(user: widget.currentUser)
              : const SizedBox.shrink(),
        ),
        // Peer cards — scrambled, unclickable, with badges
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => _PeerCard(user: _displayedUsers[i]),
              childCount: _displayedUsers.length,
            ),
          ),
        ),
        // Loading indicator
        if (_isLoadingMore)
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SelfProfileCard extends StatelessWidget {
  final NexoraUser? user;
  const _SelfProfileCard({this.user});

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.cardSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.dividerColor),
        ),
        child: const Center(child: Text('Not logged in')),
      );
    }

    final isSelfAdmin = user!.role == 'admin' || user!.role == 'superadmin';
    final selfRoleColor = user!.role == 'superadmin'
        ? const Color(0xFF9D4EDD)
        : const Color(0xFF4F8BFF);

    return GestureDetector(
      onTap: () => _navigateToPokemonCardWithFade(context, user!),
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF9D4EDD).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF9D4EDD).withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(3.0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelfAdmin ? selfRoleColor : Colors.transparent,
                  width: 3.0,
                ),
                boxShadow: isSelfAdmin
                    ? [
                        BoxShadow(
                          color: selfRoleColor.withValues(alpha: 0.45),
                          blurRadius: 10,
                          spreadRadius: 1.5,
                        ),
                      ]
                    : null,
              ),
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: user!.profilePicUrl != null
                        ? CachedNetworkImageProvider(user!.profilePicUrl!)
                        : null,
                    backgroundColor: Color(0xFF9D4EDD).withValues(alpha: 0.2),
                    child: user!.profilePicUrl == null
                        ? Text(
                            user!.name.isNotEmpty ? user!.name[0].toUpperCase() : '?',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: isSelfAdmin ? selfRoleColor : const Color(0xFF9D4EDD),
                            ),
                          )
                        : null,
                  ),
                  // Admin seal stamps
                  ...user!.sealColors.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final seal = entry.value;
                    return Positioned(
                      right: idx * 5.0,
                      bottom: idx * 5.0,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Color(seal.colorValue),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.darkSlate, width: 1.5),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user!.name,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSelfAdmin) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: selfRoleColor,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                color: selfRoleColor.withValues(alpha: 0.4),
                                blurRadius: 6,
                                offset: const Offset(0, 1.5),
                              ),
                            ],
                          ),
                          child: Text(
                            user!.role == 'superadmin' ? 'Super Admin' : 'Admin',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.successGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Self',
                          style: TextStyle(
                            color: AppTheme.successGreen,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Reg: ${user!.regNo} • ${user!.faculty}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted)),
                  Text('Slot: ${user!.slot}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
                ],
              ),
            ),
            // Tap to edit indicator
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _showEditProfile(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Color(0xFF9D4EDD).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit, size: 14, color: Color(0xFF9D4EDD)),
                    SizedBox(width: 4),
                    Text('Edit', style: TextStyle(color: Color(0xFF9D4EDD), fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditProfile(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Edit Profile', style: Theme.of(ctx).textTheme.headlineSmall),
            const SizedBox(height: 16),
            const SizedBox(height: 8),
            Text('Profile updates will sync to the verified user record.',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }

  void _navigateToPokemonCardWithFade(BuildContext context, NexoraUser user) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => PokemonCardPage(user: user),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }
}

class _PeerCard extends StatelessWidget {
  final NexoraUser user;
  const _PeerCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _navigateToPokemonCardWithFade(context, user),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.darkSlate,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.dividerColor),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppTheme.darkSlate,
                  child: const Icon(Icons.person, color: AppTheme.textMuted),
                ),
                // Approver-colored verification badges (scrambled)
                ...user.sealColors.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final seal = entry.value;
                  return Positioned(
                    right: idx * 4.0,
                    bottom: idx * 4.0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Color(seal.colorValue),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.darkSlate, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Color(seal.colorValue).withValues(alpha: 0.5),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Scrambled / anonymized display — no clickable name
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          user.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textMuted,
                                  ),
                        ),
                      ),
                      if (user.isVerified)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.successGreen.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('Verified',
                              style: TextStyle(color: AppTheme.successGreen, fontSize: 10, fontWeight: FontWeight.w600)),
                        )
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Reg: ${user.regNo}', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
                  Text('Slot: ${user.slot} • ${user.faculty}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
                  Text('Seals: ${user.auditSeals.length} admin${user.auditSeals.length > 1 ? 's' : ''}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.textMuted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToPokemonCardWithFade(BuildContext context, NexoraUser user) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => PokemonCardPage(user: user),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }
}

// ===================================================================
// ADMIN ENGINE — Multi-field search + approval queue
// ===================================================================
class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _searchCtrl = TextEditingController();
  String _searchType = 'Name';
  List<NexoraUser> _results = [];
  List<NexoraUser> _pendingUsers = [];
  bool _searching = false;

  static const List<String> _searchTypes = ['Name', 'Reg No', 'Faculty', 'Slot'];

  @override
  void initState() {
    super.initState();
    _loadPending();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPending() async {
    final firestore = context.read<FirestoreService>();
    final list = await firestore.getPendingUsers();
    setState(() => _pendingUsers = list);
  }

  Future<void> _runSearch() async {
    if (_searchCtrl.text.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _searching = true);
    final firestore = context.read<FirestoreService>();
    final query = _searchCtrl.text.trim();
    List<NexoraUser> results = [];
    switch (_searchType) {
      case 'Name':
        results = await firestore.searchUsers(name: query);
        break;
      case 'Reg No':
        results = await firestore.searchUsers(regNo: query);
        break;
      case 'Faculty':
        results = await firestore.searchUsers(faculty: query);
        break;
      case 'Slot':
        results = await firestore.searchUsers(slot: query);
        break;
    }
    setState(() {
      _results = results;
      _searching = false;
    });
  }

  Future<void> _approveUser(NexoraUser pendingUser) async {
    final auth = context.read<AuthService>();
    final adminUid = auth.currentUser!.uid;

    final err = await auth.approveStudent(
      studentUid: pendingUser.uid,
      adminUid: adminUid,
      studentName: pendingUser.name,
      studentRegNo: pendingUser.regNo,
      studentFaculty: pendingUser.faculty,
      studentSlot: pendingUser.slot,
      studentEmail: pendingUser.email,
    );
    if (err == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Approved ${pendingUser.name}'),
          duration: const Duration(seconds: 2),
        ),
      );
      await _loadPending();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Approval failed: $err'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Search Section
        Text('Search Users', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search...',
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
                onSubmitted: (_) => _runSearch(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<String>(
                value: _searchType,
                decoration: const InputDecoration(border: InputBorder.none),
                items: _searchTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _searchType = v!),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _searching ? null : _runSearch,
            child: _searching
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Search'),
          ),
        ),

        // Results
        if (_results.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Search Results (${_results.length})', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ..._results.map((user) => _UserResultCard(user: user)),
        ],

        // Pending Approval Queue
        const SizedBox(height: 32),
        Row(
          children: [
            Text('Approval Queue', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Color(0xFF9D4EDD),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_pendingUsers.length}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_pendingUsers.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.cardSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.dividerColor),
            ),
            child: const Center(
              child: Text('No pending approvals', style: TextStyle(color: AppTheme.textMuted)),
            ),
          )
        else
          ..._pendingUsers.map((user) => _ApprovalCard(
                user: user,
                onApprove: () => _approveUser(user),
              )),
      ],
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  final NexoraUser user;
  final VoidCallback onApprove;

  const _ApprovalCard({required this.user, required this.onApprove});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Color(0xFF9D4EDD).withValues(alpha: 0.15),
                  child: Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                    style: const TextStyle(color: Color(0xFF9D4EDD), fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.name, style: Theme.of(context).textTheme.titleMedium),
                      Text('Reg: ${user.regNo} • ${user.faculty} • Slot: ${user.slot}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text('Email: ${user.email}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
                ),
                ElevatedButton(
                  onPressed: onApprove,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                  child: const Text('Approve'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UserResultCard extends StatelessWidget {
  final NexoraUser user;
  const _UserResultCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Scrambled / unclickable peer card with verification badges
            Stack(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppTheme.darkSlate,
                ),
                // Approver-colored verification seals
                ...user.sealColors.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final seal = entry.value;
                  return Positioned(
                    right: idx * 4.0,
                    bottom: idx * 4.0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Color(seal.colorValue),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.darkSlate, width: 1.5),
                      ),
                    );
                  }).toList(),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.name, style: Theme.of(context).textTheme.titleMedium),
                  Text('${user.regNo} • ${user.faculty} • Slot ${user.slot}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted)),
                ],
              ),
            ),
            // Verification status
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: user.isVerified ? AppTheme.successGreen.withValues(alpha: 0.1) : AppTheme.warningAmber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                user.isVerified ? 'Verified' : 'Pending',
                style: TextStyle(
                  color: user.isVerified ? AppTheme.successGreen : AppTheme.warningAmber,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}