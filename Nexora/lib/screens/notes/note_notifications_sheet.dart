import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:nexora/core/theme.dart';
import 'package:nexora/core/utils.dart';
import 'package:nexora/models/note_model.dart';
import 'package:nexora/models/notification_model.dart';
import 'package:nexora/services/notification_service.dart';
import 'package:nexora/widgets/role_badge.dart';

/// Modal sheet displaying broadcast notifications for note creations and updates.
class NoteNotificationsSheet extends StatelessWidget {
  const NoteNotificationsSheet({super.key});

  static Future<void> show(BuildContext context) {
    NotificationService().markAllAsRead();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const NoteNotificationsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: NexoraTheme.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: NexoraTheme.border, width: 1.2),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          // Grab Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: NexoraTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: NexoraTheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: NexoraTheme.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Icon(
                    Icons.notifications_active_outlined,
                    color: NexoraTheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Note Broadcasts',
                        style: TextStyle(
                          color: NexoraTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Real-time alerts broadcasted to all students',
                        style: TextStyle(
                          color: NexoraTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Admin-only: firestore.rules restricts broadcast deletion to admins, so
                // offering this to every user produced a guaranteed failure.
                if (NotificationService().canModerateNotifications())
                  IconButton(
                    tooltip: 'Clear All Broadcasts',
                    icon: const Icon(Icons.delete_sweep_rounded,
                        color: NexoraTheme.error, size: 20),
                    onPressed: () => _confirmClearAllBroadcasts(context),
                  ),
                IconButton(
                  icon: const Icon(Icons.close, color: NexoraTheme.textSecondary, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: NexoraTheme.border),

          // Notification List
          Flexible(
            child: StreamBuilder<List<NoteNotificationModel>>(
              stream: NotificationService().streamNotifications(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(color: NexoraTheme.primary),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Error loading updates: ${snapshot.error}',
                        style: const TextStyle(color: NexoraTheme.error, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final notifications = snapshot.data ?? [];
                if (notifications.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.notifications_none_rounded,
                            size: 48,
                            color: NexoraTheme.textSecondary.withValues(alpha: 0.35),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No broadcasts yet',
                            style: TextStyle(
                              color: NexoraTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Whenever anyone updates or posts notes, notifications will appear here for all members in real-time.',
                            style: TextStyle(
                              color: NexoraTheme.textSecondary,
                              fontSize: 13,
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  itemCount: notifications.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final notif = notifications[index];
                    final isUpdate = notif.isUpdate;
                    final accentColor = isUpdate ? const Color(0xFF9D4EDD) : NexoraTheme.primary;

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _viewNoteDetails(context, notif),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: NexoraTheme.scaffold,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: accentColor.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  isUpdate ? Icons.edit_note_rounded : Icons.post_add_rounded,
                                  color: accentColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: accentColor.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(4),
                                            border: Border.all(
                                              color: accentColor.withValues(alpha: 0.4),
                                            ),
                                          ),
                                          child: Text(
                                            isUpdate ? 'UPDATED NOTE' : 'NEW NOTE',
                                            style: TextStyle(
                                              color: accentColor,
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          relativeTime(notif.timestamp),
                                          style: NexoraTheme.monoStyle(
                                            color: NexoraTheme.textSecondary,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      notif.noteTitle,
                                      style: const TextStyle(
                                        color: NexoraTheme.textPrimary,
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Text(
                                          'by ',
                                          style: TextStyle(
                                            color: NexoraTheme.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          notif.authorName,
                                          style: const TextStyle(
                                            color: NexoraTheme.textPrimary,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (notif.authorRegNo.isNotEmpty) ...[
                                          const SizedBox(width: 6),
                                          Text(
                                            '(${notif.authorRegNo})',
                                            style: NexoraTheme.monoStyle(
                                              color: NexoraTheme.primary,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: NexoraTheme.textSecondary,
                                  size: 18,
                                ),
                                tooltip: 'Delete broadcast',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _confirmDeleteBroadcast(context, notif),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: NexoraTheme.textSecondary,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _viewNoteDetails(BuildContext context, NoteNotificationModel notif) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: NexoraTheme.primary),
      ),
    );

    final doc = await NotificationService().fetchNote(notif.noteId);
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    if (doc == null || !doc.exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF1E2633),
          content: Text(
            'This note is no longer available in the academic feed.',
            style: TextStyle(color: NexoraTheme.textSecondary),
          ),
        ),
      );
      return;
    }

    final note = NoteModel.fromFirestore(doc);
    if (!context.mounted) return;
    _showNoteDetailSheet(context, note);
  }

  static void _showNoteDetailSheet(BuildContext context, NoteModel note) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF12171F),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: Color(0xFF1E2633), width: 1.2)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C3A4B),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: NexoraTheme.primary.withValues(alpha: 0.15),
                    backgroundImage: (note.authorPhotoUrl != null && note.authorPhotoUrl!.isNotEmpty)
                        ? CachedNetworkImageProvider(note.authorPhotoUrl!)
                        : null,
                    child: (note.authorPhotoUrl == null || note.authorPhotoUrl!.isEmpty)
                        ? Text(
                            note.authorName.isNotEmpty ? note.authorName[0].toUpperCase() : '?',
                            style: const TextStyle(color: NexoraTheme.primary, fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                note.authorName,
                                style: const TextStyle(
                                  color: NexoraTheme.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14.5,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (note.isAuthorAdmin) ...[
                              const SizedBox(width: 6),
                              RoleBadge(
                                role: note.authorRole!,
                                adminColorHex: note.authorAdminColorHex,
                                fontSize: 9.5,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${note.authorRegNo} • ${relativeTime(note.timestamp)}',
                          style: const TextStyle(color: NexoraTheme.textSecondary, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: NexoraTheme.textSecondary, size: 20),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              if (note.title != null && note.title!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  note.title!,
                  style: const TextStyle(
                    color: NexoraTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SelectableText(
                note.content,
                style: const TextStyle(
                  color: NexoraTheme.textPrimary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              if (note.imageUrl != null && note.imageUrl!.isNotEmpty) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: note.imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      height: 180,
                      color: NexoraTheme.scaffold,
                      child: const Center(
                        child: CircularProgressIndicator(color: NexoraTheme.primary),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      height: 140,
                      color: NexoraTheme.scaffold,
                      child: const Center(
                        child: Icon(Icons.broken_image_outlined, color: NexoraTheme.textSecondary),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1E2633),
                    foregroundColor: NexoraTheme.textPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _confirmDeleteBroadcast(BuildContext context, NoteNotificationModel notif) async {
    // Guard the action itself, not just the button that opens it.
    if (!NotificationService().canModerateNotifications()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only admins can remove broadcasts.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NexoraTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: NexoraTheme.error, size: 24),
            SizedBox(width: 10),
            Text('Delete Broadcast?', style: TextStyle(color: NexoraTheme.textPrimary, fontSize: 17)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this broadcast for "${notif.noteTitle}"? It will be removed from the alerts feed.',
          style: const TextStyle(color: NexoraTheme.textSecondary, fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: NexoraTheme.textSecondary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: NexoraTheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await NotificationService().deleteNotification(notif.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: NexoraTheme.success,
              content: Text('Broadcast notification removed.'),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: NexoraTheme.error,
              content: Text('Failed to delete broadcast: $e'),
            ),
          );
        }
      }
    }
  }

  static Future<void> _confirmClearAllBroadcasts(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NexoraTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_sweep_rounded, color: NexoraTheme.error, size: 24),
            SizedBox(width: 10),
            Text('Clear All Broadcasts?', style: TextStyle(color: NexoraTheme.textPrimary, fontSize: 17)),
          ],
        ),
        content: const Text(
          'Are you sure you want to clear all note broadcast alerts? This will erase all broadcast history for everyone.',
          style: TextStyle(color: NexoraTheme.textSecondary, fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: NexoraTheme.textSecondary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: NexoraTheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await NotificationService().clearAllNotifications();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: NexoraTheme.success,
              content: Text('All broadcast notifications cleared.'),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: NexoraTheme.error,
              content: Text('Failed to clear broadcasts: $e'),
            ),
          );
        }
      }
    }
  }
}
