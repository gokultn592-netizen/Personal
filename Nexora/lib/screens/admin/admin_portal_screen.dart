import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:nexora/core/constants.dart';
import 'package:nexora/core/services/push_notification_service.dart';
import 'package:nexora/core/theme.dart';
import 'package:nexora/models/user_model.dart';
import 'package:nexora/services/nexus_service.dart';
import 'package:nexora/widgets/nx_avatar.dart';
import 'package:nexora/widgets/nexora_logo.dart';
import 'package:nexora/widgets/role_badge.dart';

enum SearchFilterMode { all, byFaculty, byRegNo, bySlot, byDepartment }

class AdminPortalScreen extends StatefulWidget {
  final UserModel currentAdmin;

  const AdminPortalScreen({super.key, required this.currentAdmin});

  @override
  State<AdminPortalScreen> createState() => _AdminPortalScreenState();
}

class _AdminPortalScreenState extends State<AdminPortalScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Search Members State
  SearchFilterMode _selectedFilter = SearchFilterMode.all;
  final TextEditingController _searchController = TextEditingController();
  String _debouncedQuery = '';

  @override
  void initState() {
    super.initState();
    final tabCount = widget.currentAdmin.isSuperAdmin ? 4 : 3;
    _tabController = TabController(length: tabCount, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() => _debouncedQuery = query.trim().toLowerCase());
  }

  // --- Segment 1: Atomic Approval Transaction ---
  Future<void> _approveCandidate(DocumentSnapshot pendingDoc) async {
    final candidateUid = pendingDoc.id;
    final candidateData = (pendingDoc.data() as Map<String, dynamic>?) ?? {};
    final candidateName = (candidateData['name'] ?? '').toString();
    final regNo = (candidateData['regNo'] ?? '').toString();
    final candidateEmail = (candidateData['email'] ?? '').toString();

    // Cross-project duplicate guard (read-only).
    //
    // One human can hold a Nexus account and a Nexora account, and the same
    // email can appear twice in the pending queue. Approving both would mint two
    // vouched identities for one person, defeating the point of the directory.
    // This reads Nexus standing only — Nexora never writes to Nexus.
    final nexusMember = await NexusService().lookupMember(candidateEmail);
    if (nexusMember != null && nexusMember.isApproved) {
      final proceed = await _confirmAlreadyApprovedInNexus(
        name: candidateName,
        regNo: regNo,
        email: candidateEmail,
        nexusRole: nexusMember.role,
        nexusName: nexusMember.name,
      );
      if (proceed != true) return;
    }

    try {
      final firestore = FirebaseFirestore.instance;

      await firestore.runTransaction((transaction) async {
        final pendingRef = pendingDoc.reference;
        final userRef = firestore.collection('users').doc(candidateUid);

        final pendingSnapshot = await transaction.get(pendingRef);
        if (!pendingSnapshot.exists) {
          throw Exception("Candidate registration record no longer exists.");
        }

        final coursesRaw = (candidateData['courses'] as List<dynamic>?) ?? [];
        final clubsRaw = (candidateData['clubs'] as List<dynamic>?) ?? [];
        final faculties = coursesRaw
            .map((c) => (c['faculty'] ?? '').toString().trim().toLowerCase())
            .where((f) => f.isNotEmpty)
            .toSet()
            .toList();

        // 1. Construct verified user contract with audit stamps
        final newUserData = {
          'uid': candidateUid,
          'email': candidateData['email'] ?? '',
          'name': candidateName,
          'regNo': regNo,
          'branch': candidateData['branch'] ?? '',
          'year': candidateData['year'] ?? '',
          'phoneNo': candidateData['phoneNo'] ?? '',
          'photoUrl': candidateData['photoUrl'],
          'role': 'student',
          // AuthGate checks `status` first; the approval transaction must stamp
          // it or the approved user is re-routed to the onboarding form.
          'status': 'approved',
          'isNexusMember': candidateData['isNexusMember'] == true,
          'adminColorHex': null,
          'approvedBy': widget.currentAdmin.uid,
          'approverColorHex': widget.currentAdmin.adminColorHex ?? widget.currentAdmin.approverColorHex,
          'academic': {
            'proctorName': candidateData['proctorName'] ?? candidateData['facultyAdvisor'] ?? '',
            'facultyAdvisor': candidateData['proctorName'] ?? candidateData['facultyAdvisor'] ?? '',
            'coreSlot': candidateData['coreSlot'] ?? '',
            'nptel': '',
            'extraCurricular': '',
            'clubs': List<String>.from(clubsRaw),
          },
          'courses': coursesRaw,
          'searchIndices': {
            'faculties': faculties,
            'regNoLower': regNo.toLowerCase(),
            'nameLower': candidateName.toLowerCase(),
          },
          'createdAt': FieldValue.serverTimestamp(),
        };

        // 2. Atomic Transfer
        transaction.set(userRef, newUserData);
        transaction.delete(pendingRef);
      });

      // 3. Nothing is written to Nexus. Nexus is a live community platform with
      //    its own admin flow and is the source of truth for membership;
      //    Nexora is a read-only mirror of it. A candidate approved here is
      //    recorded as `isNexusMember` and the Pending screen watches their
      //    Nexus standing, but granting Nexus membership is a Nexus admin's
      //    decision alone.
      // 3. Notify student of approval
      unawaited(PushNotificationService.instance.notifyStudentApproval(
        studentUid: candidateUid,
        studentName: candidateName,
        approved: true,
      ));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: NexoraTheme.success,
          content: Text('Candidate $candidateName ($regNo) verified.'),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: NexoraTheme.error,
            content: Text('Approval transaction failed: $e'),
          ),
        );
      }
    }
  }

  /// Asks the admin to confirm when a candidate is already an approved member
  /// of the Nexus community, which usually means a duplicate record.
  Future<bool?> _confirmAlreadyApprovedInNexus({
    required String name,
    required String regNo,
    required String email,
    required String nexusRole,
    String? nexusName,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NexoraTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.link_rounded, color: Color(0xFFF5A524), size: 22),
            SizedBox(width: 10),
            Text('Already in Nexus',
                style: TextStyle(
                    color: NexoraTheme.textPrimary, fontSize: 16.5)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$name ($regNo) already has an approved Nexus account '
              '(role: $nexusRole).',
              style: const TextStyle(
                  color: NexoraTheme.textSecondary, fontSize: 13.5, height: 1.45),
            ),
            const SizedBox(height: 12),
            _KeyValue(label: 'Email', value: email),
            if (nexusName != null && nexusName.isNotEmpty)
              _KeyValue(label: 'Nexus name', value: nexusName),
            const SizedBox(height: 12),
            const Text(
              'Approving creates a Nexora identity for someone Nexus already '
              'recognises. That is expected for a Nexus member joining Nexora. '
              'Continue only if this is the same person and not a duplicate '
              'registration.',
              style: TextStyle(color: Color(0xFFF5A524), fontSize: 12.5, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: NexoraTheme.textSecondary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF5A524)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Approve anyway'),
          ),
        ],
      ),
    );
  }

  Future<void> _rejectCandidate(DocumentSnapshot pendingDoc) async {
    final candidateData = (pendingDoc.data() as Map<String, dynamic>?) ?? {};
    try {
      await pendingDoc.reference.delete();

      // Notify student of rejection
      unawaited(PushNotificationService.instance.notifyStudentApproval(
        studentUid: pendingDoc.id,
        studentName: (candidateData['name'] ?? 'Candidate').toString(),
        approved: false,
      ));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: NexoraTheme.error,
            content: Text('Registration for ${candidateData['name'] ?? 'Candidate'} rejected.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: NexoraTheme.error, content: Text('Rejection error: $e')),
        );
      }
    }
  }

  // --- Segment 3: Super Admin Role Promotion Dialog ---
  void _openRolePromotionDialog(BuildContext context, UserModel targetUser) {
    String selectedRole = targetUser.role;
    String selectedColor = targetUser.adminColorHex ?? NexoraTheme.adminColorHexOptions.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: NexoraTheme.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: NexoraTheme.border),
          ),
          title: Text(
            'Promote / Demote: ${targetUser.name}',
            style: GoogleFonts.syne(color: NexoraTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Assigned Role', style: GoogleFonts.inter(color: NexoraTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: selectedRole,
                dropdownColor: NexoraTheme.card,
                style: GoogleFonts.inter(color: NexoraTheme.textPrimary, fontSize: 14),
                items: [
                  DropdownMenuItem(value: 'student', child: Text('Student', style: GoogleFonts.inter())),
                  DropdownMenuItem(value: 'admin', child: Text('Admin', style: GoogleFonts.inter())),
                  DropdownMenuItem(value: 'superadmin', child: Text('Super Admin', style: GoogleFonts.inter())),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedRole = val);
                },
              ),
              if (selectedRole == 'admin' || selectedRole == 'superadmin') ...[
                const SizedBox(height: 16),
                Text(
                  'Approver Signature Color Stamp',
                  style: GoogleFonts.inter(color: NexoraTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  children: NexoraTheme.adminColorHexOptions.map((hex) {
                    final color = NexoraTheme.parseHex(hex);
                    final isSelected = selectedColor.toLowerCase() == hex.toLowerCase();
                    return GestureDetector(
                      onTap: () => setDialogState(() => selectedColor = hex),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.transparent,
                            width: 2.5,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, size: 18, color: Colors.white)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: GoogleFonts.inter(color: NexoraTheme.textSecondary, fontWeight: FontWeight.w600)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: NexoraTheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                // firestore.rules allows role changes only for a superadmin.
                // Check locally too so the failure is not a silent rejection.
                if (!widget.currentAdmin.isSuperAdmin) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: NexoraTheme.error,
                      content: Text('Only a Super Admin can change roles.'),
                    ),
                  );
                  return;
                }
                try {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(targetUser.uid)
                      .update({
                    'role': selectedRole,
                    'adminColorHex':
                        (selectedRole == 'admin' || selectedRole == 'superadmin')
                            ? selectedColor
                            : null,
                    'approverColorHex':
                        (selectedRole == 'admin' || selectedRole == 'superadmin')
                            ? selectedColor
                            : targetUser.approverColorHex,
                  });
                  if (mounted) {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: NexoraTheme.success,
                        content: Text('Updated ${targetUser.name} to $selectedRole'),
                      ),
                    );
                  }
                } catch (e) {
                  // Previously unguarded: a failed promotion showed nothing.
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: NexoraTheme.error,
                        content: Text('Role update failed: $e'),
                      ),
                    );
                  }
                }
              },
              child: Text('Save', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.currentAdmin.isAdmin) {
      return Scaffold(
        backgroundColor: NexoraTheme.scaffold,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.gpp_bad_rounded, size: 64, color: NexoraTheme.error),
              const SizedBox(height: 16),
              Text(
                'Access Denied',
                style: GoogleFonts.syne(color: NexoraTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Administrative privileges required.',
                style: GoogleFonts.inter(color: NexoraTheme.textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: NexoraTheme.scaffold,
      appBar: AppBar(
        title: Row(
          children: [
            const NexoraLogo(size: 22, showWordmark: false),
            const SizedBox(width: 10),
            Text(
              'Admin Audit Engine',
              style: GoogleFonts.syne(
                fontWeight: FontWeight.w700,
                fontSize: 19,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: NexoraTheme.primary,
          labelColor: NexoraTheme.primary,
          unselectedLabelColor: NexoraTheme.textSecondary,
          labelStyle: GoogleFonts.syne(fontWeight: FontWeight.w700, fontSize: 12.5),
          unselectedLabelStyle: GoogleFonts.syne(fontWeight: FontWeight.w600, fontSize: 12.5),
          tabs: [
            const Tab(icon: Icon(Icons.how_to_reg_outlined, size: 18), text: 'Pending Queue'),
            const Tab(icon: Icon(Icons.manage_search_outlined, size: 18), text: 'Member Records'),
            const Tab(icon: Icon(Icons.menu_book_rounded, size: 18), text: 'Courses'),
            if (widget.currentAdmin.isSuperAdmin)
              const Tab(icon: Icon(Icons.admin_panel_settings_outlined, size: 18), text: 'Promotions'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendingQueueTab(),
          _buildMemberRecordsTab(),
          _buildCourseCatalogTab(),
          if (widget.currentAdmin.isSuperAdmin) _buildRolePromotionTab(),
        ],
      ),
    );
  }

  // --- Tab 1: Pending Queue ---
  Widget _buildPendingQueueTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('pendingUsers').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: NexoraTheme.primary));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: NexoraTheme.card,
                    shape: BoxShape.circle,
                    border: Border.all(color: NexoraTheme.border),
                  ),
                  child: const Icon(Icons.check_circle_outline_rounded, size: 36, color: NexoraTheme.success),
                ),
                const SizedBox(height: 14),
                Text(
                  'Queue Cleared',
                  style: GoogleFonts.syne(
                    color: NexoraTheme.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'No pending candidate applications to audit.',
                  style: GoogleFonts.inter(color: NexoraTheme.textSecondary, fontSize: 13),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final doc = docs[i];
            final candidate = PendingUserModel.fromFirestore(doc);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: NexoraTheme.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: NexoraTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        candidate.name,
                        style: GoogleFonts.syne(
                          color: NexoraTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: NexoraTheme.scaffold,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: NexoraTheme.border),
                        ),
                        child: Text(
                          candidate.regNo,
                          style: NexoraTheme.monoStyle(
                            color: NexoraTheme.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (candidate.isNexusMember) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9D4EDD).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF9D4EDD).withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.hub_rounded, size: 12, color: Color(0xFF9D4EDD)),
                          const SizedBox(width: 5),
                          Text(
                            'Nexus Member • Academic Verification Required',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFC77DFF),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    'Branch: ${candidate.branch} • Year: ${candidate.year} • Tel: ${candidate.phoneNo}',
                    style: GoogleFonts.inter(color: NexoraTheme.textSecondary, fontSize: 13),
                  ),
                  if (candidate.courses.isNotEmpty || candidate.clubs.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Courses (${candidate.courses.length}): ${candidate.courses.map((c) => c.name).take(3).join(', ')}${candidate.courses.length > 3 ? '…' : ''} • Clubs: ${candidate.clubs.isEmpty ? 'None' : candidate.clubs.join(', ')}',
                      style: GoogleFonts.inter(color: NexoraTheme.textSecondary, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => _rejectCandidate(doc),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: NexoraTheme.error,
                          side: const BorderSide(color: NexoraTheme.error),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text('Reject', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13)),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        onPressed: () => _approveCandidate(doc),
                        style: FilledButton.styleFrom(
                          backgroundColor: NexoraTheme.success,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.verified, size: 16),
                        label: Text('Approve & Seal', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- Tab 2: Member Records ---
  Widget _buildMemberRecordsTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          color: NexoraTheme.scaffold,
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                style: GoogleFonts.inter(color: NexoraTheme.textPrimary, fontSize: 14),
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search members...',
                  hintStyle: GoogleFonts.inter(color: NexoraTheme.textSecondary, fontSize: 13.5),
                  prefixIcon: const Icon(Icons.search, color: NexoraTheme.primary),
                  suffixIcon: _debouncedQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: NexoraTheme.textSecondary),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _debouncedQuery = '');
                          },
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip('All', SearchFilterMode.all),
                    _filterChip('By Faculty', SearchFilterMode.byFaculty),
                    _filterChip('By Reg No', SearchFilterMode.byRegNo),
                    _filterChip('By Slot', SearchFilterMode.bySlot),
                    _filterChip('By Dept', SearchFilterMode.byDepartment),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: NexoraTheme.primary));
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return Center(
                  child: Text('No verified members found.', style: GoogleFonts.inter(color: NexoraTheme.textSecondary, fontSize: 13)),
                );
              }

              final allUsers = docs.map(UserModel.fromFirestore).toList();

              // Lightning-fast instant in-memory search across multiple tokens & fields
              final query = _debouncedQuery.trim().toLowerCase();
              final List<UserModel> filteredUsers;

              if (query.isEmpty) {
                filteredUsers = allUsers;
              } else {
                final tokens = query.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
                filteredUsers = allUsers.where((user) {
                  switch (_selectedFilter) {
                    case SearchFilterMode.byFaculty:
                      final facultyPool = [
                        user.academic.proctorName,
                        user.academic.facultyAdvisor,
                        user.branch,
                        ...user.searchIndices.faculties,
                        ...user.courses.map((c) => c.faculty),
                        ...user.courses.map((c) => c.name),
                        ...user.courses.map((c) => c.code),
                      ].where((f) => f.trim().isNotEmpty).map((f) => f.toLowerCase()).toList();

                      const honorifics = {
                        'dr', 'dr.', 'prof', 'prof.', 'professor', 'mr', 'mr.',
                        'mrs', 'mrs.', 'ms', 'faculty', 'proctor', 'advisor', 'sir', 'teacher'
                      };
                      final meaningfulTokens = tokens.where((t) => !honorifics.contains(t)).toList();
                      final searchTokens = meaningfulTokens.isEmpty ? tokens : meaningfulTokens;

                      return searchTokens.every((t) => facultyPool.any((f) => f.contains(t)));

                    case SearchFilterMode.byRegNo:
                      final cleanReg = user.regNo.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
                      const regFillers = {'reg', 'regno', 'no', 'roll', 'number'};
                      final meaningfulTokens = tokens.where((t) => !regFillers.contains(t)).toList();
                      final searchTokens = meaningfulTokens.isEmpty ? tokens : meaningfulTokens;

                      final joinedSearch = searchTokens.join().replaceAll(RegExp(r'[^a-z0-9]'), '');
                      if (joinedSearch.isNotEmpty && cleanReg.contains(joinedSearch)) {
                        return true;
                      }
                      return searchTokens.every((t) => cleanReg.contains(t.replaceAll(RegExp(r'[^a-z0-9]'), '')));

                    case SearchFilterMode.bySlot:
                      final slotPool = [
                        user.academic.coreSlot,
                        '${user.academic.coreSlot} slot',
                        '${user.academic.coreSlot} core slot',
                        '${user.academic.coreSlot} batch',
                        ...user.courses.map((c) => c.slot),
                        ...user.courses.map((c) => '${c.slot} slot'),
                      ].where((s) => s.trim().isNotEmpty).map((s) => s.toLowerCase()).toList();

                      const slotFillers = {'slot', 'slots', 'core', 'batch', 'time', 'timing'};
                      final meaningfulTokens = tokens.where((t) => !slotFillers.contains(t)).toList();
                      final searchTokens = meaningfulTokens.isEmpty ? tokens : meaningfulTokens;

                      return searchTokens.every((t) => slotPool.any((s) => s.contains(t)));

                    case SearchFilterMode.byDepartment:
                      final cleanBranch = user.branch.toLowerCase();
                      const deptFillers = {'dept', 'department', 'branch', 'school'};
                      final meaningfulTokens = tokens.where((t) => !deptFillers.contains(t)).toList();
                      final searchTokens = meaningfulTokens.isEmpty ? tokens : meaningfulTokens;

                      return searchTokens.every(cleanBranch.contains);

                    case SearchFilterMode.all:
                      final corpus = [
                        user.name,
                        user.regNo,
                        user.regNo.replaceAll(RegExp(r'[^a-zA-Z0-9]'), ''),
                        user.branch,
                        'branch ${user.branch}',
                        'dept ${user.branch}',
                        'department ${user.branch}',
                        user.year,
                        '${user.year} year',
                        '${user.year}st year',
                        '${user.year}nd year',
                        '${user.year}rd year',
                        '${user.year}th year',
                        '1st year', '2nd year', '3rd year', '4th year',
                        user.email,
                        user.phoneNo,
                        user.phoneNo.replaceAll(RegExp(r'[^0-9]'), ''),
                        user.role,
                        user.academic.proctorName,
                        'proctor ${user.academic.proctorName}',
                        'advisor ${user.academic.proctorName}',
                        user.academic.facultyAdvisor,
                        user.academic.coreSlot,
                        '${user.academic.coreSlot} slot',
                        '${user.academic.coreSlot} core',
                        '${user.academic.coreSlot} batch',
                        'slot ${user.academic.coreSlot}',
                        'slot',
                        user.academic.nptel,
                        'nptel ${user.academic.nptel}',
                        user.academic.extraCurricular,
                        'extra curricular ${user.academic.extraCurricular}',
                        ...user.academic.clubs,
                        ...user.academic.clubs.map((cl) => 'club $cl'),
                        ...user.searchIndices.faculties,
                        ...user.courses.map((c) => c.name),
                        ...user.courses.map((c) => 'course ${c.name}'),
                        ...user.courses.map((c) => c.code),
                        ...user.courses.map((c) => c.faculty),
                        ...user.courses.map((c) => 'faculty ${c.faculty}'),
                        ...user.courses.map((c) => 'dr ${c.faculty}'),
                        ...user.courses.map((c) => 'prof ${c.faculty}'),
                        ...user.courses.map((c) => c.slot),
                        ...user.courses.map((c) => '${c.slot} slot'),
                      ].join(' ').toLowerCase();

                      const noiseWords = {'the', 'in', 'of', 'and', 'at', 'for', 'student', 'member'};
                      final meaningfulTokens = tokens.where((t) => !noiseWords.contains(t)).toList();
                      final searchTokens = meaningfulTokens.isEmpty ? tokens : meaningfulTokens;

                      return searchTokens.every(corpus.contains);
                  }
                }).toList();
              }

              if (filteredUsers.isEmpty) {
                return Center(
                  child: Text('No matching members found.', style: GoogleFonts.inter(color: NexoraTheme.textSecondary, fontSize: 13)),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                itemCount: filteredUsers.length,
                itemBuilder: (context, index) {
                  final user = filteredUsers[index];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: NexoraTheme.border),
                    ),
                    child: Material(
                      color: NexoraTheme.card,
                      borderRadius: BorderRadius.circular(12),
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: NxAvatar.fromUser(user, radius: 22, ringWidth: 2.5),
                      // Prominently display only the member's name without position crowding
                      title: Text(
                        user.name,
                        style: GoogleFonts.syne(
                          color: NexoraTheme.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 15.5,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${user.regNo.isNotEmpty ? user.regNo : "—"} • ${user.branch.isNotEmpty ? user.branch : "Student"}',
                          style: GoogleFonts.inter(
                            color: NexoraTheme.textSecondary,
                            fontSize: 12.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      trailing: const Icon(Icons.info_outline_rounded, color: NexoraTheme.textSecondary, size: 20),
                      onTap: () => _openMemberBiodataSheet(context, user),
                    ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // --- Biodata Bottom Sheet for Member Records tab ---
  void _openMemberBiodataSheet(BuildContext context, UserModel user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: NexoraTheme.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (_, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: NexoraTheme.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            // Header
            Row(
              children: [
                NxAvatar.fromUser(user, radius: 28, ringWidth: 3, forceRing: true),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: GoogleFonts.syne(
                          color: NexoraTheme.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        user.regNo.isNotEmpty ? user.regNo : '—',
                        style: GoogleFonts.jetBrainsMono(
                          color: NexoraTheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      if (user.isAdmin) ...[
                        const SizedBox(height: 4),
                        RoleBadge.fromUser(user),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _bioDivider('Academic Info'),
            _bioRow(Icons.school_outlined, 'Department', user.branch.isNotEmpty ? user.branch : '—'),
            _bioRow(Icons.calendar_today_outlined, 'Year', user.year.isNotEmpty ? '${user.year}${_yearSuffix(user.year)} Year' : '—'),
            _bioRow(Icons.person_outline_rounded, 'Proctor', user.academic.proctorName.isNotEmpty ? user.academic.proctorName : (user.academic.facultyAdvisor.isNotEmpty ? user.academic.facultyAdvisor : '—')),
            _bioRow(Icons.wb_sunny_outlined, 'Core Slot', user.academic.coreSlot.isNotEmpty ? user.academic.coreSlot : '—'),
            _bioRow(Icons.email_outlined, 'Email', user.email.isNotEmpty ? user.email : '—'),
            _bioRow(Icons.phone_outlined, 'Phone', user.phoneNo.isNotEmpty ? user.phoneNo : '—'),
            const SizedBox(height: 16),
            _bioDivider('NPTEL & Extra Curricular'),
            _bioRow(Icons.ondemand_video_outlined, 'NPTEL Course', user.academic.nptel.isNotEmpty ? user.academic.nptel : 'None'),
            _bioRow(Icons.emoji_events_outlined, 'Extra Curricular', user.academic.extraCurricular.isNotEmpty ? user.academic.extraCurricular : 'None'),
            const SizedBox(height: 16),
            _bioDivider('Clubs'),
            if (user.academic.clubs.isNotEmpty)
              Wrap(
                spacing: 8, runSpacing: 8,
                children: user.academic.clubs.map((club) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: NexoraTheme.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: NexoraTheme.primary.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    club,
                    style: GoogleFonts.inter(
                      color: NexoraTheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )).toList(),
              )
            else
              Text('No clubs joined', style: GoogleFonts.inter(color: NexoraTheme.textSecondary, fontSize: 12.5, fontStyle: FontStyle.italic)),
            const SizedBox(height: 16),
            _bioDivider('Enrolled Courses'),
            if (user.courses.where((c) => c.name.isNotEmpty).isNotEmpty)
              ...user.courses.where((c) => c.name.isNotEmpty).map((c) =>
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: NexoraTheme.scaffold,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: NexoraTheme.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.name,
                              style: GoogleFonts.inter(
                                color: NexoraTheme.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (c.faculty.isNotEmpty || c.slot.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                [if (c.faculty.isNotEmpty) c.faculty, if (c.slot.isNotEmpty) c.slot].join(' • '),
                                style: GoogleFonts.inter(
                                  color: NexoraTheme.textSecondary,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (c.code.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: NexoraTheme.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            c.code,
                            style: GoogleFonts.jetBrainsMono(
                              color: NexoraTheme.primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              )
            else
              Text('No courses enrolled', style: GoogleFonts.inter(color: NexoraTheme.textSecondary, fontSize: 12.5, fontStyle: FontStyle.italic)),
            if (widget.currentAdmin.isSuperAdmin) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _openRolePromotionDialog(context, user);
                },
                icon: const Icon(Icons.tune_rounded, size: 16),
                label: Text('Manage Role & Colour', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: NexoraTheme.primary,
                  side: const BorderSide(color: NexoraTheme.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _yearSuffix(String year) {
    switch (year.trim()) {
      case '1': return 'st';
      case '2': return 'nd';
      case '3': return 'rd';
      default: return 'th';
    }
  }

  Widget _bioDivider(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: NexoraTheme.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(child: Divider(color: NexoraTheme.border, height: 1)),
      ],
    ),
  );

  Widget _bioRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: NexoraTheme.textSecondary),
        const SizedBox(width: 10),
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: NexoraTheme.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              color: NexoraTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );


  Widget _filterChip(String label, SearchFilterMode mode) {
    final isSelected = _selectedFilter == mode;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        shape: const StadiumBorder(),
        selected: isSelected,
        onSelected: (_) => setState(() => _selectedFilter = mode),
        selectedColor: NexoraTheme.primary.withValues(alpha: 0.18),
        checkmarkColor: NexoraTheme.primary,
        backgroundColor: NexoraTheme.card,
        labelStyle: GoogleFonts.inter(
          color: isSelected ? NexoraTheme.primary : NexoraTheme.textSecondary,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          fontSize: 12,
        ),
        side: BorderSide(
          color: isSelected ? NexoraTheme.primary : NexoraTheme.border,
        ),
      ),
    );
  }

  // --- Tab 3: Super Admin Promotion ---
  Widget _buildRolePromotionTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: NexoraTheme.primary));
        }

        final docs = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(14),
          itemCount: docs.length,
          itemBuilder: (context, i) {
            final user = UserModel.fromFirestore(docs[i]);

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: NexoraTheme.border),
              ),
              child: Material(
                color: NexoraTheme.card,
                borderRadius: BorderRadius.circular(10),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  leading: NxAvatar.fromUser(user, radius: 20, ringWidth: 2.8),
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.name,
                          style: GoogleFonts.syne(
                            color: NexoraTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 15.5,
                            letterSpacing: -0.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (user.isAdmin) ...[
                        const SizedBox(width: 8),
                        RoleBadge.fromUser(user),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    '${user.regNo} • Role: ${user.role == 'superadmin' ? 'Super Admin' : (user.role == 'admin' ? 'Admin' : 'Student')}',
                    style: GoogleFonts.inter(color: NexoraTheme.textSecondary, fontSize: 12.5),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.tune_rounded, color: NexoraTheme.primary),
                    onPressed: () => _openRolePromotionDialog(context, user),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- Tab: Course Dropdown Catalog ---
  Widget _buildCourseCatalogTab() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('config').doc('courses').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: NexoraTheme.primary));
        }

        List<String> courseNames = List<String>.from(kDefaultCourseNames);
        if (snapshot.hasData && snapshot.data!.exists && snapshot.data!.data() != null) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final list = data['courseNames'] as List<dynamic>?;
          if (list != null && list.isNotEmpty) {
            courseNames = list.map((e) => e.toString()).toList();
          }
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: NexoraTheme.primary,
            icon: const Icon(Icons.add, color: Colors.white),
            label: Text('Add Course', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13.5)),
            onPressed: () => _showAddCourseDialog(courseNames),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: NexoraTheme.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: NexoraTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: NexoraTheme.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.menu_book_rounded, color: NexoraTheme.primary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Course Dropdown Catalog',
                                style: GoogleFonts.syne(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w700,
                                  color: NexoraTheme.textPrimary,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${courseNames.length} active courses in registration dropdown',
                                style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  color: NexoraTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Reset to Default Courses',
                          icon: const Icon(Icons.restart_alt_rounded, color: NexoraTheme.textSecondary),
                          onPressed: _confirmResetCourses,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Admins can add, edit, reorder, or delete course names below. Any changes made here are instantly available to students in their course enrollment dropdown.',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: NexoraTheme.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Courses list — Clean, spacious, full-width cards
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  children: List.generate(courseNames.length, (index) {
                    final courseName = courseNames[index];
                    final meta = kDefaultCourseMetadata[courseName];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: NexoraTheme.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: NexoraTheme.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: NexoraTheme.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '#${index + 1}',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: NexoraTheme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  courseName,
                                  style: GoogleFonts.syne(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: NexoraTheme.textPrimary,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                              // Reorder & Action buttons
                              if (courseNames.length > 1) ...[
                                if (index > 0)
                                  IconButton(
                                    icon: const Icon(Icons.arrow_upward_rounded, size: 17, color: NexoraTheme.textSecondary),
                                    tooltip: 'Move up',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                    onPressed: () => _reorderCourse(courseNames, index, index - 1),
                                  ),
                                if (index < courseNames.length - 1)
                                  IconButton(
                                    icon: const Icon(Icons.arrow_downward_rounded, size: 17, color: NexoraTheme.textSecondary),
                                    tooltip: 'Move down',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                    onPressed: () => _reorderCourse(courseNames, index, index + 1),
                                  ),
                              ],
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18, color: NexoraTheme.primary),
                                tooltip: 'Edit course',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                onPressed: () => _showEditCourseDialog(courseNames, index),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: NexoraTheme.error),
                                tooltip: 'Delete course',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                onPressed: () => _confirmDeleteCourse(courseNames, index),
                              ),
                            ],
                          ),
                          if (meta != null && (meta['faculty']!.isNotEmpty || meta['slot']!.isNotEmpty || meta['code']!.isNotEmpty)) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                if (meta['faculty']!.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                    decoration: BoxDecoration(
                                      color: NexoraTheme.scaffold,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: NexoraTheme.border),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.person_outline_rounded, size: 13, color: NexoraTheme.textSecondary),
                                        const SizedBox(width: 5),
                                        Text(
                                          meta['faculty']!,
                                          style: GoogleFonts.inter(fontSize: 11.5, color: NexoraTheme.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (meta['slot']!.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                    decoration: BoxDecoration(
                                      color: NexoraTheme.scaffold,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: NexoraTheme.border),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.schedule_rounded, size: 13, color: NexoraTheme.textSecondary),
                                        const SizedBox(width: 5),
                                        Text(
                                          meta['slot']!,
                                          style: GoogleFonts.jetBrainsMono(fontSize: 11.5, color: NexoraTheme.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (meta['code']!.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                    decoration: BoxDecoration(
                                      color: NexoraTheme.primary.withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: NexoraTheme.primary.withValues(alpha: 0.3)),
                                    ),
                                    child: Text(
                                      meta['code']!,
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: NexoraTheme.primary,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                ),
              ),

            ],
          ),
        );
      },
    );
  }

  Future<void> _saveCourseCatalog(List<String> list) async {
    try {
      await FirebaseFirestore.instance.collection('config').doc('courses').set({
        'courseNames': list,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': widget.currentAdmin.uid,
      }, SetOptions(merge: true));
      _notifyCatalogSaved();
    } catch (e) {
      // Previously an unawaited write: a permission failure dropped the
      // reorder silently with no feedback.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: NexoraTheme.error,
            content: Text('Could not save the course catalog: $e'),
          ),
        );
      }
    }
  }

  void _notifyCatalogSaved() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: NexoraTheme.success,
        content: Text('Course catalog updated'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _reorderCourse(List<String> list, int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= list.length) return;
    if (newIndex < 0 || newIndex >= list.length) return;
    if (oldIndex == newIndex) return;
    final updated = List<String>.from(list);
    final item = updated.removeAt(oldIndex);
    updated.insert(newIndex, item);
    await _saveCourseCatalog(updated);
  }

  void _showAddCourseDialog(List<String> currentList) {
    // Disposed when the dialog finishes, not when the future resolves.
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NexoraTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Add Course Name',
          style: GoogleFonts.syne(color: NexoraTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 17),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the course name as it should appear in the student dropdown:',
              style: GoogleFonts.inter(color: NexoraTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              style: GoogleFonts.inter(color: NexoraTheme.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'e.g. Operating Systems Fundamentals',
                hintStyle: GoogleFonts.inter(color: NexoraTheme.textSecondary, fontSize: 13),
                filled: true,
                fillColor: NexoraTheme.scaffold,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: NexoraTheme.textSecondary, fontWeight: FontWeight.w600)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: NexoraTheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final val = controller.text.trim();
              if (val.isEmpty) return;
              if (currentList.contains(val)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Course already exists in catalog')),
                );
                return;
              }
              final updated = List<String>.from(currentList)..add(val);
              Navigator.pop(ctx);
              await _saveCourseCatalog(updated);
            },
            child: Text('Add Course', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  void _showEditCourseDialog(List<String> currentList, int index) {
    final currentName = currentList[index];
    final controller = TextEditingController(text: currentName);
    // The catalog can shrink underneath this dialog, so guard the index.
    if (index < 0 || index >= currentList.length) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NexoraTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Edit Course Name',
          style: GoogleFonts.syne(color: NexoraTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 17),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Update course name in the dropdown catalog:',
              style: GoogleFonts.inter(color: NexoraTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              style: GoogleFonts.inter(color: NexoraTheme.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'e.g. Operating Systems Fundamentals',
                hintStyle: GoogleFonts.inter(color: NexoraTheme.textSecondary, fontSize: 13),
                filled: true,
                fillColor: NexoraTheme.scaffold,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: NexoraTheme.textSecondary, fontWeight: FontWeight.w600)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: NexoraTheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final val = controller.text.trim();
              if (val.isEmpty) return;
              if (index < 0 || index >= currentList.length) {
                Navigator.pop(ctx);
                return;
              }
              final updated = List<String>.from(currentList);
              updated[index] = val;
              Navigator.pop(ctx);
              await _saveCourseCatalog(updated);
            },
            child: Text('Save', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  void _confirmDeleteCourse(List<String> currentList, int index) {
    // The catalog stream can shrink between build and tap.
    if (index < 0 || index >= currentList.length) return;
    final name = currentList[index];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NexoraTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Remove Course?', style: GoogleFonts.syne(fontWeight: FontWeight.w700, fontSize: 17, color: NexoraTheme.textPrimary)),
        content: Text(
          'Are you sure you want to remove "$name" from the student registration dropdown?',
          style: GoogleFonts.inter(color: NexoraTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: NexoraTheme.textSecondary, fontWeight: FontWeight.w600)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: NexoraTheme.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final updated = List<String>.from(currentList)..removeAt(index);
              await _saveCourseCatalog(updated);
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: NexoraTheme.card,
                    content: Text('Removed "$name"'),
                  ),
                );
              }
            },
            child: Text('Delete', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _confirmResetCourses() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NexoraTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Reset Course Dropdown?', style: GoogleFonts.syne(fontWeight: FontWeight.w700, fontSize: 17, color: NexoraTheme.textPrimary)),
        content: Text(
          'This will reset the course catalog back to the 8 default courses (Operating Systems, Computer Architecture, etc.).',
          style: GoogleFonts.inter(color: NexoraTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: NexoraTheme.textSecondary, fontWeight: FontWeight.w600)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: NexoraTheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              await _saveCourseCatalog(List<String>.from(kDefaultCourseNames));
              if (mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: NexoraTheme.success,
                    content: Text('Course dropdown reset to defaults'),
                  ),
                );
              }
            },
            child: Text('Reset', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

/// Small label/value row used by the Nexus link warning dialog.
class _KeyValue extends StatelessWidget {
  final String label;
  final String value;

  const _KeyValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: NexoraTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.jetBrainsMono(
                color: NexoraTheme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
