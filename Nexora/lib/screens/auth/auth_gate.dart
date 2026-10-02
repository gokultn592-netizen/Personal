import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/cache/cache_service.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/nexora_logo.dart';
import '../main_shell.dart';
import 'login_screen.dart';
import 'pending_screen.dart';
import 'profile_setup_screen.dart';

/// Auth gate routing based on Firebase Auth + Firestore status:
/// 1. Unauthenticated -> LoginScreen
/// 2. Authenticated & Verified in users/{uid} -> MainShell (Instant via Hive Cache)
/// 3. Authenticated & Queued in pendingUsers/{uid} -> PendingScreen
/// 4. Authenticated via Google/Firebase with no academic profile -> ProfileSetupScreen
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  /// A user is approved only if an explicit approval signal is present.
  static bool _isApproved(Map<String, dynamic> data) {
    final status = (data['status'] ?? '').toString().trim();
    if (status.isNotEmpty) return status == 'approved';

    // Legacy documents written before `status` existed carry an approver stamp.
    final approvedBy = (data['approvedBy'] ?? '').toString().trim();
    if (approvedBy.isNotEmpty) return true;

    final role = (data['role'] ?? '').toString().trim();
    return role == 'admin' || role == 'superadmin';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges,
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const _SplashLoadingScreen();
        }

        final user = authSnap.data;
        if (user == null) {
          return const LoginScreen();
        }

        return _AuthenticatedGate(user: user);
      },
    );
  }
}

class _AuthenticatedGate extends StatefulWidget {
  final User user;
  const _AuthenticatedGate({required this.user});

  @override
  State<_AuthenticatedGate> createState() => _AuthenticatedGateState();
}

class _AuthenticatedGateState extends State<_AuthenticatedGate> {
  Map<String, dynamic>? _cachedProfile;

  @override
  void initState() {
    super.initState();
    _cachedProfile = CacheService().getUserProfile(widget.user.uid);
  }

  @override
  Widget build(BuildContext context) {
    final hasCachedApproval =
        _cachedProfile != null && AuthGate._isApproved(_cachedProfile!);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .snapshots(),
      builder: (context, userSnap) {
        // If Firestore stream produces updated profile data, save it silently to Hive
        if (userSnap.hasData && userSnap.data?.data() != null) {
          final liveData = userSnap.data!.data()!;
          CacheService().saveUserProfile(widget.user.uid, liveData);
        }

        // Fast path: cached profile is already verified and approved.
        // Enter MainShell immediately with zero blocking splash!
        if (hasCachedApproval) {
          // If live Firestore data arrived and explicitly revoked approval:
          if (userSnap.hasData && userSnap.data?.data() != null) {
            final liveData = userSnap.data!.data()!;
            if (!AuthGate._isApproved(liveData)) {
              // Live account is no longer approved; fall through to pending/setup checks below.
            } else {
              return const MainShell();
            }
          } else {
            // Still waiting for stream or offline: render MainShell normally from cache!
            return const MainShell();
          }
        }

        // Cold start without cached profile: show splash while waiting
        if (userSnap.connectionState == ConnectionState.waiting) {
          return const _SplashLoadingScreen();
        }

        // If offline / network error:
        if (userSnap.hasError) {
          if (hasCachedApproval) {
            return const MainShell();
          }
          return const _GateErrorScreen();
        }

        final userDoc = userSnap.data;
        final userExists = userSnap.hasData && (userDoc?.exists ?? false);
        final userData = userDoc?.data() ?? <String, dynamic>{};

        if (userExists && AuthGate._isApproved(userData)) {
          return const MainShell();
        }

        // Not verified in users/{uid}. Inspect pendingUsers/{uid} queue.
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('pendingUsers')
              .doc(widget.user.uid)
              .snapshots(),
          builder: (context, pendingSnap) {
            if (pendingSnap.connectionState == ConnectionState.waiting) {
              return const _SplashLoadingScreen();
            }

            if (pendingSnap.hasError) {
              return const _GateErrorScreen();
            }

            final pendingDoc = pendingSnap.data;
            final pendingExists =
                pendingSnap.hasData && (pendingDoc?.exists ?? false);
            final pendingData = pendingDoc?.data() ?? <String, dynamic>{};

            if (pendingExists) {
              return PendingScreen(
                uid: widget.user.uid,
                name: (pendingData['name'] ??
                        userData['name'] ??
                        widget.user.displayName ??
                        '')
                    .toString(),
                regNo: (pendingData['regNo'] ?? userData['regNo'] ?? '')
                    .toString(),
              );
            }

            // If user document existed with an already registered regNo
            final existingRegNo = (userData['regNo'] ?? '').toString().trim();
            if (userExists && existingRegNo.isNotEmpty) {
              return PendingScreen(
                uid: widget.user.uid,
                name: (userData['name'] ?? widget.user.displayName ?? '').toString(),
                regNo: existingRegNo,
              );
            }

            // Fresh Google authenticated user without an academic record.
            return ProfileSetupScreen(user: widget.user);
          },
        );
      },
    );
  }
}

/// Shown when the account lookup fails, instead of silently falling through to
/// the registration form.
class _GateErrorScreen extends StatelessWidget {
  const _GateErrorScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F14),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_rounded,
                      color: Color(0xFF7A7A8E), size: 44),
                  const SizedBox(height: 14),
                  const Text(
                    'Could not verify your account',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'We could not reach the directory. Check your connection and try again.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF7A7A8E), fontSize: 13, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: () => FirebaseAuth.instance.currentUser?.reload(),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Retry'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF334155)),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SplashLoadingScreen extends StatelessWidget {
  const _SplashLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0B0F14),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NexoraLogo(size: 88, showWordmark: true, showSubtitle: true),
            SizedBox(height: 28),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: NexoraTheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
