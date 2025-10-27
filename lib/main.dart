import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// --- FIXED IMPORTS ---
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:firebase_auth/firebase_auth.dart'; 
import 'login_page.dart'; // Your login page
import 'home_screen.dart'; // Your home screen

// --- NOTIFICATION CHANNELS (No Changes) ---
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

// --- BACKGROUND HANDLER (UPDATED) ---
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  print("📩 Background message: ${message.messageId}");

  // --- LOGIC REMOVED ---
  // Your server.js is now responsible for saving the message.
  // We remove this to prevent duplicate messages.
  /*
  if (message.data.isNotEmpty) {
    try {
      await FirebaseFirestore.instance.collection('adminMessages').add({
        'message': message.data['message'] ?? 'No message body',
        'senderName': message.data['senderName'] ?? 'Admin',
        'timestamp': FieldValue.serverTimestamp(),
      });
      print("✅ Background message saved to Firestore");
    } catch (e) {
      print("❌ Error saving background message to Firestore: $e");
    }
  }
  */
  // --------------------------

  // We only show the local notification
  await _showNotification(message);
}

// --- SHOW LOCAL NOTIFICATION FOR FCM (No Changes) ---
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

// --- INITIALIZE NOTIFICATIONS (No Changes) ---
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

// --- sendDeviceTokenToServer (FIXED) ---
// Note: This function isn't called directly from main.dart, 
// but its listener logic IS used.
Future<void> sendDeviceTokenToServer(String uid, String? email) async {
  try {
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;

    print('🔥 Device Token: $token');

    final res = await http.post(
      Uri.parse('https://login-popup-backend.onrender.com/register-token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'token': token, 
        'uid': uid, // Fixed: send 'uid'
        'email': email  // Fixed: send 'email'
      }),
    );

    if (res.statusCode == 200) {
      print('✅ Token sent to server');
    } else {
      print('❌ Failed to send token: ${res.body}');
    }
  } catch (e) {
    print('⚠️ Error sending token: $e');
  }
}

// --- main() (UPDATED) ---
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

  await FirebaseMessaging.instance.subscribeToTopic('all-users');
  print('✅ Subscribed to FCM topic: all-users');

  // Foreground listener (UPDATED)
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('📲 Foreground message: ${message.notification?.title}');
    
    // --- LOGIC REMOVED ---
    // Your server.js is now responsible for saving the message.
    // We remove this to prevent duplicate messages.
    /*
    if (message.data.isNotEmpty) {
      try {
        FirebaseFirestore.instance.collection('adminMessages').add({
          'message': message.data['message'] ?? 'No message body',
          'senderName': message.data['senderName'] ?? 'Admin',
          'timestamp': FieldValue.serverTimestamp(),
        });
        print("✅ Foreground message saved to Firestore");
      } catch (e) {
        print("❌ Error saving foreground message to Firestore: $e");
      }
    }
    */
    // --------------------------

    // We only show the notification
    _showNotification(message);
  });

  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print('📬 App opened from notification: ${message.notification?.title}');
  });
  
  // --- Token Refresh Listener (FIXED) ---
  // This listens for when FCM issues a new token
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    print('🔁 Token refreshed: $newToken');
    // Check if a user is currently logged in
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // If user is logged in, send their new token to your server
      await http.post(
        Uri.parse('https://login-popup-backend.onrender.com/register-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': newToken, 
          'uid': user.uid,      // Fixed: send 'uid'
          'email': user.email   // Fixed: send 'email'
        }),
      );
      print('🔁 Token refreshed & updated on server');
    }
  });


  runApp(const MyApp());
}

// --- MyApp class (No Changes) ---
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Login App',
      theme: ThemeData(primarySwatch: Colors.blue),
      
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          if (snapshot.hasData) {
            return const WhatsAppHome();
          }

          return const LoginPage();
        },
      ),
    );
  }
}