import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:nexora/core/theme.dart';
import 'package:nexora/core/utils.dart';
import 'package:nexora/models/note_deletion_log_model.dart';
import 'package:nexora/models/user_model.dart';
import 'package:nexora/services/note_service.dart';
import 'package:nexora/widgets/nexora_logo.dart';
import 'package:nexora/widgets/role_badge.dart';

/// Secure audit log screen displaying all deleted academic notes.
///
/// Restricted exclusively to admins and superadmins.
class NoteDeletionLogsScreen extends StatelessWidget {
  final UserModel currentAdmin;

  const NoteDeletionLogsScreen({super.key, required this.currentAdmin});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<NoteDeletionLogModel>>(
      stream: NoteService.streamDeletionLogs(),
      builder: (context, snapshot) {
        final logs = snapshot.data ?? [];
        return Scaffold(
          backgroundColor: NexoraTheme.scaffold,
          appBar: AppBar(
            title: const Row(
              children: [
                NexoraLogo(size: 22, showWordmark: false),
                SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Note Deletion Logs',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Audit Trail • Admin Exclusive',
                      style: TextStyle(fontSize: 10.5, color: NexoraTheme.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              if (logs.isNotEmpty)
                IconButton(
                  tooltip: 'Clear All Deletion Logs',
                  icon: const Icon(Icons.delete_sweep_rounded, color: NexoraTheme.error, size: 22),
                  onPressed: () => _confirmClearAllLogs(context),
                ),
              const SizedBox(width: 8),
            ],
          ),
          bottomNavigationBar: logs.isEmpty
              ? null
              : SafeArea(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                    decoration: BoxDecoration(
                      color: NexoraTheme.card,
                      border: const Border(
                        top: BorderSide(color: NexoraTheme.border, width: 1),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, -3),
                        ),
                      ],
                    ),
                    child: SizedBox(
                      height: 48,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: NexoraTheme.error,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        icon: const Icon(Icons.delete_forever_rounded, size: 20),
                        label: Text(
                          'Erase All Deletion Logs (${logs.length})',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () => _confirmClearAllLogs(context),
                      ),
                    ),
                  ),
                ),
          body: Builder(
            builder: (_) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: NexoraTheme.primary));
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Error loading deletion logs: ${snapshot.error}',
                      style: const TextStyle(color: NexoraTheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              if (logs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.history_edu_rounded,
                          size: 56,
                          color: NexoraTheme.textSecondary.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'No deletion logs recorded',
                          style: TextStyle(
                            color: NexoraTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'When authors or admins remove notes from the public feed, full immutable audit copies appear here.',
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                itemCount: logs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final log = logs[index];
              final deletedDate = DateFormat('MMM d, yyyy • h:mm a').format(log.deletedAt);
              final createdDate = DateFormat('MMM d, yyyy • h:mm a').format(log.noteCreatedAt);
              final isByAuthor = log.isDeletedByAuthor;
              final badgeColor = isByAuthor ? const Color(0xFFF59E0B) : NexoraTheme.error;

              return Container(
                decoration: BoxDecoration(
                  color: NexoraTheme.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: badgeColor.withValues(alpha: 0.35),
                  ),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Status Row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            isByAuthor ? Icons.person_remove_rounded : Icons.admin_panel_settings_rounded,
                            size: 16,
                            color: badgeColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: badgeColor.withValues(alpha: 0.35)),
                          ),
                          child: Text(
                            isByAuthor ? 'DELETED BY AUTHOR' : 'DELETED BY ADMIN',
                            style: TextStyle(
                              color: badgeColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          relativeTime(log.deletedAt),
                          style: NexoraTheme.monoStyle(
                            color: NexoraTheme.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 19, color: NexoraTheme.error),
                          tooltip: 'Delete Log Entry',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _confirmDeleteLog(context, log),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Note Title
                    Text(
                      log.noteTitle,
                      style: const TextStyle(
                        color: NexoraTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Note Body
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: NexoraTheme.scaffold,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: NexoraTheme.border),
                      ),
                      child: Text(
                        log.content,
                        style: const TextStyle(
                          color: NexoraTheme.textPrimary,
                          fontSize: 13.5,
                          height: 1.4,
                        ),
                      ),
                    ),

                    // Optional Image Thumbnail
                    if (log.imageUrl != null && log.imageUrl!.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: log.imageUrl!,
                          height: 120,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            height: 120,
                            color: NexoraTheme.scaffold,
                            child: const Center(
                              child: CircularProgressIndicator(strokeWidth: 2, color: NexoraTheme.primary),
                            ),
                          ),
                          errorWidget: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),
                    const Divider(height: 1, color: NexoraTheme.border),
                    const SizedBox(height: 10),

                    // Audit Metadata Grid
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Author
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ORIGINAL AUTHOR',
                                style: TextStyle(
                                  color: NexoraTheme.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                log.authorName,
                                style: const TextStyle(
                                  color: NexoraTheme.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                log.authorRegNo,
                                style: NexoraTheme.monoStyle(
                                  color: NexoraTheme.primary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Deleted By
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'DELETED BY',
                                style: TextStyle(
                                  color: NexoraTheme.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      log.deletedByName,
                                      style: const TextStyle(
                                        color: NexoraTheme.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (log.deletedByRole == 'admin' || log.deletedByRole == 'superadmin') ...[
                                    const SizedBox(width: 4),
                                    RoleBadge(
                                      role: log.deletedByRole,
                                      adminColorHex: log.deletedByAdminColorHex,
                                      fontSize: 8.5,
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                    ),
                                  ],
                                ],
                              ),
                              if (log.deletedByRegNo.isNotEmpty)
                                Text(
                                  log.deletedByRegNo,
                                  style: NexoraTheme.monoStyle(
                                    color: badgeColor,
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Posted: $createdDate',
                          style: const TextStyle(color: NexoraTheme.textSecondary, fontSize: 10.5),
                        ),
                        Text(
                          'Deleted: $deletedDate',
                          style: TextStyle(color: badgeColor.withValues(alpha: 0.9), fontSize: 10.5),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  },
);
}

  static Future<void> _confirmDeleteLog(BuildContext context, NoteDeletionLogModel log) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NexoraTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: NexoraTheme.error, size: 24),
            SizedBox(width: 10),
            Text('Delete Audit Log?', style: TextStyle(color: NexoraTheme.textPrimary, fontSize: 17)),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete this audit log for "${log.noteTitle}" by ${log.authorName}? This entry will be erased from the audit trail.',
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
            child: const Text('Delete Log'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await NoteService.deleteAuditLog(log.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: NexoraTheme.success,
              content: Text('Audit log entry permanently deleted.'),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: NexoraTheme.error,
              content: Text('Failed to delete log: $e'),
            ),
          );
        }
      }
    }
  }

  static Future<void> _confirmClearAllLogs(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NexoraTheme.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: NexoraTheme.error, size: 24),
            SizedBox(width: 10),
            Text('Clear All Audit Logs?', style: TextStyle(color: NexoraTheme.textPrimary, fontSize: 17)),
          ],
        ),
        content: const Text(
          'Are you sure you want to permanently erase ALL deletion audit logs? All historical records of deleted notes will be permanently removed. This action cannot be undone.',
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
            child: const Text('Clear All Logs'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await NoteService.clearAllAuditLogs();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: NexoraTheme.success,
              content: Text('All deletion audit logs have been cleared.'),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: NexoraTheme.error,
              content: Text('Failed to clear logs: $e'),
            ),
          );
        }
      }
    }
  }
}
