import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../services/auth_service.dart';
import '../../services/nexus_service.dart';
import '../../widgets/nx_card.dart';
import '../../widgets/nexora_logo.dart';
import '../../widgets/status_screens.dart';
import '../main_shell.dart';
import 'login_screen.dart';

class PendingScreen extends StatefulWidget {
  const PendingScreen({super.key, this.uid, this.name, this.regNo});

  final String? uid;
  final String? name;
  final String? regNo;

  @override
  State<PendingScreen> createState() => _PendingScreenState();
}

class _PendingScreenState extends State<PendingScreen> {
  final _auth = AuthService();

  bool _busy = false;
  bool _redirected = false;

  /// True once a Nexus admin's approval has been mirrored into Nexora, so the
  /// auto-approval runs at most once per screen.
  bool _nexusAutoApproved = false;
  bool _nexusWatcherActive = false;

  /// Live watch of this person's standing in the Nexus community.
  ///
  /// Nexus is the source of truth for membership. When a Nexus admin promotes
  /// the user from `pending` to `friend`, this stream fires and the user is
  /// approved in Nexora immediately — no Nexora admin review, no refresh. This
  /// is the real-time half of the mirror; the only write is into Nexora's own
  /// database.
  void _startNexusWatcher(String email) {
    if (_nexusWatcherActive || email.trim().isEmpty) return;
    _nexusWatcherActive = true;

    NexusService().watchMember(email).listen(
      (member) async {
        if (!mounted || _redirected) return;
        if (member == null || !member.isApproved) return;
        if (_nexusAutoApproved) return;
        _nexusAutoApproved = true;

        final error = await _auth.approveFromNexus(
          uid: FirebaseAuth.instance.currentUser?.uid,
          email: email,
        );
        if (!mounted) return;
        if (error != null) {
          // Surface the failure rather than leaving the user stuck with no
          // explanation.
          showNxSnack(
            context,
            'Nexus approved you, but Nexora could not finish: $error',
            error: true,
          );
          _nexusAutoApproved = false;
        }
      },
      onError: (Object error) {
        debugPrint('[PendingScreen] Nexus watcher error: $error');
        // A denied read is not "not a member" — stop watching rather than
        // looping, and let the normal Nexora review path continue.
        _nexusWatcherActive = false;
      },
      cancelOnError: true,
    );
  }

