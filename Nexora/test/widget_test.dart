import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:nexora/core/constants.dart';
import 'package:nexora/core/utils.dart';
import 'package:nexora/models/user_model.dart';
import 'package:nexora/models/note_model.dart';
import 'package:nexora/models/note_deletion_log_model.dart';
import 'package:nexora/models/notification_model.dart';
import 'package:nexora/widgets/role_badge.dart';
import 'package:nexora/widgets/nx_avatar.dart';
import 'package:nexora/widgets/nexora_logo.dart';
import 'package:nexora/widgets/member_card.dart';
import 'package:nexora/screens/members/pokemon_card_screen.dart';

void main() {
  group('Nexora Constants & Utilities Tests', () {
    test('Nexus PWA URL is correctly configured and valid', () {
      expect(kNexusUrl, 'https://nexus-e7a36.web.app/index.html');
      final uri = Uri.tryParse(kNexusUrl);
      expect(uri, isNotNull);
      expect(uri!.isScheme('HTTPS'), isTrue);
    });

    test('Developer emails list includes genesis developer', () {
      expect(kDeveloperEmails, contains('gokultn592@gmail.com'));
    });

    test('Color hex parser converts standard 6-char hex and handles fallbacks', () {
      final blue = colorFromHex('#4F8BFF');
      expect(blue.value, const Color(0xFF4F8BFF).value);

      final fallback = colorFromHex(null, const Color(0xFF10B981));
      expect(fallback.value, const Color(0xFF10B981).value);
    });

    test('alphaOf applies opacity correctly', () {
      const color = Color(0xFF4F8BFF);
      final transparent = alphaOf(color, 0.5);
      expect((transparent.a * 255).round(), closeTo(128, 2));
    });

    test('roleColorFor resolves purple for Super Admin and blue for Admin', () {
      final superadminColor = roleColorFor(role: 'superadmin');
      expect(superadminColor.value, const Color(0xFF9D4EDD).value);

      final adminColor = roleColorFor(role: 'admin');
      expect(adminColor.value, const Color(0xFF4F8BFF).value);

      final customColor = roleColorFor(role: 'superadmin', adminColorHex: '#10B981');
      expect(customColor.value, const Color(0xFF10B981).value);
    });
  });

  group('Nexora Role UI Tests', () {
    testWidgets('RoleBadge displays Super Admin with purple background and white text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Row(
                children: [
                  Text('Gokul'),
                  SizedBox(width: 8),
                  RoleBadge(role: 'superadmin'),
                ],
              ),
            ),
          ),
        ),
      );

      final badgeText = find.text('Super Admin');
      expect(badgeText, findsOneWidget);

      final textWidget = tester.widget<Text>(badgeText);
      expect(textWidget.style?.color, Colors.white);

      final containerFinder = find.ancestor(
        of: badgeText,
        matching: find.byType(Container),
      );
      expect(containerFinder, findsWidgets);

      final containerWidget = tester.widget<Container>(containerFinder.first);
      final decoration = containerWidget.decoration as BoxDecoration;
      expect(decoration.color?.value, const Color(0xFF9D4EDD).value);
    });

    testWidgets('NxAvatar renders colored ring around profile pic with thickness', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: NxAvatar(
                name: 'Gokul SuperAdmin',
                ringColor: Color(0xFF9D4EDD),
                ringWidth: 3.5,
              ),
            ),
          ),
        ),
      );

      final container = find.ancestor(
        of: find.byType(CircleAvatar),
        matching: find.byType(Container),
      );
      expect(container, findsOneWidget);

      final containerWidget = tester.widget<Container>(container);
      final decoration = containerWidget.decoration as BoxDecoration;
      final border = decoration.border as Border;
      expect(border.top.color.value, const Color(0xFF9D4EDD).value);
      expect(border.top.width, 3.5);
    });

    testWidgets('NexoraLogo renders geometric checkmark N, wordmark and subtitle', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: NexoraLogo(size: 80, showWordmark: true, showSubtitle: true),
            ),
          ),
        ),
      );

      expect(find.text('NEXORA'), findsOneWidget);
      expect(find.text('NEXT ERA'), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });

  group('Nexora Data Models Tests', () {
    test('UserModel serializes to and from Map accurately', () {
      final user = UserModel(
        uid: 'user_123',
        email: 'student@example.com',
        name: 'Gokul Test',
        regNo: '23BDS0084',
        branch: 'Int MTech DS',
        year: '2nd Year',
        phoneNo: '9876543210',
        photoUrl: null,
        role: 'superadmin',
        adminColorHex: '#4F8BFF',
        approvedBy: 'genesis_developer',
        approverColorHex: '#4F8BFF',
        academic: AcademicInfo(
          proctorName: 'Dr. Sivakumar',
          coreSlot: 'A1',
          nptel: 'Data Science',
          extraCurricular: 'Coding Club',
          clubs: ['AI Club', 'GDSC'],
        ),
        courses: [
          CourseItem(
            code: 'CSE1001',
            name: 'Computer Architecture and Organization',
            faculty: 'Sivakumar',
            slot: 'A1 + TA1',
          ),
        ],
        searchIndices: SearchIndices(
          faculties: ['sivakumar'],
          regNoLower: '23bds0084',
          nameLower: 'gokul test',
        ),
      );

      final map = user.toMap();
      expect(map['uid'], 'user_123');
      expect(map['regNo'], '23BDS0084');
      expect(map['role'], 'superadmin');
      expect(user.isAdmin, isTrue);
      expect(user.isSuperAdmin, isTrue);
      expect(user.academic.facultyAdvisor, 'Dr. Sivakumar');
      expect(user.courses.length, 1);
      expect(user.courses.first.faculty, 'Sivakumar');
    });

    test('NoteModel serializes to and from Map accurately', () {
      final now = DateTime.now();
      final note = NoteModel(
        id: 'note_456',
        title: 'Operating Systems Revision',
        content: 'Comprehensive notes for Module 2 deadlock handling.',
        imageUrl: 'https://example.com/note.jpg',
        postedByUid: 'user_123',
        authorName: 'Gokul Test',
        authorRegNo: '23BDS0084',
        timestamp: now,
      );

      final map = note.toMap();
      expect(map['postedByUid'], 'user_123');
      expect(map['authorName'], 'Gokul Test');
      expect(map['authorRegNo'], '23BDS0084');
      expect(map['title'], 'Operating Systems Revision');
      expect(map['content'], 'Comprehensive notes for Module 2 deadlock handling.');
      expect(map['imageUrl'], 'https://example.com/note.jpg');
    });

    test('PendingUserModel correctly retains isNexusMember and requires admin verification', () {
      final now = DateTime.now();
      final pendingCandidate = PendingUserModel(
        uid: 'nexus_candidate_789',
        email: 'nexus_student@example.com',
        name: 'Nexus Student',
        regNo: '23BDS0099',
        branch: 'Int MTech DS',
        year: '2nd Year',
        phoneNo: '9876543211',
        isNexusMember: true,
        nexusRole: 'friend',
        submittedAt: now,
      );

      final map = pendingCandidate.toMap();
      expect(map['uid'], 'nexus_candidate_789');
      expect(map['isNexusMember'], isTrue);
      expect(map['nexusRole'], 'friend');
      expect(map['regNo'], '23BDS0099');
      expect(pendingCandidate.isNexusMember, isTrue);
    });

    test('NoteNotificationModel serializes to and from Map and correctly flags update', () {
      final now = DateTime.now();
      final notif = NoteNotificationModel(
        id: 'notif_1',
        noteId: 'note_123',
        noteTitle: 'Compiler Design Unit 4',
        authorName: 'Gokul Test',
        authorUid: 'user_123',
        authorRegNo: '23BDS0084',
        type: 'updated',
        timestamp: now,
      );

      expect(notif.isUpdate, isTrue);
      expect(notif.noteTitle, 'Compiler Design Unit 4');
      expect(notif.authorName, 'Gokul Test');
      expect(notif.authorRegNo, '23BDS0084');

      final map = notif.toMap();
      expect(map['noteId'], 'note_123');
      expect(map['noteTitle'], 'Compiler Design Unit 4');
      expect(map['authorName'], 'Gokul Test');
      expect(map['type'], 'updated');
    });

    test('NoteModel isEdited flag correctly tracks when updatedAt is set', () {
      final now = DateTime.now();
      final note = NoteModel(
        id: 'note_456',
        title: 'Operating Systems Revision',
        content: 'Deadlock avoidance notes.',
        postedByUid: 'user_123',
        authorName: 'Gokul Test',
        authorRegNo: '23BDS0084',
        timestamp: now,
        updatedAt: now.add(const Duration(minutes: 5)),
      );

      expect(note.isEdited, isTrue);
      expect(note.updatedAt, isNotNull);
    });

    test('NoteDeletionLogModel serializes correctly and tracks deletion actor', () {
      final now = DateTime.now();
      final log = NoteDeletionLogModel(
        id: 'log_999',
        noteId: 'note_456',
        noteTitle: 'Operating Systems Revision',
        content: 'Deadlock notes',
        authorUid: 'author_123',
        authorName: 'Student Author',
        authorRegNo: '23BDS0001',
        authorRole: 'student',
        noteCreatedAt: now.subtract(const Duration(days: 2)),
        deletedByUid: 'admin_789',
        deletedByName: 'Admin User',
        deletedByRegNo: '23BDS0084',
        deletedByRole: 'superadmin',
        isDeletedByAuthor: false,
        deletedAt: now,
      );

      expect(log.isDeletedByAuthor, isFalse);
      expect(log.noteTitle, 'Operating Systems Revision');
      expect(log.deletedByName, 'Admin User');
      expect(log.deletedByRole, 'superadmin');

      final map = log.toMap();
      expect(map['noteId'], 'note_456');
      expect(map['authorUid'], 'author_123');
      expect(map['deletedByUid'], 'admin_789');
      expect(map['isDeletedByAuthor'], isFalse);
    });
  });

  group('Nexora MemberCard & Interaction Tests', () {
    final testUser = UserModel(
      uid: 'user_101',
      email: 'student@nexora.edu',
      name: 'Ananya Sharma',
      regNo: '23BCE1001',
      branch: 'Computer Science and Engineering',
      year: '2',
      phoneNo: '+91 9876543210',
      role: 'student',
      approvedBy: 'admin_123',
      approverColorHex: '#4F8BFF',
      academic: AcademicInfo(
        coreSlot: 'Morning',
        proctorName: 'Dr. Ramesh Kumar',
        nptel: 'Cloud Computing',
        extraCurricular: 'Debate Club',
        clubs: ['Coding Club', 'Robotics'],
      ),
      courses: [
        CourseItem(code: 'CSE2001', name: 'Data Structures', faculty: 'Dr. Ramesh Kumar', slot: 'A1'),
      ],
      searchIndices: SearchIndices(
        faculties: ['ramesh kumar'],
        regNoLower: '23bce1001',
        nameLower: 'ananya sharma',
      ),
    );

    testWidgets('MemberCard renders self card without swipe instruction text and handles swipe', (tester) async {
      bool tappedOrSwiped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MemberCard(
              user: testUser,
              isSelf: true,
              onSwipeToEdit: () {
                tappedOrSwiped = true;
              },
            ),
          ),
        ),
      );

      // Verify name, regNo and core slot are rendered
      expect(find.text('Ananya Sharma'), findsOneWidget);
      expect(find.text('23BCE1001'), findsOneWidget);
      expect(find.text('Morning'), findsOneWidget);

      // Verify NO swipe instruction text is present
      expect(find.text('Swipe to edit'), findsNothing);
      expect(find.text('Swipe to edit profile'), findsNothing);

      // Simulate a horizontal swipe gesture across the card
      await tester.drag(find.text('Ananya Sharma'), const Offset(200, 0));
      await tester.pumpAndSettle();

      expect(tappedOrSwiped, isTrue, reason: 'Swiping the self-profile card should trigger onSwipeToEdit callback');
    });

    testWidgets('MemberCard renders peer card with card action indicator and handles tap', (tester) async {
      bool cardTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MemberCard(
              user: testUser,
              isSelf: false,
              onTap: () {
                cardTapped = true;
              },
            ),
          ),
        ),
      );

      // Verify peer card renders name and card action indicator
      expect(find.text('Ananya Sharma'), findsOneWidget);
      expect(find.text('Card'), findsOneWidget);

      // Tap card
      await tester.tap(find.text('Ananya Sharma'));
      await tester.pumpAndSettle();

      expect(cardTapped, isTrue, reason: 'Tapping a peer card with onTap should trigger card callback');
    });

    testWidgets('PokemonCardScreen renders front face and flips 3D on tap to back face', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PokemonCardScreen(
            user: testUser,
            isSelf: true,
          ),
        ),
      );

      // Front face elements should be visible initially
      expect(find.text('Member Card'), findsOneWidget);
      expect(find.text('Ananya Sharma'), findsOneWidget);
      expect(find.text('REGISTRATION SERIAL'), findsOneWidget);
      expect(find.text('COMMUNITY PROFILE'), findsOneWidget);

      // Tap card to trigger 3D flip
      await tester.tap(find.text('Ananya Sharma'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      // Back face dossier elements should now be visible
      expect(find.text('ACADEMIC DOSSIER'), findsOneWidget);
      expect(find.text('PROCTOR / FACULTY ADVISOR'), findsOneWidget);
      expect(find.text('Dr. Ramesh Kumar'), findsNWidgets(2));
      expect(find.text('ENROLLED COURSES (1)'), findsOneWidget);
    });
  });
}

