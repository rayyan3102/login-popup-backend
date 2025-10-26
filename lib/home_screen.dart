import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// -----------------------------------------------------------
// --- Local notification setup ---
// -----------------------------------------------------------
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> initializeLocalNotifications() async {
  const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initSettings =
      InitializationSettings(android: androidSettings);

  await flutterLocalNotificationsPlugin.initialize(initSettings);
}

// -----------------------------------------------------------
// --- Data Model ---
// -----------------------------------------------------------
class Conversation {
  final String name;
  final String lastMessage;
  final String time;
  final int unreadCount;

  Conversation({
    required this.name,
    required this.lastMessage,
    required this.time,
    this.unreadCount = 0,
  });

  factory Conversation.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;

    String formattedTime = '...';
    if (data['timestamp'] != null) {
      Timestamp ts = data['timestamp'] as Timestamp;
      DateTime dt = ts.toDate();
      formattedTime = '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    }

    return Conversation(
      name: data['senderName'] ?? 'Admin',
      lastMessage: data['message'] ?? 'No message',
      time: formattedTime,
      unreadCount: 0,
    );
  }
}

// -----------------------------------------------------------
// --- Main Home Screen ---
// -----------------------------------------------------------
class WhatsAppHome extends StatefulWidget {
  const WhatsAppHome({super.key});

  @override
  State<WhatsAppHome> createState() => _WhatsAppHomeState();
}

class _WhatsAppHomeState extends State<WhatsAppHome> {
  @override
  void initState() {
    super.initState();
    _setupNotifications();
  }

  Future<void> _setupNotifications() async {
    await initializeLocalNotifications();

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      if (message.notification != null) {
        await _showLocalNotification(
          message.notification!.title ?? 'New Message',
          message.notification!.body ?? '',
        );
      }
    });
  }

  Future<void> _showLocalNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'admin_messages',
      'Admin Messages',
      channelDescription: 'Shows notifications from the admin',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
    );
    const NotificationDetails details =
        NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      details,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: 0,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color.fromARGB(255, 7, 62, 94),
          title: const Text('My Messenger', style: TextStyle(color: Colors.white)),
          foregroundColor: Colors.white,
          actions: [
            IconButton(icon: const Icon(Icons.search), onPressed: () {}),
            IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelStyle: TextStyle(fontWeight: FontWeight.bold),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'MESSAGES'),
              Tab(text: 'STATUS'),
              Tab(text: 'CALLS'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            MessageList(), // Real-time admin messages
            const Center(child: Text('Status updates appear here!')),
            const Center(child: Text('Your call history appears here!')),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: const Color.fromARGB(255, 37, 112, 211),
          onPressed: () {},
          child: const Icon(Icons.message, color: Colors.white),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------
// --- MessageList (admin messages in real-time) ---
// -----------------------------------------------------------
class MessageList extends StatelessWidget {
  final Stream<QuerySnapshot> _adminMessagesStream = FirebaseFirestore.instance
      .collection('adminMessages')
      .orderBy('timestamp', descending: true)
      .snapshots();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _adminMessagesStream,
      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Something went wrong'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No messages yet'));
        }

        return ListView(
          children: snapshot.data!.docs.map((DocumentSnapshot document) {
            Conversation chat = Conversation.fromFirestore(document);

            return Column(
              children: [
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.blue,
                    radius: 25,
                    child: Icon(Icons.admin_panel_settings, color: Colors.white),
                  ),
                  title: Text(
                    chat.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(chat.lastMessage),
                  trailing: Text(chat.time,
                      style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ),
                const Divider(height: 1, indent: 80),
              ],
            );
          }).toList(),
        );
      },
    );
  }
}