  void _enterPlatform() {
    if (_redirected || !mounted) return;
    _redirected = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const MainShell()),
        (route) => false,
      );
    });
  }

  Future<void> _signOut() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _auth.signOut();
    } catch (error) {
      if (mounted) showNxSnack(context, authErrorMessage(error), error: true);
    }
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _backToSignIn() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  bool _isApproved(Map<String, dynamic> data) {
    final status = (data['status'] ?? '').toString().trim();
    final role = (data['role'] ?? '').toString().trim();
    final approvedBy = (data['approvedBy'] ?? '').toString().trim();
    return status == 'approved' ||
        approvedBy.isNotEmpty ||
        (role.isNotEmpty && role != 'candidate');
  }

  @override
  Widget build(BuildContext context) {
    final uid = widget.uid ?? FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return MessageScreen(
        title: 'Session expired',
        message:
            'These credentials are no longer active on this device. Sign in '
            'again to resume the verification you already submitted.',
        icon: Icons.lock_clock_rounded,
        actionLabel: 'Back to sign in',
        onAction: _backToSignIn,
      );
    }

    return Scaffold(
      backgroundColor: NexoraTheme.scaffold,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Row(
          children: [
            NexoraLogo(size: 24, showWordmark: false),
            SizedBox(width: 10),
            Text('Nexora - Next Era'),
          ],
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _statusPane(
              icon: Icons.cloud_off_rounded,
              tint: NexoraTheme.warning,
              title: 'Connection interrupted',
              message:
                  'Your request is still queued on the server. ${authErrorMessage(snapshot.error!)}',
            );
          }

          final userDoc = snapshot.data;
          final exists = snapshot.hasData && (userDoc?.exists ?? false);
          final data = userDoc?.data() ?? const <String, dynamic>{};

          // Watch Nexus standing so a Nexus admin's approval lands here in
          // real time. Started once, keyed on the candidate's email.
          final candidateEmail =
              (data['email'] ?? FirebaseAuth.instance.currentUser?.email ?? '')
                  .toString();
          if (!exists || !_isApproved(data)) {
            _startNexusWatcher(candidateEmail);
          }

          if (exists && _isApproved(data)) {
            _enterPlatform();
            return _statusPane(
              icon: Icons.verified_rounded,
              tint: NexoraTheme.success,
              title: 'Identity stamped',
              message: 'An admin vouched for you. Opening the app…',
              spinner: true,
            );
          }

          return _pendingPane(
            uid,
            userName: (data['name'] ?? '').toString(),
            userRegNo: (data['regNo'] ?? '').toString(),
          );
        },
      ),
    );
  }

  Widget _pendingPane(String uid, {String userName = '', String userRegNo = ''}) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('pendingUsers')
          .doc(uid)
          .snapshots(),
      builder: (context, pendingSnap) {
        if (pendingSnap.hasError) {
          return _statusPane(
            icon: Icons.cloud_off_rounded,
            tint: NexoraTheme.warning,
            title: 'Connection interrupted',
            message:
                'Your request is still queued. ${authErrorMessage(pendingSnap.error!)}',
          );
        }

        final data = pendingSnap.data?.data() ?? const <String, dynamic>{};
        final exists = pendingSnap.hasData && (pendingSnap.data?.exists ?? false);
        final name = _pick(_pick(widget.name, data['name']), userName);
        final regNo = _pick(_pick(widget.regNo, data['regNo']), userRegNo);
        final branch = _pick(null, data['branch']);
        final year = _pick(null, data['year']);

        final coursesRaw = (data['courses'] as List<dynamic>?) ?? [];
        final clubsRaw = (data['clubs'] as List<dynamic>?) ?? [];
        final coursesCount = coursesRaw.isNotEmpty ? coursesRaw.length : (data['noOfCourses'] as int? ?? 0);
        final clubsCount = clubsRaw.isNotEmpty ? clubsRaw.length : (data['noOfClubs'] as int? ?? 0);

        if (pendingSnap.hasData && !exists && name.isEmpty && regNo.isEmpty) {
          return _statusPane(
            icon: Icons.sync_rounded,
            tint: NexoraTheme.primary,
            title: 'Sealing your record',
            message:
                'The approval transaction is finishing. Hold on a moment longer.',
            spinner: true,
          );
        }

        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        const NexoraLogo(
                          size: 72,
                          showWordmark: false,
                        ),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: NexoraTheme.scaffold,
                            shape: BoxShape.circle,
                            border: Border.all(color: NexoraTheme.warning, width: 1.5),
                          ),
                          child: const Icon(
                            Icons.hourglass_bottom_rounded,
                            size: 16,
                            color: NexoraTheme.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Awaiting approval',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                      color: NexoraTheme.textPrimary,
                      letterSpacing: -0.5,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Your candidate profile is locked inside the verification '
                        'queue. Access is granted the moment an admin stamps it.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: NexoraTheme.textSecondary,
                      fontSize: 14,
                      height: 1.55,
                    ),
                  ),
                  if (data['isNexusMember'] == true) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9D4EDD).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF9D4EDD).withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.verified_user_outlined, size: 20, color: Color(0xFF9D4EDD)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Nexus Account Linked: Nexora requires verified student profiles (not anonymous). An admin will review your registration number and academic details shortly.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                height: 1.4,
                                color: const Color(0xFFD8B4FE),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  NxCard(
                    child: Column(
                      children: [
                        _detailRow('Full name', name.isEmpty ? '—' : name),
                        const Divider(),
                        _detailRow(
                          'Registration no.',
                          regNo.isEmpty ? '—' : regNo,
                          mono: true,
                        ),
                        if (branch.isNotEmpty || year.isNotEmpty) ...[
                          const Divider(),
                          _detailRow(
                            'Program',
                            [branch, year]
                                .where((part) => part.isNotEmpty)
                                .join('  •  '),
                          ),
                        ],
                        if (coursesCount > 0) ...[
                          const Divider(),
                          _detailRow(
                            'Courses',
                            '$coursesCount registered',
                          ),
                        ],
                        if (clubsCount > 0) ...[
                          const Divider(),
                          _detailRow(
                            'Clubs',
                            '$clubsCount joined',
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          'Scanning for an admin seal…',
                          style: TextStyle(
                            color: NexoraTheme.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (kDeveloperEmails.contains(FirebaseAuth.instance.currentUser?.email?.toLowerCase())) ...[
                    FilledButton.icon(
                      onPressed: _busy ? null : () async {
                        setState(() => _busy = true);
                        final err = await AuthService().claimGenesisSuperAdmin(uid);
                        if (!mounted) return;
                        setState(() => _busy = false);
                        if (err != null) {
                          showNxSnack(context, err, error: true);
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: NexoraTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.admin_panel_settings_rounded, size: 20),
                      label: const Text('Claim Super Admin Access'),
                    ),
                    const SizedBox(height: 12),
                  ],
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _signOut,
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('Sign out'),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'You can close the app. Your request stays in the queue.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: NexoraTheme.textSecondary,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _pick(String? preferred, Object? raw) {
    if (preferred != null && preferred.trim().isNotEmpty) {
      return preferred.trim();
    }
    final value = raw == null ? '' : raw.toString();
    return value.trim();
  }

  Widget _detailRow(String label, String value, {bool mono = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: const TextStyle(
                color: NexoraTheme.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: mono
                  ? GoogleFonts.robotoMono(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: NexoraTheme.primary,
                      letterSpacing: 0.7,
                    )
                  : const TextStyle(
                      color: NexoraTheme.textPrimary,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPane({
    required IconData icon,
    required Color tint,
    required String title,
    required String message,
    bool spinner = false,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                color: alphaOf(tint, 0.13),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: alphaOf(tint, 0.4)),
              ),
              child: Icon(icon, size: 34, color: tint),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: NexoraTheme.textPrimary,
                letterSpacing: -0.4,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: NexoraTheme.textSecondary,
                fontSize: 14,
                height: 1.55,
              ),
            ),
            if (spinner) ...[
              const SizedBox(height: 20),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.6),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
