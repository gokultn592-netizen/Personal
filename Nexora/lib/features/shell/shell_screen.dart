import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../notes/notes_screen.dart';
import '../nexus/nexus_screen.dart';
import '../../features/members/members_screen.dart';
import '../../services/auth_service.dart';

class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _currentIndex = 0;

  static const List<Widget> _screens = [
    NotesScreen(),
    NexusScreen(),
    MembersScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final isAdmin = auth.currentUser?.role == 'admin' || auth.currentUser?.role == 'approver';

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.article_outlined),
            activeIcon: Icon(Icons.article_rounded),
            label: 'Notes',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.web_outlined),
            activeIcon: Icon(Icons.web_rounded),
            label: 'Nexus',
          ),
          BottomNavigationBarItem(
            icon: Icon(isAdmin ? Icons.shield_outlined : Icons.people_outline),
            activeIcon: Icon(isAdmin ? Icons.shield_rounded : Icons.people_rounded),
            label: 'Members',
          ),
        ],
      ),
    );
  }
}