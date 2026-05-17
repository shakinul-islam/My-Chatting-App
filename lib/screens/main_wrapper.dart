import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'home_page.dart';

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _selectedIndex = 0;

  // স্ক্রিনগুলোকে মেমোরিতে ধরে রাখতে এবং ল্যাগ কমাতে IndexedStack ব্যবহার করা হয়েছে
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [const HomePage(), const CallsScreen(), const ProfileScreen()];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: IndexedStack(index: _selectedIndex, children: _screens),

      // ====== 🎛️ মডার্ন স্লিক বটম নেভিগেশন বার ======
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.06),
              blurRadius: 20,
              spreadRadius: 0,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: NavigationBar(
          elevation: 0,
          backgroundColor: Colors.white,
          height: 72,
          selectedIndex: _selectedIndex,
          onDestinationSelected: (int index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          indicatorColor: Colors.blueAccent.withOpacity(0.08),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              selectedIcon: Icon(
                Icons.chat_bubble_rounded,
                color: Colors.blueAccent,
                size: 24,
              ),
              icon: Icon(
                Icons.chat_bubble_outline_rounded,
                color: Color(0xFF64748B),
                size: 24,
              ),
              label: 'Chats',
            ),
            NavigationDestination(
              selectedIcon: Icon(
                Icons.phone_rounded,
                color: Colors.blueAccent,
                size: 24,
              ),
              icon: Icon(
                Icons.phone_outlined,
                color: Color(0xFF64748B),
                size: 24,
              ),
              label: 'Calls',
            ),
            NavigationDestination(
              selectedIcon: Icon(
                Icons.person_rounded,
                color: Colors.blueAccent,
                size: 24,
              ),
              icon: Icon(
                Icons.person_outline_rounded,
                color: Color(0xFF64748B),
                size: 24,
              ),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== ২. পারফেক্ট ও মডার্ন কল হিস্ট্রি স্ক্রিন ====================
class CallsScreen extends StatelessWidget {
  const CallsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final FirebaseAuth auth = FirebaseAuth.instance;
    final String myEmail = auth.currentUser?.email ?? "";

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          "Calls",
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: myEmail.isEmpty
          ? const Center(child: Text("User not logged in"))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('calls')
                  .where('participants', arrayContains: myEmail)
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.blueAccent),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.06),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.phone_missed_rounded,
                            size: 50,
                            color: Colors.redAccent,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "No call history found",
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                var callDocs = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  itemCount: callDocs.length,
                  itemBuilder: (context, index) {
                    var callData =
                        callDocs[index].data() as Map<String, dynamic>;

                    String callerName =
                        callData['callerName'] ?? "Unknown Caller";
                    String receiverName =
                        callData['receiverName'] ?? "Unknown Receiver";
                    bool isIncoming = callData['callerEmail'] != myEmail;

                    String displayName = isIncoming ? callerName : receiverName;
                    bool isVideo = callData['isVideo'] ?? false;

                    // কল টাইপ অনুযায়ী থিম ডাইনামিক কালার নির্ধারণ
                    Color statusColor = isIncoming
                        ? const Color(0xFF10B981)
                        : const Color(0xFF3B82F6); // গ্রিন বনাম ব্লু

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withOpacity(0.015),
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
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.08),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isIncoming
                                  ? Icons.call_received_rounded
                                  : Icons.call_made_rounded,
                              color: statusColor,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Row(
                              children: [
                                Icon(
                                  isVideo
                                      ? Icons.videocam_rounded
                                      : Icons.phone_rounded,
                                  size: 14,
                                  color: const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isVideo ? "Video Call" : "Audio Call",
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isVideo
                                  ? Icons.videocam_rounded
                                  : Icons.phone_rounded,
                              color: const Color(0xFF475569),
                              size: 18,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

// ==================== ৩. অপ্টিমাইজড ও আল্ট্রা-মডার্ন প্রোফাইল স্ক্রিন ====================
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _userName = "Loading...";
  String _profilePicUrl = "";
  bool _isUploading = false;

  final String _cloudinaryCloudName = "dnthfbpe7";
  final String _cloudinaryUploadPreset = "chat_preset";

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    String myEmail = _auth.currentUser?.email ?? "";
    if (myEmail.isNotEmpty) {
      var snapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: myEmail)
          .get();

      if (snapshot.docs.isNotEmpty && mounted) {
        setState(() {
          _userName = snapshot.docs[0]['name'] ?? "No Name";
          _profilePicUrl = snapshot.docs[0]['profilePic'] ?? "";
        });
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 40,
    );

    if (image != null) {
      setState(() {
        _isUploading = true;
      });

      try {
        String apiUrl =
            "https://api.cloudinary.com/v1_1/$_cloudinaryCloudName/image/upload";
        MultipartFile multipartFile;

        if (Theme.of(context).platform == TargetPlatform.iOS ||
            Theme.of(context).platform == TargetPlatform.android) {
          multipartFile = await MultipartFile.fromFile(
            image.path,
            filename: image.name,
          );
        } else {
          var bytes = await image.readAsBytes();
          multipartFile = MultipartFile.fromBytes(bytes, filename: image.name);
        }

        FormData formData = FormData.fromMap({
          "file": multipartFile,
          "upload_preset": _cloudinaryUploadPreset,
        });

        Dio dio = Dio();
        var response = await dio.post(apiUrl, data: formData);

        if (response.statusCode == 200) {
          String uploadedUrl = response.data['secure_url'];

          String myEmail = _auth.currentUser?.email ?? "";
          var userQuery = await _firestore
              .collection('users')
              .where('email', isEqualTo: myEmail)
              .get();

          if (userQuery.docs.isNotEmpty) {
            await _firestore
                .collection('users')
                .doc(userQuery.docs[0].id)
                .update({'profilePic': uploadedUrl});
          }

          if (mounted) {
            setState(() {
              _profilePicUrl = uploadedUrl;
              _isUploading = false;
            });
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Profile picture updated successfully!"),
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isUploading = false;
          });
        }
        print("Cloudinary Upload Error: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String userEmail = _auth.currentUser?.email ?? "No Email";

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          "Profile",
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10),
          child: Column(
            children: [
              const SizedBox(height: 10),

              // ====== 📸 সেন্ট্রাল প্রোফাইল ইমেজ সেকশন উইথ গ্লো ======
              Center(
                child: GestureDetector(
                  onTap: _isUploading ? null : _pickAndUploadImage,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withOpacity(0.08),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(64),
                          child: _profilePicUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: _profilePicUrl,
                                  width: 120,
                                  height: 120,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    width: 120,
                                    height: 120,
                                    color: Colors.blueAccent.withOpacity(0.05),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.blueAccent,
                                      ),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      Container(
                                        width: 120,
                                        height: 120,
                                        color: Colors.blueAccent.withOpacity(
                                          0.1,
                                        ),
                                        child: const Icon(
                                          Icons.person_rounded,
                                          size: 60,
                                          color: Colors.blueAccent,
                                        ),
                                      ),
                                )
                              : Container(
                                  width: 120,
                                  height: 120,
                                  color: Colors.blueAccent.withOpacity(0.1),
                                  child: const Icon(
                                    Icons.person_rounded,
                                    size: 60,
                                    color: Colors.blueAccent,
                                  ),
                                ),
                        ),
                      ),
                      if (_isUploading)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.4),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      if (!_isUploading)
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Colors.blueAccent,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ====== 📝 ইউজার ইনফরমেশন প্রিমিয়াম কার্ড ======
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 20,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withOpacity(0.02),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      _userName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      userEmail,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // ====== 🚪 মডার্ন আউটলাইনড / সফট লগআউট বাটন ======
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(
                      0xFFFEE2E2,
                    ), // লাইট রেড সফট ব্যাকগ্রাউন্ড
                    foregroundColor: const Color(
                      0xFFEF4444,
                    ), // ব্রাইট রেড টেক্সট ও আইকন
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        title: const Text(
                          "Logout",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        content: const Text(
                          "Are you sure you want to logout from this account?",
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              "Cancel",
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _auth.signOut();
                            },
                            child: const Text(
                              "Yes, Logout",
                              style: TextStyle(
                                color: Color(0xFFEF4444),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  label: const Text(
                    "Logout Account",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
