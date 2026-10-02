import 'package:cloud_firestore/cloud_firestore.dart';

/// Immutable audit record of a deleted academic note.
class NoteDeletionLogModel {
  final String id;
  final String noteId;
  final String noteTitle;
  final String content;
  final String? imageUrl;
  final String authorUid;
  final String authorName;
  final String authorRegNo;
  final String authorRole;
  final String? authorAdminColorHex;
  final DateTime noteCreatedAt;
  final DateTime? noteUpdatedAt;
  final String deletedByUid;
  final String deletedByName;
  final String deletedByRegNo;
  final String deletedByRole;
  final String? deletedByAdminColorHex;
  final bool isDeletedByAuthor;
  final DateTime deletedAt;

  NoteDeletionLogModel({
    required this.id,
    required this.noteId,
    required this.noteTitle,
    required this.content,
    this.imageUrl,
    required this.authorUid,
    required this.authorName,
    required this.authorRegNo,
    required this.authorRole,
    this.authorAdminColorHex,
    required this.noteCreatedAt,
    this.noteUpdatedAt,
    required this.deletedByUid,
    required this.deletedByName,
    required this.deletedByRegNo,
    required this.deletedByRole,
    this.deletedByAdminColorHex,
    required this.isDeletedByAuthor,
    required this.deletedAt,
  });

  factory NoteDeletionLogModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};

    DateTime parseDate(dynamic value, [DateTime? fallback]) {
      if (value is Timestamp) return value.toDate();
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      return fallback ?? DateTime.now();
    }

    return NoteDeletionLogModel(
      id: doc.id,
      noteId: (data['noteId'] ?? '').toString(),
      noteTitle: (data['noteTitle'] ?? 'Academic Note').toString(),
      content: (data['content'] ?? '').toString(),
      imageUrl: data['imageUrl'] as String?,
      authorUid: (data['authorUid'] ?? '').toString(),
      authorName: (data['authorName'] ?? 'Member').toString(),
      authorRegNo: (data['authorRegNo'] ?? '').toString(),
      authorRole: (data['authorRole'] ?? 'student').toString(),
      authorAdminColorHex: data['authorAdminColorHex'] as String?,
      noteCreatedAt: parseDate(data['noteCreatedAt']),
      noteUpdatedAt: data['noteUpdatedAt'] != null ? parseDate(data['noteUpdatedAt']) : null,
      deletedByUid: (data['deletedByUid'] ?? '').toString(),
      deletedByName: (data['deletedByName'] ?? 'Admin').toString(),
      deletedByRegNo: (data['deletedByRegNo'] ?? '').toString(),
      deletedByRole: (data['deletedByRole'] ?? 'admin').toString(),
      deletedByAdminColorHex: data['deletedByAdminColorHex'] as String?,
      isDeletedByAuthor: data['isDeletedByAuthor'] == true,
      deletedAt: parseDate(data['deletedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'noteId': noteId,
        'noteTitle': noteTitle,
        'content': content,
        'imageUrl': imageUrl,
        'authorUid': authorUid,
        'authorName': authorName,
        'authorRegNo': authorRegNo,
        'authorRole': authorRole,
        'authorAdminColorHex': authorAdminColorHex,
        'noteCreatedAt': noteCreatedAt,
        if (noteUpdatedAt != null) 'noteUpdatedAt': noteUpdatedAt,
        'deletedByUid': deletedByUid,
        'deletedByName': deletedByName,
        'deletedByRegNo': deletedByRegNo,
        'deletedByRole': deletedByRole,
        'deletedByAdminColorHex': deletedByAdminColorHex,
        'isDeletedByAuthor': isDeletedByAuthor,
        'deletedAt': FieldValue.serverTimestamp(),
      };
}
