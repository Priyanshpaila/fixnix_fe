// ignore_for_file: unused_import

import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import 'package:dio/dio.dart';

final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Keep it minimal in background
}

final messagingInitProvider = FutureProvider<void>((ref) async {
  // Local notifications init
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInit = DarwinInitializationSettings();
  await flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(android: androidInit, iOS: iosInit),
    onDidReceiveNotificationResponse: (resp) {
      final deeplink = resp.payload;
      if (deeplink != null) AppNotificationRouter.handleDeepLink(deeplink);
    },
  );

  // Permissions
  final settings = await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );
  if (settings.authorizationStatus == AuthorizationStatus.denied) return;

  // Register device token with backend (requires auth)
  final token = await FirebaseMessaging.instance.getToken();
  if (token != null) {
    try {
      await api.dio.post(
        '/api/users/devices/register',
        data: {'token': token, 'platform': Platform.isIOS ? 'ios' : 'android'},
      );
    } catch (_) {
      /* ignore if not logged in yet */
    }
  }

  // Foreground → local notification
  FirebaseMessaging.onMessage.listen((msg) async {
    final n = msg.notification;
    final deeplink = msg.data['deeplink'] as String?;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'tickets',
        'Ticket Notifications',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      n?.title ?? 'New ticket',
      n?.body ?? 'You have a new assignment',
      details,
      payload: deeplink,
    );
  });

  // App opened from tray
  FirebaseMessaging.onMessageOpenedApp.listen((msg) {
    final deeplink = msg.data['deeplink'] as String?;
    if (deeplink != null) AppNotificationRouter.handleDeepLink(deeplink);
  });
});

class AppNotificationRouter {
  static Future<void> handleDeepLink(String uri) async {
    final u = Uri.parse(uri);
    if (u.host == 'ticket' && u.pathSegments.isNotEmpty) {
      final id = u.pathSegments.first;
      AppNav.goToTicket(id);
    }
  }
}

// simple global function pointer set in main.dart
class AppNav {
  static late void Function(String ticketId) goToTicket;
}
