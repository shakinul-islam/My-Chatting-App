import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'individual_chat.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String searchQuery = "";

  // চ্যাট রুম আইডি তৈরি করার লজিক
  String getChatRoomId(String a, String b) {
    return a.substring(0, 1).codeUnitAt(0) > b.substring(0, 1).codeUnitAt(0)
        ? "${b}_$a"
        : "${a}_$b";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Messages"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _auth.signOut(),
          ),
        ],
      ),
      body: Column(
        children: [
          // ১. সার্চ বার
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              onChanged: (val) {
                setState(() {
                  searchQuery = val.trim().toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: "Search users...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[200],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // ২. ইউজার লিস্ট
          Expanded(
            child: searchQuery.isEmpty
                ? _buildRecentChats() // রিসেন্ট চ্যাট লিস্ট
                : _buildSearchList(), // সার্চ রেজাল্ট লিস্ট
          ),
        ],
      ),
    );
  }

  // রিসেন্ট চ্যাট লিস্ট (ইমেইলের বদলে নাম দেখাবে)
  Widget _buildRecentChats() {
    String myEmail = _auth.currentUser?.email ?? "";

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('chatrooms')
          .where('users', arrayContains: myEmail)
          .orderBy('lastMessageTime', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No recent chats. Search to start!"));
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            var ds = snapshot.data!.docs[index];
            var data = ds.data() as Map<String, dynamic>;

            List users = data['users'] ?? [];
            String receiverEmail = users.firstWhere(
              (e) => e != myEmail,
              orElse: () => "",
            );

            String receiverKey = receiverEmail.replaceAll('.', '_');

            return ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.blueAccent,
                child: Icon(Icons.person, color: Colors.white),
              ),
              title: Text(
                data['userNames'] != null
                    ? (data['userNames'][receiverKey] ?? receiverEmail)
                    : receiverEmail,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                data['lastMessage'] == "" || data['lastMessage'] == null
                    ? "Tap to chat"
                    : data['lastMessage'],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => IndividualChat(
                      chatRoomId: ds.id,
                      receiverName: data['userNames'] != null
                          ? (data['userNames'][receiverKey] ?? receiverEmail)
                          : receiverEmail,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // সার্চ লিস্ট ঠিক করা হয়েছে
  Widget _buildSearchList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No users found"));
        }

        // সার্চ কুয়েরি অনুযায়ী ইউজার ফিল্টার করা
        var users = snapshot.data!.docs.where((doc) {
          String name = doc['name'].toString().toLowerCase();
          return name.contains(searchQuery);
        }).toList();

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            var userData = users[index].data() as Map<String, dynamic>;

            // নিজের আইডি সার্চে দেখাবে না
            if (userData['email'] == _auth.currentUser?.email)
              return const SizedBox();

            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(userData['name'] ?? "No Name"),
              subtitle: Text(userData['email'] ?? ""),

              // home_page.dart এর _buildSearchList এর ভেতর onTap অংশটি এভাবে পরিবর্তন করুন:
              onTap: () async {
                String myEmail = _auth.currentUser!.email!;
                String receiverEmail = userData['email'];
                String chatRoomId = getChatRoomId(myEmail, receiverEmail);

                // ১. আপনার নিজের নাম ডাটাবেস থেকে খুঁজে বের করা
                var myData = await FirebaseFirestore.instance
                    .collection('users')
                    .where('email', isEqualTo: myEmail)
                    .get();

                // আপনার নাম যদি ডাটাবেসে থাকে তবে সেটি নিবে, নাহলে ইমেইল দেখাবে
                String myName = myData.docs.isNotEmpty
                    ? myData.docs[0]['name']
                    : myEmail;

                // ২. চ্যাটরুম ম্যাপ আপডেট করা
                Map<String, dynamic> chatRoomMap = {
                  "users": [myEmail, receiverEmail],
                  "userNames": {
                    myEmail.replaceAll(
                      '.',
                      '_',
                    ): myName, // এখানে আর Md Shakinul নেই, এখন dynamic নাম আসবে
                    receiverEmail.replaceAll('.', '_'): userData['name'],
                  },
                  "lastMessage": "",
                  "lastMessageTime": FieldValue.serverTimestamp(),
                };

                await FirebaseFirestore.instance
                    .collection("chatrooms")
                    .doc(chatRoomId)
                    .set(chatRoomMap, SetOptions(merge: true));

                if (!mounted) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => IndividualChat(
                      chatRoomId: chatRoomId,
                      receiverName: userData['name'],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
