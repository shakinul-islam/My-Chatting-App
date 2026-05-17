import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import '../services/call_service.dart'; 
import 'chat_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CallService _callService = CallService(); 
  String searchQuery = "";
  String _myProfilePicUrl = "";
  bool _isDialogShowing = false; 

  @override
  void initState() {
    super.initState();
    _loadMyProfilePic();
    _listenForIncomingCalls();
  }

  Future<void> _loadMyProfilePic() async {
    String myEmail = _auth.currentUser?.email ?? "";
    if (myEmail.isNotEmpty) {
      FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: myEmail)
          .snapshots()
          .listen((snapshot) {
            if (snapshot.docs.isNotEmpty) {
              if (mounted) {
                setState(() {
                  _myProfilePicUrl = snapshot.docs[0]['profilePic'] ?? "";
                });
              }
            }
          });
    }
  }

  void _listenForIncomingCalls() {
    String? myUid = _auth.currentUser?.uid;
    String? myEmail = _auth.currentUser?.email;

    if (myUid == null && myEmail == null) {
      Future.delayed(const Duration(seconds: 1), _listenForIncomingCalls);
      return;
    }

    FirebaseFirestore.instance
        .collection('calls')
        .where('status', isEqualTo: 'ringing')
        .snapshots()
        .listen((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            for (var doc in snapshot.docs) {
              var callData = doc.data();
              String callId = doc.id;

              if (callData['receiverId'] == myUid ||
                  callData['receiverId'] == myEmail) {
                if (!_isDialogShowing) {
                  _showIncomingCallDialog(callData, callId);
                }
                break;
              }
            }
          }
        });
  }

  void _showIncomingCallDialog(Map<String, dynamic> callData, String callId) {
    _isDialogShowing = true;

    String callType = callData['type'] ?? 'audio';
    String callerName = callData['callerName'] ?? 'Someone';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          contentPadding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 8),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                callType == 'video' ? Icons.videocam_rounded : Icons.call_rounded,
                color: callType == 'video' ? Colors.blueAccent : Colors.green,
                size: 26,
              ),
              const SizedBox(width: 10),
              Text(
                callType == 'video' ? "Incoming Video Call" : "Incoming Audio Call",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              CircleAvatar(
                radius: 40,
                backgroundColor: callType == 'video' 
                    ? Colors.blueAccent.withOpacity(0.1) 
                    : Colors.green.withOpacity(0.1),
                child: Icon(
                  callType == 'video' ? Icons.videocam_rounded : Icons.person_rounded,
                  size: 44,
                  color: callType == 'video' ? Colors.blueAccent : Colors.green,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                callerName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              const Text(
                "is calling you...",
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actionsPadding: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
          actions: [
            // Decline Button
            GestureDetector(
              onTap: () async {
                _isDialogShowing = false;
                await FirebaseFirestore.instance
                    .collection('calls')
                    .doc(callId)
                    .update({'status': 'rejected'});
                if (context.mounted) Navigator.pop(context);
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.call_end_rounded, color: Colors.redAccent, size: 28),
              ),
            ),
            // Accept Button
            GestureDetector(
              onTap: () async {
                _isDialogShowing = false;
                await FirebaseFirestore.instance
                    .collection('calls')
                    .doc(callId)
                    .update({'status': 'accepted'});

                if (context.mounted) Navigator.pop(context);

                await _callService.joinIncomingCall(
                  channelId: callData['channelId'],
                  callType: callData['type'] ?? 'audio',
                );
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.call_rounded, color: Colors.green, size: 28),
              ),
            ),
          ],
        );
      },
    ).then((_) => _isDialogShowing = false);
  }

  String getChatRoomId(String a, String b) {
    return a.substring(0, 1).codeUnitAt(0) > b.substring(0, 1).codeUnitAt(0)
        ? "${b}_$a"
        : "${a}_$b";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), 
      appBar: AppBar(
        titleSpacing: 16,
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.blueAccent.withOpacity(0.1),
              backgroundImage: _myProfilePicUrl.isNotEmpty
                  ? NetworkImage(_myProfilePicUrl)
                  : null,
              child: _myProfilePicUrl.isEmpty
                  ? const Icon(Icons.person_rounded, size: 20, color: Colors.blueAccent)
                  : null,
            ),
            const SizedBox(width: 12),
            const Text(
              "Messages",
              style: TextStyle(
                fontWeight: FontWeight.bold, 
                fontSize: 20,
                color: Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // ====== Search Bar ======
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: TextField(
                onChanged: (val) {
                  setState(() {
                    searchQuery = val.trim().toLowerCase();
                  });
                },
                decoration: InputDecoration(
                  hintText: "Search users...",
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5),
                  ),
                ),
              ),
            ),
          ),
          
          // ====== Chat List Area ======
          Expanded(
            child: searchQuery.isEmpty
                ? _buildRecentChats()
                : _buildSearchList(),
          ),
        ],
      ),
    );
  }

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
          return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 12),
                Text(
                  "No recent chats. Search to start!",
                  style: TextStyle(color: Colors.grey[500], fontSize: 14),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: snapshot.data!.docs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            var ds = snapshot.data!.docs[index];
            var data = ds.data() as Map<String, dynamic>;

            List users = data['users'] ?? [];
            String receiverEmail = users.firstWhere(
              (e) => e != myEmail,
              orElse: () => "",
            );

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('email', isEqualTo: receiverEmail)
                  .snapshots(),
              builder: (context, userSnapshot) {
                String receiverName = receiverEmail;
                String receiverPic = "";

                if (userSnapshot.hasData && userSnapshot.data!.docs.isNotEmpty) {
                  var userData = userSnapshot.data!.docs[0].data() as Map<String, dynamic>;
                  receiverName = userData['name'] ?? receiverEmail;
                  receiverPic = userData['profilePic'] ?? "";
                }

                return Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFFF1F5F9)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.blueAccent.withOpacity(0.1),
                      backgroundImage: receiverPic.isNotEmpty
                          ? NetworkImage(receiverPic)
                          : null,
                      child: receiverPic.isEmpty
                          ? const Icon(Icons.person_rounded, color: Colors.blueAccent, size: 24)
                          : null,
                    ),
                    title: Text(
                      receiverName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                        fontSize: 15,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        data['lastMessage'] == "" || data['lastMessage'] == null
                            ? "Tap to chat"
                            : data['lastMessage'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            receiverEmail: receiverEmail,
                            receiverName: receiverName,
                            receiverImage: receiverPic,
                          ),
                        ),
                      );
                    },
                    onLongPress: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          title: Text(
                            "Delete conversation?",
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          ),
                          content: Text(
                            "This will delete all messages permanently with $receiverName.",
                            style: const TextStyle(color: Color(0xFF64748B)),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text("Cancel", style: TextStyle(color: Color(0xFF64748B))),
                            ),
                            TextButton(
                              onPressed: () async {
                                Navigator.pop(context);
                                await DatabaseService().deleteEntireConversation(ds.id);
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Conversation deleted.")),
                                );
                              },
                              child: const Text("Delete", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSearchList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No users found", style: TextStyle(color: Color(0xFF64748B))));
        }

        var users = snapshot.data!.docs.where((doc) {
          String name = doc['name'].toString().toLowerCase();
          return name.contains(searchQuery);
        }).toList();

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: users.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            var userData = users[index].data() as Map<String, dynamic>;

            if (userData['email'] == _auth.currentUser?.email) {
              return const SizedBox();
            }

            String userPic = userData['profilePic'] ?? "";

            return Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFF1F5F9)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: userPic.isNotEmpty
                      ? NetworkImage(userPic)
                      : null,
                  child: userPic.isEmpty 
                      ? const Icon(Icons.person_rounded, color: Color(0xFF64748B), size: 24) 
                      : null,
                ),
                title: Text(
                  userData['name'] ?? "No Name",
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontSize: 15),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: Text(
                    userData['email'] ?? "",
                    style: const TextStyle(color: Color(0xFF818CF8), fontSize: 12),
                  ),
                ),
                trailing: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.blueAccent, size: 20),
                onTap: () async {
                  String myEmail = _auth.currentUser!.email!;
                  String receiverEmail = userData['email'];
                  String chatRoomId = getChatRoomId(myEmail, receiverEmail);

                  var myData = await FirebaseFirestore.instance
                      .collection('users')
                      .where('email', isEqualTo: myEmail)
                      .get();

                  String myName = myData.docs.isNotEmpty
                      ? myData.docs[0]['name']
                      : myEmail;

                  Map<String, dynamic> chatRoomMap = {
                    "users": [myEmail, receiverEmail],
                    "userNames": {
                      myEmail.replaceAll('.', '_'): myName,
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
                      builder: (context) => ChatScreen(
                        receiverEmail: receiverEmail,
                        receiverName: userData['name'] ?? "No Name",
                        receiverImage: userPic,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}