import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../core/config/app_config.dart';

/// A member's standing in the Nexus community, as read from Nexora.
class NexusMember {
  /// The Nexus document id, which is also the Nexus Auth UID. Never a Nexora
  /// UID — the two projects have separate Auth instances.
  final String nexusDocId;

  final String email;
  final String? name;

  /// One of `pending`, `friend`, `admin`.
  final String role;

  /// True when a Nexus admin has approved this person (`friend` or `admin`).
  final bool isApproved;

  const NexusMember({
    required this.nexusDocId,
    required this.email,
    required this.role,
    required this.isApproved,
    this.name,
  });
}

/// Read-only view of a member's standing in the Nexus community
/// (Firebase project `nexus-e7a36`).
///
/// ## Read-only by design
///
/// Nexora never writes to Nexus. Nexus is a live, working community platform
/// with its own admins and its own approval flow, and Nexora is a read-only
/// mirror of it. This service therefore performs **reads only** — it does not
/// create, update, or delete a single Nexus document.
///
/// ## Direction of truth
///
/// **Nexus is the source of truth for community membership.** A person approved
/// by a Nexus admin (`role: 'friend'` or `'admin'`) is auto-approved in Nexora.
/// Nexora never grants Nexus membership; only a Nexus admin can do that.
///
/// ## Authentication
///
/// The Nexus `users` collection is not world-readable, so every read here runs
/// as a signed-in user. Without a session, lookups are rejected and
/// [lastLookupError] records why — a denied read is deliberately distinguishable
/// from "no such member", which is what previously made this silently useless.
///
/// ## Keying
///
/// The two projects have separate Auth instances, so the same Google account has
/// a **different UID in each**. Everything is matched on normalised email.
class NexusService {
  static final NexusService _instance = NexusService._internal();
  factory NexusService() => _instance;
  NexusService._internal();

  static FirebaseOptions get kOptions => FirebaseOptions(
    apiKey: AppConfig.nexusFirebaseApiKey,
    appId: AppConfig.nexusFirebaseAppId,
    messagingSenderId: AppConfig.nexusFirebaseMessagingSenderId,
    projectId: AppConfig.nexusFirebaseProjectId,
    authDomain: AppConfig.nexusFirebaseAuthDomain,
    storageBucket: AppConfig.nexusFirebaseStorageBucket,
    databaseURL: AppConfig.nexusFirebaseDatabaseUrl,
  );

  static const int defaultPageSize = 20;

  static const String _materialsCollection = 'materials';
  static const String _usersCollection = 'users';

  /// Nexus role vocabulary, from index.html / admin.html in the NEXUS project.
  /// `pending` is the only state without materials access; `friend` and `admin`
  /// both have it, and only `admin` unlocks the Nexus admin portal.
  static const String rolePending = 'pending';
  static const String roleFriend = 'friend';
  static const String roleAdmin = 'admin';

  FirebaseApp? _nexusApp;
  FirebaseFirestore? _firestore;
  bool _initialized = false;
  String? _initError;
  Future<void>? _initInFlight;

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------

  /// Initialise the secondary Nexus Firebase app.
  ///
  /// Memoised through an in-flight future so concurrent callers (app startup,
  /// the Nexus tab, and the registration flow) cannot race into a
  /// `[core/duplicate-app]` failure.
  Future<void> initialize() {
    if (_initialized && _firestore != null) return Future.value();
    return _initInFlight ??= _initializeOnce();
  }

  Future<void> _initializeOnce() async {
    try {
      FirebaseApp? existing;
      for (final app in Firebase.apps) {
        if (app.name == 'nexus_app') {
          existing = app;
          break;
        }
      }
      _nexusApp = existing ??
          await Firebase.initializeApp(name: 'nexus_app', options: kOptions);
      _firestore = FirebaseFirestore.instanceFor(app: _nexusApp!);
      _initialized = true;
      _initError = null;
    } catch (e) {
      _initError = e.toString();
      _initialized = false;
      debugPrint('[NexusService] Initialize failed: $_initError');
    } finally {
      _initInFlight = null;
    }
  }

  FirebaseFirestore? get firestore => _firestore;

  bool get isReady => _firestore != null;

