import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/cache/cache_service.dart';
import '../models/notification_model.dart';

/// Centralized notification service managing broadcast notifications to all Nexora members.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('noteNotifications');

  final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);
  static ValueNotifier<int> get unreadCount => _instance.unreadCountNotifier;

  /// Seeded from the persisted marker in [CacheService] once the box is open, so
  /// the unread badge survives an app restart instead of resetting to zero
  /// (or, previously, to "everything unread").
  DateTime _lastReadTime = DateTime.now();
  StreamSubscription<List<NoteNotificationModel>>? _badgeSubscription;

  NotificationService._internal() {
    _restoreLastRead();
    _initUnreadTracker();
  }

  Future<void> _restoreLastRead() async {
    try {
      await CacheService().init();
      final stored = CacheService().getLastReadAt();
      if (stored != null) _lastReadTime = stored;
    } catch (e) {
      debugPrint('[NotificationService] read marker restore failed: $e');
    }
  }

  void _initUnreadTracker() {
    // Without onError a PERMISSION_DENIED becomes an unhandled stream error
    // for the lifetime of the process.
    _badgeSubscription = streamNotifications(limit: 20).listen(
      (list) {
        var count = 0;
        for (final n in list) {
          if (n.timestamp.isAfter(_lastReadTime)) {
            count++;
          }
        }
        unreadCountNotifier.value = count;
      },
      onError: (Object error, StackTrace _) {
        debugPrint('[NotificationService] unread tracker error: $error');
        unreadCountNotifier.value = 0;
      },
    );
  }

  /// Cached role of the signed-in user, used to gate moderation actions.
  String? _cachedRole;
  Future<bool>? _roleInFlight;

  /// Whether the signed-in user may moderate (delete) broadcasts.
  ///
  /// Reads the role from `users/{uid}` and caches it. `firestore.rules` remains
  /// the real authority; this only stops the UI from offering an action that is
  /// guaranteed to be rejected. Safe to call from `build()` — it never awaits.
  bool canModerateNotifications() {
    final cached = _cachedRole;
    if (cached != null) {
      return cached == 'admin' || cached == 'superadmin';
    }
    // Kick off a one-shot lookup; the UI updates when it completes.
    unawaited(refreshRole());
    return false;
  }

  /// Fetches and caches the caller's role from `users/{uid}`.
  Future<bool> refreshRole() => _roleInFlight ??= _loadRole();

  Future<bool> _loadRole() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      _cachedRole = null;
      return false;
    }
    try {
      final snap = await _firestore.collection('users').doc(uid).get();
      _cachedRole = snap.data()?['role']?.toString().trim();
      return _cachedRole == 'admin' || _cachedRole == 'superadmin';
    } catch (e) {
      debugPrint('[NotificationService] role lookup failed: $e');
      return false;
    } finally {
      _roleInFlight = null;
    }
  }

  /// Marks all current notifications as read and clears the unread badge count.
  void markAllAsRead() {
    _lastReadTime = DateTime.now();
    unreadCountNotifier.value = 0;
    // Persist so the badge is correct on the next launch.
    unawaited(CacheService().setLastReadAt(_lastReadTime));
  }

  /// Broadcasts a notification to everyone when anyone posts or updates a note.
  Future<void> broadcastNoteNotification({
    required String noteId,
    required String noteTitle,
    required String authorName,
    required String authorUid,
    required String authorRegNo,
    required bool isUpdate,
  }) async {
    try {
      final effectiveTitle = noteTitle.trim().isEmpty ? 'Academic Note' : noteTitle.trim();
      final type = isUpdate ? 'updated' : 'created';

      await _collection.add({
        'noteId': noteId,
        'noteTitle': effectiveTitle,
        'authorName': authorName.trim(),
        'authorUid': authorUid,
        'authorRegNo': authorRegNo.trim(),
        'type': type,
        'timestamp': FieldValue.serverTimestamp(),
      });
      debugPrint('[NotificationService] Broadcast sent successfully for note: $noteId ($type)');
    } catch (e) {
      debugPrint('[NotificationService] broadcastNoteNotification error: $e');
    }
  }

  /// Streams the latest note notifications for all members ordered by timestamp descending.
  Stream<List<NoteNotificationModel>> streamNotifications({int limit = 40}) {
    return _collection
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(NoteNotificationModel.fromFirestore).toList());
  }

  /// Fetches a specific note document by ID for previewing.
  Future<DocumentSnapshot<Map<String, dynamic>>?> fetchNote(String noteId) async {
    try {
      return await _firestore.collection('notes').doc(noteId).get();
    } catch (e) {
      debugPrint('[NotificationService] fetchNote error: $e');
      return null;
    }
  }

  /// Deletes a specific broadcast notification document from Firestore.
///
/// Admin-only under `firestore.rules` (`allow delete: if isAdmin()`), so the UI
/// gates this action. Callers must check [canModerateNotifications].
  Future<void> deleteNotification(String notifId) async {
    try {
      await _collection.doc(notifId).delete();
      debugPrint('[NotificationService] Deleted notification: $notifId');
    } catch (e) {
      debugPrint('[NotificationService] deleteNotification error: $e');
      rethrow;
    }
  }

  /// Clears all broadcast notifications from Firestore and resets unread count.
///
/// Admin-only under `firestore.rules`.
  Future<void> clearAllNotifications() async {
    try {
      final snapshot = await _collection.get();
      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      unreadCountNotifier.value = 0;
      debugPrint('[NotificationService] Cleared all notifications');
    } catch (e) {
      debugPrint('[NotificationService] clearAllNotifications error: $e');
      rethrow;
    }
  }

  /// Cancels background notification listeners when tearing down service.
  void dispose() {
    _badgeSubscription?.cancel();
  }
}
