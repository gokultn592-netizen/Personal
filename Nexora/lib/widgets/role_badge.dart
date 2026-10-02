import 'package:flutter/material.dart';

import '../core/utils.dart';
import '../models/user_model.dart';

/// Renders a role pill badge (e.g., 'Super Admin' in purple background,
/// or 'Admin' in blue/custom admin color background with white text).
class RoleBadge extends StatelessWidget {
  const RoleBadge({
    super.key,
    required this.role,
    this.adminColorHex,
    this.approverColorHex,
    this.fontSize = 10,
    this.padding = const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
  });

  factory RoleBadge.fromUser(
    UserModel user, {
    double fontSize = 10,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
  }) {
    return RoleBadge(
      role: user.role,
      adminColorHex: user.adminColorHex,
      approverColorHex: user.approverColorHex,
      fontSize: fontSize,
      padding: padding,
    );
  }

  final String role;
  final String? adminColorHex;
  final String? approverColorHex;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    if (role != 'admin' && role != 'superadmin') {
      return const SizedBox.shrink();
    }

    final color = roleColorFor(
      role: role,
      adminColorHex: adminColorHex,
      approverColorHex: approverColorHex,
    );
    final label = role == 'superadmin' ? 'Super Admin' : 'Admin';

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 6,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
