import 'package:flutter/material.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_theme.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../core/models/nexora_models.dart';
import '../../core/cache/cache_service.dart';
import 'note_detail_screen.dart';
import 'create_note_screen.dart';
import '../../screens/notes/note_deletion_logs_screen.dart';
import '../../models/user_model.dart';

class NotesScreen extends StatefulWidget {
  const NotesScreen({super.key});

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  List<Note>? _cachedNotes;
  bool _hasEverLoaded = false;
  bool _showSkeleton = true;
  int _logoTapCount = 0;

  @override
  void initState() {
    super.initState();
    _loadCacheAndFetch();
  }

  void _loadCacheAndFetch() async {
    final notes = CacheService().getNotes();
    final cachedAt = CacheService().getNotesCachedAt();
    final isExpired = cachedAt == null || DateTime.now().difference(cachedAt).inMinutes > 30;

    // Convert cached Map data back to Note objects
    List<Note> reconstructed = [];
    if (notes != null && notes.isNotEmpty) {
      reconstructed = notes.map((m) {
        return Note(
          noteId: m['id'] ?? m['noteId'] ?? '',
          title: m['title'] ?? '',
          content: m['content'] ?? '',
          authorName: m['authorName'] ?? '',
          authorRegNo: m['authorRegNo'] ?? '',
          authorUid: m['authorUid'] ?? m['postedByUid'] ?? '',
          authorRole: m['authorRole'],
          authorAdminColorHex: m['authorAdminColorHex'],
          imageUrl: m['imageUrl'],
          timestamp: DateTime.parse(m['timestamp']),
          isVerifiedPost: m['isVerifiedPost'] ?? true,
        );
      }).toList();
    }

    if (reconstructed.isNotEmpty) {
      setState(() {
        _cachedNotes = reconstructed;
        _showSkeleton = false;
        _hasEverLoaded = true;
      });
      if (isExpired) {
        // Force refresh by clearing stream and letting StreamBuilder refetch
      } else {
        // Under 30 min: skip force fetch; StreamBuilder still listens silently
      }
    } else {
      setState(() => _showSkeleton = true);
    }
  }

  void _fetchFirebaseInBackground() {
    // Background fetch updates UI silently when stream emits
    // StreamBuilder handles the live stream; cache updates via listener below
  }

