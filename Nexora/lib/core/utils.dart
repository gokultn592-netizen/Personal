import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'constants.dart';
import 'theme.dart';

const _months = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Returns [color] at [opacity] without relying on deprecated colour APIs.
Color alphaOf(Color color, double opacity) {
  final clamped = opacity.clamp(0.0, 1.0);
  return color.withValues(alpha: clamped);
}

Color colorFromHex(String? hex, [Color fallback = const Color(0xFF4F8BFF)]) {
  if (hex == null) return fallback;
  var value = hex.trim().replaceAll('#', '');
  if (value.isEmpty) return fallback;
  if (value.length == 6) value = 'FF$value';
  final parsed = int.tryParse(value, radix: 16);
  if (parsed == null) return fallback;
  return Color(parsed);
}

Color approverColorOf(String? hex) =>
    colorFromHex(hex, colorFromHex(kApproverPalette.first, const Color(0xFF4F8BFF)));

String defaultSignatureColorFor(String uid) {
  if (uid.isEmpty) return kApproverPalette.first;
  return kApproverPalette[uid.hashCode.abs() % kApproverPalette.length];
}

/// Resolves the specific badge and border ring color for admin / superadmin roles.
///
/// Priority: adminColorHex → approverColorHex → verifiedBlue fallback.
/// Students always get verifiedBlue — their approverColorHex is the color of
/// the admin who verified them, not their own badge color.
Color roleColorFor({
  required String role,
  String? adminColorHex,
  String? approverColorHex,
}) {
  if (adminColorHex != null && adminColorHex.isNotEmpty) {
    return colorFromHex(adminColorHex);
  }
  if (role == 'superadmin') {
    return (approverColorHex != null && approverColorHex.isNotEmpty)
        ? colorFromHex(approverColorHex)
        : const Color(0xFF9D4EDD);
  }
  if (role == 'admin') {
    return (approverColorHex != null && approverColorHex.isNotEmpty)
        ? colorFromHex(approverColorHex)
        : const Color(0xFF4F8BFF);
  }
  return approverColorOf(approverColorHex);
}


String initialsOf(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  final first = parts.first.substring(0, 1);
  final last = parts.last.substring(0, 1);
  return (first + last).toUpperCase();
}

String relativeTime(DateTime? time) {
  if (time == null) return 'sending';
  final diff = DateTime.now().toLocal().difference(time.toLocal());
  if (diff.inSeconds < 45) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return stampTime(time);
}

String stampTime(DateTime? time) {
  if (time == null) return 'pending sync';
  final local = time.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day ${_months[local.month - 1]} ${local.year}  $hour:$minute';
}

String authErrorMessage(Object error) {
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'invalid-email':
        return 'That email address does not look valid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email or password is incorrect.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Try again in a few minutes.';
      case 'network-request-failed':
        return 'Network unavailable. Check your connection.';
      case 'operation-not-allowed':
        return 'Email/Password sign-in is disabled in the Firebase console.';
      default:
        return error.message ?? 'Authentication failed (${error.code}).';
    }
  }
  if (error is FirebaseException) {
    return error.message ?? 'Request failed (${error.code}).';
  }
  final text = error.toString();
  return text.replaceFirst('Exception: ', '');
}

String firestoreErrorMessage(Object error) => authErrorMessage(error);

void showNxSnack(BuildContext context, String message, {bool error = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline : Icons.check_circle_outline,
              size: 18,
              color: error ? NxColors.danger : NxColors.success,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}

/// Whether a role carries moderation privileges.
///
/// The retired `'approver'` role is still accepted so legacy documents render
/// correctly, but nothing writes it any more — see `kRoleStudent` in
/// `core/constants.dart`.
bool isPrivilegedRole(String? role) =>
    role == kRoleAdmin || role == kRoleSuperAdmin || role == 'approver';

String roleLabel(String? role) {
  switch (role) {
    case kRoleSuperAdmin:
      return 'Super Admin';
    case kRoleAdmin:
      return 'Admin';
    case 'approver':
      return 'Approver';
    default:
      return 'Student';
  }
}

/// Returns a user-facing formatted title for an academic branch.
///
/// If [full] is true, returns the expanded degree title:
///   • `'Int MTech DS'`  → `'Integrated M.Tech • Data Science'`
///   • `'Int MTech CSE'` → `'Integrated M.Tech • Computer Science'`
///   • `'Int MTech SE'`  → `'Integrated M.Tech • Software Engineering'`
/// Otherwise returns the standard clean short code.
String formatBranchName(String branch, {bool full = false}) {
  final clean = branch.trim();
  if (!full) {
    if (clean.toLowerCase() == 'computer science and engineering') return 'CSE';
    return clean;
  }

  switch (clean) {
    case 'Computer Science and Engineering':
      return 'B.Tech • Computer Science & Eng.';
    case 'Int MTech DS':
      return 'Integrated M.Tech • Data Science';
    case 'Int MTech CSE':
      return 'Integrated M.Tech • Computer Science';
    case 'Int MTech SE':
      return 'Integrated M.Tech • Software Engineering';
    case 'B.Tech CSE':
      return 'B.Tech • Computer Science & Eng.';
    case 'B.Tech ECE':
      return 'B.Tech • Electronics & Communication';
    case 'B.Tech EEE':
      return 'B.Tech • Electrical & Electronics';
    case 'B.Tech ME':
      return 'B.Tech • Mechanical Engineering';
    case 'B.Tech Civil':
      return 'B.Tech • Civil Engineering';
    case 'M.Sc Data Science':
      return 'M.Sc • Data Science';
    default:
      return clean.isNotEmpty ? clean : 'Engineering & Technology';
  }
}

/// Infers the branch from a VIT / campus registration number (e.g. 25MID0051 → 'Int MTech DS').
String? inferBranchFromRegNo(String regNo) {
  final upper = regNo.trim().toUpperCase();
  if (upper.contains('MID')) return 'Int MTech DS';
  if (upper.contains('MIC') || upper.contains('MIE')) return 'Int MTech CSE';
  if (upper.contains('MIS')) return 'Int MTech SE';
  if (upper.contains('BCE')) return 'B.Tech CSE';
  if (upper.contains('BEC')) return 'B.Tech ECE';
  if (upper.contains('BEE')) return 'B.Tech EEE';
  if (upper.contains('BME')) return 'B.Tech ME';
  if (upper.contains('BCL')) return 'B.Tech Civil';
  if (upper.contains('MCA')) return 'MCA';
  return null;
}

