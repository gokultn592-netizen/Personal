import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexora/core/cache/cache_service.dart';
import 'package:nexora/core/constants.dart';
import 'package:nexora/models/user_model.dart';
import '../../core/models/nexora_models.dart';

/// Firestore transaction and profile service — Pane 1 (Claude Code / OmniRoute).
/// Aligned to UserModel schema (lib/models/user_model.dart); ignores app_user.dart.
class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Atomic approval: reads pendingUsers/{pendingUid}, writes exact UserModel schema
  /// to users/{pendingUid}, stamps approval credentials, deletes pending entry.
  Future<String?> approveUserTransaction({
    required String pendingUid,
    required String adminUid,
    required String adminColorHex,
  }) async {
    try {
      await _firestore.runTransaction((tx) async {
        final pendingDoc = _firestore.collection('pendingUsers').doc(pendingUid);
        final snap = await tx.get(pendingDoc);
        if (!snap.exists) throw Exception('Pending user not found');
        final data = snap.data();
        if (data == null) throw Exception('Pending user data is null');

        // Build exact UserModel from pending data + approval stamps
        final userRef = _firestore.collection('users').doc(pendingUid);

        final academic = AcademicInfo.fromMap(
          data['academic'] as Map<String, dynamic>?,
        );
        final coursesRaw = (data['courses'] as List<dynamic>?) ?? [];
        final courses = coursesRaw
            .map((e) => CourseItem.fromMap(e as Map<String, dynamic>?))
            .toList();
        final searchIndices = SearchIndices.fromMap(
          data['searchIndices'] as Map<String, dynamic>?,
        );

        final user = UserModel(
          uid: pendingUid,
          email: data['email'] ?? '',
          name: data['name'] ?? '',
          regNo: data['regNo'] ?? '',
          branch: data['branch'] ?? '',
          year: data['year'] ?? '',
          phoneNo: data['phoneNo'] ?? '',
          photoUrl: data['photoUrl'] as String?,
          role: 'student',
          adminColorHex: adminColorHex,
          approvedBy: adminUid,
          approverColorHex: adminColorHex,
          academic: academic,
          courses: courses,
          searchIndices: searchIndices,
        );

        tx.set(userRef, user.toMap());
        tx.delete(pendingDoc);
      });
      return null;
    } catch (e) {
      return 'Approval failed: $e';
    }
  }

  /// Reject / delete pending user entry.
  Future<String?> rejectUser(String pendingUid) async {
    try {
      await _firestore.collection('pendingUsers').doc(pendingUid).delete();
      return null;
    } catch (e) {
      return 'Rejection failed: $e';
    }
  }

  /// Self-profile update — updates ONLY editable profile data.
  /// Does NOT overwrite role, approvedBy, approverColorHex, adminColorHex.
  Future<String?> updateSelfProfile(UserModel user) async {
    try {
      await _firestore.collection('users').doc(user.uid).update({
        'phoneNo': user.phoneNo,
        'photoUrl': user.photoUrl,
        'branch': user.branch,
        'year': user.year,
        'academic': user.academic.toMap(),
        'courses': user.courses.map((c) => c.toMap()).toList(),
        'searchIndices': user.searchIndices.toMap(),
      });
      return null;
    } catch (e) {
      return 'Profile update failed: $e';
    }
  }

  /// Permanently deletes a user's account and profile data from users/{uid}.
  Future<String?> deleteUserAccount(String uid) async {
    try {
      await _firestore.collection('users').doc(uid).delete();
      await CacheService().clearUserProfile(uid);
      return null;
    } catch (e) {
      return 'Account deletion failed: $e';
    }
  }

  /// Streams the verified student directory.
  ///
  /// Requires a verified account under `firestore.rules`
  /// (`allow list: if isVerified()`), so a non-admin caller is rejected rather
  /// than receiving an empty directory.
  Stream<List<UserModel>> streamVerifiedUsers({int limit = 200}) {
    return _firestore
        .collection('users')
        .orderBy('nameLower')
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map(UserModel.fromFirestore).toList());
  }

  /// Loads the page after [after], using the same ordering as
  /// [streamVerifiedUsers], and returns the raw snapshot so the caller can use
  /// its last document as the cursor for the next call.
  ///
  /// The previous implementation re-ran the same un-paginated query and
  /// returned the same first page, so the directory silently stopped at the
  /// initial page size.
  Future<QuerySnapshot<Map<String, dynamic>>> loadMoreUsers({
    DocumentSnapshot<Map<String, dynamic>>? after,
    int limit = 200,
  }) {
    var query = _firestore.collection('users').orderBy('nameLower');
    if (after != null) query = query.startAfterDocument(after);
    return query.limit(limit).get();
  }

  /// Streams the admin approval queue. Admin-only under `firestore.rules`.
  Stream<List<UserModel>> streamPendingUsers({int limit = 100}) {
    return _firestore
        .collection('pendingUsers')
        .orderBy('submittedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs.map((d) => UserModel.fromMap(d.data(), d.id)).toList());
  }

  /// Loads the page after [after] in the approval queue.
  Future<QuerySnapshot<Map<String, dynamic>>> loadMorePendingUsers({
    DocumentSnapshot<Map<String, dynamic>>? after,
    int limit = 100,
  }) {
    var query =
        _firestore.collection('pendingUsers').orderBy('submittedAt', descending: true);
    if (after != null) query = query.startAfterDocument(after);
    return query.limit(limit).get();
  }

  /// Stream active course names configured by admins with fallback to default list.
  /// Automatically writes fresh emissions into the 24-hour Hive cache.
  Stream<List<String>> streamCourseNames() {
    return _firestore.collection('config').doc('courses').snapshots().map((snap) {
      List<String> result;
      if (!snap.exists || snap.data() == null) {
        result = List<String>.from(kDefaultCourseNames);
      } else {
        final list = snap.data()?['courseNames'] as List<dynamic>?;
        if (list == null || list.isEmpty) {
          result = List<String>.from(kDefaultCourseNames);
        } else {
          result = list.map((e) => e.toString()).toList();
        }
      }
      CacheService().saveCourseNames(result).catchError((e) => null);
      return result;
    });
  }

  /// One-time fetch of active course names with 24-hour Hive cache.
  /// Subsequent fetches return from Hive instantly without touching Firestore.
  Future<List<String>> getCourseNames({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = CacheService().getFreshCourseNames();
      if (cached != null && cached.isNotEmpty) {
        return cached;
      }
    }

    try {
      final snap = await _firestore.collection('config').doc('courses').get();
      List<String> result;
      if (!snap.exists || snap.data() == null) {
        result = List<String>.from(kDefaultCourseNames);
      } else {
        final list = snap.data()!['courseNames'] as List<dynamic>?;
        if (list == null || list.isEmpty) {
          result = List<String>.from(kDefaultCourseNames);
        } else {
          result = list.map((e) => e.toString()).toList();
        }
      }
      // Save to Hive cache with 24 hour TTL
      await CacheService().saveCourseNames(result);
      return result;
    } catch (_) {
      // Offline fallback: try any previous cached courses
      final cached = CacheService().getCourseNames();
      if (cached != null && cached.isNotEmpty) {
        return cached;
      }
      return List<String>.from(kDefaultCourseNames);
    }
  }

  /// Update the active course dropdown list (Admin operation).
  Future<void> updateCourseNames(List<String> courseNames, {required String updatedBy}) async {
    await _firestore.collection('config').doc('courses').set({
      'courseNames': courseNames,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': updatedBy,
    }, SetOptions(merge: true));
    await CacheService().saveCourseNames(courseNames);
  }

  /// Reset the course dropdown catalog back to initial defaults.
  Future<void> resetCourseNamesToDefault({required String updatedBy}) async {
    await updateCourseNames(List<String>.from(kDefaultCourseNames), updatedBy: updatedBy);
  }

  /// Helper: Convert UserModel to NexoraUser for UI display.
  NexoraUser _userModelToNexoraUser(UserModel um) {
    return NexoraUser(
      uid: um.uid,
      email: um.email,
      name: um.name,
      regNo: um.regNo,
      faculty: um.branch, // Assuming faculty maps to branch
      slot: um.year,      // Assuming slot maps to year
      role: um.role,
      profilePicUrl: um.photoUrl,
      auditSeals: const [],
      sealColors: const [],
      isVerified: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Search verified users by name, regNo, faculty, or slot.
  /// Returns list of NexoraUser for UI consumption.
  Future<List<NexoraUser>> searchUsers({
    String? name,
    String? regNo,
    String? faculty,
    String? slot,
  }) async {
    Query query = _firestore.collection('users');

    if (name != null && name.isNotEmpty) {
      // Search on nameLower field (case-insensitive)
      query = query.where('searchIndices.nameLower', isEqualTo: name.toLowerCase());
    }
    if (regNo != null && regNo.isNotEmpty) {
      // Search on regNoLower field (case-insensitive)
      query = query.where('searchIndices.regNoLower', isEqualTo: regNo.toLowerCase());
    }
    if (faculty != null && faculty.isNotEmpty) {
      // Search on faculty field (exact match, case-sensitive)
      query = query.where('faculty', isEqualTo: faculty);
    }
    if (slot != null && slot.isNotEmpty) {
      // Search on slot field (exact match, case-sensitive)
      query = query.where('slot', isEqualTo: slot);
    }

    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .map(_userModelToNexoraUser)
        .toList();
  }
}