import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a note broadcast notification sent to everyone in Nexora.
class NoteNotificationModel {
  final String id;
  final String noteId;
  final String noteTitle;
  final String authorName;
  final String authorUid;
  final String authorRegNo;
  final String type; // 'created' or 'updated'
  final DateTime timestamp;

  NoteNotificationModel({
    required this.id,
    required this.noteId,
    required this.noteTitle,
    required this.authorName,
    required this.authorUid,
    required this.authorRegNo,
    this.type = 'updated',
    required this.timestamp,
  });

  bool get isUpdate => type == 'updated';

  factory NoteNotificationModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    DateTime parsedDate = DateTime.now();
    final ts = data['timestamp'];
    if (ts is Timestamp) {
      parsedDate = ts.toDate();
    } else if (ts is int) {
      parsedDate = DateTime.fromMillisecondsSinceEpoch(ts);
    }

    return NoteNotificationModel(
      id: doc.id,
      noteId: (data['noteId'] ?? '').toString(),
      noteTitle: (data['noteTitle'] ?? 'Academic Note').toString(),
      authorName: (data['authorName'] ?? 'Member').toString(),
      authorUid: (data['authorUid'] ?? '').toString(),
      authorRegNo: (data['authorRegNo'] ?? '').toString(),
      type: (data['type'] ?? 'updated').toString(),
      timestamp: parsedDate,
    );
  }

  Map<String, dynamic> toMap() => {
        'noteId': noteId,
        'noteTitle': noteTitle,
        'authorName': authorName,
        'authorUid': authorUid,
        'authorRegNo': authorRegNo,
        'type': type,
        'timestamp': FieldValue.serverTimestamp(),
      };
}
