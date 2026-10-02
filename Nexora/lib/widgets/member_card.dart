import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme.dart';
import '../core/utils.dart';
import '../models/user_model.dart';

class MemberCard extends StatelessWidget {
  const MemberCard({
    super.key,
    required this.user,
    required this.isSelf,
    this.onTap,
    this.onSwipeToEdit,
    this.onSelfTap,
  });

  final UserModel user;
  final bool isSelf;
  final VoidCallback? onTap;
  final VoidCallback? onSwipeToEdit;
  final VoidCallback? onSelfTap;

  static const _radius = BorderRadius.all(Radius.circular(16));

  bool get _isAdmin => user.isAdmin;

  String get _slot => user.academic.coreSlot.trim();

  String get _formattedYear {
    final y = user.year.trim();
    if (y.isEmpty) return '';
    final n = int.tryParse(y);
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

  String get _meta => [user.branch.trim(), _formattedYear]
      .where((part) => part.isNotEmpty)
      .join('  •  ');

  Color get _roleColor => roleColorFor(
        role: user.role,
        adminColorHex: user.adminColorHex,
        approverColorHex: user.approverColorHex,
      );

  /// The color to use for ALL visual indicators on this card.
  ///
  /// Priority:
  ///   • Admin (self or peer) → their adminColorHex (custom signature color)
  ///   • Student self → verifiedBlue (Nexora brand identity color)
  ///   • Student peer → approverColorHex (the approving admin's color stamp)
  Color get _cardColor {
    if (_isAdmin) return _roleColor;
    return approverColorOf(user.approverColorHex);
  }

  @override
  Widget build(BuildContext context) {
    // Admins (self or peer): colored border with their signature color
    // Students self: verifiedBlue border
    // Students peer: approver colored border
    final Color borderColor = _cardColor.withValues(alpha: isSelf ? 0.90 : 0.45);
    final double borderWidth = isSelf ? 2.0 : 1.2;

    final effectiveTap = onTap ?? onSelfTap;
    final effectiveSwipe = onSwipeToEdit ?? (isSelf ? onSelfTap : null);

    final cardContent = Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: NexoraTheme.card,
        borderRadius: _radius,
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: [
          BoxShadow(
            color: _cardColor.withValues(alpha: isSelf ? 0.18 : 0.08),
            blurRadius: isSelf ? 16 : 10,
            spreadRadius: isSelf ? 1.0 : 0.0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: _radius,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: effectiveTap,
            customBorder: const RoundedRectangleBorder(borderRadius: _radius),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _avatar(),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                user.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.syne(
                                  color: NexoraTheme.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                  height: 1.3,
                                ),
                              ),
                            ),
                            if (_isAdmin) ...[
                              const SizedBox(width: 8),
                              _roleBadge(),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                user.regNo,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: NexoraTheme.primary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            if (_slot.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              _tag(
                                text: _slot,
                                color: _cardColor,
                                icon: Icons.wb_sunny_outlined,
                              ),
                            ],
                          ],
                        ),
                        if (_meta.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            _meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: NexoraTheme.textSecondary,
                              fontSize: 12,
                              height: 1.35,
                            ),
                          ),
                        ],
                        const SizedBox(height: 9),
                        Row(
                          children: [
                            _sealBadge(),
                            if (effectiveTap != null) ...[
                              const Spacer(),
                              _cardActionHint(),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // If self-card, enable horizontal swipe gesture to trigger edit profile without instruction text
    if (isSelf && effectiveSwipe != null) {
      double dragDistance = 0.0;
      return GestureDetector(
        onHorizontalDragStart: (_) => dragDistance = 0.0,
        onHorizontalDragUpdate: (details) => dragDistance += details.primaryDelta ?? 0,
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity.abs() > 80 || dragDistance.abs() > 40) {
            effectiveSwipe();
          }
        },
        child: cardContent,
      );
    }

    return cardContent;
  }

  Widget _avatar() {
    // Circle outline shows for all verified members in their admin color
    final photo = user.photoUrl ?? '';

    final circle = CircleAvatar(
      radius: 23,
      backgroundColor: NexoraTheme.input,
      backgroundImage: photo.isEmpty ? null : NetworkImage(photo),
      child: photo.isEmpty
          ? Text(
              initialsOf(user.name),
              style: GoogleFonts.syne(
                color: _cardColor,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            )
          : null,
    );

    final ringed = Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _cardColor, width: 2.5),
        boxShadow: [
          BoxShadow(
            color: _cardColor.withValues(alpha: isSelf ? 0.40 : 0.28),
            blurRadius: isSelf ? 10 : 7,
            spreadRadius: isSelf ? 1.5 : 0.5,
          ),
        ],
      ),
      child: circle,
    );

    return SizedBox(
      width: 58,
      height: 58,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ringed,
          Positioned(
            right: 0,
            bottom: 1,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: NexoraTheme.card,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.verified_rounded,
                size: 16,
                color: _cardColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sealBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: _cardColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _cardColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, size: 12, color: _cardColor),
          const SizedBox(width: 4),
          Text(
            'Verified Identity',
            style: GoogleFonts.inter(
              color: _cardColor,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _roleBadge() {
    // _cardColor = _roleColor for admins — uses adminColorHex directly
    final label = user.isSuperAdmin ? 'Super Admin' : 'Admin';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: _cardColor.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _tag({required String text, required Color color, IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: NexoraTheme.input,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: NexoraTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardActionHint() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: NexoraTheme.scaffold,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _cardColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.style_outlined, size: 12, color: _cardColor),
          const SizedBox(width: 4),
          Text(
            'Card',
            style: GoogleFonts.jetBrainsMono(
              color: NexoraTheme.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 2),
          Icon(Icons.chevron_right_rounded, size: 13, color: _cardColor),
        ],
      ),
    );
  }
}
