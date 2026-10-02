import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/constants.dart';
import '../core/services/push_notification_service.dart';
import 'nexus_service.dart';

/// Auth & session state service for Nexora.
/// Handles Firebase Authentication (Email/Password & Google Sign-In)
/// and writes candidate registrations to pendingUsers/{uid}.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AuthService();

  /// Stream of Firebase Auth state changes.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Currently authenticated user.
  User? get currentUser => _auth.currentUser;

  /// Firebase Auth account creation + pendingUsers document creation.
  Future<String?> registerCandidate({
    required String email,
    required String password,
    required String name,
    required String regNo,
    required String branch,
    required String year,
    required String phoneNo,
    String? facultyAdvisor,
    String? coreSlot,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = cred.user;
      if (user == null) return 'Registration failed: no user returned';
      final uid = user.uid;
      final cleanEmail = email.trim().toLowerCase();

      final data = <String, dynamic>{
        'uid': uid,
        'email': email.trim(),
        'name': name.trim(),
        'regNo': regNo.trim().toUpperCase(),
        'branch': branch.trim(),
        'year': year.trim(),
        'phoneNo': phoneNo.trim(),
        'submittedAt': FieldValue.serverTimestamp(),
      };
      if (facultyAdvisor != null && facultyAdvisor.trim().isNotEmpty) {
        data['facultyAdvisor'] = facultyAdvisor.trim();
      }
      if (coreSlot != null && coreSlot.trim().isNotEmpty) {
        data['coreSlot'] = coreSlot.trim();
      }

      // Nexus is the source of truth for community membership, on **every**
      // entry path — not just Google. Without this check an approved Nexus
      // member registering with email/password was dropped into the pending
      // queue and had to wait for a Nexora admin, which defeats the mirror.
      await _ensureNexusSession();
      final member = await NexusService().lookupMember(cleanEmail);
      if (member != null && member.isApproved) {
        await _writeNexusApprovedUser(
          uid: uid,
          email: cleanEmail,
          name: name.trim(),
          regNo: regNo.trim().toUpperCase(),
          branch: branch.trim(),
          year: year.trim(),
          phoneNo: phoneNo.trim(),
          proctor: (facultyAdvisor ?? '').trim(),
          coreSlot: (coreSlot ?? '').trim(),
          nexusRole: member.role,
          nexusDocId: member.nexusDocId,
        );
        return null;
      }

      await _firestore.collection('pendingUsers').doc(uid).set(data);

      // Alert admins so candidate is reviewed in AdminPortalScreen
      try {
        await _firestore.collection('adminNotifications').add({
          'type': 'new_candidate_registration',
          'title': 'New Registration Pending',
          'message': '$name ($regNo, $branch) has registered and awaits verification.',
          'uid': uid,
          'name': name,
          'regNo': regNo,
          'branch': branch,
          'isNexusMember': false,
          'submittedAt': FieldValue.serverTimestamp(),
          'read': false,
        });

        unawaited(PushNotificationService.instance.notifyAdminsNewRegistration(
          candidateName: name,
          candidateUid: uid,
          regNo: regNo,
          branch: branch,
        ));
      } catch (e) {
        debugPrint('[AuthService] Admin registration alert failed: $e');
      }

      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Registration failed';
    }
  }

  /// Whether the current user was admitted by the Nexus mirror rather than by
  /// a Nexora admin.
  ///
  /// Read from the freshly written `users/{uid}` record so the caller can route
  /// straight to the app instead of showing a pending screen.
  Future<bool> wasApprovedViaNexus() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return false;
    try {
      final snap = await _firestore.collection('users').doc(uid).get();
      if (!snap.exists) return false;
      final data = snap.data();
      if (data == null) return false;
      return data['approvedBy'] == 'nexus_community' &&
          data['status'] == 'approved';
    } catch (e) {
      debugPrint('[AuthService] approval-source check failed: $e');
      return false;
    }
  }

  /// Establishes the read-only Nexus session if it is not already open.
  ///
  /// Uses silent Google auth, so it only succeeds for an account that has
  /// previously signed in with Google on this device. Failure is non-fatal —
  /// the user simply falls back to the normal Nexora approval queue.
  Future<void> _ensureNexusSession() async {
    if (NexusService().isSignedIn) return;
    await NexusService().signInToNexusWithAccount(_auth.currentUser);
  }

  /// Writes a verified `users/{uid}` record for someone a Nexus admin already
  /// approved. Shared by the Google registration path and the email/password
  /// path so both honour the same rule.
  Future<void> _writeNexusApprovedUser({
    required String uid,
    required String email,
    required String name,
    required String regNo,
    required String branch,
    required String year,
    required String phoneNo,
    required String proctor,
    required String coreSlot,
    required String nexusRole,
    required String nexusDocId,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'email': email,
      'name': name,
      'regNo': regNo,
      'branch': branch,
      'year': year,
      'phoneNo': phoneNo,
      'role': kRoleStudent,
      'status': 'approved',
      'isNexusMember': true,
      'nexusRole': nexusRole,
      'nexusDocId': nexusDocId,
      'adminColorHex': null,
      'approvedBy': 'nexus_community',
      'approverColorHex': '#30A46C',
      'academic': {
        'proctorName': proctor,
        'facultyAdvisor': proctor,
        'coreSlot': coreSlot,
        'nptel': '',
        'extraCurricular': '',
        'clubs': const <String>[],
      },
      'courses': const <Map<String, dynamic>>[],
      'searchIndices': {
        'faculties': const <String>[],
        'regNoLower': regNo.toLowerCase(),
        'nameLower': name.toLowerCase(),
      },
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Clear any stale draft.
    try {
      await _firestore.collection('pendingUsers').doc(uid).delete();
    } catch (_) {}
  }

  /// Submit academic profile for a freshly authenticated Google user (or unprofiled user).
  /// Enters candidate record into pendingUsers/{uid} for administrative verification.
  Future<String?> submitCandidateProfile({
    required String uid,
    required String email,
    required String name,
    required String regNo,
    required String branch,
    required String year,
    required String phoneNo,
    String? photoUrl,
    String? proctorName,
    String? facultyAdvisor,
    String? coreSlot,
    List<Map<String, dynamic>> courses = const [],
    List<String> clubs = const [],
  }) async {
    try {
      final effectiveProctor = (proctorName ?? facultyAdvisor ?? '').trim();
      final cleanEmail = email.trim().toLowerCase();
      final isDeveloper = kDeveloperEmails.contains(cleanEmail);

      // Genesis bootstrap: the very first verified account self-elevates to
      // superadmin. This MUST NOT be derived from a `users` collection query —
      // firestore.rules only grants directory reads to verified members, so a
      // brand-new registrant would get PERMISSION_DENIED and be unable to
      // register at all. The sentinel document below is readable by any
      // signed-in account and is written exactly once (see firestore.rules).
      bool isFirstMember = false;
      if (!isDeveloper) {
        final bootstrap = await _firestore.doc('bootstrap/initialized').get();
        isFirstMember = !bootstrap.exists;
      }

      // Read this student's standing in the Nexus community.
      //
      // Nexus is the source of truth for community membership and is a live,
      // working platform: Nexora only ever reads from it. A person a Nexus admin
      // has approved (`role: 'friend'` or `'admin'`) is auto-approved in Nexora —
      // one identity, one gate.
      final nexusMember = await NexusService().lookupMember(cleanEmail);
      final isNexusApproved = nexusMember?.isApproved ?? false;
      final nexusRole = nexusMember?.role;

      // Auto-approve when Nexus already recognises this person, or when this is
      // the genesis account.
      final shouldAutoApprove = isDeveloper || isFirstMember || isNexusApproved;

      if (shouldAutoApprove) {
        final faculties = courses
            .map((c) => (c['faculty'] ?? '').toString().trim().toLowerCase())
            .where((f) => f.isNotEmpty)
            .toSet()
            .toList();

        // A person already approved in Nexus is a normal `student` in Nexora —
        // they are not made an admin, they are simply not asked to re-apply.
        // Only the genesis path grants elevated roles.
        final effectiveRole =
            (isDeveloper || isFirstMember) ? 'superadmin' : 'student';
        final effectiveApprover =
            (isDeveloper || isFirstMember) ? 'genesis_developer' : 'nexus_community';
        final effectiveApproverColor =
            (isDeveloper || isFirstMember) ? '#3B82F6' : '#30A46C';

        // Claim the genesis sentinel BEFORE writing the user record. The rules
        // grant `users` create only while `bootstrap/initialized` is absent, so
        // claiming first makes the grant single-use even if two registrations
        // land concurrently.
        if (!isDeveloper) {
          try {
            await _firestore.doc('bootstrap/initialized').set({
              'claimedBy': uid,
              'claimedByEmail': cleanEmail,
              'claimedAt': FieldValue.serverTimestamp(),
            });
          } on FirebaseException catch (e) {
            if (e.code == 'permission-denied' ||
                e.code == 'failed-precondition' ||
                e.code == 'already-exists') {
              // Someone else already took the genesis slot — fall through to
              // the normal pending-user flow instead of self-elevating.
              return await _submitAsPending(
                uid: uid,
                email: email,
                name: name,
                regNo: regNo,
                branch: branch,
                year: year,
                phoneNo: phoneNo,
                photoUrl: photoUrl,
                effectiveProctor: effectiveProctor,
                coreSlot: coreSlot,
                courses: courses,
                clubs: clubs,
                isNexusApproved: isNexusApproved,
                nexusRole: nexusRole,
              );
            }
            return 'Could not finalize account setup: ${e.message}';
          }
        }

        // Write directly to users/{uid} as approved!
        await _firestore.collection('users').doc(uid).set({
          'uid': uid,
          'email': email.trim(),
          'name': name.trim(),
          'regNo': regNo.trim().toUpperCase(),
          'branch': branch.trim(),
          'year': year.trim(),
          'phoneNo': phoneNo.trim(),
          if (photoUrl != null && photoUrl.trim().isNotEmpty) 'photoUrl': photoUrl.trim(),
          'role': effectiveRole,
          'status': 'approved',
          'isNexusMember': isNexusApproved,
          if (nexusRole != null) 'nexusRole': nexusRole,
          'adminColorHex': effectiveRole == 'superadmin' ? effectiveApproverColor : null,
          'approvedBy': effectiveApprover,
          'approverColorHex': effectiveApproverColor,
          'academic': {
            'proctorName': effectiveProctor,
            'facultyAdvisor': effectiveProctor,
            'coreSlot': coreSlot ?? '',
            'nptel': '',
            'extraCurricular': '',
            'clubs': clubs,
          },
          'courses': courses,
          'searchIndices': {
            'faculties': faculties,
            'regNoLower': regNo.trim().toLowerCase(),
            'nameLower': name.trim().toLowerCase(),
          },
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Clean up pendingUsers if a draft existed
        try {
          await _firestore.collection('pendingUsers').doc(uid).delete();
        } catch (_) {}

        return null;
      }

      // Normal pending-candidate submission. Extracted so the genesis path can
      // fall back to it when the bootstrap sentinel is already claimed.
      return await _submitAsPending(
        uid: uid,
        email: email,
        name: name,
        regNo: regNo,
        branch: branch,
        year: year,
        phoneNo: phoneNo,
        photoUrl: photoUrl,
        effectiveProctor: effectiveProctor,
        coreSlot: coreSlot,
        courses: courses,
        clubs: clubs,
        isNexusApproved: isNexusApproved,
        nexusRole: nexusRole,
      );
    } on FirebaseException catch (e) {
      return e.message;
    } catch (e) {
      return 'Failed to save profile: $e';
    }
  }

  /// Writes the candidate to `pendingUsers/{uid}` and alerts the admins.
  Future<String?> _submitAsPending({
    required String uid,
    required String email,
    required String name,
    required String regNo,
    required String branch,
    required String year,
    required String phoneNo,
    String? photoUrl,
    required String effectiveProctor,
    String? coreSlot,
    required List<Map<String, dynamic>> courses,
    required List<String> clubs,
    required bool isNexusApproved,
    String? nexusRole,
  }) async {
    try {
      final data = <String, dynamic>{
        'uid': uid,
        'email': email.trim(),
        'name': name.trim(),
        'regNo': regNo.trim().toUpperCase(),
        'branch': branch.trim(),
        'year': year.trim(),
        'phoneNo': phoneNo.trim(),
        'noOfCourses': courses.length,
        'courses': courses,
        'noOfClubs': clubs.length,
        'clubs': clubs,
        'isNexusMember': isNexusApproved,
        if (nexusRole != null) 'nexusRole': nexusRole,
        'submittedAt': FieldValue.serverTimestamp(),
      };
      if (photoUrl != null && photoUrl.trim().isNotEmpty) {
        data['photoUrl'] = photoUrl.trim();
      }
      if (effectiveProctor.isNotEmpty) {
        data['proctorName'] = effectiveProctor;
        data['facultyAdvisor'] = effectiveProctor;
      }
      if (coreSlot != null && coreSlot.trim().isNotEmpty) {
        data['coreSlot'] = coreSlot.trim();
      }

      await _firestore.collection('pendingUsers').doc(uid).set(data);

      // Alert the admins. `firestore.rules` has a matching block for
      // `adminNotifications`; the previous version had none, so every write was
      // rejected by default-deny and swallowed here — admins were never told.
      try {
        final notifTitle = isNexusApproved
            ? 'New Registration (Nexus Member)'
            : 'New Registration Pending';
        final notifMsg = isNexusApproved
            ? '$name ($regNo, $branch) - Nexus member registered and awaits admin verification.'
            : '$name ($regNo, $branch) has registered and awaits verification.';

        await _firestore.collection('adminNotifications').add({
          'type': 'new_candidate_registration',
          'title': notifTitle,
          'message': notifMsg,
          'uid': uid,
          'name': name,
          'regNo': regNo,
          'branch': branch,
          'isNexusMember': isNexusApproved,
          if (photoUrl != null && photoUrl.trim().isNotEmpty) 'photoUrl': photoUrl.trim(),
          'submittedAt': FieldValue.serverTimestamp(),
          'read': false,
        });

        // Push notification alert to all administrators
        unawaited(PushNotificationService.instance.notifyAdminsNewRegistration(
          candidateName: name,
          candidateUid: uid,
          regNo: regNo,
          branch: branch,
        ));
      } catch (e) {
        // The candidate is already queued; an alert failure must not block
        // registration, but it should be visible in logs.
        debugPrint('[AuthService] admin alert failed: $e');
      }

      return null;
    } on FirebaseException catch (e) {
      return e.message;
    } catch (e) {
      return 'Failed to save profile: $e';
    }
  }

  /// Mirrors a Nexus community approval into Nexora.
  ///
  /// Called when a Nexus admin promotes the user (`role: 'friend'`) and the
  /// Pending screen's live watcher observes it. This writes **only to Nexora**:
  /// the candidate's `pendingUsers/{uid}` record is converted into a verified
  /// `users/{uid}` record, exactly as a Nexora admin approval would, but
  /// stamped with the Nexus community as the approver.
  ///
  /// Re-verifies the Nexus standing immediately before writing, so a revoked
  /// promotion cannot be used to grant access.
  Future<String?> approveFromNexus({required String? uid, required String email}) async {
    if (uid == null || uid.isEmpty) return 'Not signed in.';
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return 'Missing email.';

    // Re-check, do not trust the stream event alone.
    final member = await NexusService().lookupMember(cleanEmail);
    if (member == null) return 'No Nexus account found for this email.';
    if (!member.isApproved) return 'Nexus has not approved this account yet.';

    try {
      final pendingRef = _firestore.collection('pendingUsers').doc(uid);
      final pendingSnap = await pendingRef.get();
      if (!pendingSnap.exists) {
        // Already promoted (or approved by a Nexora admin in the meantime).
        return null;
      }
      final d = pendingSnap.data() ?? const <String, dynamic>{};

      final coursesRaw = (d['courses'] as List<dynamic>?) ?? [];
      final clubsRaw = (d['clubs'] as List<dynamic>?) ?? [];
      final regNo = (d['regNo'] ?? '').toString();
      final name = (d['name'] ?? '').toString();
      final proctor = (d['proctorName'] ?? '').toString().trim();
      final advisor = (d['facultyAdvisor'] ?? '').toString().trim();
      final effectiveProctor = proctor.isNotEmpty ? proctor : advisor;
      final faculties = coursesRaw
          .map((c) => (c['faculty'] ?? '').toString().trim().toLowerCase())
          .where((f) => f.isNotEmpty)
          .toSet()
          .toList();

      final batch = _firestore.batch();
      batch.set(_firestore.collection('users').doc(uid), {
        'uid': uid,
        'email': cleanEmail,
        'name': name,
        'regNo': regNo,
        'branch': (d['branch'] ?? '').toString(),
        'year': (d['year'] ?? '').toString(),
        'phoneNo': (d['phoneNo'] ?? '').toString(),
        'photoUrl': d['photoUrl'],
        'role': kRoleStudent,
        'status': 'approved',
        'isNexusMember': true,
        'nexusRole': member.role,
        'nexusDocId': member.nexusDocId,
        'adminColorHex': null,
        'approvedBy': 'nexus_community',
        'approverColorHex': '#30A46C',
        'academic': {
          'proctorName': effectiveProctor,
          'facultyAdvisor': effectiveProctor,
          'coreSlot': (d['coreSlot'] ?? '').toString(),
          'nptel': '',
          'extraCurricular': '',
          'clubs': List<String>.from(clubsRaw),
        },
        'courses': coursesRaw,
        'searchIndices': {
          'faculties': faculties,
          'regNoLower': regNo.toLowerCase(),
          'nameLower': name.toLowerCase(),
        },
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.delete(pendingRef);
      await batch.commit();
      return null;
    } on FirebaseException catch (e) {
      return e.message;
    } catch (e) {
      return 'Failed to mirror the Nexus approval: $e';
    }
  }

  /// Promotes a pending user to Super Admin.
  ///
  /// The UI only offers this to the hardcoded developer email, but the check is
  /// repeated here because the client-side gate alone is not a security
  /// boundary — `firestore.rules` independently requires `isAdmin()` for the
  /// `users` create.
  Future<String?> claimGenesisSuperAdmin(String uid) async {
    try {
      final email = _auth.currentUser?.email?.trim().toLowerCase() ?? '';
      if (email.isEmpty || !kDeveloperEmails.contains(email)) {
        return 'Only the designated developer can claim this role.';
      }
      final pendingDoc = await _firestore.collection('pendingUsers').doc(uid).get();
      if (!pendingDoc.exists) return 'Record not found';
      final d = pendingDoc.data()!;
      final coursesRaw = (d['courses'] as List<dynamic>?) ?? [];
      final clubsRaw = (d['clubs'] as List<dynamic>?) ?? [];
      final regNo = (d['regNo'] ?? '').toString();
      final name = (d['name'] ?? '').toString();

      final faculties = coursesRaw
          .map((c) => (c['faculty'] ?? '').toString().trim().toLowerCase())
          .where((f) => f.isNotEmpty)
          .toSet()
          .toList();

      final rawProctor = (d['proctorName'] ?? '').toString().trim();
      final rawAdvisor = (d['facultyAdvisor'] ?? '').toString().trim();
      final proctor = rawProctor.isNotEmpty ? rawProctor : rawAdvisor;

      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'email': d['email'] ?? '',
        'name': name,
        'regNo': regNo,
        'branch': d['branch'] ?? '',
        'year': d['year'] ?? '',
        'phoneNo': d['phoneNo'] ?? '',
        'photoUrl': d['photoUrl'],
        'role': 'superadmin',
        'status': 'approved',
        'adminColorHex': '#3B82F6',
        'approvedBy': 'genesis_claim',
        'approverColorHex': '#3B82F6',
        'academic': {
  // Prefer whichever of the two mirrored keys actually holds a value.
        'proctorName': proctor,
          'facultyAdvisor': proctor,
          'coreSlot': d['coreSlot'] ?? '',
          'nptel': '',
          'extraCurricular': '',
          'clubs': List<String>.from(clubsRaw),
        },
        'courses': coursesRaw,
        'searchIndices': {
          'faculties': faculties,
          'regNoLower': regNo.toLowerCase(),
          'nameLower': name.toLowerCase(),
        },
        'createdAt': FieldValue.serverTimestamp(),
      });

      await pendingDoc.reference.delete();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Login via Firebase Auth.
  /// Email/password sign-in.
///
/// Named parameters: the `login()` call site passes `email:` and `password:` by
/// name, which did not compile against the previous positional signature.
  Future<String?> login({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      // Open the Nexus read session here too. Without it, an email/password
      // user who is already an approved Nexus member would be unable to
      // confirm their standing and would sit in the pending queue waiting for
      // a Nexora admin.
      await _ensureNexusSession();
      // Ensure FCM push notification token is committed to users/{uid}
      unawaited(PushNotificationService.instance.saveTokenToFirestore());
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Login failed';
    }
  }

  /// Sign out from Firebase Auth and Google, including the Nexus read session.
  Future<void> signOut() async {
    await NexusService().signOutOfNexus();
    await _auth.signOut();
    if (!kIsWeb) {
      try {
        await GoogleSignIn().signOut();
      } catch (_) {}
    }
  }

  /// Permanently deletes the current Firebase Auth user account.
  Future<String?> deleteCurrentUser() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.delete();
      }
      await signOut();
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        await signOut();
        return 'Please sign in again before deleting your account for security verification.';
      }
      return e.message ?? 'Account deletion failed';
    } catch (e) {
      await signOut();
      return 'Account deletion error: $e';
    }
  }

  /// Google Sign-In with cross-platform web popup and mobile credential exchange.
  /// Does NOT write to users/{uid}, allowing AuthGate to direct unprofiled users to ProfileSetupScreen.
  Future<String?> signInWithGoogle() async {
    try {
      UserCredential cred;
      String? googleIdToken;
      String? googleAccessToken;

      if (kIsWeb) {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        cred = await _auth.signInWithPopup(googleProvider);
      } else {
        final googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) return 'Sign-in cancelled';
        final googleAuth = await googleUser.authentication;
        // `authentication` is non-nullable in google_sign_in 6.x, but its
        // tokens can still be absent for an account with no linked credential.
        if (googleAuth.idToken == null || googleAuth.accessToken == null) {
          return 'Could not obtain a Google credential. Please try again.';
        }
        googleIdToken = googleAuth.idToken;
        googleAccessToken = googleAuth.accessToken;
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        cred = await _auth.signInWithCredential(credential);
      }
      if (cred.user == null) return 'Google sign-in failed';

      // Open a read-only session on the Nexus project using the same Google
      // identity. The Nexus `users` collection is not world-readable, so
      // without this every cross-project lookup is rejected — which is why the
      // mirror previously never returned anything.
      //
      // Failures here are non-fatal: the user stays signed in to Nexora and the
      // Nexus-backed features simply report that standing is unavailable.
      if (googleIdToken != null && googleAccessToken != null) {
        await NexusService().signInToNexus(
          idToken: googleIdToken,
          accessToken: googleAccessToken,
        );
      } else {
        // Web popup path does not expose the raw tokens. Ask Nexus Auth to
        // establish the session itself via the same account.
        await NexusService().signInToNexusWithAccount(cred.user);
      }

      // Ensure FCM push notification token is committed to users/{uid}
      unawaited(PushNotificationService.instance.saveTokenToFirestore());

      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Google sign-in error: $e';
    }
  }
}
