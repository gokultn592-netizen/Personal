import 'package:cloud_firestore/cloud_firestore.dart';

class NoteModel {
  final String id;
  final String? title;
  final String content;
  final String? imageUrl;
  final String postedByUid;
  final String authorName;
  final String authorRegNo;
  final String? authorRole;
  final String? authorAdminColorHex;
  final String? authorPhotoUrl;
  final DateTime timestamp;
  final DateTime? updatedAt;

  NoteModel({
    required this.id,
    this.title,
    required this.content,
    this.imageUrl,
    required this.postedByUid,
    required this.authorName,
    required this.authorRegNo,
    this.authorRole,
    this.authorAdminColorHex,
    this.authorPhotoUrl,
    required this.timestamp,
    this.updatedAt,
  });

  bool get isAuthorAdmin => authorRole == 'admin' || authorRole == 'superadmin';
  bool get isAuthorSuperAdmin => authorRole == 'superadmin';
  bool get isEdited => updatedAt != null;

  factory NoteModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parsedTimestamp = DateTime.now();
    if (map['timestamp'] is Timestamp) {
      parsedTimestamp = (map['timestamp'] as Timestamp).toDate();
    } else if (map['timestamp'] is int) {
      parsedTimestamp = DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int);
    }

    DateTime? parsedUpdatedAt;
    if (map['updatedAt'] is Timestamp) {
      parsedUpdatedAt = (map['updatedAt'] as Timestamp).toDate();
    } else if (map['updatedAt'] is int) {
      parsedUpdatedAt = DateTime.fromMillisecondsSinceEpoch(map['updatedAt'] as int);
    }

    return NoteModel(
      id: id,
      title: map['title'],
      content: map['content'] ?? '',
      imageUrl: map['imageUrl'],
      postedByUid: (map['postedByUid'] ?? map['authorUid'] ?? '').toString(),
      // Never invent identity data. A note with missing attribution is rendered
      // with an explicit "unattributed" marker so the ledger does not display
      // a fabricated scholar name or registration number.
      authorName: map['authorName']?.toString() ?? 'Unattributed',
      authorRegNo: map['authorRegNo']?.toString() ?? '',
      authorRole: map['authorRole']?.toString(),
      authorAdminColorHex: map['authorAdminColorHex']?.toString(),
      authorPhotoUrl: map['authorPhotoUrl']?.toString(),
      timestamp: parsedTimestamp,
      updatedAt: parsedUpdatedAt,
    );
  }

  factory NoteModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return NoteModel.fromMap(data, doc.id);
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'content': content,
        'imageUrl': imageUrl,
        'postedByUid': postedByUid,
        'authorName': authorName,
        'authorRegNo': authorRegNo,
        'authorRole': authorRole,
        'authorAdminColorHex': authorAdminColorHex,
        'authorPhotoUrl': authorPhotoUrl,
        'timestamp': FieldValue.serverTimestamp(),
        if (updatedAt != null) 'updatedAt': updatedAt,
      };

  NoteModel copyWith({
    String? id,
    String? title,
    String? content,
    String? imageUrl,
    String? postedByUid,
    String? authorName,
    String? authorRegNo,
    String? authorRole,
    String? authorAdminColorHex,
    String? authorPhotoUrl,
    DateTime? timestamp,
    DateTime? updatedAt,
  }) {
    return NoteModel(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      imageUrl: imageUrl ?? this.imageUrl,
      postedByUid: postedByUid ?? this.postedByUid,
      authorName: authorName ?? this.authorName,
      authorRegNo: authorRegNo ?? this.authorRegNo,
      authorRole: authorRole ?? this.authorRole,
      authorAdminColorHex: authorAdminColorHex ?? this.authorAdminColorHex,
      authorPhotoUrl: authorPhotoUrl ?? this.authorPhotoUrl,
      timestamp: timestamp ?? this.timestamp,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
