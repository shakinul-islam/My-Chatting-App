import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:cached_network_image/cached_network_image.dart';

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

  // Cloudinary এর ক্রেডেনশিয়ালস (আপনার ক্লাউডিনারি অ্যাকাউন্ট অনুযায়ী এগুলো চেঞ্জ করবেন)
  final String _cloudinaryCloudName = "your_cloud_name";
  final String _cloudinaryUploadPreset = "your_upload_preset";

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // ফায়ারস্টোর থেকে ইউজারের নাম এবং প্রোফাইল পিকচার লোড করার লজিক
  Future<void> _loadUserData() async {
    String myEmail = _auth.currentUser?.email ?? "";
    if (myEmail.isNotEmpty) {
      var userDoc = await _firestore
          .collection('users')
          .where('email', isEqualTo: myEmail)
          .get();
      if (userDoc.docs.isNotEmpty && mounted) {
        setState(() {
          _userName = userDoc.docs[0]['name'] ?? "No Name";
          _profilePicUrl = userDoc.docs[0]['profilePic'] ?? "";
        });
      }
    }
  }

  // গ্যালারি থেকে ছবি সিলেক্ট করে Cloudinary তে আপলোড করার লজিক
  Future<void> _pickAndUploadImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );

    if (image != null) {
      setState(() {
        _isUploading = true;
      });

      try {
        String apiUrl =
            "https://api.cloudinary.com/v1_1/$_cloudinaryCloudName/image/upload";

        FormData formData = FormData.fromMap({
          "file": await MultipartFile.fromFile(
            image.path,
            filename: image.name,
          ),
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to upload image.")),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String myEmail = _auth.currentUser?.email ?? "No Email";

    return Scaffold(
      backgroundColor: const Color(
        0xFFF8FAFC,
      ), // প্রিমিয়াম অফ-व्हाইট ব্যাকগ্রাউন্ড
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
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // ====== 📸 প্রোফাইল পিকচার সেকশন উইথ শ্যাডো অ্যান্ড বর্ডার ======
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
                          borderRadius: BorderRadius.circular(60),
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
                                        strokeWidth: 3,
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

                      // ইমেজ আপলোডিং ব্লার ওভারলে ইন্ডিকেটর
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

                      // ক্যামেরা একশন বাটন বাবল
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
              const SizedBox(height: 32),

              // ====== 📝 ইউজার ডিটেইলস ইনফো কার্ড ======
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
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
                    const SizedBox(height: 6),
                    Text(
                      myEmail,
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

              // ====== 🚪 মিনিমাল অ্যান্ড ক্লিন লগআউট বাটন ======
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
                    ), // রিয়েল মডার্ন ব্রাইট রেড এলিমেন্ট
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
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
