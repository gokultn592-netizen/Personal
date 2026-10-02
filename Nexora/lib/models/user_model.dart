import 'package:cloud_firestore/cloud_firestore.dart';

class AcademicInfo {
  final String proctorName;
  final String coreSlot;
  final String nptel;
  final String extraCurricular;
  final List<String> clubs;

  AcademicInfo({
    String proctorName = '',
    String facultyAdvisor = '',
    this.coreSlot = '',
    required this.nptel,
    required this.extraCurricular,
    required this.clubs,
  }) : proctorName = proctorName.isNotEmpty ? proctorName : facultyAdvisor;

  /// Backward-compatible alias
  String get facultyAdvisor => proctorName;

  factory AcademicInfo.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return AcademicInfo(
        proctorName: '',
        coreSlot: '',
        nptel: '',
        extraCurricular: '',
        clubs: [],
      );
    }
    // Both keys are mirrored on write, but a document may carry only one of
    // them. `??` alone would let an empty-string `proctorName` shadow a real
    // `facultyAdvisor`, so prefer whichever value is actually non-empty.
    final proctor = (map['proctorName'] ?? '').toString().trim();
    final advisor = (map['facultyAdvisor'] ?? '').toString().trim();
    return AcademicInfo(
      proctorName: proctor.isNotEmpty ? proctor : advisor,
      coreSlot: (map['coreSlot'] ?? '').toString(),
      nptel: (map['nptel'] ?? '').toString(),
      extraCurricular: (map['extraCurricular'] ?? '').toString(),
      clubs: List<String>.from(map['clubs'] ?? []),
    );
  }

  Map<String, dynamic> toMap() => {
        'proctorName': proctorName,
        'facultyAdvisor': proctorName,
        'coreSlot': coreSlot,
        'nptel': nptel,
        'extraCurricular': extraCurricular,
        'clubs': clubs,
      };

  AcademicInfo copyWith({
    String? proctorName,
    String? facultyAdvisor,
    String? coreSlot,
    String? nptel,
    String? extraCurricular,
    List<String>? clubs,
  }) {
    // `proctorName ?? facultyAdvisor` preferred whichever was non-null; callers
    // often pass only one of the two. Whichever is supplied wins, and only if
    // it is non-empty — an explicitly cleared field would otherwise be
    // repopulated from the alias.
    final nextProctor = (proctorName ?? facultyAdvisor)?.trim();
    return AcademicInfo(
      proctorName: (nextProctor?.isNotEmpty ?? false) ? nextProctor! : this.proctorName,
      coreSlot: coreSlot ?? this.coreSlot,
      nptel: nptel ?? this.nptel,
      extraCurricular: extraCurricular ?? this.extraCurricular,
      clubs: clubs ?? List<String>.from(this.clubs),
    );
  }
}

class CourseItem {
  final String code;
  final String name;
  final String faculty;
  final String slot;

  CourseItem({
    required this.code,
    required this.name,
    required this.faculty,
    required this.slot,
  });

  factory CourseItem.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return CourseItem(code: '', name: '', faculty: '', slot: '');
    }
    return CourseItem(
      code: map['code'] ?? '',
      name: map['name'] ?? '',
      faculty: map['faculty'] ?? '',
      slot: map['slot'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'code': code,
        'name': name,
        'faculty': faculty,
        'slot': slot,
      };

  CourseItem copyWith({
    String? code,
    String? name,
    String? faculty,
    String? slot,
  }) {
    return CourseItem(
      code: code ?? this.code,
      name: name ?? this.name,
      faculty: faculty ?? this.faculty,
      slot: slot ?? this.slot,
    );
  }
}

class SearchIndices {
  final List<String> faculties;
  final String regNoLower;
  final String nameLower;

  SearchIndices({
    required this.faculties,
    required this.regNoLower,
    required this.nameLower,
  });

  factory SearchIndices.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return SearchIndices(faculties: [], regNoLower: '', nameLower: '');
    }
    return SearchIndices(
      faculties: List<String>.from(map['faculties'] ?? []),
      regNoLower: map['regNoLower'] ?? '',
      nameLower: map['nameLower'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'faculties': faculties,
        'regNoLower': regNoLower,
        'nameLower': nameLower,
      };

  SearchIndices copyWith({
    List<String>? faculties,
    String? regNoLower,
    String? nameLower,
  }) {
    return SearchIndices(
      faculties: faculties ?? List<String>.from(this.faculties),
      regNoLower: regNoLower ?? this.regNoLower,
      nameLower: nameLower ?? this.nameLower,
    );
  }
}

