import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:nexora/core/theme.dart';
import 'package:nexora/models/notification_model.dart';
import 'package:nexora/screens/notes/note_notifications_sheet.dart';
import 'package:nexora/services/notification_service.dart';
import 'members/members_screen.dart';
import 'nexus/nexus_screen.dart';
import 'notes/notes_screen.dart';

/// Nexora's persistent, three-area application shell.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  StreamSubscription<List<NoteNotificationModel>>? _notificationSub;
  final Set<String> _seenNotificationIds = {};
  bool _isFirstSnapshot = true;
  NoteNotificationModel? _activeBanner;
  Timer? _bannerDismissTimer;

  final List<Widget> _pages = const [
    NotesScreen(),
    NexusScreen(),
    MembersScreen(),
  ];

  @override
  void initState() {
    super.initState();

    // Listen for real-time broadcasts so everyone gets notified of note updates
    _notificationSub = NotificationService().streamNotifications(limit: 10).listen((notifications) {
      if (!mounted) return;
      if (_isFirstSnapshot) {
        _isFirstSnapshot = false;
        // On app launch, seed seen notification IDs without triggering toasts for historic notes
        for (final notif in notifications) {
          _seenNotificationIds.add(notif.id);
        }
        return;
      }

      // Any document not in _seenNotificationIds is a brand new real-time post/update
      for (final notif in notifications) {
        if (!_seenNotificationIds.contains(notif.id)) {
          _seenNotificationIds.add(notif.id);
          _triggerBanner(notif);
          break;
        }
      }
    });
  }

  void _triggerBanner(NoteNotificationModel notif) {
    HapticFeedback.mediumImpact();
    _bannerDismissTimer?.cancel();
    setState(() => _activeBanner = notif);
    _bannerDismissTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) setState(() => _activeBanner = null);
    });
  }

  void _dismissBanner() {
    _bannerDismissTimer?.cancel();
    setState(() => _activeBanner = null);
  }

  @override
  void dispose() {
    _notificationSub?.cancel();
    _bannerDismissTimer?.cancel();
    super.dispose();
  }

  void _onTabSelected(int index) {
    if (_selectedIndex == index) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedIndex = index);
  }

  Widget _buildNotificationBanner(NoteNotificationModel notif) {
    final isUpdate = notif.isUpdate;
    final accentColor = isUpdate ? const Color(0xFF9D4EDD) : NexoraTheme.primary;

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xF212171F),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accentColor.withValues(alpha: 0.5), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.25),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            _dismissBanner();
            _onTabSelected(0);
            NoteNotificationsSheet.show(context);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: accentColor.withValues(alpha: 0.35)),
                  ),
                  child: Icon(
                    isUpdate ? Icons.edit_note_rounded : Icons.campaign_rounded,
                    color: accentColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isUpdate ? 'NOTE UPDATED' : 'NEW NOTE',
                              style: GoogleFonts.inter(
                                color: accentColor,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '• Just now',
                            style: GoogleFonts.inter(color: NexoraTheme.textSecondary, fontSize: 10.5),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notif.noteTitle,
                        style: GoogleFonts.syne(
                          color: NexoraTheme.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'by ${notif.authorName}${notif.authorRegNo.isNotEmpty ? ' (${notif.authorRegNo})' : ''}',
                        style: GoogleFonts.inter(
                          color: NexoraTheme.textSecondary,
                          fontSize: 11.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: NexoraTheme.textSecondary),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: _dismissBanner,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: _pages,
          ),
          if (_activeBanner != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _buildNotificationBanner(_activeBanner!),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Color(0xF50D1017),
          border: Border(
            top: BorderSide(color: Color(0xFF1E2536), width: 1.0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 16,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: NavigationBar(
            height: 66,
            elevation: 0,
            animationDuration: const Duration(milliseconds: 220),
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onTabSelected,
            backgroundColor: Colors.transparent,
            indicatorColor: const Color(0x264F8BFF), // Tech blue at 15%
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.article_outlined),
                selectedIcon: const Icon(Icons.article_rounded),
                label: 'Notes',
              ),
              const NavigationDestination(
                icon: Icon(Icons.hub_outlined),
                selectedIcon: Icon(Icons.hub_rounded),
                label: 'Nexus',
              ),
              const NavigationDestination(
                icon: Icon(Icons.badge_outlined),
                selectedIcon: Icon(Icons.badge_rounded),
                label: 'Members',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

