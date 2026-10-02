import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../services/nexus_service.dart';

/// Top-level background message handler for FCM.
/// Must be annotated with `@pragma('vm:entry-point')` so Flutter's isolate
/// can invoke it when the app is terminated or in the background.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  debugPrint('[FCM Background] Received message ID: ${message.messageId}');

  // If message contains data payload and no notification block, display local notification
  if (message.notification == null && message.data.isNotEmpty) {
    final title = message.data['title']?.toString() ?? 'Nexora Notification';
    final body = message.data['body']?.toString() ??
        message.data['message']?.toString() ??
        '';
    if (body.isNotEmpty) {
      await PushNotificationService.showBackgroundLocalNotification(
        title: title,
        body: body,
        payload: message.data,
      );
    }
  }
}

/// Centralized Push Notification & FCM management service for Nexora.
class PushNotificationService {
  PushNotificationService._internal();
  static final PushNotificationService instance =
      PushNotificationService._internal();
  factory PushNotificationService() => instance;

  static const String channelId = 'nexora_high_importance_channel';
  static const String channelName = 'Nexora Notifications';
  static const String channelDescription =
      'High-priority alerts for approvals, notes, and Nexus academic materials.';

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  bool _initialized = false;
  GlobalKey<NavigatorState>? navigatorKey;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _materialsSubscription;
  final Set<String> _seenMaterialIds = {};
  bool _initialMaterialsLoaded = false;