class UserModel {
  final String uid;
  final String email;
  final String name;
  final String regNo;
  final String branch;
  final String year;
  final String phoneNo;
  final String? photoUrl;
  final String role; // 'superadmin' | 'admin' | 'student'
  final String? adminColorHex;
  final String approvedBy;
  final String approverColorHex;
  final AcademicInfo academic;
  final List<CourseItem> courses;
  final SearchIndices searchIndices;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.regNo,
    required this.branch,
    required this.year,
    required this.phoneNo,
    this.photoUrl,
    required this.role,
    this.adminColorHex,
    required this.approvedBy,
    required this.approverColorHex,
    required this.academic,
    required this.courses,
    required this.searchIndices,
  });

  bool get isAdmin => role == 'admin' || role == 'superadmin' || role == 'approver';
  bool get isSuperAdmin => role == 'superadmin';

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    final coursesRaw = (map['courses'] as List<dynamic>?) ?? [];
    return UserModel(
      uid: uid,
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      regNo: map['regNo'] ?? '',
      branch: map['branch'] ?? '',
      year: map['year'] ?? '',
      phoneNo: map['phoneNo'] ?? '',
      photoUrl: map['photoUrl'],
      role: map['role'] ?? 'student',
      adminColorHex: map['adminColorHex'],
      approvedBy: map['approvedBy'] ?? '',
      approverColorHex: map['approverColorHex'] ?? '#3B82F6',
      academic: AcademicInfo.fromMap(map['academic'] as Map<String, dynamic>?),
      courses: coursesRaw
          .map((e) => CourseItem.fromMap(e as Map<String, dynamic>?))
          .toList(),
      searchIndices: SearchIndices.fromMap(map['searchIndices'] as Map<String, dynamic>?),
    );
  }

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return UserModel.fromMap(data, doc.id);
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'email': email,
        'name': name,
        'regNo': regNo,
        'branch': branch,
        'year': year,
        'phoneNo': phoneNo,
        'photoUrl': photoUrl,
        'role': role,
        'adminColorHex': adminColorHex,
        'approvedBy': approvedBy,
        'approverColorHex': approverColorHex,
        'academic': academic.toMap(),
        'courses': courses.map((c) => c.toMap()).toList(),
        'searchIndices': searchIndices.toMap(),
      };

  UserModel copyWith({
    String? uid,
    String? email,
    String? name,
    String? regNo,
    String? branch,
    String? year,
    String? phoneNo,
    String? photoUrl,
    String? role,
    String? adminColorHex,
    String? approvedBy,
    String? approverColorHex,
    AcademicInfo? academic,
    List<CourseItem>? courses,
    SearchIndices? searchIndices,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      regNo: regNo ?? this.regNo,
      branch: branch ?? this.branch,
      year: year ?? this.year,
      phoneNo: phoneNo ?? this.phoneNo,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      adminColorHex: adminColorHex ?? this.adminColorHex,
      approvedBy: approvedBy ?? this.approvedBy,
      approverColorHex: approverColorHex ?? this.approverColorHex,
      academic: academic ?? this.academic,
      courses: courses ?? this.courses,
      searchIndices: searchIndices ?? this.searchIndices,
    );
  }
}

class PendingUserModel {
  final String uid;
  final String email;
  final String name;
  final String regNo;
  final String branch;
  final String year;
  final String phoneNo;
  final String? photoUrl;
  final String? proctorName;
  final String? coreSlot;
  final List<CourseItem> courses;
  final List<String> clubs;
  final bool isNexusMember;
  final String? nexusRole;
  final DateTime submittedAt;

  String? get facultyAdvisor => proctorName;

  PendingUserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.regNo,
    required this.branch,
    required this.year,
    required this.phoneNo,
    this.photoUrl,
    this.proctorName,
    String? facultyAdvisor,
    this.coreSlot,
    this.courses = const [],
    this.clubs = const [],
    this.isNexusMember = false,
    this.nexusRole,
    required this.submittedAt,
  });

  factory PendingUserModel.fromFirestore(DocumentSnapshot doc) {
    final d = (doc.data() as Map<String, dynamic>?) ?? {};
    final coursesRaw = (d['courses'] as List<dynamic>?) ?? [];
    return PendingUserModel(
      uid: doc.id,
      email: d['email'] ?? '',
      name: d['name'] ?? '',
      regNo: d['regNo'] ?? '',
      branch: d['branch'] ?? '',
      year: d['year'] ?? '',
      phoneNo: d['phoneNo'] ?? '',
      photoUrl: d['photoUrl'],
      proctorName: d['proctorName'] ?? d['facultyAdvisor'],
      coreSlot: d['coreSlot'],
      courses: coursesRaw
          .map((e) => CourseItem.fromMap(e as Map<String, dynamic>?))
          .toList(),
      clubs: List<String>.from(d['clubs'] ?? []),
      isNexusMember: (d['isNexusMember'] as bool?) ?? false,
      nexusRole: d['nexusRole'] as String?,
      submittedAt: (d['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'email': email,
        'name': name,
        'regNo': regNo,
        'branch': branch,
        'year': year,
        'phoneNo': phoneNo,
        if (photoUrl != null) 'photoUrl': photoUrl,
        if (proctorName != null) 'proctorName': proctorName,
        if (proctorName != null) 'facultyAdvisor': proctorName,
        if (coreSlot != null) 'coreSlot': coreSlot,
        'isNexusMember': isNexusMember,
        if (nexusRole != null) 'nexusRole': nexusRole,
        'noOfCourses': courses.length,
        'courses': courses.map((c) => c.toMap()).toList(),
        'noOfClubs': clubs.length,
        'clubs': clubs,
        'submittedAt': FieldValue.serverTimestamp(),
      };
}
