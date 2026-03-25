import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:instagram_clone_flutter_firebase/screens/chat_screen.dart';
import 'package:instagram_clone_flutter_firebase/screens/post_profile.dart';
import 'package:instagram_clone_flutter_firebase/screens/profile_screen.dart';
import 'package:instagram_clone_flutter_firebase/screens/reels_screen.dart';
import 'package:instagram_clone_flutter_firebase/screens/live_viewer_screen.dart';
import 'package:instagram_clone_flutter_firebase/firebase_options.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    await _requestPermissions();
    await _initLocalNotifications();
    await _saveTokenForCurrentUser();

    FirebaseMessaging.instance.onTokenRefresh.listen(_saveToken);
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null) {
        await _saveTokenForCurrentUser();
      }
    });
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      handleMessageData(message.data);
    });

    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        handleMessageData(initial.data);
      });
    }
  }

  Future<void> _requestPermissions() async {
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    final android =
        _local
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings =
        InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _local.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        final data = jsonDecode(payload) as Map<String, dynamic>;
        handleMessageData(data);
      },
    );

    const channel = AndroidNotificationChannel(
      'high_importance_channel',
      'Notifications',
      description: 'Instagram-like notifications',
      importance: Importance.high,
    );
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _saveTokenForCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) return;
    await _saveToken(token);
  }

  Future<void> _saveToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection("users").doc(user.uid).update({
      "fcmToken": token,
      "fcmTokens": FieldValue.arrayUnion([token]),
    });
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    final payload = jsonEncode(message.data);
    await _local.show(
      notification.hashCode,
      notification.title,
      notification.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'high_importance_channel',
          'Notifications',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }

  Future<void> handleMessageData(Map<String, dynamic> data) async {
    final nav = navigatorKey.currentState;
    if (nav == null) return;

    final notificationId = (data["notificationId"] ?? "").toString();
    if (notificationId.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection("notifications")
            .doc(notificationId)
            .update({"isRead": true});
      } catch (_) {}
    }

    final type = (data["type"] ?? "").toString();
    final senderId = (data["senderId"] ?? "").toString();
    final receiverId = (data["receiverId"] ?? "").toString();
    final senderUsername = (data["senderUsername"] ?? "user").toString();
    final senderPhotoUrl = (data["senderPhotoUrl"] ?? "").toString();
    final profileUid = (data["profileUid"] ?? "").toString();
    final liveId = (data["liveId"] ?? "").toString();

    if (type == "message" && senderId.isNotEmpty) {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      if (currentUid == null) return;
      nav.push(
        MaterialPageRoute(
          builder:
              (_) => ChatScreen(
                currentUid: currentUid,
                otherUid: senderId,
                otherUsername: senderUsername,
                otherPhotoUrl: senderPhotoUrl,
              ),
        ),
      );
      return;
    }

    if (type == "follow" ||
        type == "follow_request" ||
        type == "follow_accept") {
      if (senderId.isEmpty) return;
      nav.push(
        MaterialPageRoute(builder: (_) => ProfileScreen(uid: senderId)),
      );
      return;
    }

    if (type == "share_profile" && profileUid.isNotEmpty) {
      nav.push(
        MaterialPageRoute(builder: (_) => ProfileScreen(uid: profileUid)),
      );
      return;
    }

    if (type == "live" && liveId.isNotEmpty) {
      nav.push(MaterialPageRoute(builder: (_) => LiveViewerScreen(liveId: liveId)));
      return;
    }

    if (type == "share_reel") {
      nav.push(MaterialPageRoute(builder: (_) => const ReelsScreen()));
      return;
    }

    if (type == "like" || type == "comment" || type == "share_post") {
      final targetUid =
          receiverId.isNotEmpty
              ? receiverId
              : FirebaseAuth.instance.currentUser?.uid;
      nav.push(
        MaterialPageRoute(builder: (_) => PostDetailScreen(uid: targetUid)),
      );
      return;
    }
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // FCM will display notification payloads in the background by default.
  // Keeping this handler to ensure Firebase is ready when needed.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}
