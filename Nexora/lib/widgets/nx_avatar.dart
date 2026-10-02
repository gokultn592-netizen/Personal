import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/utils.dart';
import '../models/user_model.dart';

class NxAvatar extends StatelessWidget {
  const NxAvatar({
    super.key,
    required this.name,
    this.url,
    this.radius = 22,
    this.ringColor,
    this.ringWidth = 3.0,
    this.hasGlow = false,
  });

  factory NxAvatar.fromUser(
    UserModel user, {
    double radius = 22,
    double ringWidth = 3.0,
    bool forceRing = false,
  }) {
    final ring = (user.isAdmin || forceRing)
        ? roleColorFor(
            role: user.role,
            adminColorHex: user.adminColorHex,
            approverColorHex: user.approverColorHex,
          )
        : null;

    return NxAvatar(
      name: user.name,
      url: user.photoUrl,
      radius: radius,
      ringColor: ring,
      ringWidth: ringWidth,
      hasGlow: user.isAdmin,
    );
  }

  final String name;
  final String? url;
  final double radius;
  final Color? ringColor;
  final double ringWidth;
  final bool hasGlow;

  @override
  Widget build(BuildContext context) {
    final avatar = CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF1E2A3D),
      backgroundImage: (url == null || url!.isEmpty) ? null : NetworkImage(url!),
      child: (url == null || url!.isEmpty)
          ? Text(
              initialsOf(name),
              style: TextStyle(
                color: ringColor ?? NxColors.brand,
                fontSize: radius * 0.72,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
            )
          : null,
    );

    if (ringColor == null) return avatar;

    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ringColor!, width: ringWidth),
        boxShadow: hasGlow
            ? [
                BoxShadow(
                  color: ringColor!.withValues(alpha: 0.4),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: avatar,
    );
  }
}
