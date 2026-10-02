import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/nexora_models.dart';
import '../../models/note_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/note_service.dart';

class NoteDetailScreen extends StatelessWidget {
  final Note note;

  const NoteDetailScreen({super.key, required this.note});

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.errorRed, size: 24),
            SizedBox(width: 10),
            Text('Delete Note?', style: TextStyle(color: AppTheme.textPrimary, fontSize: 17)),
          ],
        ),
        content: const Text('This will permanently remove the note and log an audit entry.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 13.5, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.errorRed),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      try {
        final auth = AuthService();
        final user = auth.currentUser;
        if (user == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            backgroundColor: AppTheme.errorRed,
            content: Text('Not signed in — cannot delete'),
          ));
          return;
        }
        final deletedBy = UserModel(
          uid: user.uid,
          email: user.email ?? '',
          name: user.displayName ?? 'Unknown',
          regNo: '',
          branch: '',
          year: '',
          phoneNo: '',
          role: 'student',
          adminColorHex: null,
          approvedBy: 'self',
          approverColorHex: '',
          academic: AcademicInfo(proctorName: '', nptel: '', extraCurricular: '', clubs: [], coreSlot: ''),
          courses: const [],
          searchIndices: SearchIndices(faculties: const [], regNoLower: '', nameLower: ''),
        );
        await NoteService.deleteNoteWithAudit(
          note: NoteModel(
            id: note.noteId,
            title: note.title,
            content: note.content,
            imageUrl: note.imageUrl,
            postedByUid: note.authorUid,
            authorName: note.authorName,
            authorRegNo: note.authorRegNo,
            authorRole: note.authorRole ?? 'student',
            authorAdminColorHex: note.authorAdminColorHex,
            timestamp: note.timestamp,
          ),
          deletedBy: deletedBy,
        );
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          backgroundColor: AppTheme.successGreen,
          content: Text('Note deleted — audit logged'),
        ));
        if (context.mounted) Navigator.of(context).pop();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppTheme.errorRed,
          content: Text('Failed to delete note: $e'),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAuthorAdmin = note.isAuthorAdmin;
    final authorRoleColor = note.authorRole == 'superadmin'
        ? const Color(0xFF9D4EDD)
        : const Color(0xFF4F8BFF);

    return Scaffold(
      appBar: AppBar(
        title: Text(note.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author attribution header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.dividerColor),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isAuthorAdmin ? authorRoleColor : Colors.transparent,
                        width: 3.0,
                      ),
                      boxShadow: isAuthorAdmin
                          ? [
                              BoxShadow(
                                color: authorRoleColor.withValues(alpha: 0.4),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: isAuthorAdmin
                          ? authorRoleColor.withValues(alpha: 0.2)
                          : AppTheme.brandBlue.withValues(alpha: 0.2),
                      child: Text(
                        note.authorName.isNotEmpty
                            ? note.authorName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          color: isAuthorAdmin ? authorRoleColor : AppTheme.brandBlue,
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                note.authorName,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isAuthorAdmin) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: authorRoleColor,
                                  borderRadius: BorderRadius.circular(6),
                                  boxShadow: [
                                    BoxShadow(
                                      color: authorRoleColor.withValues(alpha: 0.4),
                                      blurRadius: 5,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  note.authorRole == 'superadmin' ? 'Super Admin' : 'Admin',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          'Registration No: ${note.authorRegNo}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                        ),
                        Text(
                          'Posted: ${DateFormat('MMMM d, yyyy • h:mm a').format(note.timestamp)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textMuted,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.successGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.successGreen.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified, size: 14, color: AppTheme.successGreen),
                        const SizedBox(width: 4),
                        Text(
                          'Verified',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppTheme.successGreen,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Note content
            Text(
              note.content,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
            ),

            // Image if exists
            if (note.imageUrl != null) ...[
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: note.imageUrl!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    height: 250,
                    color: AppTheme.darkSlate,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    height: 250,
                    color: AppTheme.darkSlate,
                    child: const Center(child: Icon(Icons.broken_image, color: AppTheme.textMuted)),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Delete action
            Center(
              child: TextButton.icon(
                icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.errorRed, size: 20),
                label: const Text('Delete Note', style: TextStyle(color: AppTheme.errorRed, fontWeight: FontWeight.w600)),
                onPressed: () => _confirmDelete(context),
              ),
            ),

            const SizedBox(height: 16),

            // Verified entry badge
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.successGreen.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.successGreen.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.security, color: AppTheme.successGreen, size: 28),
                  const SizedBox(height: 8),
                  Text(
                    'Verified Academic Record',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppTheme.successGreen,
                          fontWeight: FontWeight.w600,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'This post cannot be edited or deleted. Full attribution: ${note.authorName} (${note.authorRegNo})',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textMuted,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