  /// Human-readable reason the Nexus backend is unavailable, if any.
  String? get initializationError => _initError;

  /// Error code from the most recent Nexus lookup, if any.
  ///
  /// Set when a read was *rejected or failed*, which is deliberately distinct
  /// from a successful read that found nothing.
  String? lastLookupError;

  // ---------------------------------------------------------------------------
  // Authentication (read-only access)
  // ---------------------------------------------------------------------------

  /// True once a session exists on the Nexus project.
  bool get isSignedIn {
    final app = _nexusApp;
    if (app == null) return false;
    try {
      return FirebaseAuth.instanceFor(app: app).currentUser != null;
    } catch (_) {
      return false;
    }
  }

  /// Sign in to the Nexus project using the *existing* Google credential.
  ///
  /// Nexus and Nexora are separate Auth instances, so this creates a distinct
  /// Nexus session for the same human. It grants **read** access to the Nexus
  /// `users` collection and nothing else — the app never writes to Nexus.
  ///
  /// Returns false (without throwing) when the sign-in cannot be completed, so
  /// a failure here can never block a Nexora user from signing in.
  Future<bool> signInToNexus({
    required String idToken,
    required String accessToken,
  }) async {
    try {
      await initialize();
      final app = _nexusApp;
      if (app == null) {
        debugPrint('[NexusService] sign-in skipped: app not initialised');
        return false;
      }

      final auth = FirebaseAuth.instanceFor(app: app);
      if (auth.currentUser != null) return true;

      final credential = GoogleAuthProvider.credential(
        idToken: idToken,
        accessToken: accessToken,
      );
      await auth.signInWithCredential(credential);
      debugPrint('[NexusService] signed in to Nexus (read-only session)');
      return true;
    } catch (e) {
      debugPrint('[NexusService] Nexus sign-in failed: $e');
      return false;
    }
  }

  /// Sign out of the Nexus project. Does not affect the Nexora session.
  Future<void> signOutOfNexus() async {
    try {
      final app = _nexusApp;
      if (app == null) return;
      await FirebaseAuth.instanceFor(app: app).signOut();
    } catch (e) {
      debugPrint('[NexusService] sign-out failed: $e');
    }
  }

