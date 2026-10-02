import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/cache/cache_service.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../services/auth_service.dart';
import '../../widgets/nexora_logo.dart';
import '../../widgets/nx_field.dart';

/// Helper to hold controllers for an individual course entry.
class _CourseEntry {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController facultyCtrl = TextEditingController();
  final TextEditingController codeCtrl = TextEditingController();
  final TextEditingController slotCtrl = TextEditingController();
  bool isCustom = false;

  void dispose() {
    nameCtrl.dispose();
    facultyCtrl.dispose();
    codeCtrl.dispose();
    slotCtrl.dispose();
  }
}

/// Helper to hold controller for an individual club entry.
class _ClubEntry {
  final TextEditingController nameCtrl = TextEditingController();

  void dispose() {
    nameCtrl.dispose();
  }
}

/// Screen displayed immediately after Google authentication when no
/// academic profile exists for the user yet in the student community platform.
class ProfileSetupScreen extends StatefulWidget {
  final User user;

  const ProfileSetupScreen({super.key, required this.user});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _auth = AuthService();

  late final TextEditingController _nameCtrl;
  final TextEditingController _regNoCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _proctorCtrl = TextEditingController();

  // Branch dropdown state (defaults to 'Int MTech DS')
  String _selectedBranch = kDepartments.first;
  final List<String> _branchOptions = List<String>.from(kDepartments);

  // Year dropdown state (defaults to '1')
  String _selectedYear = kAcademicYears.first;

  // Core Slot dropdown state (defaults to 'Morning')
  String _selectedCoreSlot = kSlots.first;

  // Dynamic Course Dropdown Options & Stream
  List<String> _courseOptions = List<String>.from(kDefaultCourseNames);
  StreamSubscription<DocumentSnapshot>? _courseSubscription;

  // Dynamic Course Entries
  final List<_CourseEntry> _courses = [];

  // Dynamic Club Entries
  final List<_ClubEntry> _clubs = [];

  bool _busy = false;
  String? _error;