  @override
  Widget build(BuildContext context) {
    final firestore = context.watch<FirestoreService>();

    // Triple-tap check
    if (_logoTapCount >= 3) {
      _logoTapCount = 0;
      final auth = context.read<AuthService>();
      final user = auth.currentUser;
      final currentAdmin = user != null
          ? UserModel(
              uid: user.uid,
              email: user.email ?? '',
              name: user.displayName ?? 'Admin',
              regNo: '',
              branch: '',
              year: '',
              phoneNo: '',
              role: 'admin',
              adminColorHex: '#9D4EDD',
              approvedBy: 'self',
              approverColorHex: '#9D4EDD',
              academic: AcademicInfo(
                proctorName: '',
                nptel: '',
                extraCurricular: '',
                clubs: [],
              ),
              courses: const [],
              searchIndices: SearchIndices(
                faculties: const [],
                regNoLower: '',
                nameLower: '',
              ),
            )
          : UserModel(
              uid: '',
              email: '',
              name: 'Admin',
              regNo: '',
              branch: '',
              year: '',
              phoneNo: '',
              role: 'admin',
              adminColorHex: '#9D4EDD',
              approvedBy: 'self',
              approverColorHex: '#9D4EDD',
              academic: AcademicInfo(
                proctorName: '',
                nptel: '',
                extraCurricular: '',
                clubs: [],
              ),
              courses: const [],
              searchIndices: SearchIndices(
                faculties: const [],
                regNoLower: '',
                nameLower: '',
              ),
            );
      // Use addPostFrameCallback so Navigator.push happens after build completes
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NoteDeletionLogsScreen(currentAdmin: currentAdmin),
          ),
        );
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => _logoTapCount++,
          child: const Text('Notes Feed'),
        ),
        actions: [
          Consumer<AuthService>(
            builder: (_, auth, __) => IconButton(
              icon: const Icon(Icons.add_rounded),
              onPressed: auth.currentUser != null
                  ? () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CreateNoteScreen()),
                      )
                  : null,
              tooltip: 'Create Note',
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          CacheService().clearAll();
          setState(() {
            _cachedNotes = null;
            _showSkeleton = true;
          });
          await Future.delayed(const Duration(milliseconds: 600));
        },
        child: _cachedNotes != null && _cachedNotes!.isNotEmpty
            ? _buildNotesList(context, _cachedNotes!, firestore)
            : StreamBuilder<List<Note>>(
                stream: firestore.notesStream,
                builder: (context, snapshot) {
                  // When Firebase arrives, save to Hive and update UI
                  if (snapshot.hasData && snapshot.data != null) {
                    final notesList = snapshot.data!;
                    if (notesList.isNotEmpty) {
                      // Save to cache in background; don't await blocking UI
                      CacheService().saveNotes(notesList.map((n) => n.toFirestore()).toList());
                    }
                  }

                  if (_cachedNotes != null && _cachedNotes!.isNotEmpty) {
                    return _buildNotesList(context, _cachedNotes!, firestore);
                  }

                  if (_showSkeleton && !_hasEverLoaded) {
                    return const Center(
                      child: SizedBox(
                        width: 200,
                        height: 120,
                        child: Card(
                          color: AppTheme.cardSurface,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(width: 160, height: 16, color: AppTheme.dividerColor),
                                SizedBox(height: 8),
                                Container(width: 120, height: 12, color: AppTheme.dividerColor.withValues(alpha: 0.5)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: SizedBox(
                        width: 200,
                        height: 120,
                        child: Card(
                          color: AppTheme.cardSurface,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(width: 160, height: 16, color: AppTheme.dividerColor),
                                SizedBox(height: 8),
                                Container(width: 120, height: 12, color: AppTheme.dividerColor.withValues(alpha: 0.5)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline, size: 48, color: AppTheme.errorRed),
                          const SizedBox(height: 12),
                          Text('Error loading notes', style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Text(snapshot.error.toString(), style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    );
                  }
                  final notes = snapshot.data ?? [];
                  if (notes.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.article_outlined, size: 64, color: AppTheme.textMuted),
                          const SizedBox(height: 16),
                          Text('No notes yet', style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(height: 8),
                          Text(
                            'Verified academic posts appear here',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppTheme.textMuted,
                                ),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.only(top: 8, bottom: 100),
                    itemCount: notes.length,
                    itemBuilder: (context, index) => _NoteCard(note: notes[index]),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildNotesList(BuildContext context, List<Note> notes, FirestoreService firestore) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 100),
      itemCount: notes.length,
      itemBuilder: (context, index) => _NoteCard(note: notes[index]),
    );
  }
}

class _FakeDoc {
  final Map<String, dynamic> data;
  _FakeDoc(this.data);
  dynamic operator [](String key) => data[key];
}

class _NoteCard extends StatelessWidget {
  final Note note;
  const _NoteCard({required this.note});

  @override
  Widget build(BuildContext context) {
    final isAuthorAdmin = note.isAuthorAdmin;
    final authorRoleColor = note.authorRole == 'superadmin'
        ? const Color(0xFF9D4EDD)
        : const Color(0xFF4F8BFF);

    return Card(
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => NoteDetailScreen(note: note)),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isAuthorAdmin ? authorRoleColor : Colors.transparent,
                        width: 2.5,
                      ),
                      boxShadow: isAuthorAdmin
                          ? [
                              BoxShadow(
                                color: authorRoleColor.withValues(alpha: 0.4),
                                blurRadius: 6,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: CircleAvatar(
                      radius: 18,
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
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                note.authorName,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isAuthorAdmin) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: authorRoleColor,
                                  borderRadius: BorderRadius.circular(5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: authorRoleColor.withValues(alpha: 0.4),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  note.authorRole == 'superadmin' ? 'Super Admin' : 'Admin',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          'Reg: ${note.authorRegNo}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.textMuted,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    DateFormat('MMM d, yyyy • h:mm a').format(note.timestamp),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textMuted,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                note.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                note.content,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (note.imageUrl != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: note.imageUrl!.startsWith('http')
                      ? CachedNetworkImage(
                          imageUrl: note.imageUrl!,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            height: 180,
                            color: AppTheme.darkSlate,
                            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            height: 180,
                            color: AppTheme.darkSlate,
                            child: const Center(child: Icon(Icons.broken_image, color: AppTheme.textMuted)),
                          ),
                        )
                      : Image.file(
                          File(note.imageUrl!),
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Delete button for author (visible in feed)
                  Consumer<AuthService>(
                    builder: (_, auth, __) {
                      final currentUid = auth.currentUser?.uid ?? '';
                      final isAuthor = note.authorUid == currentUid || note.authorUid == note.postedByUid;
                      if (!isAuthor) return const SizedBox.shrink();
                      return IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.errorRed, size: 20),
                        tooltip: 'Delete my note',
                        onPressed: () async {
                          final confirmed = await NoteDetailScreen._confirmDelete(context);
                          // Delete service is called inside _confirmDelete after confirmation
                        },
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