  /// Establish a read-only Nexus session from an already-authenticated Nexora
  /// user, for flows that cannot hand over the raw Google tokens (the web popup
  /// path, or an email/password account).
  ///
  /// The two projects have separate Auth instances, so this cannot simply
  /// borrow the Nexora session. It re-authenticates with Google using a
  /// silent prompt, which is the only way to obtain a Nexus ID token for the
  /// same human. Failure is non-fatal.
  Future<bool> signInToNexusWithAccount(User? nexoraUser) async {
    if (nexoraUser == null) return false;
    try {
      await initialize();
      final app = _nexusApp;
      if (app == null) return false;

      final auth = FirebaseAuth.instanceFor(app: app);
      if (auth.currentUser != null) return true;

      // Requires the user to already be authenticated with Google in Nexora.
      final googleUser = await GoogleSignIn().signInSilently();
      if (googleUser == null) return false;
      final googleAuth = await googleUser.authentication;
      if (googleAuth.idToken == null || googleAuth.accessToken == null) return false;

      await auth.signInWithCredential(
        GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
          accessToken: googleAuth.accessToken,
        ),
      );
      debugPrint('[NexusService] signed in to Nexus via silent Google auth');
      return true;
    } catch (e) {
      debugPrint('[NexusService] silent Nexus sign-in unavailable: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Materials (read-only)
  // ---------------------------------------------------------------------------

  /// Materials base query, shared by the first page and every subsequent page so
  /// ordering and paging can never drift apart.
  Query<Map<String, dynamic>> _materialsQuery({
    DocumentSnapshot<Map<String, dynamic>>? after,
  }) {
    var query = _firestore!
        .collection(_materialsCollection)
        .orderBy('createdAt', descending: true)
        .limit(defaultPageSize);
    if (after != null) query = query.startAfterDocument(after);
    return query;
  }

  /// Live stream of the materials collection.
  ///
  /// Returns `null` (rather than an empty stream) when Nexus is unavailable, so
  /// the UI can distinguish "backend unreachable" from "no documents" instead of
  /// rendering a misleading "No materials found".
  Stream<QuerySnapshot<Map<String, dynamic>>>? watchMaterials() {
    if (_firestore == null) return null;
    return _materialsQuery().snapshots();
  }

  /// Loads the page following [after], using the same ordering as
  /// [watchMaterials].
  Future<List<DocumentSnapshot<Map<String, dynamic>>>> loadMoreMaterials({
    DocumentSnapshot<Map<String, dynamic>>? after,
  }) async {
    if (_firestore == null) return const [];
    final snap = await _materialsQuery(after: after).get();
    return snap.docs;
  }

  /// Total documents in the Nexus `materials` collection.
  ///
  /// Used to verify that the native feed and the Nexus PWA show the same set.
  Future<int?> countMaterials() async {
    if (_firestore == null) return null;
    try {
      final snap = await _firestore!.collection(_materialsCollection).count().get();
      return snap.count;
    } catch (e) {
      debugPrint('[NexusService] countMaterials failed: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Members (read-only)
  // ---------------------------------------------------------------------------

  /// Whether a Nexus role represents an approved community member.
  static bool roleIsApproved(String? role) =>
      role == roleFriend || role == roleAdmin;

  /// One-shot lookup of a Nexus member by email.
  ///
  /// Returns null when no document matched **or** when the read was not
  /// permitted. Check [lastLookupError] to tell those apart — conflating them
  /// is what previously made this integration silently no-op.
  Future<NexusMember?> lookupMember(String email) async {
    lastLookupError = null;
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty) return null;

    try {
      await initialize();
      if (_firestore == null) {
        lastLookupError = initializationError ?? 'Nexus backend unavailable';
        return null;
      }

      final query = await _firestore!
          .collection(_usersCollection)
          .where('email', isEqualTo: cleanEmail)
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;

      final doc = query.docs.first;
      final data = doc.data();
      final role = (data['role'] ?? rolePending).toString().toLowerCase();

      return NexusMember(
        nexusDocId: doc.id,
        email: (data['email'] ?? cleanEmail).toString(),
        name: data['name']?.toString(),
        role: role,
        isApproved: roleIsApproved(role),
      );
    } on FirebaseException catch (e) {
      lastLookupError = e.code;
      debugPrint('[NexusService] member lookup denied/failed: ${e.code}');
      return null;
    } catch (e) {
      lastLookupError = e.toString();
      debugPrint('[NexusService] member lookup failed: $e');
      return null;
    }
  }

  /// Whether a Nexus admin has already approved this person.
  ///
  /// Used to auto-approve them in Nexora without a second review.
  Future<bool> isApprovedInNexus(String email) async {
    final member = await lookupMember(email);
    return member?.isApproved ?? false;
  }

  /// Live listener for a member's Nexus standing.
  ///
  /// This is the real-time half of the mirror: when a Nexus admin promotes
  /// someone from `pending` to `friend`, the returned stream emits and Nexora
  /// can auto-approve them immediately — no refresh, no second gate.
  ///
  /// Emits `null` when the member is not (yet) in Nexus. A read error is
  /// surfaced through [lastLookupError] and terminates the stream, because a
  /// denied read must not be mistaken for "not a member".
  Stream<NexusMember?> watchMember(String email) {
    final cleanEmail = email.trim().toLowerCase();

    if (_firestore == null || cleanEmail.isEmpty) {
      return Stream<NexusMember?>.value(null);
    }

    return _firestore!
        .collection(_usersCollection)
        .where('email', isEqualTo: cleanEmail)
        .limit(1)
        .snapshots()
        .map((snap) {
          lastLookupError = null;
          if (snap.docs.isEmpty) return null;
          final doc = snap.docs.first;
          final data = doc.data();
          final role = (data['role'] ?? rolePending).toString().toLowerCase();
          return NexusMember(
            nexusDocId: doc.id,
            email: (data['email'] ?? cleanEmail).toString(),
            name: data['name']?.toString(),
            role: role,
            isApproved: roleIsApproved(role),
          );
        })
        .handleError((Object error) {
          if (error is FirebaseException) {
            lastLookupError = error.code;
          } else {
            lastLookupError = error.toString();
          }
          debugPrint('[NexusService] member watch error: $error');
        });
  }
}
