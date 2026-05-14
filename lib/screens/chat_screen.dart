import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import 'search_screen.dart'; // SearchScreen এর জন্য এই ইম্পোর্টটি জরুরি

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final DatabaseService _dbService = DatabaseService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  void _send() async {
    if (_messageController.text.isNotEmpty) {
      await _dbService.sendMessage(
        _messageController.text,
        _auth.currentUser?.email ?? "Anonymous",
      );
      _messageController.clear(); // মেসেজ পাঠানোর পর ইনপুট ফিল্ড খালি করা
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Chat Room"),
        actions: [
          // সার্চ বাটন: এটি আপনাকে সার্চ স্ক্রিনে নিয়ে যাবে
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SearchScreen()),
              );
            },
          ),
          // লগআউট বাটন: আইকন পরিবর্তন করে exit_to_app দেওয়া হয়েছে
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: () {
              _auth.signOut().then((_) {
                // লগআউট হওয়ার পর স্ট্যাক ক্লিয়ার করে লগইন স্ক্রিনে ফিরে যাওয়া নিরাপদ
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/login', (route) => false);
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // মেসেজ লিস্ট দেখানোর অংশ
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _dbService.getMessages(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                var docs = snapshot.data!.docs;
                return ListView.builder(
                  reverse: true, // নতুন মেসেজ নিচে দেখাবে
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    bool isMe =
                        docs[index]['sender'] == _auth.currentUser?.email;
                    return ListTile(
                      title: Align(
                        alignment: isMe
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isMe ? Colors.blue[100] : Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: isMe
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              Text(
                                docs[index]['text'],
                                style: const TextStyle(fontSize: 16),
                              ),
                              Text(
                                docs[index]['sender'],
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // মেসেজ ইনপুট বক্স
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: "Enter message...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
                  onPressed: _send,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
