import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/database_service.dart';

class IndividualChat extends StatefulWidget {
  final String chatRoomId;
  final String receiverName;

  const IndividualChat({
    super.key,
    Caesar,
    required this.chatRoomId,
    required this.receiverName,
  });

  @override
  State<IndividualChat> createState() => _IndividualChatState();
}

class _IndividualChatState extends State<IndividualChat> {
  final TextEditingController _messageController = TextEditingController();
  final DatabaseService _dbService = DatabaseService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // নিজের ইমেইলটি গেট করা
  String get myEmail => _auth.currentUser?.email ?? "";

  // মেসেজ পাঠানোর ফাংশন (সংশোধিত)
  void sendMessage() async {
    if (_messageController.text.trim().isNotEmpty) {
      String msg = _messageController.text.trim();

      // ১. মেসেজের ডেটা ম্যাপ তৈরি
      Map<String, dynamic> messageMap = {
        "message": msg,
        "sendBy": myEmail,
        "time": DateTime.now()
            .millisecondsSinceEpoch, // সর্টিং এর জন্য মিলি-সেকেন্ড
      };

      // ২. টেক্সট ফিল্ড আগে খালি করা (ইউজার এক্সপেরিয়েন্সের জন্য)
      _messageController.clear();

      // ৩. ডেটাবেসে মেসেজ পাঠানো (এটি মেইন ডকুমেন্ট এবং সাব-কালেকশন দুইটাই আপডেট করবে)
      try {
        await _dbService.addConversationMessages(widget.chatRoomId, messageMap);
      } catch (e) {
        print("Error sending message: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.receiverName), elevation: 0),
      body: Column(
        children: [
          // চ্যাট মেসেজ লিস্ট
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _dbService.getConversationMessages(widget.chatRoomId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("Say Hi!"));
                }

                return ListView.builder(
                  reverse: true, // নতুন মেসেজ নিচে দেখানোর জন্য
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var ds = snapshot.data!.docs[index];
                    bool isMe = ds["sendBy"] == myEmail;
                    return MessageTile(message: ds["message"], isMe: isMe);
                  },
                );
              },
            ),
          ),

          // মেসেজ ইনপুট এরিয়া
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 2,
                  blurRadius: 5,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: "Type a message...",
                      border: InputBorder.none,
                    ),
                    onSubmitted: (value) =>
                        sendMessage(), // এন্টার টিপলে মেসেজ যাবে
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blueAccent),
                  onPressed: sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// মেসেজ বাবলের জন্য উইজেট
class MessageTile extends StatelessWidget {
  final String message;
  final bool isMe;

  const MessageTile({super.key, required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? Colors.blueAccent : Colors.grey[300],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(15),
            topRight: const Radius.circular(15),
            bottomLeft: isMe
                ? const Radius.circular(15)
                : const Radius.circular(0),
            bottomRight: isMe
                ? const Radius.circular(0)
                : const Radius.circular(15),
          ),
        ),
        child: Text(
          message,
          style: TextStyle(
            color: isMe ? Colors.white : Colors.black87,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
