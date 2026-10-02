import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Offline cache for notes, Nexus materials, user profile, members directory,
/// and course catalog.
///
/// Firestore documents carry values Hive cannot serialise (`Timestamp`,
/// `GeoPoint`, `DocumentReference`, …), so every payload is normalised to
/// primitives before it is written. Without this step any `put()` containing a
/// `Timestamp` throws `HiveError: Cannot write, unknown type` and the cache
/// silently stays empty.
class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  static const String _notesBox = 'nexora_notes_box';
  static const String _materialsBox = 'nexus_materials_box';
  static const String _userProfileBox = 'user_profile_box';
  static const String _membersBox = 'nexora_members_box';
  static const String _courseCatalogBox = 'course_catalog_box';

  static const String _notesKey = 'nexora_notes';
  static const String _materialsKey = 'nexus_materials';
  static const String _membersKey = 'nexora_members_list';
  static const String _coursesKey = 'nexora_course_catalog';
  static const String _lastReadKey = 'nexora_last_read_at';

  /// Cache TTLs
  static const Duration materialsTtl = Duration(minutes: 30);
  static const Duration membersTtl = Duration(minutes: 15);
  static const Duration courseCatalogTtl = Duration(hours: 24);

  Box? _notesCache;
  Box? _materialsCache;
  Box? _userProfileCache;
  Box? _membersCache;
  Box? _courseCatalogCache;

  /// Opens all application Hive cache boxes.
  ///
  /// Checks `isOpen` rather than relying on a null handle: a box that was
  /// closed leaves a non-null reference, and the cached handle would then fail
  /// every subsequent write.
  Future<void> init() async {
    if (_notesCache == null || !_notesCache!.isOpen) {
      _notesCache = await Hive.openBox(_notesBox);
    }
    if (_materialsCache == null || !_materialsCache!.isOpen) {
      _materialsCache = await Hive.openBox(_materialsBox);
    }
    if (_userProfileCache == null || !_userProfileCache!.isOpen) {
      _userProfileCache = await Hive.openBox(_userProfileBox);
    }
    if (_membersCache == null || !_membersCache!.isOpen) {
      _membersCache = await Hive.openBox(_membersBox);
    }
    if (_courseCatalogCache == null || !_courseCatalogCache!.isOpen) {
      _courseCatalogCache = await Hive.openBox(_courseCatalogBox);
    }
  }

  // ---------------------------------------------------------------------------
  // Normalisation
  // ---------------------------------------------------------------------------

  /// Converts a Firestore value into something Hive can store.
  ///
  /// `Timestamp` becomes an ISO-8601 string so the feed can rebuild a
  /// `DateTime` (or `Timestamp`) on read. Unknown objects degrade to their
  /// `toString()` rather than aborting the whole write.
  static Object? _normalise(Object? value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is DateTime) return value.toIso8601String();
    if (value is num || value is bool || value is String) return value;
    if (value is Map) {
      return value.map<String, dynamic>(
        (k, v) => MapEntry(k.toString(), _normalise(v)),
      );
    }
    if (value is Iterable) return value.map(_normalise).toList();
    return value.toString();
  }

  static List<Map<String, dynamic>> _normaliseList(List<Map<String, dynamic>> items) {
    return items
        .map((e) => e.map<String, dynamic>((k, v) => MapEntry(k, _normalise(v))))
        .toList(growable: false);
  }

  /// Reverses [_normalise] for known date fields so callers keep receiving
  /// the type they expect instead of a raw ISO string.
  static Object? _revive(Object? value, String key) {
    const dateKeys = {
      'createdAt',
      'timestamp',
      'cached_at',
      'updatedAt',
      'submittedAt',
      'approvedAt',
    };
    if (value is String && dateKeys.contains(key)) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return Timestamp.fromDate(parsed);
    }
    return value;
  }

  static Map<String, dynamic> _reviveMap(Map<dynamic, dynamic> raw) {
    final out = <String, dynamic>{};
    raw.forEach((k, v) {
      if (v is Map) {
        out[k.toString()] = _reviveMap(v);
      } else if (v is List) {
        out[k.toString()] = v.map((item) {
          if (item is Map) return _reviveMap(item);
          return item;
        }).toList();
      } else {
        out[k.toString()] = _revive(v, k.toString());
      }
    });
    return out;
  }

  List<Map<String, dynamic>>? _readList(Box? box, String key) {
    final raw = box?.get(key);
    if (raw == null) return null;
    final data = raw['data'];
    if (data is! List) return null;
    return data
        .whereType<Map>()
        .map(_reviveMap)
        .toList(growable: false);
  }

  DateTime? _readCachedAt(Box? box, String key) {
    final raw = box?.get(key);
    if (raw == null) return null;
    final ts = raw['cached_at'];
    if (ts is String) return DateTime.tryParse(ts);
    return null;
  }

  // ---------------------------------------------------------------------------
  // User Profile (instant splash-less cold launch)
  // ---------------------------------------------------------------------------

  /// Persists a user's verified profile data locally.
  Future<void> saveUserProfile(String uid, Map<String, dynamic> data) async {
    try {
      await init();
      await _userProfileCache!.put(uid, {
        'data': _normalise(data),
        'cached_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[CacheService] saveUserProfile failed: $e');
    }
  }

  /// Synchronously loads the cached user profile for instant launch.
  Map<String, dynamic>? getUserProfile(String uid) {
    final raw = _userProfileCache?.get(uid);
    if (raw == null) return null;
    final data = raw['data'];
    if (data is! Map) return null;
    return _reviveMap(data);
  }

  DateTime? getUserProfileCachedAt(String uid) => _readCachedAt(_userProfileCache, uid);

  Future<void> clearUserProfile(String uid) async {
    await init();
    await _userProfileCache?.delete(uid);
  }

  // ---------------------------------------------------------------------------
  // Members directory (15 minute TTL)
  // ---------------------------------------------------------------------------

  /// Caches the verified members list for fast directory loading.
  Future<void> saveMembers(List<Map<String, dynamic>> members) async {
    try {
      await init();
      await _membersCache!.put(_membersKey, {
        'data': _normaliseList(members),
        'cached_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[CacheService] saveMembers failed: $e');
    }
  }

  /// Returns cached members list if present.
  List<Map<String, dynamic>>? getMembers() => _readList(_membersCache, _membersKey);

  DateTime? getMembersCachedAt() => _readCachedAt(_membersCache, _membersKey);

  /// Whether cached members are missing or older than [membersTtl].
  bool get isMembersCacheStale {
    final cachedAt = getMembersCachedAt();
    if (cachedAt == null) return true;
    return DateTime.now().difference(cachedAt) > membersTtl;
  }

  /// Convenience: cached members or empty list when missing or stale.
  List<Map<String, dynamic>> getFreshMembers() {
    if (isMembersCacheStale) return const [];
    return getMembers() ?? const [];
  }

  Future<void> clearMembers() async {
    await init();
    await _membersCache?.delete(_membersKey);
  }

  // ---------------------------------------------------------------------------
  // Course Catalog (24 hour TTL)
  // ---------------------------------------------------------------------------

  /// Caches active course catalog options.
  Future<void> saveCourseNames(List<String> courseNames) async {
    try {
      await init();
      await _courseCatalogCache!.put(_coursesKey, {
        'data': courseNames,
        'cached_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[CacheService] saveCourseNames failed: $e');
    }
  }

  /// Synchronously returns cached course catalog names.
  List<String>? getCourseNames() {
    final raw = _courseCatalogCache?.get(_coursesKey);
    if (raw == null) return null;
    final data = raw['data'];
    if (data is! List) return null;
    return data.map((e) => e.toString()).toList();
  }

  DateTime? getCourseNamesCachedAt() => _readCachedAt(_courseCatalogCache, _coursesKey);

  /// Whether cached course catalog is missing or older than [courseCatalogTtl].
  bool get isCourseCatalogStale {
    final cachedAt = getCourseNamesCachedAt();
    if (cachedAt == null) return true;
    return DateTime.now().difference(cachedAt) > courseCatalogTtl;
  }

  /// Convenience: returns cached course names if within the 24 hour TTL.
  List<String>? getFreshCourseNames() {
    if (isCourseCatalogStale) return null;
    return getCourseNames();
  }

  Future<void> clearCourseCatalog() async {
    await init();
    await _courseCatalogCache?.delete(_coursesKey);
  }

  // ---------------------------------------------------------------------------
  // Notes
  // ---------------------------------------------------------------------------

  Future<void> saveNotes(List<Map<String, dynamic>> notes) async {
    await init();
    await _notesCache!.put(_notesKey, {
      'data': _normaliseList(notes),
      'cached_at': DateTime.now().toIso8601String(),
    });
  }

  List<Map<String, dynamic>>? getNotes() => _readList(_notesCache, _notesKey);

  DateTime? getNotesCachedAt() => _readCachedAt(_notesCache, _notesKey);

  // ---------------------------------------------------------------------------
  // Nexus materials
  // ---------------------------------------------------------------------------

  Future<bool> saveMaterials(List<Map<String, dynamic>> materials) async {
    try {
      await init();
      await _materialsCache!.put(_materialsKey, {
        'data': _normaliseList(materials),
        'cached_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('[CacheService] saveMaterials failed: $e');
      return false;
    }
  }

  List<Map<String, dynamic>>? getMaterials() => _readList(_materialsCache, _materialsKey);

  DateTime? getMaterialsCachedAt() => _readCachedAt(_materialsCache, _materialsKey);

  bool get isMaterialsCacheStale {
    final cachedAt = getMaterialsCachedAt();
    if (cachedAt == null) return true;
    return DateTime.now().difference(cachedAt) > materialsTtl;
  }

  List<Map<String, dynamic>> getFreshMaterials() {
    if (isMaterialsCacheStale) return const [];
    return getMaterials() ?? const [];
  }

  Future<void> clearMaterials() async {
    await init();
    await _materialsCache!.delete(_materialsKey);
  }

  // ---------------------------------------------------------------------------
  // Notification read marker (survives restarts)
  // ---------------------------------------------------------------------------

  DateTime? getLastReadAt() => _readCachedAt(_materialsCache, _lastReadKey);

  Future<void> setLastReadAt(DateTime when) async {
    try {
      await init();
      await _materialsCache!.put(_lastReadKey, {'cached_at': when.toIso8601String()});
    } catch (e) {
      debugPrint('[CacheService] setLastReadAt failed: $e');
    }
  }

  Future<void> clearAll() async {
    await init();
    await _notesCache?.clear();
    await _materialsCache?.clear();
    await _userProfileCache?.clear();
    await _membersCache?.clear();
    await _courseCatalogCache?.clear();
    await _materialsCache?.delete(_lastReadKey);
  }
}