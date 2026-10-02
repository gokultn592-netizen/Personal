import 'package:cloud_firestore/cloud_firestore.dart';

/// User model representing verified academic identity
class NexoraUser {
  final String uid;
  final String email;
  final String name;
  final String regNo;     // Registration / Student Number
  final String faculty;
  final String slot;      // Academic slot (e.g., A1, B2)
  final String role;      // student | admin | approver
  final String? profilePicUrl;
  final List<String> auditSeals;  // List of admin UIDs who approved
  final List<ColorSeal> sealColors;  // Signature colors per admin approval
  final bool isVerified;
  final DateTime createdAt;
  final DateTime updatedAt;

  NexoraUser({
    required this.uid,
    required this.email,
    required this.name,
    required this.regNo,
    required this.faculty,
    required this.slot,
    required this.role,
    this.profilePicUrl,
    this.auditSeals = const [],
    this.sealColors = const [],
    this.isVerified = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory NexoraUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return NexoraUser(
      uid: doc.id,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      regNo: data['regNo'] ?? '',
      faculty: data['faculty'] ?? '',
      slot: data['slot'] ?? '',
      role: data['role'] ?? 'student',
      profilePicUrl: data['profilePicUrl'],
      auditSeals: List<String>.from(data['auditSeals'] ?? []),
      sealColors: (data['sealColors'] as List<dynamic>?)
          ?.map((c) => ColorSeal.fromMap(c))
          .toList() ??
      [],
      isVerified: data['isVerified'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'uid': uid,
        'email': email,
        'name': name,
        'regNo': regNo,
        'faculty': faculty,
        'slot': slot,
        'role': role,
        'profilePicUrl': profilePicUrl,
        'auditSeals': auditSeals,
        'sealColors': sealColors.map((c) => c.toMap()).toList(),
        'isVerified': isVerified,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };
}

/// Color seal for admin approval signature
class ColorSeal {
  final String adminUid;
  final int colorValue;
  final DateTime stampedAt;

  ColorSeal({
    required this.adminUid,
    required this.colorValue,
    required this.stampedAt,
  });

  factory ColorSeal.fromMap(Map<String, dynamic> map) => ColorSeal(
        adminUid: map['adminUid'],
        colorValue: map['colorValue'],
        stampedAt: (map['stampedAt'] as Timestamp).toDate(),
      );

  Map<String, dynamic> toMap() => {
        'adminUid': adminUid,
        'colorValue': colorValue,
        'stampedAt': Timestamp.fromDate(stampedAt),
      };
}

/// Note model for the academic notes collection
class Note {
  final String noteId;
  final String title;
  final String content;
  final String authorName;
  final String authorRegNo;
  final String authorUid;
  final String? authorRole;
  final String? authorAdminColorHex;
  final String? imageUrl;
  final DateTime timestamp;
  final bool isVerifiedPost;

  Note({
    required this.noteId,
    required this.title,
    required this.content,
    required this.authorName,
    required this.authorRegNo,
    required this.authorUid,
    this.authorRole,
    this.authorAdminColorHex,
    this.imageUrl,
    required this.timestamp,
    this.isVerifiedPost = true,
  });

  bool get isAuthorAdmin => authorRole == 'admin' || authorRole == 'superadmin';

  factory Note.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return Note(
      noteId: doc.id,
      title: d['title'] ?? '',
      content: d['content'] ?? '',
      authorName: d['authorName'] ?? '',
      authorRegNo: d['authorRegNo'] ?? '',
      authorUid: d['postedByUid'] ?? d['authorUid'] ?? '',
      authorRole: d['authorRole'],
      authorAdminColorHex: d['authorAdminColorHex'],
      imageUrl: d['imageUrl'],
      timestamp: (d['timestamp'] as Timestamp).toDate(),
      isVerifiedPost: d['isVerifiedPost'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() => {
        'title': title,
        'content': content,
        'authorName': authorName,
        'authorRegNo': authorRegNo,
        'authorUid': authorUid,
        'postedByUid': authorUid,
        'authorRole': authorRole,
        'authorAdminColorHex': authorAdminColorHex,
        'imageUrl': imageUrl,
        'timestamp': Timestamp.fromDate(timestamp),
        'isVerifiedPost': isVerifiedPost,
      };
}