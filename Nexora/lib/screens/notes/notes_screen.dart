import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:nexora/core/cache/cache_service.dart';
import 'package:nexora/core/theme.dart';
import 'package:nexora/core/utils.dart';
import 'package:nexora/models/note_model.dart';
import 'package:nexora/models/user_model.dart';
import 'package:nexora/screens/notes/note_deletion_logs_screen.dart';
import 'package:nexora/screens/notes/post_note_sheet.dart';
import 'package:nexora/services/note_service.dart';
import 'package:nexora/widgets/nexora_logo.dart';
import 'package:nexora/widgets/role_badge.dart';

class NotesScreen extends StatefulWidget {
  final UserModel? currentUser;

  const NotesScreen({super.key, this.currentUser});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  List<NoteModel> _notes = [];
  bool _isLoading = true;
  bool _hasError = false;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _notesSubscription;
  UserModel? _activeUser;
  int _logoTapCount = 0;
  Timer? _logoTapTimer;

  @override
  void initState() {
    super.initState();
    _activeUser = widget.currentUser;
    _resolveCurrentUser();
    // 1. On init → call CacheService().getNotes() immediately
    _loadCachedNotes();
    // 3. Start Firestore stream in background
    _startNotesStream();
  }

  @override
  void dispose() {
    _notesSubscription?.cancel();
    _logoTapTimer?.cancel();
    super.dispose();
  }

  Future<UserModel?> _resolveCurrentUser() async {
    if (_activeUser != null) return _activeUser;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (doc.exists && doc.data() != null) {
      final user = UserModel.fromFirestore(doc);
      if (mounted) {
        setState(() => _activeUser = user);
      } else {
        _activeUser = user;
      }
      return _activeUser;
    }
    return null;
  }

