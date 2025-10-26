// lib/notifications.dart
import 'package:firebase_messaging/firebase_messaging.dart';

void setupPushNotifications() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  // Ask permission
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    print('User granted permission');
  }

  // Get device token
  String? token = await messaging.getToken();
  print("FCM Token: $token");

  // Foreground listener
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print("Foreground message: ${message.notification?.title}");
  });
}
