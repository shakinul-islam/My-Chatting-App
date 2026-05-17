import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'individual_chat.dart'; // সঠিক ফাইল ইম্পোর্ট রাখুন

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String searchQuery = "";

  // চ্যাটルーム আইডি জেনারেট করার ফাংশন (দুই ইউজারের ইমেইল মিলিয়ে)
  String getChatRoomId(String a, String b) {
    if (a.substring(0, 1).codeUnitAt(0) > b.substring(0, 1).codeUnitAt(0)) {
      return "${b}_$a";
    } else {
      return "${a}_$b";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(
        0xFFF8FAFC,
      ), // মডার্ন অফ-হোয়াইট ব্যাকগ্রাউন্ড
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          "Search Users",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B), // ডিপ স্লেট কালার
            letterSpacing: -0.5,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF1E293B),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // ====== 🔍 মডার্ন গ্লোয়িং সার্চ বার ======
          Padding(
            padding: const EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 15.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withOpacity(0.04),
                    spreadRadius: 1,
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                onChanged: (val) =>
                    setState(() => searchQuery = val.toLowerCase()),
                style: const TextStyle(
                  color: Color(0xFF1E293B),
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: "Search by name...",
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Colors.blueAccent,
                    size: 24,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: Colors.blueAccent,
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),

          // ====== 👥 ইউজার রেজাল্ট লিস্ট ======
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.blueAccent),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState("No users found");
                }

                var users = snapshot.data!.docs.where((doc) {
                  var name = doc['name'].toString().toLowerCase();
                  return name.contains(searchQuery) &&
                      doc['email'] != _auth.currentUser?.email;
                }).toList();

                if (users.isEmpty) {
                  return _buildEmptyState("No results match your search");
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 5,
                  ),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    var data = users[index];
                    String userName = data['name'] ?? 'Unknown';
                    String userEmail = data['email'] ?? '';

                    // নাম থেকে প্রথম অক্ষর ক্যাপিটাল লেটার হিসেবে নেওয়ার জন্য (Avatar এর জন্য)
                    String firstLetter = userName.isNotEmpty
                        ? userName.substring(0, 1).toUpperCase()
                        : "U";

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withOpacity(0.02),
                              spreadRadius: 1,
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          leading: CircleAvatar(
                            radius: 24,
                            backgroundColor: Colors.blueAccent.withOpacity(0.1),
                            child: Text(
                              firstLetter,
                              style: const TextStyle(
                                color: Colors.blueAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                          ),
                          title: Text(
                            userName,
                            style: const TextStyle(
                              color: Color(0xFF1E293B),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              userEmail,
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 13,
                              ),
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 14,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          onTap: () {
                            String myEmail = _auth.currentUser!.email!;
                            String chatRoomId = getChatRoomId(
                              myEmail,
                              data['email'],
                            );

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => IndividualChat(
                                  chatRoomId: chatRoomId,
                                  receiverName: data['name'],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ====== 🚫 মডার্ন এম্পটি স্টেট উইজেট ======
  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.supervised_user_circle_outlined,
            size: 70,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
