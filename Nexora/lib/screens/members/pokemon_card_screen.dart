import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../models/user_model.dart';
import '../../widgets/nexora_logo.dart';
import '../../widgets/nx_avatar.dart';

/// Full-screen collectible Pokemon-style trading card viewer.
///
/// Features:
///   • 3D perspective flip around Y-axis (Matrix4 transform) between Front and Back faces
///   • Authentic TCG collectible card aesthetics (holographic/metallic bezel, energy badges, portrait window)
///   • Front Face: Member title, card rank, glowing portrait, registration serial, slot ability, approver seal
///   • Back Face: Official Nexora card back pattern with academic dossier (proctor, enrolled courses, clubs)
///   • Self-user horizontal swipe to edit profile without any instructional text clutter
///   • Read-only security enforcement for administrative inspection
class PokemonCardScreen extends StatefulWidget {
  const PokemonCardScreen({
    super.key,
    required this.user,
    required this.isSelf,
    this.isViewerAdmin = false,
    this.onEditProfile,
  });

  final UserModel user;
  final bool isSelf;
  final bool isViewerAdmin;
  final VoidCallback? onEditProfile;

  @override
  State<PokemonCardScreen> createState() => _PokemonCardScreenState();
}

class _PokemonCardScreenState extends State<PokemonCardScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flipController;
  late final Animation<double> _flipAnimation;
  bool _isBack = false;

  UserModel get user => widget.user;
  bool get isSelf => widget.isSelf;
  bool get isAdmin => widget.user.isAdmin;
  bool get canSeeBio => isSelf || widget.isViewerAdmin;

  Color get _cardColor => roleColorFor(
        role: user.role,
        adminColorHex: user.adminColorHex,
        approverColorHex: user.approverColorHex,
      );

  String get _slot => user.academic.coreSlot.trim();

  String get _formattedYear {
    final y = user.year.trim();
    if (y.isEmpty) return '';
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

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _flipAnimation = CurvedAnimation(
      parent: _flipController,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _flipCard() {
    if (_flipController.isAnimating) return;
    if (_isBack) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    setState(() => _isBack = !_isBack);
  }

  void _handleSwipe() {
    if (widget.isSelf && widget.onEditProfile != null) {
      widget.onEditProfile!();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    // Subtract AppBar height (~56), top/bottom safe-area and vertical scroll padding (24)
    final availableHeight = screenSize.height - topPadding - bottomPadding - 56 - 24;
    final cardWidth = math.min(screenSize.width - 40, 326.0);
    final cardHeight = math.min(availableHeight * 0.90, 520.0);

    return Scaffold(
      backgroundColor: NexoraTheme.scaffold,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: NexoraTheme.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: NexoraTheme.border),
            ),
            child: const Icon(Icons.arrow_back_rounded, size: 16, color: Colors.white),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Member Card',
          style: GoogleFonts.syne(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: NexoraTheme.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: _isBack ? 'View Front' : 'Flip Card',
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _cardColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _cardColor.withValues(alpha: 0.4)),
              ),
              child: Icon(Icons.flip_rounded, size: 18, color: _cardColor),
            ),
            onPressed: _flipCard,
          ),
          if (widget.isSelf && widget.onEditProfile != null) ...[
            IconButton(
              tooltip: 'Edit Profile',
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: NexoraTheme.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: NexoraTheme.border),
                ),
                child: const Icon(Icons.edit_outlined, size: 18, color: Colors.white70),
              ),
              onPressed: widget.onEditProfile,
            ),
          ],
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 3D Flippable Pokemon Collectible Card
              GestureDetector(
                onTap: _flipCard,
                onHorizontalDragEnd: (details) {
                  final velocity = details.primaryVelocity ?? 0;
                  if (velocity.abs() > 120 && widget.isSelf) {
                    _handleSwipe();
                  }
                },
                child: AnimatedBuilder(
                  animation: _flipAnimation,
                  builder: (context, _) {
                    final angle = _flipAnimation.value * math.pi;
                    final showBackFace = angle > (math.pi / 2);

                    final transform = Matrix4.identity()
                      ..setEntry(3, 2, 0.0012)
                      ..rotateY(angle);

                    Widget cardWidget;
                    if (showBackFace) {
                      // Mirror horizontally so back face text renders upright
                      transform.scale(-1.0, 1.0, 1.0);
                      cardWidget = _buildBackFace(cardWidth, cardHeight);
                    } else {
                      cardWidget = _buildFrontFace(cardWidth, cardHeight);
                    }

                    return Transform(
                      transform: transform,
                      alignment: Alignment.center,
                      child: Container(
                        width: cardWidth,
                        height: cardHeight,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: _cardColor.withValues(alpha: 0.32),
                              blurRadius: 28,
                              spreadRadius: 2,
                              offset: const Offset(0, 8),
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.65),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: cardWidget,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  /// Front face of the collectible Pokemon card.
  Widget _buildFrontFace(double width, double height) {
    return Container(
      decoration: BoxDecoration(
        color: NexoraTheme.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _cardColor.withValues(alpha: 0.85), width: 2.2),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            NexoraTheme.cardRaised,
            NexoraTheme.card,
            NexoraTheme.card.withValues(alpha: 0.95),
            _cardColor.withValues(alpha: 0.08),
          ],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Holographic diagonal foil shimmer line
            Positioned(
              top: -60,
              right: -60,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _cardColor.withValues(alpha: 0.25),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Card Banner: Stage / Level & Slot Energy
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _cardColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: _cardColor.withValues(alpha: 0.45)),
                          ),
                          child: Text(
                            isAdmin
                                ? (user.isSuperAdmin ? 'SUPER ADMIN' : 'ADMIN')
                                : ([
                                    if (_formattedYear.isNotEmpty) _formattedYear.toUpperCase(),
                                    if (user.branch.isNotEmpty) formatBranchName(user.branch).toUpperCase(),
                                  ].join(' • ').isNotEmpty
                                    ? [
                                        if (_formattedYear.isNotEmpty) _formattedYear.toUpperCase(),
                                        if (user.branch.isNotEmpty) formatBranchName(user.branch).toUpperCase(),
                                      ].join(' • ')
                                    : 'VERIFIED STUDENT'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: _cardColor,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                      if (_slot.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: NexoraTheme.input,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: _cardColor.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.wb_sunny_rounded, size: 10.5, color: _cardColor),
                              const SizedBox(width: 4),
                              Text(
                                _slot,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Name only (no role badge pill)
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      user.name,
                      maxLines: 1,
                      style: GoogleFonts.syne(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Holographic Inset Portrait Window
                  Expanded(
                    flex: 12,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF090C14),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _cardColor.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _cardColor.withValues(alpha: 0.15),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Radial gradient halo behind portrait
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  _cardColor.withValues(alpha: 0.35),
                                  Colors.transparent,
                                ],
                                radius: 0.7,
                              ),
                            ),
                          ),
                          // Avatar portrait with colored ring
                          NxAvatar.fromUser(
                            user,
                            radius: 44,
                            ringWidth: 3.5,
                            forceRing: true,
                          ),
                          // Inset verified icon stamp
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: NexoraTheme.card.withValues(alpha: 0.85),
                                shape: BoxShape.circle,
                                border: Border.all(color: _cardColor.withValues(alpha: 0.4)),
                              ),
                              child: Icon(Icons.verified_rounded, size: 12, color: _cardColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Move / Ability 1: Registration ID & Branch
                  _cardAbilityTile(
                    icon: Icons.fingerprint_rounded,
                    title: 'REGISTRATION SERIAL',
                    value: user.regNo,
                    subtitle: formatBranchName(user.branch, full: true),
                  ),
                  const SizedBox(height: 6),

                  // Move / Ability 2: Proctor Name
                  _cardAbilityTile(
                    icon: Icons.person_pin_rounded,
                    title: 'PROCTOR NAME',
                    value: user.academic.proctorName.isNotEmpty
                        ? user.academic.proctorName
                        : 'Not Assigned',
                  ),
                  const Spacer(),

                  // Card Footer: Member serial ID
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: NexoraTheme.input.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: NexoraTheme.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.badge_rounded, size: 12, color: _cardColor),
                            const SizedBox(width: 5),
                            Text(
                              'NEXORA MEMBER',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: _cardColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '#${user.regNo.isNotEmpty ? user.regNo : user.uid.substring(0, math.min(6, user.uid.length)).toUpperCase()}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: NexoraTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Back face of the collectible Pokemon card (Academic Dossier).
  Widget _buildBackFace(double width, double height) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0C101A),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _cardColor.withValues(alpha: 0.85), width: 2.2),
        gradient: LinearGradient(
          begin: Alignment.bottomRight,
          end: Alignment.topLeft,
          colors: [
            const Color(0xFF090D17),
            NexoraTheme.cardRaised,
            const Color(0xFF111726),
            _cardColor.withValues(alpha: 0.08),
          ],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Center watermark emblem
            Center(
              child: Opacity(
                opacity: 0.05,
                child: NexoraLogo(size: width * 0.55, showWordmark: false),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Back Header
                  Row(
                    children: [
                      Icon(Icons.lock_person_outlined, size: 13, color: _cardColor),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          'ACADEMIC DOSSIER',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: _cardColor,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      Text(
                        '#2026',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: NexoraTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: NexoraTheme.border, height: 16),

                  // Dossier Content
                  Expanded(
                    child: canSeeBio
                        ? _buildAuthorizedBio()
                        : _buildRestrictedBio(),
                  ),

                  const SizedBox(height: 8),
                  // Footer Security Signature
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: NexoraTheme.input.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: NexoraTheme.border),
                    ),
                    child: Row(
                      children: [
                        const NexoraLogo(size: 14, showWordmark: false),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'NEXORA IDENTITY',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                        Text(
                          canSeeBio ? 'VERIFIED' : 'PROTECTED',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: canSeeBio ? NexoraTheme.success : NexoraTheme.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Authorized view for self and admins.
  Widget _buildAuthorizedBio() {
    final courses = user.courses.where((c) => c.name.trim().isNotEmpty || c.code.trim().isNotEmpty || c.slot.trim().isNotEmpty || c.faculty.trim().isNotEmpty).toList();
    final clubs = user.academic.clubs;
    final nptel = user.academic.nptel.trim();
    final extra = user.academic.extraCurricular.trim();

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        // Enrolled Courses
        _bioSectionTitle('ENROLLED COURSES (${courses.length})'),
        const SizedBox(height: 4),
        if (courses.isEmpty)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: NexoraTheme.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: NexoraTheme.border),
            ),
            child: Text(
              'No courses registered for this semester',
              style: GoogleFonts.inter(fontSize: 11.5, color: NexoraTheme.textMuted),
            ),
          )
        else
          ...courses.map(
            (c) => Container(
              margin: const EdgeInsets.only(bottom: 5),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6.5),
              decoration: BoxDecoration(
                color: NexoraTheme.card,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: NexoraTheme.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.name.isNotEmpty ? c.name : 'Course',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: NexoraTheme.textPrimary,
                          ),
                        ),
                        if (c.faculty.isNotEmpty)
                          Text(
                            c.faculty,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 9.5,
                              color: NexoraTheme.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (c.slot.isNotEmpty)
                    Text(
                      c.slot,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: NexoraTheme.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ),

        // NPTEL
        if (nptel.isNotEmpty) ...[
          const SizedBox(height: 8),
          _bioSectionTitle('NPTEL'),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: NexoraTheme.card,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: NexoraTheme.border),
            ),
            child: Text(
              nptel,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: NexoraTheme.textPrimary,
              ),
            ),
          ),
        ],

        // Extracurricular
        if (extra.isNotEmpty) ...[
          const SizedBox(height: 8),
          _bioSectionTitle('EXTRACURRICULAR'),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: NexoraTheme.card,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: NexoraTheme.border),
            ),
            child: Text(
              extra,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: NexoraTheme.textPrimary,
              ),
            ),
          ),
        ],

        // Clubs & Chapters
        if (clubs.isNotEmpty) ...[
          const SizedBox(height: 8),
          _bioSectionTitle('CLUBS & CHAPTERS'),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 5,
            children: clubs
                .map(
                  (club) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: NexoraTheme.input,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: NexoraTheme.border),
                    ),
                    child: Text(
                      club,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: NexoraTheme.textSecondary,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  /// Restricted view for peer students.
  Widget _buildRestrictedBio() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _cardColor.withValues(alpha: 0.12),
                border: Border.all(color: _cardColor.withValues(alpha: 0.35)),
              ),
              child: Icon(Icons.verified_user_rounded, size: 36, color: _cardColor),
            ),
            const SizedBox(height: 14),
            Text(
              'Verified Student Dossier',
              style: GoogleFonts.syne(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Full course registration and academic parameters are restricted to administrative audit. Identity authenticated by campus administrators.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: NexoraTheme.textSecondary,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bioSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.jetBrainsMono(
        fontSize: 9.5,
        fontWeight: FontWeight.w700,
        color: NexoraTheme.textMuted,
        letterSpacing: 0.6,
      ),
    );
  }

  Widget _cardAbilityTile({
    required IconData icon,
    required String title,
    required String value,
    String subtitle = '',
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: NexoraTheme.input.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: NexoraTheme.border.withValues(alpha: 0.8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: _cardColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 14, color: _cardColor),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          color: NexoraTheme.textMuted,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      color: NexoraTheme.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
