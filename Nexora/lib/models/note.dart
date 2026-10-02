import 'package:cloud_firestore/cloud_firestore.dart';

class Note {
  const Note({
    required this.id,
    required this.title,
    required this.body,
    required this.authorUid,
    required this.authorName,
    required this.authorRegNo,
    required this.authorFaculty,
    required this.authorSlot,
    this.imageUrl,
    this.authorApproverName,
    this.authorApproverColor,
    this.verified = true,
    this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final String authorUid;
  final String authorName;
  final String authorRegNo;
  final String authorFaculty;
  final String authorSlot;
  final String? imageUrl;
  final String? authorApproverName;
  final String? authorApproverColor;
  final bool verified;
  final DateTime? createdAt;

  static Note fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final rawCreated = data['createdAt'];
    return Note(
      id: (data['id'] as String?) ?? doc.id,
      title: (data['title'] as String?) ?? 'Untitled note',
      body: (data['body'] as String?) ?? '',
      authorUid: (data['authorUid'] as String?) ?? '',
      authorName: (data['authorName'] as String?) ?? 'Unknown author',
      authorRegNo: (data['authorRegNo'] as String?) ?? '',
      authorFaculty: (data['authorFaculty'] as String?) ?? '',
      authorSlot: (data['authorSlot'] as String?) ?? '',
      imageUrl: data['imageUrl'] as String?,
      authorApproverName: data['authorApproverName'] as String?,
      authorApproverColor: data['authorApproverColor'] as String?,
      verified: (data['verified'] as bool?) ?? false,
      createdAt: rawCreated is Timestamp ? rawCreated.toDate() : null,
    );
  }
}