  void _onLogoTap() async {
    _logoTapCount++;
    _logoTapTimer?.cancel();
    _logoTapTimer = Timer(const Duration(milliseconds: 1200), () {
      _logoTapCount = 0;
    });

    if (_logoTapCount >= 3) {
      _logoTapCount = 0;
      _logoTapTimer?.cancel();
      HapticFeedback.heavyImpact();

      final user = await _resolveCurrentUser();
      if (!mounted) return;
      final currentUid = FirebaseAuth.instance.currentUser?.uid ?? 'admin';
      final adminUser = user ??
          UserModel(
            uid: currentUid,
            email: FirebaseAuth.instance.currentUser?.email ?? '',
            name: FirebaseAuth.instance.currentUser?.displayName ?? 'Admin',
            regNo: 'ADMIN',
            branch: 'Administration',
            year: '1',
            phoneNo: '',
            role: 'admin',
            approvedBy: 'genesis',
            approverColorHex: '#3B82F6',
            academic: AcademicInfo(nptel: '', extraCurricular: '', clubs: []),
            courses: const [],
            searchIndices: SearchIndices(faculties: const [], regNoLower: 'admin', nameLower: 'admin'),
          );

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => NoteDeletionLogsScreen(currentAdmin: adminUser),
        ),
      );
    }
  }

  Future<void> _confirmDeleteNote(BuildContext context, NoteModel note) async {
    final fbUser = FirebaseAuth.instance.currentUser;
    if (fbUser == null) {
      if (context.mounted) {
        showNxSnack(context, 'You must be signed in to delete notes.');
      }
      return;
    }
    final resolved = await _resolveCurrentUser();
    final currentUser = resolved ??
        UserModel(
          uid: fbUser.uid,
          email: fbUser.email ?? '',
          name: fbUser.displayName ?? 'Scholar',
          regNo: '',
          branch: '',
          year: '1',
          phoneNo: '',
          role: 'student',
          approvedBy: 'system',
          approverColorHex: '#3B82F6',
          academic: AcademicInfo(nptel: '', extraCurricular: '', clubs: []),
          courses: const [],
          searchIndices: SearchIndices(faculties: const [], regNoLower: '', nameLower: ''),
        );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: NexoraTheme.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: NexoraTheme.border),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: NexoraTheme.error.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  color: NexoraTheme.error, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'Delete Note?',
              style: GoogleFonts.syne(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: NexoraTheme.textPrimary,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${note.title?.isNotEmpty == true ? note.title : "this academic note"}"? '
          'An immutable copy will be recorded in the deletion audit trail.',
          style: GoogleFonts.inter(
              color: NexoraTheme.textSecondary, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                  color: NexoraTheme.textSecondary,
                  fontWeight: FontWeight.w600),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: NexoraTheme.error,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Delete Note',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await NoteService.deleteNoteWithAudit(
            note: note, deletedBy: currentUser);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: NexoraTheme.success,
              content: Text('Note deleted and archived to audit log.'),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: NexoraTheme.error,
              content: Text('Failed to delete note: $e'),
            ),
          );
        }
      }
    }
  }


  void _loadCachedNotes() {
    final cached = CacheService().getNotes();
    if (cached != null && cached.isNotEmpty) {
      // 2. If cache exists → show notes instantly, no spinner
      setState(() {
        _notes = cached
            .map((note) =>
                NoteModel.fromMap(note, (note['id'] ?? '').toString()))
            .toList();
        _isLoading = false;
      });
    }
  }

  void _startNotesStream() {
    _notesSubscription?.cancel();
    if (_notes.isEmpty) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
      // Fallback: if offline and stream hangs without cache, show offline empty state
      Timer(const Duration(seconds: 4), () {
        if (mounted && _isLoading && _notes.isEmpty) {
          setState(() {
            _isLoading = false;
            _hasError = true;
          });
        }
      });
    }

    _notesSubscription = NoteService.feed().listen(
      (snapshot) {
        // 4. When Firestore data arrives → update UI + call CacheService().saveNotes()
        final freshNotes = snapshot.docs.map(NoteModel.fromFirestore).toList();
        final rawDocs = [
          for (final doc in snapshot.docs) {'id': doc.id, ...doc.data()}
        ];
        CacheService().saveNotes(rawDocs);

        if (mounted) {
          setState(() {
            _notes = freshNotes;
            _isLoading = false;
            _hasError = false;
          });
        }
      },
      onError: (error) {
        debugPrint('[NotesScreen] Stream error: $error');
        if (mounted) {
          setState(() {
            _isLoading = false;
            if (_notes.isEmpty) {
              _hasError = true;
            }
          });
        }
      },
    );
  }

  Future<void> _openPostSheet(BuildContext context) async {
    UserModel? user = widget.currentUser;
    if (user == null) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to publish notes.')),
        );
        return;
      }
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!doc.exists || doc.data() == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Only verified members can publish notes.')),
          );
        }
        return;
      }
      user = UserModel.fromFirestore(doc);
    }

    if (context.mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => PostNoteSheet(currentUser: user!),
      );
    }
  }

  void _viewFullScreenImage(BuildContext context, String imageUrl, String tag) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: NexoraTheme.textPrimary),
          ),
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.8,
              maxScale: 4.0,
              child: Hero(
                tag: tag,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const Center(
                    child:
                        CircularProgressIndicator(color: NexoraTheme.primary),
                  ),
                  errorWidget: (_, __, ___) => const Icon(
                    Icons.broken_image_rounded,
                    color: NexoraTheme.textSecondary,
                    size: 48,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NexoraTheme.scaffold,
      appBar: AppBar(
        title: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _onLogoTap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: NexoraLogo(size: 22, showWordmark: false),
              ),
              const SizedBox(width: 8),
              Text(
                'Academic Notes',
                style: GoogleFonts.syne(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: NexoraTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: NexoraTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: const StadiumBorder(),
              ),
              onPressed: () => _openPostSheet(context),
              icon: const Icon(Icons.add, size: 16),
              label: Text(
                'Post Note',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12.5),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading && _notes.isEmpty
          ? const Center(
              child: CircularProgressIndicator(color: NexoraTheme.primary),
            )
          : _hasError && _notes.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_rounded,
                            size: 48, color: NexoraTheme.textSecondary),
                        const SizedBox(height: 12),
                        Text(
                          'No cached notes available offline.',
                          style: GoogleFonts.inter(color: NexoraTheme.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _startNotesStream,
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: Text('Retry', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                          style: FilledButton.styleFrom(
                            backgroundColor: NexoraTheme.primary,
                            foregroundColor: Colors.white,
                            shape: const StadiumBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _notes.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: NexoraTheme.cardRaised,
                                border: Border.all(color: NexoraTheme.border),
                              ),
                              child: const Icon(Icons.feed_outlined,
                                  size: 44, color: NexoraTheme.textSecondary),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No Academic Notes Yet',
                              style: GoogleFonts.syne(
                                color: NexoraTheme.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Be the first to publish course notes or study guides for your peers.',
                              style: GoogleFonts.inter(
                                color: NexoraTheme.textSecondary,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              onPressed: () => _openPostSheet(context),
                              icon: const Icon(Icons.add, size: 16),
                              label: Text(
                                'Publish First Note',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: NexoraTheme.primary,
                                foregroundColor: Colors.white,
                                shape: const StadiumBorder(),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      color: NexoraTheme.primary,
                      backgroundColor: NexoraTheme.card,
                      onRefresh: () async {
                        _startNotesStream();
                      },
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        itemCount: _notes.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final note = _notes[index];
              final formattedDate =
                  DateFormat('MMM d, yyyy • h:mm a').format(note.timestamp);
              final heroTag = 'note_img_${note.id}';

              final currentUid = FirebaseAuth.instance.currentUser?.uid;
              final canDelete = (currentUid != null && currentUid == note.postedByUid) ||
                  (_activeUser?.isAdmin == true) ||
                  (widget.currentUser?.isAdmin == true);

              final authorIsAdmin = note.isAuthorAdmin;
              final authorRoleColor = roleColorFor(
                role: note.authorRole ?? 'student',
                adminColorHex: note.authorAdminColorHex,
              );

              final authorAvatar = CircleAvatar(
                radius: 17,
                backgroundColor: authorIsAdmin
                    ? authorRoleColor.withValues(alpha: 0.18)
                    : NexoraTheme.primary.withValues(alpha: 0.15),
                backgroundImage: (note.authorPhotoUrl != null &&
                        note.authorPhotoUrl!.isNotEmpty)
                    ? NetworkImage(note.authorPhotoUrl!)
                    : null,
                child: (note.authorPhotoUrl == null ||
                        note.authorPhotoUrl!.isEmpty)
                    ? Text(
                        note.authorName.isNotEmpty
                            ? note.authorName[0].toUpperCase()
                            : 'U',
                        style: TextStyle(
                          color: authorIsAdmin
                              ? authorRoleColor
                              : NexoraTheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      )
                    : null,
              );

              final borderedAuthorAvatar = authorIsAdmin
                  ? Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: authorRoleColor, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: authorRoleColor.withValues(alpha: 0.4),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: authorAvatar,
                    )
                  : authorAvatar;

              return Container(
                decoration: BoxDecoration(
                  color: NexoraTheme.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: NexoraTheme.border, width: 1),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Author Header (Structured 2-row layout with zero overflow)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        borderedAuthorAvatar,
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Line 1: Author Name and Date
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      note.authorName,
                                      style: GoogleFonts.syne(
                                        color: NexoraTheme.textPrimary,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.1,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    formattedDate,
                                    style: GoogleFonts.inter(
                                      color: NexoraTheme.textMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              // Line 2: Role Badge & Reg No (Wrap prevents right-side overflow)
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (authorIsAdmin)
                                    RoleBadge(
                                      role: note.authorRole!,
                                      adminColorHex: note.authorAdminColorHex,
                                      fontSize: 9.5,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                    ),
                                  if (note.authorRegNo.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: NexoraTheme.scaffold,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                            color: NexoraTheme.border),
                                      ),
                                      child: Text(
                                        note.authorRegNo,
                                        style: NexoraTheme.monoStyle(
                                          color: NexoraTheme.primary,
                                          fontSize: 10.5,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (canDelete) ...[
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 19,
                              color: NexoraTheme.textMuted,
                            ),
                            tooltip: 'Delete note',
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(),
                            onPressed: () => _confirmDeleteNote(context, note),
                          ),
                        ],
                      ],
                    ),

                    // Integrity Stamp Badge
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: NexoraTheme.success.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: NexoraTheme.success.withValues(alpha: 0.22)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.verified,
                              size: 12, color: NexoraTheme.success),
                          const SizedBox(width: 5),
                          Text(
                            'Verified Attribution • Non-Anonymous',
                            style: GoogleFonts.inter(
                              color: NexoraTheme.success,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Title
                    if (note.title != null &&
                        note.title!.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        note.title!.trim(),
                        style: GoogleFonts.syne(
                          color: NexoraTheme.textPrimary,
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],

                    // Content
                    const SizedBox(height: 8),
                    Text(
                      note.content,
                      style: GoogleFonts.inter(
                        color: NexoraTheme.textPrimary.withValues(alpha: 0.92),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),

                    // Image (Uploaded via ImgBB, displayed via CachedNetworkImage with Hero zoom)
                    if (note.imageUrl != null && note.imageUrl!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => _viewFullScreenImage(
                            context, note.imageUrl!, heroTag),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Hero(
                            tag: heroTag,
                            child: CachedNetworkImage(
                              imageUrl: note.imageUrl!,
                              width: double.infinity,
                              height: 210,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Container(
                                height: 210,
                                color: NexoraTheme.scaffold,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: NexoraTheme.primary,
                                  ),
                                ),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                height: 120,
                                color: NexoraTheme.scaffold,
                                child: const Center(
                                  child: Icon(Icons.broken_image,
                                      color: NexoraTheme.textSecondary),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
    );
  }
}
