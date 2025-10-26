// home_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // <-- 1. Import Firestore

// --- Data Model (No changes) ---
class Conversation {
  final String name;
  final String lastMessage;
  final String time; // We'll use a string for now
  final int unreadCount;

  Conversation({
    required this.name,
    required this.lastMessage,
    required this.time,
    this.unreadCount = 0,
  });

  // 2. ADDED: Factory constructor to create a Conversation from a Firestore document
  factory Conversation.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    
    // Note: You must adjust these field names ('chatName', 'lastMessage', etc.)
    // to match the exact field names in your Firestore 'chats' collection.
    
    // Convert Firestore Timestamp to a simple string (e.g., "10:30 AM")
    String formattedTime = '...'; // Default
    if (data['lastMessageTimestamp'] != null) {
      Timestamp ts = data['lastMessageTimestamp'] as Timestamp;
      DateTime dt = ts.toDate();
      formattedTime = '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}'; // Simple time
    }

    return Conversation(
      name: data['chatName'] ?? 'Unknown Chat',
      lastMessage: data['lastMessage'] ?? 'No messages yet',
      time: formattedTime,
      unreadCount: data['unreadCount'] ?? 0,
    );
  }
}

// --- WhatsAppHome Widget (No changes) ---
class WhatsAppHome extends StatelessWidget {
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
              Tab(text: 'CHATS'),
              Tab(text: 'STATUS'),
              Tab(text: 'CALLS'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            MessageList(), // <--- This is now a real-time list
            const Center(child: Text('Status updates appear here!')),
            const Center(child: Text('Your call history appears here!')),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: const Color.fromARGB(255, 37, 112, 211),
          onPressed: () {
            // TODO: Action to start a new chat
          },
          child: const Icon(Icons.message, color: Colors.white),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------
// --- 3. UPDATED: MessageList is now a StatefulWidget ---
// -----------------------------------------------------------

class MessageList extends StatefulWidget {
  @override
  _MessageListState createState() => _MessageListState();
}

class _MessageListState extends State<MessageList> {
  // 4. Define the stream from Firestore
  // This listens to the 'chats' collection, ordered by the latest message
  final Stream<QuerySnapshot> _chatsStream = FirebaseFirestore.instance
      .collection('chats')
      // .orderBy('lastMessageTimestamp', descending: true) // Use this to sort chats
      .snapshots();

  @override
  Widget build(BuildContext context) {
    // 5. Use a StreamBuilder to build the list
    return StreamBuilder<QuerySnapshot>(
      stream: _chatsStream,
      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
        
        // --- Handle Loading and Error States ---
        if (snapshot.hasError) {
          return const Center(child: Text('Something went wrong'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Start a new chat!'));
        }

        // --- Build the list if we have data ---
        return ListView(
          children: snapshot.data!.docs.map((DocumentSnapshot document) {
            // 6. Convert each Firestore document into a Conversation object
            Conversation chat = Conversation.fromFirestore(document);

            // 7. Build the ListTile using the dynamic data
            return Column(
              children: [
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.grey,
                    radius: 28,
                    child: Text(chat.name[0], style: const TextStyle(color: Colors.white)),
                  ),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(chat.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        chat.time,
                        style: TextStyle(
                          fontSize: 12.0,
                          color: chat.unreadCount > 0 ? const Color.fromARGB(255, 37, 106, 211) : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      chat.lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                  trailing: chat.unreadCount > 0
                      ? Container(
                          width: 20,
                          height: 20,
                          decoration: const BoxDecoration(
                            color: Color.fromARGB(255, 37, 92, 211),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${chat.unreadCount}',
                              style: const TextStyle(color: Colors.white, fontSize: 10),
                            ),
                          ),
                        )
                      : null,
                  onTap: () {
                    // TODO: Navigate to the individual Chat Screen
                    print('Tapped on chat: ${chat.name}');
                  },
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