  /// Initializes FCM listeners, permissions, local notifications channel,
  /// and auth token sync.
  Future<void> initialize({GlobalKey<NavigatorState>? navKey}) async {
    if (_initialized) return;
    navigatorKey = navKey;

    try {
      // 1. Register top-level background handler
      if (!kIsWeb) {
        FirebaseMessaging.onBackgroundMessage(
            firebaseMessagingBackgroundHandler);
      }

      // 2. Setup Flutter Local Notifications
      await _initLocalNotifications();

      // 3. Request FCM Permissions
      await requestPermission();

      // 4. Foreground notification presentation options (iOS/macOS)
      if (!kIsWeb) {
        await _fcm.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      // 5. Setup foreground notification listener
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[FCM Foreground] Got message: ${message.messageId}');
        _handleForegroundMessage(message);
      });

      // 6. Handle notification click when app is opened from background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('[FCM OpenedApp] User tapped notification: ${message.data}');
        _handleNotificationTap(message.data);
      });

      // 7. Check if app was opened from terminated state via notification click
      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[FCM Terminated] App launched via notification: ${initialMessage.data}');
        _handleNotificationTap(initialMessage.data);
      }

      // 8. Listen to token refreshes
      _fcm.onTokenRefresh.listen((newToken) {
        debugPrint('[FCM] Token refreshed: $newToken');
        saveTokenToFirestore(token: newToken);
      });

      // 9. Sync FCM token on every login state change
      FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user != null) {
          saveTokenToFirestore();
        }
      });

      // 10. Automatically watch for new Nexus materials to notify members
      startNexusMaterialsWatcher();

      _initialized = true;
      debugPrint('[PushNotificationService] Initialized successfully.');
    } catch (e) {
      debugPrint('[PushNotificationService] Initialization error: $e');
    }
  }

  /// Configures local notification channels and plugins.
  Future<void> _initLocalNotifications() async {
    if (kIsWeb) return;

    const androidSettings = AndroidInitializationSettings('@drawable/ic_notification');

    const initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload != null && response.payload!.isNotEmpty) {
          try {
            final data = jsonDecode(response.payload!) as Map<String, dynamic>;
            _handleNotificationTap(data);
          } catch (_) {
            _handleNotificationTap({'payload': response.payload});
          }
        }
      },
    );

    // Create high-importance Android channel
    if (Platform.isAndroid) {
      const androidChannel = AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDescription,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);
    }
  }

  /// Request push notification permissions.
  Future<NotificationSettings> requestPermission() async {
    final settings = await _fcm.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');
    return settings;
  }

  /// Retrieves the current FCM token and commits it to `users/{uid}/fcmToken`
  /// in Cloud Firestore with a server timestamp.
  Future<void> saveTokenToFirestore({String? token}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('[FCM] No signed-in user; skipping token persistence.');
      return;
    }

    try {
      final fcmToken = token ?? await _fcm.getToken();
      if (fcmToken == null || fcmToken.isEmpty) {
        debugPrint('[FCM] Token is empty; skipping Firestore write.');
        return;
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fcmToken': fcmToken,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint(
          '[FCM] Successfully persisted token for user ${user.uid} (${fcmToken.substring(0, 12)}...)');
    } catch (e) {
      debugPrint('[FCM] Failed to save FCM token to Firestore: $e');
    }
  }

  /// Shows foreground banner notification when app is currently open.
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title']?.toString() ?? 'Nexora Notification';
    final body = notification?.body ?? message.data['body']?.toString() ?? message.data['message']?.toString() ?? '';

    if (body.isEmpty) return;

    await showLocalNotification(
      title: title,
      body: body,
      payload: message.data,
    );
  }

  /// Handles notification tap and directs user to the relevant screen.
  void _handleNotificationTap(Map<String, dynamic> data) {
    debugPrint('[PushNotificationService] Handling tap with data: $data');
    final type = data['type']?.toString();
    final context = navigatorKey?.currentContext;

    if (context == null) return;

    if (type == 'new_note') {
      Navigator.of(context).pushNamed('/shell');
    } else if (type == 'new_candidate_registration') {
      Navigator.of(context).pushNamed('/shell');
    } else if (type == 'new_material') {
      Navigator.of(context).pushNamed('/shell');
    }
  }

  /// Displays an in-app system notification via FlutterLocalNotificationsPlugin.
  Future<void> showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? payload,
    int? id,
  }) async {
    if (kIsWeb) return;

    final notifId = id ?? DateTime.now().millisecondsSinceEpoch.remainder(100000);
    final jsonPayload = payload != null ? jsonEncode(payload) : null;

    const androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@drawable/ic_notification',
      color: Color(0xFF4F8BFF),
      playSound: true,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(''),
    );

    const details = NotificationDetails(
      android: androidDetails,
    );

    await _localNotifications.show(
      notifId,
      title,
      body,
      details,
      payload: jsonPayload,
    );
  }

  /// Static helper for background isolate execution.
  static Future<void> showBackgroundLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    final plugin = FlutterLocalNotificationsPlugin();
    final notifId = DateTime.now().millisecondsSinceEpoch.remainder(100000);

    const androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@drawable/ic_notification',
      color: Color(0xFF4F8BFF),
      styleInformation: BigTextStyleInformation(''),
    );

    await plugin.show(
      notifId,
      title,
      body,
      const NotificationDetails(android: androidDetails),
      payload: payload != null ? jsonEncode(payload) : null,
    );
  }

  // ---------------------------------------------------------------------------
  // Step 4: Event-driven Notification Dispatchers
  // ---------------------------------------------------------------------------

  /// Trigger 1: Admin approval/rejection → notify student.
  /// Trigger: When admin taps approve or reject in `admin_portal_screen.dart`.
  Future<void> notifyStudentApproval({
    required String studentUid,
    required String studentName,
    required bool approved,
  }) async {
    final title = approved ? 'Registration Approved' : 'Registration Status';
    final body = approved
        ? 'Your Nexora registration has been approved! Welcome.'
        : 'Your registration was not approved.';

    try {
      // 1. Write to targeted user notifications collection
      await FirebaseFirestore.instance
          .collection('users')
          .doc(studentUid)
          .collection('notifications')
          .add({
        'type': approved ? 'registration_approved' : 'registration_rejected',
        'title': title,
        'body': body,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      // 2. Queue in push_notifications for cloud dispatch
      await FirebaseFirestore.instance.collection('push_notifications').add({
        'targetUid': studentUid,
        'title': title,
        'body': body,
        'data': {
          'type': approved ? 'registration_approved' : 'registration_rejected',
          'studentUid': studentUid,
        },
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('[PushNotificationService] Dispatched student approval notification to $studentUid');
    } catch (e) {
      debugPrint('[PushNotificationService] notifyStudentApproval error: $e');
    }

    // If current signed-in device matches candidate (e.g. testing), show banner
    if (FirebaseAuth.instance.currentUser?.uid == studentUid) {
      await showLocalNotification(
        title: title,
        body: body,
        payload: {'type': approved ? 'approved' : 'rejected'},
      );
    }
  }

  /// Trigger 2: New member registration → notify admins.
  /// Trigger: When new candidate registers in `auth_service.dart`.
  Future<void> notifyAdminsNewRegistration({
    required String candidateName,
    required String candidateUid,
    required String regNo,
    required String branch,
  }) async {
    const title = 'New Registration Pending';
    final body = 'New student registration pending your approval in Nexora: $candidateName ($regNo).';

    try {
      // Queue in push_notifications targeted to all admin tokens
      await FirebaseFirestore.instance.collection('push_notifications').add({
        'targetRole': 'admin',
        'title': title,
        'body': body,
        'data': {
          'type': 'new_candidate_registration',
          'candidateUid': candidateUid,
          'candidateName': candidateName,
          'regNo': regNo,
          'branch': branch,
        },
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint('[PushNotificationService] Queued admin alert for candidate $candidateName');
    } catch (e) {
      debugPrint('[PushNotificationService] notifyAdminsNewRegistration error: $e');
    }

    // If signed-in user is already admin on this device, show local alert
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(currentUid).get();
        final role = doc.data()?['role']?.toString();
        if (role == 'admin' || role == 'superadmin') {
          await showLocalNotification(
            title: title,
            body: body,
            payload: {'type': 'new_candidate_registration', 'uid': candidateUid},
          );
        }
      } catch (_) {}
    }
  }

  /// Trigger 3: New note posted → notify all members.
  /// Trigger: When note is published in `post_note_sheet.dart`.
  Future<void> notifyAllNewNote({
    required String uploaderName,
    required String title,
    required String noteId,
  }) async {
    const notifTitle = 'New Academic Note';
    final effectiveTitle = title.trim().isEmpty ? 'Academic Note' : title.trim();
    final notifBody = '$uploaderName posted a new note: $effectiveTitle';

    try {
      await FirebaseFirestore.instance.collection('push_notifications').add({
        'targetTopic': 'all_members',
        'title': notifTitle,
        'body': notifBody,
        'data': {
          'type': 'new_note',
          'noteId': noteId,
          'uploaderName': uploaderName,
          'title': effectiveTitle,
        },
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint('[PushNotificationService] Queued broadcast notification for note $noteId');
    } catch (e) {
      debugPrint('[PushNotificationService] notifyAllNewNote error: $e');
    }
  }

  /// Trigger 4: New Nexus material uploaded → notify all members.
  /// Trigger: Detected via Nexus Firestore stream when new material appears.
  Future<void> notifyAllNewMaterial({
    required String subject,
    required String title,
  }) async {
    const notifTitle = 'New Nexus Material';
    final notifBody = 'New $subject material uploaded to Nexus: $title';

    try {
      await FirebaseFirestore.instance.collection('push_notifications').add({
        'targetTopic': 'all_members',
        'title': notifTitle,
        'body': notifBody,
        'data': {
          'type': 'new_material',
          'subject': subject,
          'title': title,
        },
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint('[PushNotificationService] Queued broadcast for material $title ($subject)');
    } catch (e) {
      debugPrint('[PushNotificationService] notifyAllNewMaterial error: $e');
    }

    // Display local banner notification
    await showLocalNotification(
      title: notifTitle,
      body: notifBody,
      payload: {'type': 'new_material', 'subject': subject},
    );
  }

  /// Starts listening to the live materials stream to detect new uploads.
  void startNexusMaterialsWatcher() {
    _materialsSubscription?.cancel();
    final stream = NexusService().watchMaterials();
    if (stream == null) return;

    _materialsSubscription = stream.listen((snapshot) {
      if (!_initialMaterialsLoaded) {
        // Seed seen IDs on first emission so existing materials don't trigger alerts
        for (final doc in snapshot.docs) {
          _seenMaterialIds.add(doc.id);
        }
        _initialMaterialsLoaded = true;
        return;
      }

      // Check for document additions
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final id = change.doc.id;
          if (!_seenMaterialIds.contains(id)) {
            _seenMaterialIds.add(id);
            final data = change.doc.data() ?? {};
            final subject = data['subject']?.toString() ?? 'Academic';
            final title = data['title']?.toString() ?? 'New Material';
            notifyAllNewMaterial(subject: subject, title: title);
          }
        }
      }
    }, onError: (err) {
      debugPrint('[PushNotificationService] Nexus materials watcher error: $err');
    });
  }

  void dispose() {
    _materialsSubscription?.cancel();
  }
}
