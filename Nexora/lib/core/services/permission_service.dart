import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../theme.dart';

/// Centralized service for managing and requesting device permissions in Nexora.
class PermissionService {
  PermissionService._();
  static final PermissionService instance = PermissionService._();
  factory PermissionService() => instance;


  /// Request photo library / media images permission for attaching images to notes.
  /// Handles Android 13+ (READ_MEDIA_IMAGES) and Android <=12 (READ_EXTERNAL_STORAGE).
  Future<bool> requestPhotosPermission({BuildContext? context}) async {
    if (kIsWeb) return true;

    PermissionStatus status;
    // Android only (iOS removed)
    status = await Permission.photos.request();
    if (!status.isGranted && !status.isLimited) {
      final storageStatus = await Permission.storage.request();
      if (storageStatus.isGranted || storageStatus.isLimited) {
        return true;
      }
    }

    if (status.isGranted || status.isLimited) return true;

    if (context != null && context.mounted && status.isPermanentlyDenied) {
      _showSettingsDialog(
        context,
        title: 'Photo Library Access Required',
        message: 'Nexora needs photo library access to attach images to notes. Please enable it in Settings.',
      );
    }
    return false;
  }

  /// Request POST_NOTIFICATIONS permission on first app launch (Android 13+ & iOS).
  Future<bool> requestNotificationPermission() async {
    if (kIsWeb) return true;
    final status = await Permission.notification.request();
    return status.isGranted || status.isLimited;
  }

  /// Shows an OLED-styled modal dialog prompting the user to open device settings
  /// when a critical permission is permanently denied.
  void _showSettingsDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NexoraTheme.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: NexoraTheme.border),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: NexoraTheme.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(
            color: NexoraTheme.textSecondary,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: NexoraTheme.textSecondary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: NexoraTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              openAppSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }
}
