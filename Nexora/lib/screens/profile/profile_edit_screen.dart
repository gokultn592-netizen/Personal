import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:nexora/core/constants.dart';
import 'package:nexora/core/theme.dart';
import 'package:nexora/core/utils.dart';
import 'package:nexora/models/user_model.dart';
import 'package:nexora/services/auth_service.dart';
import 'package:nexora/services/firestore_service.dart';
import 'package:nexora/services/device_storage_service.dart';
import 'package:nexora/widgets/role_badge.dart';

const _inputSurface = Color(0xFF212936);

/// Edits only the signed-in user's mutable academic profile fields.
class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key, required this.user});

  final UserModel user;

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  late final TextEditingController _phone;
  late final TextEditingController _advisor;
  late final TextEditingController _nptel;
  late final TextEditingController _extraCurricular;
  late final List<_CourseDraft> _courses;
  late final List<String> _clubs;
  String? _department;   // selected from kDepartments dropdown
  String? _year;         // selected from kAcademicYears dropdown
  String? _coreSlot;    // selected from kSlots dropdown (Morning/Evening/…)
  List<String> _courseCatalog = List<String>.from(kDefaultCourseNames);
  String? _photoUrl;
  Uint8List? _pickedBytes;
  String _pickedName = 'profile.jpg';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _photoUrl = widget.user.photoUrl;
    _phone = TextEditingController(text: widget.user.phoneNo);
    _advisor = TextEditingController(text: widget.user.academic.facultyAdvisor);
    _nptel = TextEditingController(text: widget.user.academic.nptel);
    _extraCurricular = TextEditingController(text: widget.user.academic.extraCurricular);
    _clubs = List<String>.from(widget.user.academic.clubs);
    // Department: validate against known list; fall back to null (shows hint)
    final rawBranch = widget.user.branch.trim();
    _department = kDepartments.contains(rawBranch) ? rawBranch : null;
    // Year: validate; accept '1'-'5' (support both '2nd Year' and '2')
    final rawYear = widget.user.year.trim();
    final yearDigit = RegExp(r'[1-5]').firstMatch(rawYear)?.group(0);
    _year = yearDigit ?? (kAcademicYears.contains(rawYear) ? rawYear : null);
    // Core Slot: validate against kSlots list
    final rawSlot = widget.user.academic.coreSlot.trim();
    _coreSlot = kSlots.contains(rawSlot) ? rawSlot : null;
    // Render every enrolled course, not a fixed 7. The editor previously
    // generated 7 rows and wrote all 7 back on save, so students with 8-12
    // courses silently lost the extras.
    final enrolled = widget.user.courses;
    _courses = enrolled
        .map(_CourseDraft.new)
        .toList(growable: true);
    while (_courses.length < kMaxCourses) {
      _courses.add(_CourseDraft(
        CourseItem(code: '', name: '', faculty: '', slot: ''),
      ));
    }

    FirestoreService().getCourseNames().then((names) {
      if (mounted) setState(() => _courseCatalog = names);
    });
  }

  @override
  void dispose() {
    _phone.dispose();
    _advisor.dispose();
    _nptel.dispose();
    _extraCurricular.dispose();
    for (final course in _courses) {
      course.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1440,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (!mounted) return;

    // Enforce the documented ceiling. `kMaxProfileImageBytes` was declared but
    // never checked, so oversized images were uploaded unchecked.
    if (bytes.lengthInBytes > kMaxProfileImageBytes) {
      showNxSnack(
        context,
        'That image is ${(bytes.lengthInBytes / (1024 * 1024)).toStringAsFixed(1)} MB. '
        'Maximum is ${(kMaxProfileImageBytes / (1024 * 1024)).round()} MB.',
      );
      return;
    }

    setState(() {
      _pickedBytes = bytes;
      _pickedName = image.name.isEmpty ? 'profile.jpg' : image.name;
    });
  }

  Future<void> _addClub() async {
    final controller = TextEditingController();
    // The controller is disposed inside the dialog's own lifecycle, after the
    // exit animation. Disposing it immediately after `showDialog` returns left
    // the TextField holding a disposed controller during that animation.
    final club = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add club'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Club name'),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
    final value = club?.trim();
    if (value != null && value.isNotEmpty && !_clubs.contains(value)) {
      setState(() => _clubs.add(value));
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final courses = _courses.map((draft) => draft.toCourse()).toList(growable: false);
    final facultyTokens = <String>{
      _advisor.text.trim().toLowerCase(),
      ...courses.map((course) => course.faculty.trim().toLowerCase()),
    }..removeWhere((value) => value.isEmpty);

    await _withBusy(() async {
      String? uploadedUrl = _photoUrl;

      if (_pickedBytes != null) {
        uploadedUrl = await DeviceStorageService.saveFile(
          bytes: Uint8List.fromList(_pickedBytes!),
          folder: 'profile_pics',
          fileName: '${widget.user.uid}.jpg',
        );
        if (uploadedUrl == null) {
          throw Exception('Failed to upload image. Please check network connection.');
        }
      }

      var updatedUser = widget.user.copyWith(
        phoneNo: _phone.text.trim(),
        branch: _department ?? widget.user.branch,
        year: _year ?? widget.user.year,
        photoUrl: uploadedUrl,
        academic: AcademicInfo(
          facultyAdvisor: _advisor.text.trim(),
          coreSlot: _coreSlot ?? widget.user.academic.coreSlot,
          nptel: _nptel.text.trim(),
          extraCurricular: _extraCurricular.text.trim(),
          clubs: List<String>.from(_clubs),
        ),
        courses: courses,
        searchIndices: SearchIndices(
          faculties: facultyTokens.toList()..sort(),
          regNoLower: widget.user.regNo.toLowerCase(),
          nameLower: widget.user.name.toLowerCase(),
        ),
      );

      // Explicitly update photoUrl as specified
      updatedUser = updatedUser.copyWith(photoUrl: uploadedUrl);

      final error = await FirestoreService().updateSelfProfile(updatedUser);
      if (error != null) {
        throw Exception(error);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved successfully.')),
      );
      Navigator.of(context).pop();
    }, errorMessage: 'Unable to save profile.');
  }

  Future<void> _withBusy(
    Future<void> Function() task, {
    required String errorMessage,
  }) async {
    setState(() => _busy = true);
    try {
      await task();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: NexoraTheme.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: NexoraTheme.border),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: NexoraTheme.error, size: 24),
            const SizedBox(width: 10),
            Text(
              'Delete Account?',
              style: GoogleFonts.syne(
                color: NexoraTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          'This will permanently delete your academic profile and credentials from Nexora. '
          'Your profile cannot be recovered. Are you sure you want to proceed?',
          style: GoogleFonts.inter(
            color: NexoraTheme.textSecondary,
            fontSize: 13.5,
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: NexoraTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: NexoraTheme.error,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(
              'Delete Account',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await _withBusy(() async {
      final uid = widget.user.uid;
      final firestoreErr = await FirestoreService().deleteUserAccount(uid);
      if (firestoreErr != null) {
        throw Exception(firestoreErr);
      }
      final authErr = await AuthService().deleteCurrentUser();
      if (authErr != null) {
        throw Exception(authErr);
      }
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }, errorMessage: 'Unable to complete account deletion.');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Edit profile'),
          actions: [
            TextButton(
              onPressed: _busy ? null : _save,
              child: const Text('Save Profile'),
            ),
          ],
        ),
        body: Stack(
          children: [
            Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _section(child: _photoHeader()),
                  _section(
                    title: 'Identity & Contact',
                    child: Column(children: [
                      _dropdown(
                        label: 'Department',
                        value: _department,
                        items: kDepartments,
                        icon: Icons.school_outlined,
                        displayBuilder: (b) => formatBranchName(b, full: true),
                        onChanged: (v) => setState(() => _department = v),
                      ),
                      _dropdown(
                        label: 'Year of Study',
                        value: _year,
                        items: kAcademicYears,
                        icon: Icons.calendar_today_outlined,
                        displayBuilder: (y) => 'Year $y',
                        onChanged: (v) => setState(() => _year = v),
                      ),
                      _dropdown(
                        label: 'Core Slot',
                        value: _coreSlot,
                        items: kSlots,
                        icon: Icons.wb_sunny_outlined,
                        onChanged: (v) => setState(() => _coreSlot = v),
                      ),
                      _field(_phone, 'Phone Number', keyboardType: TextInputType.phone),
                      _field(_advisor, 'Proctor / Faculty Advisor', hint: 'Dr. Suresh'),
                    ]),
                  ),
                  _section(
                    title: '7-course matrix',
                    child: Column(children: List.generate(7, _courseCard)),
                  ),
                  _section(
                    title: 'Co-curricular & clubs',
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _field(_nptel, 'NPTEL Course'),
                      _field(_extraCurricular, 'Extra Curricular'),
                      Text('Clubs', style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        ..._clubs.map((club) => InputChip(
                              label: Text(club),
                              onDeleted: () => setState(() => _clubs.remove(club)),
                            )),
                        ActionChip(
                          avatar: const Icon(Icons.add, size: 18),
                          label: const Text('Add Club'),
                          onPressed: _busy ? null : _addClub,
                        ),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: NexoraTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _busy ? null : _save,
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                      label: Text(
                        'Save Profile Changes',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _section(
                    title: 'Account & Security',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Permanent Account Deletion',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Deleting your account permanently erases your verified student profile, academic records, and sign-in credentials from Nexora. This action cannot be reversed.',
                          style: GoogleFonts.inter(
                            color: NexoraTheme.textSecondary,
                            fontSize: 12.5,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: NexoraTheme.error,
                            side: const BorderSide(color: NexoraTheme.error),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                          ),
                          onPressed: _busy ? null : _confirmDeleteAccount,
                          icon: const Icon(Icons.delete_forever_rounded, size: 18),
                          label: Text(
                            'Delete Account & Wipe Data',
                            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
            if (_busy)
              const ColoredBox(
                color: Color(0x990B0F14),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      );

  Widget _photoHeader() {
    ImageProvider<Object>? preview;
    if (_pickedBytes != null) {
      preview = MemoryImage(_pickedBytes!);
    } else if (_photoUrl != null && _photoUrl!.isNotEmpty) {
      preview = NetworkImage(_photoUrl!);
    } else {
      preview = null;
    }

    final roleColor = roleColorFor(
      role: widget.user.role,
      adminColorHex: widget.user.adminColorHex,
      approverColorHex: widget.user.approverColorHex,
    );

    final avatarWidget = CircleAvatar(
      radius: 46,
      backgroundColor: _inputSurface,
      backgroundImage: preview,
      child: preview == null
          ? (widget.user.name.isNotEmpty
              ? Text(
                  initialsOf(widget.user.name),
                  style: TextStyle(
                    color: roleColor,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : const Icon(
                  Icons.person_rounded,
                  size: 46,
                  color: NxColors.muted,
                ))
          : null,
    );

    final borderedAvatar = Container(
      padding: const EdgeInsets.all(3.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: roleColor,
          width: 3.5,
        ),
        boxShadow: [
          BoxShadow(
            color: roleColor.withValues(alpha: 0.35),
            blurRadius: 14,
            spreadRadius: 2,
          ),
        ],
      ),
      child: avatarWidget,
    );

    return Center(
      child: Column(children: [
        InkWell(
          onTap: _busy ? null : _pickPhoto,
          customBorder: const CircleBorder(),
          child: Stack(children: [
            borderedAvatar,
            Positioned(
              right: 2,
              bottom: 2,
              child: CircleAvatar(
                radius: 16,
                backgroundColor: roleColor,
                child: const Icon(
                  Icons.edit_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                widget.user.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (widget.user.isAdmin) ...[
              const SizedBox(width: 8),
              RoleBadge.fromUser(widget.user),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          widget.user.regNo,
          style: GoogleFonts.robotoMono(
            fontSize: 13,
            color: NxColors.brand,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        // Department, Year, Core Slot pills
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            if ((_department ?? widget.user.branch).isNotEmpty)
              _infoPill(Icons.school_outlined, _department ?? widget.user.branch),
            if ((_year ?? widget.user.year).isNotEmpty)
              _infoPill(Icons.calendar_today_outlined, 'Year ${_year ?? widget.user.year}'),
            if ((_coreSlot ?? widget.user.academic.coreSlot).isNotEmpty)
              _infoPill(Icons.wb_sunny_outlined, _coreSlot ?? widget.user.academic.coreSlot),
          ],
        ),
        const SizedBox(height: 6),
        TextButton.icon(
          onPressed: _busy ? null : _pickPhoto,
          icon: const Icon(Icons.photo_library_outlined, size: 18),
          label: const Text('Update profile photo'),
        ),
      ]),
    );
  }

  Widget _section({String? title, required Widget child}) => Card(
        color: NxColors.card,
        margin: const EdgeInsets.only(bottom: 14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (title != null) ...[
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 14),
            ],
            child,
          ]),
        ),
      );

  Widget _infoPill(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: NxColors.card,
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: NxColors.line),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: NxColors.muted),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.inter(
            color: NxColors.muted,
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );

  Widget _dropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    IconData? icon,
    String Function(String)? displayBuilder,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DropdownButtonFormField<String>(
          value: value,
          dropdownColor: _inputSurface,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          isExpanded: true,
          decoration: InputDecoration(
            labelText: label,
            prefixIcon: icon != null ? Icon(icon, size: 18, color: NxColors.muted) : null,
            filled: true,
            fillColor: _inputSurface,
            border: const OutlineInputBorder(),
          ),
          items: items
              .map((item) => DropdownMenuItem(
                    value: item,
                    child: Text(
                      displayBuilder != null ? displayBuilder(item) : item,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      );


  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    TextInputType? keyboardType,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            filled: true,
            fillColor: _inputSurface,
            border: const OutlineInputBorder(),
          ),
        ),
      );

  Widget _courseCard(int index) {
    final course = _courses[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _inputSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        title: Text(course.name.text.isNotEmpty ? course.name.text : 'Course ${index + 1}'),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DropdownButtonFormField<String>(
              value: _courseCatalog.contains(course.name.text) ? course.name.text : null,
              dropdownColor: _inputSurface,
              style: const TextStyle(color: Colors.white),
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Select Course from Catalog',
                filled: true,
                fillColor: _inputSurface,
                border: OutlineInputBorder(),
              ),
              items: _courseCatalog.map((name) => DropdownMenuItem(
                value: name,
                child: Text(name, overflow: TextOverflow.ellipsis),
              )).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    course.name.text = val;
                    final meta = kDefaultCourseMetadata[val];
                    if (meta != null) {
                      course.faculty.clear(); // Leave blank so faculty name appears as hint text
                      if (course.slot.text.trim().isEmpty) course.slot.text = meta['slot'] ?? '';
                      if (course.code.text.trim().isEmpty) course.code.text = meta['code'] ?? '';
                    }
                  });
                }
              },
            ),
          ),
          _field(course.name, 'Course Title', hint: 'e.g. Operating Systems Fundamentals'),
          _field(
            course.faculty,
            'Instructor / Faculty Name',
            hint: (kDefaultCourseMetadata[course.name.text.trim()]?['faculty']?.isNotEmpty ?? false)
                ? kDefaultCourseMetadata[course.name.text.trim()]!['faculty']!
                : 'e.g. Sivakumar',
          ),
          Row(
            children: [
              Expanded(child: _field(course.code, 'Code', hint: 'CSE3001')),
              const SizedBox(width: 10),
              Expanded(child: _field(course.slot, 'Slot', hint: 'E1+TE1')),
            ],
          ),
        ],
      ),
    );
  }
}

class _CourseDraft {
  _CourseDraft(CourseItem course)
      : code = TextEditingController(text: course.code),
        name = TextEditingController(text: course.name),
        faculty = TextEditingController(text: course.faculty),
        slot = TextEditingController(text: course.slot);

  final TextEditingController code;
  final TextEditingController name;
  final TextEditingController faculty;
  final TextEditingController slot;

  CourseItem toCourse() => CourseItem(
        code: code.text.trim(),
        name: name.text.trim(),
        faculty: faculty.text.trim().isNotEmpty
            ? faculty.text.trim()
            : (kDefaultCourseMetadata[name.text.trim()]?['faculty'] ?? ''),
        slot: slot.text.trim(),
      );

  void dispose() {
    code.dispose();
    name.dispose();
    faculty.dispose();
    slot.dispose();
  }
}
