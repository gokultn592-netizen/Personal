import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme.dart';
import '../core/utils.dart';
import '../models/user_model.dart';
import 'nx_avatar.dart';
import 'role_badge.dart';

/// Shows an administrative, read-only inspection modal of a student's verified academic biodata.
///
/// Administrators have audit visibility into all academic parameters (department, year,
/// core slot, proctor, enrolled courses, NPTEL, clubs) but **strictly cannot modify**
/// any of the student's personal or academic records.
Future<void> showMemberBiodataSheet(BuildContext context, UserModel user) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: NexoraTheme.card,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) => _MemberBiodataSheet(user: user),
  );
}

class _MemberBiodataSheet extends StatelessWidget {
  const _MemberBiodataSheet({required this.user});

  final UserModel user;

  String get _formattedYear {
    final y = user.year.trim();
    if (y.isEmpty) return '—';
    final n = int.tryParse(RegExp(r'[1-5]').firstMatch(y)?.group(0) ?? '');
    if (n != null) {
      if (n == 1) return '1st Year';
      if (n == 2) return '2nd Year';
      if (n == 3) return '3rd Year';
      return '${n}th Year';
    }
    if (!y.toLowerCase().contains('year')) {
      return '$y Year';
    }
    return y;
  }

  Color get _accentColor => roleColorFor(
        role: user.role,
        adminColorHex: user.adminColorHex,
        approverColorHex: user.approverColorHex,
      );

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.45,
      builder: (_, scrollCtrl) => ListView(
        controller: scrollCtrl,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4.5,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: NexoraTheme.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),

          // Header profile summary
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              NxAvatar.fromUser(user, radius: 28, ringWidth: 3, forceRing: true),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: GoogleFonts.syne(
                        color: NexoraTheme.textPrimary,
                        fontSize: 17.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          user.regNo.isNotEmpty ? user.regNo : '—',
                          style: GoogleFonts.jetBrainsMono(
                            color: NexoraTheme.primary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        if (user.isAdmin) ...[
                          const SizedBox(width: 8),
                          RoleBadge.fromUser(user),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Admin Read-Only Security Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: NexoraTheme.scaffold,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: NexoraTheme.border),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.lock_outline_rounded,
                  size: 15,
                  color: NexoraTheme.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Administrative View • Student records are read-only and cannot be altered.',
                    style: GoogleFonts.inter(
                      color: NexoraTheme.textSecondary,
                      fontSize: 11.5,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Academic Info Section
          _sectionHeader('Academic Biodata'),
          _bioRow(
            Icons.school_outlined,
            'Department',
            user.branch.isNotEmpty ? formatBranchName(user.branch, full: true) : '—',
          ),
          _bioRow(
            Icons.calendar_today_outlined,
            'Year',
            _formattedYear,
          ),
          _bioRow(
            Icons.wb_sunny_outlined,
            'Core Slot',
            user.academic.coreSlot.isNotEmpty ? user.academic.coreSlot : '—',
            badgeColor: user.academic.coreSlot.isNotEmpty ? _accentColor : null,
          ),
          _bioRow(
            Icons.person_outline_rounded,
            'Proctor',
            user.academic.proctorName.isNotEmpty
                ? user.academic.proctorName
                : (user.academic.facultyAdvisor.isNotEmpty ? user.academic.facultyAdvisor : '—'),
          ),
          _bioRow(Icons.email_outlined, 'Email', user.email.isNotEmpty ? user.email : '—'),
          _bioRow(Icons.phone_outlined, 'Phone', user.phoneNo.isNotEmpty ? user.phoneNo : '—'),

          const SizedBox(height: 18),

          // NPTEL & Extracurricular Section
          _sectionHeader('NPTEL & Extracurricular'),
          _bioRow(
            Icons.ondemand_video_outlined,
            'NPTEL Course',
            user.academic.nptel.isNotEmpty ? user.academic.nptel : 'None recorded',
          ),
          _bioRow(
            Icons.emoji_events_outlined,
            'Activities',
            user.academic.extraCurricular.isNotEmpty
                ? user.academic.extraCurricular
                : 'None recorded',
          ),

          const SizedBox(height: 18),

          // Clubs Section
          _sectionHeader('Student Clubs & Chapters'),
          if (user.academic.clubs.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: user.academic.clubs.map((club) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                    decoration: BoxDecoration(
                      color: NexoraTheme.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: NexoraTheme.primary.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      club,
                      style: GoogleFonts.inter(
                        color: NexoraTheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'No clubs joined',
                style: GoogleFonts.inter(
                  color: NexoraTheme.textSecondary,
                  fontSize: 12.5,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),

          const SizedBox(height: 18),

          // Enrolled Courses Section
          _sectionHeader('Registered Courses (${user.courses.where((c) => c.name.isNotEmpty).length})'),
          if (user.courses.where((c) => c.name.isNotEmpty).isNotEmpty)
            ...user.courses.where((c) => c.name.isNotEmpty).map((course) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: NexoraTheme.scaffold,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: NexoraTheme.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            course.name,
                            style: GoogleFonts.inter(
                              color: NexoraTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (course.faculty.isNotEmpty || course.slot.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              [
                                if (course.faculty.isNotEmpty) course.faculty,
                                if (course.slot.isNotEmpty) '${course.slot} Slot',
                              ].join('  •  '),
                              style: GoogleFonts.inter(
                                color: NexoraTheme.textSecondary,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (course.code.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: NexoraTheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          course.code,
                          style: GoogleFonts.jetBrainsMono(
                            color: NexoraTheme.primary,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            })
          else
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'No courses enrolled',
                style: GoogleFonts.inter(
                  color: NexoraTheme.textSecondary,
                  fontSize: 12.5,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: GoogleFonts.jetBrainsMono(
              color: NexoraTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(child: Divider(color: NexoraTheme.border, height: 1)),
        ],
      ),
    );
  }

  Widget _bioRow(IconData icon, String label, String value, {Color? badgeColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: NexoraTheme.textSecondary),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: NexoraTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: badgeColor != null
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: badgeColor.withValues(alpha: 0.35)),
                      ),
                      child: Text(
                        value,
                        style: GoogleFonts.jetBrainsMono(
                          color: badgeColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  )
                : Text(
                    value,
                    style: GoogleFonts.inter(
                      color: NexoraTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
