import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/cache/cache_service.dart';
import '../models/note_deletion_log_model.dart';
import '../models/note_model.dart';
import '../models/user_model.dart';

/// Read/write access to the `notes` collection and audit logs.
class NoteService {
  const NoteService._();

  static CollectionReference<Map<String, dynamic>> get _notes =>
      FirebaseFirestore.instance.collection('notes');

  static CollectionReference<Map<String, dynamic>> get _deletionLogs =>
      FirebaseFirestore.instance.collection('noteDeletionLogs');

  /// Returns cached notes from Hive immediately if present.
  static List<Map<String, dynamic>>? getCachedNotes() =>
      CacheService().getNotes();

  /// Saves raw note records to Hive cache.
  static Future<void> saveNotesToCache(List<Map<String, dynamic>> notes) =>
      CacheService().saveNotes(notes);

  /// Realtime stream of the public notes feed.
  /// Automatically persists fresh emissions to Hive cache.
  static Stream<QuerySnapshot<Map<String, dynamic>>> feed({int limit = 20}) =>
      _notes
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) {
        final rawDocs = [
          for (final doc in snapshot.docs) {'id': doc.id, ...doc.data()}
        ];
        CacheService().saveNotes(rawDocs).catchError((e) => debugPrint('Cache save error: $e'));
        return snapshot;
      });

  static Future<List<QuerySnapshot<Map<String, dynamic>>>> loadMoreNotes(
      {int limit = 20}) async {
    final snap =
        await _notes.orderBy('timestamp', descending: true).limit(limit).get();
    final rawDocs = [
      for (final doc in snap.docs) {'id': doc.id, ...doc.data()}
    ];
    CacheService().saveNotes(rawDocs).catchError((e) => debugPrint('Cache save error: $e'));
    return [snap];
  }

  /// Deletes a note and records an immutable audit entry.
  ///
  /// `firestore.rules` grants `notes` delete to superadmins only, so the caller
  /// must be one; an author cannot erase a document even though they own it.
  /// This is the compensating control for the "non-erasable" ledger claim —
  /// a removal is never silent.
  static Future<void> deleteNoteWithAudit({
    required NoteModel note,
    required UserModel deletedBy,
  }) async {
    final batch = FirebaseFirestore.instance.batch();

    // 1. Remove note from active notes feed
    final noteRef = _notes.doc(note.id);
    batch.delete(noteRef);

    // 2. Commit immutable audit log entry
    final logRef = _deletionLogs.doc();
    batch.set(logRef, {
      'noteId': note.id,
      'noteTitle': (note.title != null && note.title!.trim().isNotEmpty)
          ? note.title!.trim()
          : 'Academic Note',
      'content': (note.content ?? '').trim(),
      'imageUrl': note.imageUrl,
      'authorUid': note.postedByUid,
      'authorName': note.authorName,
      'authorRegNo': note.authorRegNo,
      'authorRole': note.authorRole ?? 'student',
      'authorAdminColorHex': note.authorAdminColorHex,
      'noteCreatedAt': note.timestamp,
      if (note.updatedAt != null) 'noteUpdatedAt': note.updatedAt,
      'deletedByUid': deletedBy.uid,
      'deletedByName': deletedBy.name,
      'deletedByRegNo': deletedBy.regNo,
      'deletedByRole': deletedBy.role,
      'deletedByAdminColorHex':
          deletedBy.adminColorHex ?? deletedBy.approverColorHex,
      'isDeletedByAuthor': deletedBy.uid == note.postedByUid,
      'deletedAt': FieldValue.serverTimestamp(),
    });

    try {
      await batch.commit();
    } catch (e) {
      debugPrint('Batch commit error in deleteNoteWithAudit: $e');
      rethrow;
    }
  }

  /// Streams note deletion audit logs ordered by deletion timestamp descending.
  static Stream<List<NoteDeletionLogModel>> streamDeletionLogs(
      {int limit = 60}) {
    return _deletionLogs
        .orderBy('deletedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(NoteDeletionLogModel.fromFirestore).toList());
  }

  /// Deletes a specific audit log entry (Admin exclusive).
  static Future<void> deleteAuditLog(String logId) async {
    await _deletionLogs.doc(logId).delete();
  }

  /// Clears all audit log entries (Admin exclusive).
  static Future<void> clearAllAuditLogs() async {
    final snapshot = await _deletionLogs.get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  static Future<String> publish({
    required UserModel author,
    required String title,
    required String body,
    String? imageUrl,
    String? imageStoragePath,
    String? documentUrl,
    String? documentStoragePath,
    String? documentName,
    String? documentType,
  }) async {
    final doc = _notes.doc();
    await doc.set(<String, dynamic>{
      'id': doc.id,
      'title': title.trim(),
      'body': body.trim(),
      'imageUrl': imageUrl,
      'imageStoragePath': imageStoragePath,
      'documentUrl': documentUrl,
      'documentStoragePath': documentStoragePath,
      'documentName': documentName,
      'documentType': documentType,
      'authorUid': author.uid,
      'postedByUid': author.uid,
      'authorName': author.name,
      'authorRegNo': author.regNo,
      'authorFaculty': author.branch,
      'authorSlot': '',
      'authorApproverName': author.approvedBy,
      'authorApproverColor': author.approverColorHex,
      'verified': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }
}