  static String _yearSuffix(String y) {
    if (y == '1') return 'st';
    if (y == '2') return 'nd';
    if (y == '3') return 'rd';
    return 'th';
  }

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.user.displayName ?? '');

    // Pre-populate active course dropdown options from Hive cache
    final cached = CacheService().getFreshCourseNames();
    if (cached != null && cached.isNotEmpty) {
      _courseOptions = List<String>.from(cached);
    }

    // Realtime sync of active course dropdown options from Firestore config
    _courseSubscription = FirebaseFirestore.instance
        .collection('config')
        .doc('courses')
        .snapshots()
        .listen((snap) {
      if (snap.exists && snap.data() != null) {
        final data = snap.data() as Map<String, dynamic>;
        final list = data['courseNames'] as List<dynamic>?;
        if (list != null && list.isNotEmpty) {
          final courses = list.map((e) => e.toString()).toList();
          CacheService().saveCourseNames(courses);
          if (mounted) {
            setState(() {
              _courseOptions = courses;
            });
          }
        }
      }
    });

    // Default with the 7 default courses and 1 club
    _setCourseCount(kDefaultCourseNames.length);
    _setClubCount(1);
  }

  @override
  void dispose() {
    _courseSubscription?.cancel();
    _nameCtrl.dispose();
    _regNoCtrl.dispose();
    _phoneCtrl.dispose();
    _proctorCtrl.dispose();
    for (final c in _courses) {
      c.dispose();
    }
    for (final cl in _clubs) {
      cl.dispose();
    }
    super.dispose();
  }

  void _setCourseCount(int count) {
    if (count < 1) count = 1;
    if (count > 12) count = 12;
    while (_courses.length < count) {
      final index = _courses.length;
      final entry = _CourseEntry();
      if (index < _courseOptions.length) {
        final courseName = _courseOptions[index];
        entry.nameCtrl.text = courseName;
        final meta = kDefaultCourseMetadata[courseName];
        if (meta != null) {
          entry.facultyCtrl.text = ''; // Leave blank so faculty name appears as hint text
          entry.codeCtrl.text = meta['code'] ?? '';
          entry.slotCtrl.text = meta['slot'] ?? '';
        }
      }
      _courses.add(entry);
    }
    while (_courses.length > count) {
      final removed = _courses.removeLast();
      removed.dispose();
    }
    setState(() {});
  }

  void _addCourse() {
    if (_courses.length >= 12) return;
    final index = _courses.length;
    final entry = _CourseEntry();
    if (index < _courseOptions.length) {
      final courseName = _courseOptions[index];
      entry.nameCtrl.text = courseName;
      final meta = kDefaultCourseMetadata[courseName];
      if (meta != null) {
        entry.facultyCtrl.text = ''; // Leave blank so faculty name appears as hint text
        entry.codeCtrl.text = meta['code'] ?? '';
        entry.slotCtrl.text = meta['slot'] ?? '';
      }
    }
    setState(() {
      _courses.add(entry);
    });
  }

  void _removeCourse(int index) {
    if (_courses.length <= 1) return;
    setState(() {
      final removed = _courses.removeAt(index);
      removed.dispose();
    });
  }

  void _setClubCount(int count) {
    if (count < 0) count = 0;
    if (count > 10) count = 10;
    while (_clubs.length < count) {
      _clubs.add(_ClubEntry());
    }
    while (_clubs.length > count) {
      final removed = _clubs.removeLast();
      removed.dispose();
    }
    setState(() {});
  }

  void _addClub() {
    if (_clubs.length >= 10) return;
    setState(() {
      _clubs.add(_ClubEntry());
    });
  }

  void _removeClub(int index) {
    setState(() {
      final removed = _clubs.removeAt(index);
      removed.dispose();
    });
  }

  void _uppercaseRegNo(String value) {
    final upper = value.toUpperCase();
    if (value != upper) {
      _regNoCtrl.value = TextEditingValue(
        text: upper,
        selection: TextSelection.collapsed(offset: upper.length),
      );
    }
    final detected = inferBranchFromRegNo(upper);
    if (detected != null && _branchOptions.contains(detected) && _selectedBranch != detected) {
      setState(() => _selectedBranch = detected);
    }
  }

  Future<void> _submitProfile() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Validate courses
    for (int i = 0; i < _courses.length; i++) {
      final c = _courses[i];
      if (c.nameCtrl.text.trim().isEmpty) {
        setState(() => _error = 'Please select or enter a Course Name for Course #${i + 1}');
        return;
      }
    }

    // Validate clubs if count > 0
    for (int i = 0; i < _clubs.length; i++) {
      final cl = _clubs[i];
      if (cl.nameCtrl.text.trim().isEmpty) {
        setState(() => _error = 'Please enter a Club Name for Club #${i + 1}');
        return;
      }
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _error = null;
      _busy = true;
    });

    final coursesData = _courses.map((c) => {
      'name': c.nameCtrl.text.trim(),
      'faculty': c.facultyCtrl.text.trim().isNotEmpty
          ? c.facultyCtrl.text.trim()
          : (kDefaultCourseMetadata[c.nameCtrl.text.trim()]?['faculty']?.isNotEmpty == true
              ? kDefaultCourseMetadata[c.nameCtrl.text.trim()]!['faculty']!
              : 'TBA'),
      'code': c.codeCtrl.text.trim().toUpperCase(),
      'slot': c.slotCtrl.text.trim().toUpperCase(),
    }).toList();

    final clubsData = _clubs
        .map((cl) => cl.nameCtrl.text.trim())
        .where((name) => name.isNotEmpty)
        .toList();

    try {
      final error = await _auth.submitCandidateProfile(
        uid: widget.user.uid,
        email: widget.user.email ?? '',
        name: _nameCtrl.text.trim(),
        regNo: _regNoCtrl.text.trim().toUpperCase(),
        branch: _selectedBranch.trim(),
        year: _selectedYear,
        phoneNo: _phoneCtrl.text.trim(),
        photoUrl: widget.user.photoURL,
        proctorName: _proctorCtrl.text.trim(),
        coreSlot: _selectedCoreSlot,
        courses: coursesData,
        clubs: clubsData,
      );

      if (!mounted) return;

      if (error != null) {
        setState(() => _error = error);
        return;
      }

      showNxSnack(context, 'Profile submitted. Awaiting administrative approval.');
      // AuthGate will reactively detect the new pendingUsers document
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = authErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _auth.signOut();
    } catch (e) {
      if (mounted) showNxSnack(context, authErrorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final photoUrl = widget.user.photoURL;
    final email = widget.user.email ?? '';
    final displayName = widget.user.displayName ?? 'Student';

    return Scaffold(
      backgroundColor: NexoraTheme.scaffold,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Row(
          children: [
            NexoraLogo(size: 24, showWordmark: false),
            SizedBox(width: 10),
            Text('Nexora - Next Era'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: _busy ? null : _signOut,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Google Identity Banner Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: NexoraTheme.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: NexoraTheme.border),
                      ),
                      child: Row(
                        children: [
                          if (photoUrl != null && photoUrl.isNotEmpty)
                            CircleAvatar(
                              radius: 28,
                              backgroundImage: NetworkImage(photoUrl),
                            )
                          else
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: alphaOf(NexoraTheme.primary, 0.2),
                              child: Text(
                                displayName.isNotEmpty
                                    ? displayName[0].toUpperCase()
                                    : 'G',
                                style: GoogleFonts.poppins(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: NexoraTheme.primary,
                                ),
                              ),
                            ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        displayName,
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: NexoraTheme.textPrimary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(
                                      Icons.verified_rounded,
                                      size: 16,
                                      color: NexoraTheme.primary,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  email,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: NexoraTheme.textSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: alphaOf(NexoraTheme.primary, 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'Google Authenticated',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: NexoraTheme.primary,
                                        ),
                                      ),
                                    ),
                                    if (kDeveloperEmails.contains(email.toLowerCase()))
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: alphaOf(const Color(0xFF10B981), 0.18),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'Super Admin',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF10B981),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),

                    Text(
                      'Complete Your Student Profile',
                      style: GoogleFonts.poppins(
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                        color: NexoraTheme.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Enter your student credentials, enrolled courses, and student clubs. An administrator will verify your profile before granting full access to the community.',
                      style: TextStyle(
                        color: NexoraTheme.textSecondary,
                        fontSize: 13.5,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (_error != null) ...[
                      _errorBox(_error!),
                      const SizedBox(height: 16),
                    ],

                    // Section 1: Basic Student Credentials
                    _sectionHeader(
                      icon: Icons.badge_outlined,
                      title: 'Student Credentials',
                    ),
                    const SizedBox(height: 12),

                    // Full Name Field
                    NxField(
                      controller: _nameCtrl,
                      label: 'Full Name',
                      hint: 'As printed on your student ID',
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      prefixIcon: const Icon(
                        Icons.person_outline_rounded,
                        size: 20,
                        color: NexoraTheme.textSecondary,
                      ),
                      validator: (value) {
                        final val = value?.trim() ?? '';
                        if (val.isEmpty) return 'Full name is required';
                        if (val.length < 3) return 'Enter full official name';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Registration Number Field
                    NxField(
                      controller: _regNoCtrl,
                      label: 'Registration Number',
                      hint: '25MID0051',
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.characters,
                      onChanged: _uppercaseRegNo,
                      prefixIcon: const Icon(
                        Icons.badge_outlined,
                        size: 20,
                        color: NexoraTheme.textSecondary,
                      ),
                      validator: (value) {
                        final regNo = (value ?? '').trim().toUpperCase();
                        if (regNo.isEmpty) return 'Registration number is required';
                        final valid = RegExp(r'^[A-Z0-9]{4,20}$').hasMatch(regNo);
                        return valid
                            ? null
                            : 'Letters & numbers only (4-20 characters)';
                      },
                    ),
                    const SizedBox(height: 14),

                    // Branch Dropdown & Year Dropdown row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Branch Dropdown
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Branch / Program',
                                style: GoogleFonts.poppins(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: NexoraTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                value: _selectedBranch,
                                dropdownColor: NexoraTheme.card,
                                isExpanded: true,
                                style: GoogleFonts.poppins(
                                  color: NexoraTheme.textPrimary,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: NexoraTheme.card,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 14,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        const BorderSide(color: NexoraTheme.border),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: NexoraTheme.primary,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                items: _branchOptions
                                    .map(
                                      (b) => DropdownMenuItem(
                                        value: b,
                                        child: Text(
                                          formatBranchName(b, full: true),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedBranch = val);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Year of Study Dropdown
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Year of Study',
                                style: GoogleFonts.poppins(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: NexoraTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                initialValue: _selectedYear,
                                dropdownColor: NexoraTheme.card,
                                isExpanded: true,
                                style: GoogleFonts.poppins(
                                  color: NexoraTheme.textPrimary,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: NexoraTheme.card,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 14,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        const BorderSide(color: NexoraTheme.border),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: NexoraTheme.primary,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                items: kAcademicYears
                                    .map(
                                      (y) => DropdownMenuItem(
                                        value: y,
                                        child: Text('$y${_yearSuffix(y)} Year'),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedYear = val);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Phone Number
                    NxField(
                      controller: _phoneCtrl,
                      label: 'Contact Phone Number',
                      hint: '9876543210',
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      prefixIcon: const Icon(
                        Icons.phone_outlined,
                        size: 20,
                        color: NexoraTheme.textSecondary,
                      ),
                      validator: (value) {
                        final digits =
                            (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                        if (digits.isEmpty) return 'Phone number is required';
                        if (digits.length < 10 || digits.length > 15) {
                          return 'Enter a valid 10-15 digit phone number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Proctor Name & Core Slot Row
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: NxField(
                            controller: _proctorCtrl,
                            label: 'Proctor Name',
                            hint: 'e.g. Dr. Suresh',
                            textInputAction: TextInputAction.next,
                            textCapitalization: TextCapitalization.words,
                            prefixIcon: const Icon(
                              Icons.supervised_user_circle_outlined,
                              size: 20,
                              color: NexoraTheme.textSecondary,
                            ),
                            validator: (value) {
                              final val = value?.trim() ?? '';
                              if (val.isEmpty) return 'Proctor name is required';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Core Slot',
                                style: GoogleFonts.poppins(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: NexoraTheme.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                initialValue: _selectedCoreSlot,
                                dropdownColor: NexoraTheme.card,
                                isExpanded: true,
                                style: GoogleFonts.poppins(
                                  color: NexoraTheme.textPrimary,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: NexoraTheme.card,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 14,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide:
                                        const BorderSide(color: NexoraTheme.border),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: NexoraTheme.primary,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                items: kSlots
                                    .map(
                                      (s) => DropdownMenuItem(
                                        value: s,
                                        child: Text(s),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedCoreSlot = val);
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Section 2: Courses Enrolled
                    _sectionHeader(
                      icon: Icons.menu_book_rounded,
                      title: 'Courses Enrolled',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'No. of Courses: ',
                            style: TextStyle(
                              color: NexoraTheme.textSecondary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Container(
                            height: 32,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: NexoraTheme.card,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: NexoraTheme.border),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _courses.length,
                                dropdownColor: NexoraTheme.card,
                                style: GoogleFonts.robotoMono(
                                  color: NexoraTheme.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                                icon: const Icon(
                                  Icons.arrow_drop_down,
                                  color: NexoraTheme.primary,
                                  size: 18,
                                ),
                                items: List.generate(
                                  12,
                                  (i) => DropdownMenuItem(
                                    value: i + 1,
                                    child: Text('${i + 1}'),
                                  ),
                                ),
                                onChanged: (val) {
                                  if (val != null) _setCourseCount(val);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Dynamic Course Cards
                    ...List.generate(_courses.length, (index) {
                      final course = _courses[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: NexoraTheme.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: NexoraTheme.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: alphaOf(NexoraTheme.primary, 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'COURSE #${index + 1}',
                                        style: GoogleFonts.robotoMono(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: NexoraTheme.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_courses.length > 1)
                                  IconButton(
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                      color: NexoraTheme.textSecondary,
                                    ),
                                    tooltip: 'Remove course',
                                    onPressed: () => _removeCourse(index),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Course Name',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: NexoraTheme.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  value: course.isCustom
                                      ? '__custom__'
                                      : (_courseOptions.contains(course.nameCtrl.text)
                                          ? course.nameCtrl.text
                                          : null),
                                  dropdownColor: NexoraTheme.card,
                                  style: GoogleFonts.poppins(
                                    color: NexoraTheme.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: NexoraTheme.card,
                                    hintText: 'Select course name',
                                    hintStyle: const TextStyle(color: NexoraTheme.textSecondary),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 14,
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.auto_stories_outlined,
                                      size: 20,
                                      color: NexoraTheme.textSecondary,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: NexoraTheme.border),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: NexoraTheme.primary,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                  items: [
                                    ..._courseOptions.map(
                                      (name) => DropdownMenuItem(
                                        value: name,
                                        child: Text(name, overflow: TextOverflow.ellipsis),
                                      ),
                                    ),
                                    const DropdownMenuItem(
                                      value: '__custom__',
                                      child: Text(
                                        '+ Other (Enter Custom Course Name)',
                                        style: TextStyle(
                                          color: NexoraTheme.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                  onChanged: (val) {
                                    if (val == null) return;
                                    setState(() {
                                      if (val == '__custom__') {
                                        course.isCustom = true;
                                        course.nameCtrl.clear();
                                      } else {
                                        course.isCustom = false;
                                        course.nameCtrl.text = val;
                                        final meta = kDefaultCourseMetadata[val];
                                        if (meta != null) {
                                          course.facultyCtrl.clear(); // Leave blank so faculty name appears as hint text
                                          if (course.slotCtrl.text.trim().isEmpty) {
                                            course.slotCtrl.text = meta['slot'] ?? '';
                                          }
                                          if (course.codeCtrl.text.trim().isEmpty) {
                                            course.codeCtrl.text = meta['code'] ?? '';
                                          }
                                        }
                                      }
                                    });
                                  },
                                  validator: (v) {
                                    if (course.isCustom) return null;
                                    if (course.nameCtrl.text.trim().isEmpty) {
                                      return 'Please select a course';
                                    }
                                    return null;
                                  },
                                ),
                                if (course.isCustom) ...[
                                  const SizedBox(height: 10),
                                  NxField(
                                    controller: course.nameCtrl,
                                    label: 'Custom Course Name',
                                    hint: 'e.g. Distributed Cloud Systems',
                                    textInputAction: TextInputAction.next,
                                    textCapitalization: TextCapitalization.words,
                                    prefixIcon: const Icon(
                                      Icons.edit_note_rounded,
                                      size: 20,
                                      color: NexoraTheme.textSecondary,
                                    ),
                                    validator: (v) =>
                                        (v?.trim().isEmpty ?? true) ? 'Custom Course Name is required' : null,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 10),
                            Builder(
                              builder: (context) {
                                final selectedName = course.nameCtrl.text.trim();
                                final meta = kDefaultCourseMetadata[selectedName];
                                final defaultFaculty = meta?['faculty'] ?? '';
                                final facultyHint = defaultFaculty.isNotEmpty
                                    ? defaultFaculty
                                    : 'Faculty Name (or TBA)';

                                return NxField(
                                  controller: course.facultyCtrl,
                                  label: 'Course Faculty',
                                  hint: facultyHint,
                                  textInputAction: TextInputAction.next,
                                  textCapitalization: TextCapitalization.words,
                                  prefixIcon: const Icon(
                                    Icons.person_search_outlined,
                                    size: 20,
                                    color: NexoraTheme.textSecondary,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: NxField(
                                    controller: course.codeCtrl,
                                    label: 'Code',
                                    hint: 'e.g. CSE2001',
                                    textInputAction: TextInputAction.next,
                                    textCapitalization: TextCapitalization.characters,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: NxField(
                                    controller: course.slotCtrl,
                                    label: 'Slot',
                                    hint: 'e.g. A1+TA1',
                                    textInputAction: TextInputAction.next,
                                    textCapitalization: TextCapitalization.characters,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),

                    OutlinedButton.icon(
                      onPressed: _courses.length < 12 ? _addCourse : null,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: NexoraTheme.border),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add Another Course'),
                    ),
                    const SizedBox(height: 28),

                    // Section 3: Clubs & Student Chapters
                    _sectionHeader(
                      icon: Icons.groups_outlined,
                      title: 'Clubs & Student Chapters',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'No. of Clubs: ',
                            style: TextStyle(
                              color: NexoraTheme.textSecondary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Container(
                            height: 32,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: NexoraTheme.card,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: NexoraTheme.border),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _clubs.length,
                                dropdownColor: NexoraTheme.card,
                                style: GoogleFonts.robotoMono(
                                  color: NexoraTheme.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                                icon: const Icon(
                                  Icons.arrow_drop_down,
                                  color: NexoraTheme.primary,
                                  size: 18,
                                ),
                                items: List.generate(
                                  11,
                                  (i) => DropdownMenuItem(
                                    value: i,
                                    child: Text('$i'),
                                  ),
                                ),
                                onChanged: (val) {
                                  if (val != null) _setClubCount(val);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    if (_clubs.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: NexoraTheme.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: NexoraTheme.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              size: 18,
                              color: NexoraTheme.textSecondary,
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'No clubs selected. You can add clubs now or join later.',
                                style: TextStyle(
                                  color: NexoraTheme.textSecondary,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _addClub,
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Add Club'),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      ...List.generate(_clubs.length, (index) {
                        final club = _clubs[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: NexoraTheme.card,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: NexoraTheme.border),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: NxField(
                                  controller: club.nameCtrl,
                                  label: 'Club Name #${index + 1}',
                                  hint: 'e.g. Google Developer Student Club',
                                  textInputAction: TextInputAction.next,
                                  textCapitalization: TextCapitalization.words,
                                  prefixIcon: const Icon(
                                    Icons.military_tech_outlined,
                                    size: 20,
                                    color: NexoraTheme.textSecondary,
                                  ),
                                  validator: (v) =>
                                      (v?.trim().isEmpty ?? true) ? 'Club Name is required' : null,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: NexoraTheme.textSecondary,
                                ),
                                tooltip: 'Remove club',
                                onPressed: () => _removeClub(index),
                              ),
                            ],
                          ),
                        );
                      }),
                      OutlinedButton.icon(
                        onPressed: _clubs.length < 10 ? _addClub : null,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: NexoraTheme.border),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add Another Club'),
                      ),
                    ],
                    const SizedBox(height: 32),

                    // Submit Button
                    FilledButton(
                      onPressed: _busy ? null : _submitProfile,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              kDeveloperEmails.contains(email.toLowerCase())
                                  ? 'Initialize & Enter as Super Admin'
                                  : 'Submit Profile for Approval',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                    const SizedBox(height: 12),

                    // Sign Out / Switch Account
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _signOut,
                      icon: const Icon(Icons.logout_rounded, size: 18),
                      label: const Text('Sign out / Switch account'),
                    ),
                    const SizedBox(height: 14),

                    const Text(
                      'Your registration number, courses, and clubs are permanently bound to your student community record upon administrator verification.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: NexoraTheme.textSecondary,
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader({
    required IconData icon,
    required String title,
    Widget? trailing,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: NexoraTheme.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: NexoraTheme.textPrimary,
              ),
            ),
          ],
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _errorBox(String message) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: alphaOf(NexoraTheme.error, 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: alphaOf(NexoraTheme.error, 0.4)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 18,
              color: NexoraTheme.error,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: NexoraTheme.error,
                  fontSize: 13.5,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
}
