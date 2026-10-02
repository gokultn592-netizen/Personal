import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nexora/core/cache/cache_service.dart';

/// Regression tests for the audit findings.
///
/// These cover the defects that were silent in production: the Hive cache
/// throwing on Firestore `Timestamp` values, the role-vocabulary conflict, and
/// the `AuthGate` approval predicate that accepted any non-empty role.
void main() {
  group('CacheService material normalisation', () {
    late Directory dir;

    setUp(() async {
      dir = Directory.systemTemp.createTempSync('nexora_cache_test');
      Hive.init(dir.path);
      // CacheService is a process-wide singleton holding open box handles, so
      // each test starts from freshly opened boxes.
      await CacheService().init();
    });

    tearDown(() async {
      await Hive.close();
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    test('saveMaterials succeeds with a Timestamp payload', () async {
      // This is exactly the shape NexusScreen hands to the cache: raw Firestore
      // documents containing a `createdAt` Timestamp.
      final materials = <Map<String, dynamic>>[
        {
          'title': 'Applied Linear Algebra',
          'subject': 'DAA',
          'fileType': 'PDF',
          'uploaderName': 'Gokul',
          'fileUrl': 'https://huggingface.co/datasets/x/Linear_algebra.pdf?download=true',
          'createdAt': Timestamp.fromDate(DateTime(2026, 1, 2)),
          'docId': 'abc123',
        },
      ];

      // Previously threw: "HiveError: Cannot write, unknown type: Timestamp".
      final saved = await CacheService().saveMaterials(materials);
      expect(saved, isTrue, reason: 'saveMaterials must not throw on Timestamp');

      final read = CacheService().getMaterials();
      expect(read, isNotNull);
      expect(read!.length, 1);
      expect(read.first['title'], 'Applied Linear Algebra');
      expect(read.first['docId'], 'abc123');

      // The date field is revived as a Timestamp so the feed formats it as a
      // date rather than rendering a raw ISO string.
      expect(read.first['createdAt'], isA<Timestamp>());
    });

    test('saveMaterials survives nested maps and lists', () async {
      final saved = await CacheService().saveMaterials([
        {
          'title': 'Nested',
          'createdAt': Timestamp.fromDate(DateTime(2026, 3, 4)),
          'meta': {
            'tags': ['a', 'b'],
            'nested': {'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1))},
          },
        },
      ]);
      expect(saved, isTrue);
      expect(CacheService().getMaterials()!.first['meta'], isA<Map<String, dynamic>>());
    });

    test('materials cache honours the staleness window', () async {
      expect(CacheService().isMaterialsCacheStale, isTrue,
          reason: 'no cache yet means stale');

      await CacheService().saveMaterials([
        {
          'title': 'Fresh',
          'createdAt': Timestamp.fromDate(DateTime.now()),
        }
      ]);

      expect(CacheService().isMaterialsCacheStale, isFalse);
      expect(CacheService().getFreshMaterials().length, 1);
    });

    test('last-read marker round-trips', () async {
      final when = DateTime.now().subtract(const Duration(hours: 3));
      await CacheService().setLastReadAt(when);
      expect(CacheService().getLastReadAt(), isNotNull);
      expect(
        CacheService().getLastReadAt()!.difference(when).inSeconds.abs(),
        lessThanOrEqualTo(1),
      );
    });
  });

  group('Nexus material URL handling', () {
    // Mirrors _resolveDownloadUrl in lib/screens/nexus/nexus_screen.dart.
    String resolve(String raw) {
      final url = raw.trim();
      if (url.isEmpty) return '';
      if (url.contains('huggingface.co') && (url.contains('.part') || url.contains('parts='))) {
        final baseUrl = url.split('?')[0].replaceAll(RegExp(r'\.part\d+$'), '');
        return '$baseUrl?download=true';
      }
      return url;
    }

    test('strips Hugging Face chunk markers', () {
      expect(
        resolve('https://huggingface.co/datasets/x/big.pdf.part0?parts=5'),
        'https://huggingface.co/datasets/x/big.pdf?download=true',
      );
    });

    test('passes a normal URL through unchanged', () {
      const url = 'https://huggingface.co/datasets/x/notes.pdf?download=true';
      expect(resolve(url), url);
    });

    test('no longer substitutes one document for another', () {
      // The old code remapped a dead GitHub release URL to a Hugging Face file
      // with a *different* name, silently serving the wrong document.
      const dead = 'https://github.com/o/r/releases/download/materials-v1/'
          '1786383825722_Linear_algebra.pdf';
      expect(resolve(dead), dead);
    });
  });

  group('Nexus role vocabulary', () {
    // Mirrors NexusService.roleIsApproved and the NEXUS project's
    // pending / friend / admin vocabulary (index.html + admin.html).
    const rolePending = 'pending';
    const roleFriend = 'friend';
    const roleAdmin = 'admin';

    bool roleIsApproved(String? role) => role == roleFriend || role == roleAdmin;

    test('friend and admin are approved', () {
      expect(roleIsApproved(roleFriend), isTrue);
      expect(roleIsApproved(roleAdmin), isTrue);
    });

    test('pending and unknown roles are not approved', () {
      expect(roleIsApproved(rolePending), isFalse);
      expect(roleIsApproved('student'), isFalse,
          reason: 'Nexora-internal role must not leak into Nexus logic');
      expect(roleIsApproved(null), isFalse);
      expect(roleIsApproved(''), isFalse);
    });

    test('the `approved` flag is not the signal', () {
      // Nexus writes `approved: false` at creation and never sets it true —
      // not even in its own admin panel. Gating on it made the check
      // permanently false.
      const nexusUser = {'role': 'friend', 'approved': false};
      expect(roleIsApproved(nexusUser['role'] as String), isTrue);
    });

    test('Nexora role maps to a Nexus role, never a new one', () {
      // The WebView bridge writes into nexus_user_role_<uid>, which Nexus reads
      // back as a fallback. It must only ever contain a value Nexus knows.
      String map(String nexoraRole) =>
          (nexoraRole == 'superadmin' || nexoraRole == 'admin') ? 'admin' : 'friend';

      expect(map('student'), roleFriend);
      expect(map('admin'), roleAdmin);
      expect(map('superadmin'), roleAdmin);
      for (final r in ['student', 'admin', 'superadmin']) {
        expect([rolePending, roleFriend, roleAdmin], contains(map(r)));
      }
    });
  });

  group('AuthGate approval predicate', () {
    /// Mirrors the fixed predicate in lib/screens/auth/auth_gate.dart.
    bool isApproved(Map<String, dynamic> data) {
      final status = (data['status'] ?? '').toString().trim();
      if (status.isNotEmpty) return status == 'approved';
      final approvedBy = (data['approvedBy'] ?? '').toString().trim();
      if (approvedBy.isNotEmpty) return true;
      final role = (data['role'] ?? '').toString().trim();
      return role == 'admin' || role == 'superadmin';
    }

    test('rejects an arbitrary non-empty role', () {
      // The old predicate (`role.isNotEmpty && role != 'candidate'`) passed
      // this, because nothing ever wrote 'candidate'.
      expect(isApproved({'role': 'garbage'}), isFalse);
      expect(isApproved({'role': 'pending'}), isFalse);
      expect(isApproved({'role': 'candidate'}), isFalse);
    });

    test('accepts an explicit approval signal', () {
      expect(isApproved({'status': 'approved'}), isTrue);
      expect(isApproved({'approvedBy': 'admin-uid'}), isTrue);
      expect(isApproved({'role': 'admin'}), isTrue);
      expect(isApproved({'role': 'superadmin'}), isTrue);
    });

    test('an explicit non-approved status overrides other fields', () {
      expect(isApproved({'status': 'rejected', 'role': 'admin'}), isFalse);
    });

    test('rejects a student with no approval signal', () {
      expect(isApproved({'role': 'student'}), isFalse);
      expect(isApproved({}), isFalse);
    });
  });
}
