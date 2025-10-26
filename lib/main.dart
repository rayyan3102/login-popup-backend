import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'login_page.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// --- NOTIFICATION CHANNELS ---
const AndroidNotificationChannel highImportanceChannel = AndroidNotificationChannel(
  'high_importance_channel',
  'High Importance Notifications',
  description: 'This channel is used for important push notifications.',
  importance: Importance.high,
  playSound: true,
  enableVibration: true,
);

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// --- BACKGROUND HANDLER ---
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  _showNotification(message);
  print("📩 Background message: ${message.notification?.title}");
}

// --- SHOW LOCAL NOTIFICATION FOR FCM ---
Future<void> _showNotification(RemoteMessage message) async {
  RemoteNotification? notification = message.notification;

  if (notification != null) {
    await flutterLocalNotificationsPlugin.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          highImportanceChannel.id,
          highImportanceChannel.name,
          channelDescription: highImportanceChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
        ),
      ),
    );
  }
}

// --- INITIALIZE NOTIFICATIONS ---
Future<void> setupFlutterNotifications() async {
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initSettings =
      InitializationSettings(android: androidSettings);

  await flutterLocalNotificationsPlugin.initialize(initSettings);

  final androidImplementation = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  if (androidImplementation != null) {
    await androidImplementation.createNotificationChannel(highImportanceChannel);
  }

  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );
}

// ✅ Send FCM token to backend
Future<void> sendDeviceTokenToServer(String userId) async {
  try {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;

    print('🔥 Device Token: $token');

    final res = await http.post(
      Uri.parse('http://192.168.18.104:3000/register-token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'token': token, 'userId': userId}),
    );

    if (res.statusCode == 200) {
      print('✅ Token sent to server');
    } else {
      print('❌ Failed to send token: ${res.body}');
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      await http.post(
        Uri.parse('http://192.168.18.104:3000/register-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'token': newToken, 'userId': userId}),
      );
      print('🔁 Token refreshed & updated on server');
    });
  } catch (e) {
    print('⚠️ Error sending token: $e');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await setupFlutterNotifications();

  await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  // 🔔 Listen for foreground notifications
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('📲 Foreground message: ${message.notification?.title}');
    _showNotification(message);
  });

  // When user taps notification (app opened from background)
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print('📬 App opened from notification: ${message.notification?.title}');
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Login App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const LoginPage(),
    );
  }
}
