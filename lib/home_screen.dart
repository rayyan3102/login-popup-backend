import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// --- 1. ADDED THIS IMPORT ---
import 'package:firebase_auth/firebase_auth.dart';

// -----------------------------------------------------------
// --- Data Model (No changes, this is perfect) ---
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
      // Using 12-hour format for a friendlier look
      String period = dt.hour < 12 ? 'AM' : 'PM';
      int hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12; // Handle midnight/noon
      String minute = dt.minute.toString().padLeft(2, '0');
      formattedTime = '$hour:$minute $period';
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
// --- Main Home Screen (UPDATED) ---
// -----------------------------------------------------------
class WhatsAppHome extends StatefulWidget {
  const WhatsAppHome({super.key});

  @override
  State<WhatsAppHome> createState() => _WhatsAppHomeState();
}

class _WhatsAppHomeState extends State<WhatsAppHome> {
  // --- 2. ADDED THIS LOGOUT FUNCTION ---
  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      // The StreamBuilder in main.dart will automatically
      // detect this and show the LoginPage.
    } catch (e) {
      print("Error logging out: $e");
      // Show an error if logout fails
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error logging out: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 7, 62, 94),
        foregroundColor: Colors.white,
        shadowColor: Colors.black.withOpacity(0.5),
        elevation: 4.0, 
        title: const Text('My Messenger', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          
          // --- 3. ADDED THE LOGOUT ICON BUTTON ---
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),

          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: MessageList(),
    );
  }
}

// -----------------------------------------------------------
// --- MessageList (No changes, this is perfect) ---
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
          return const Center(
            child: Text(
              'No messages yet',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            DocumentSnapshot document = snapshot.data!.docs[index];
            Conversation chat = Conversation.fromFirestore(document);

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4.0),
              elevation: 1.0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 8.0,
                  horizontal: 16.0,
                ),
                leading: const CircleAvatar(
                  backgroundColor: Color.fromARGB(255, 37, 112, 211),
                  radius: 25,
                  child: Icon(Icons.admin_panel_settings, color: Colors.white),
                ),
                title: Text(
                  chat.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  chat.lastMessage,
                  maxLines: 1, 
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  chat.time,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            );
          },
        );
      },
    );
  }
}