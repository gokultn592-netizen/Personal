import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants.dart';
import '../core/utils.dart';
import '../models/user_model.dart';

/// Everything that touches the `users` and `pendingUsers` collections.
class UserService {
  const UserService._();

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  static CollectionReference<Map<String, dynamic>> get _pending =>
      _db.collection('pendingUsers');

  static Stream<DocumentSnapshot<Map<String, dynamic>>> profile(String uid) =>
      _users.doc(uid).snapshots();

  static Stream<QuerySnapshot<Map<String, dynamic>>> members({
    String? faculty,
    String? slot,
  }) {
    Query<Map<String, dynamic>> query = _users;
    if (faculty != null && faculty.isNotEmpty) {
      query = query.where('faculty', isEqualTo: faculty);
    }
    if (slot != null && slot.isNotEmpty) {
      query = query.where('slot', isEqualTo: slot);
    }
    return query.snapshots();
  }

  static Stream<QuerySnapshot<Map<String, dynamic>>> queue({
    String? faculty,
    String? slot,
  }) {
    Query<Map<String, dynamic>> query = _pending;
    if (faculty != null && faculty.isNotEmpty) {
      query = query.where('faculty', isEqualTo: faculty);
    }
    if (slot != null && slot.isNotEmpty) {
      query = query.where('slot', isEqualTo: slot);
    }
    return query.snapshots();
  }

  /// Writes the applicant into `pendingUsers` after the auth gate has passed.
  static Future<void> submitForApproval({
    required String uid,
    required String email,
    required String displayName,
    required String regNo,
    required String faculty,
    required String slot,
  }) async {
    final normalizedRegNo = regNo.trim().toUpperCase();

    final approvedMatch = await _users
        .where('regNo', isEqualTo: normalizedRegNo)
        .limit(1)
        .get();
    if (approvedMatch.docs.isNotEmpty) {
      throw StateError(
        'Registration number $normalizedRegNo is already verified.',
      );
    }

    final queueMatch = await _pending
        .where('regNo', isEqualTo: normalizedRegNo)
        .limit(1)
        .get();
    final foreign = queueMatch.docs.where((doc) => doc.id != uid).toList();
    if (foreign.isNotEmpty) {
      throw StateError(
        'Registration number $normalizedRegNo is already awaiting approval.',
      );
    }

    await _pending.doc(uid).set(<String, dynamic>{
      'uid': uid,
      'displayName': displayName.trim(),
      'email': email.trim(),
      'regNo': normalizedRegNo,
      'faculty': faculty,
      'slot': slot,
      'profilePicUrl': null,
      'status': 'pending',
      'requestedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Single atomic transaction: stamp the student with the approver's
  /// signature colour, then clear the queue entry. All reads happen first.
  static Future<void> approve({
    required PendingUserModel pending,
    required String approverUid,
  }) async {
    await _db.runTransaction<void>((transaction) async {
      final queueRef = _pending.doc(pending.uid);
      final userRef = _users.doc(pending.uid);
      final approverRef = _users.doc(approverUid);

      final queueSnap = await transaction.get(queueRef);
      if (!queueSnap.exists) {
        throw StateError('This registration is no longer pending.');
      }

      final approverSnap = await transaction.get(approverRef);
      if (!approverSnap.exists) {
        throw StateError('Your approver identity is missing from the directory.');
      }
      final approverData = approverSnap.data() ?? <String, dynamic>{};
      final signature = (approverData['signatureColor'] as String?) ??
          defaultSignatureColorFor(approverUid);

      transaction.set(userRef, <String, dynamic>{
        'uid': pending.uid,
        'displayName': pending.name,
        'email': pending.email,
        'regNo': pending.regNo,
        'faculty': pending.branch,
        'slot': pending.proctorName ?? '',
        'role': kRoleStudent,
        'status': 'approved',
        'profilePicUrl': pending.photoUrl,
        'approverUid': approverUid,
        'approverName': (approverData['displayName'] as String?) ?? 'Approver',
        'approverColor': signature,
        'signatureColor': null,
        'requestedAt': Timestamp.fromDate(pending.submittedAt),
        'approvedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      transaction.delete(queueRef);
    });
  }

  static Future<void> updateIdentity({
    required String uid,
    String? displayName,
    String? faculty,
    String? slot,
    String? profilePicUrl,
  }) async {
    final payload = <String, dynamic>{
      if (displayName != null && displayName.trim().isNotEmpty)
        'displayName': displayName.trim(),
      if (faculty != null) 'faculty': faculty,
      if (slot != null) 'slot': slot,
      if (profilePicUrl != null) 'profilePicUrl': profilePicUrl,
    };
    if (payload.isEmpty) return;
    await _users.doc(uid).update(payload);
  }

  static Future<void> updateSignatureColor(String uid, String hex) =>
      _users.doc(uid).update(<String, dynamic>{'signatureColor': hex});

  static Future<void> setRole(String uid, String role) =>
      _users.doc(uid).update(<String, dynamic>{'role': role});
}
