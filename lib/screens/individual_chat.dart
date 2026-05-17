import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:universal_io/io.dart' as uio;

import '../services/database_service.dart';
import '../services/cloudinary_service.dart';
import '../services/jitsi_meet_service.dart'; // Jitsi Service ইমপোর্ট করা হলো
import 'media_view_page.dart';

class IndividualChat extends StatefulWidget {
  final String chatRoomId;
  final String receiverName;

  const IndividualChat({
    super.key,
    required this.chatRoomId,
    required this.receiverName,
  });

  @override
  State<IndividualChat> createState() => _IndividualChatState();
}

class _IndividualChatState extends State<IndividualChat> {
  final TextEditingController _messageController = TextEditingController();
  final DatabaseService _dbService = DatabaseService();
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final JitsiMeetService _jitsiMeetService =
      JitsiMeetService(); // Jitsi সার্ভিস ইনিশিয়ালাইজেশন
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get myEmail => _auth.currentUser?.email ?? "";

  bool isUploading = false;
  double uploadProgress = 0.0;
  String uploadingType = 'text';

  // কল শুরু করার ফাংশন
  void _makeCall(bool isVideoCall) {
    String myName = _auth.currentUser?.displayName ?? "User";

    // Jitsi রিকোয়ারমেন্ট অনুযায়ী রুমের নাম স্পেস ও স্পেশাল ক্যারেক্টার ছাড়া করা হলো
    String cleanRoomId = widget.chatRoomId.replaceAll(
      RegExp(r'[^a-zA-Z0-9]'),
      '',
    );

    _jitsiMeetService.startCall(
      roomName: cleanRoomId,
      userName: myName,
      userEmail: myEmail,
      userAvatar: "", // এখানে প্রোফাইল পিকচারের ইউআরএল থাকলে পাস করতে পারেন
      isVideoCall: isVideoCall,
    );
  }

  void sendTextMessage() {
    if (_messageController.text.trim().isNotEmpty) {
      Map<String, dynamic> messageMap = {
        "message": _messageController.text.trim(),
        "sendBy": myEmail,
        "type": "text",
        "time": DateTime.now().millisecondsSinceEpoch,
      };
      _dbService.addConversationMessages(widget.chatRoomId, messageMap);
      _messageController.clear();
    }
  }

  void pickAndSendMedia() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Wrap(
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.image_rounded, color: Colors.blue),
                ),
                title: const Text("Image", style: TextStyle(fontWeight: FontWeight.w500)),
                onTap: () => _pickFile(isImage: true),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.video_library_rounded, color: Colors.purple),
                ),
                title: const Text("Video", style: TextStyle(fontWeight: FontWeight.w500)),
                onTap: () => _pickFile(isVideo: true),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red),
                ),
                title: const Text("PDF Document", style: TextStyle(fontWeight: FontWeight.w500)),
                onTap: () => _pickFile(isPdf: true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _pickFile({
    bool isImage = false,
    bool isVideo = false,
    bool isPdf = false,
  }) async {
    Navigator.pop(context);
    uio.File? file;
    XFile? webFile;
    String fileType = 'raw';

    if (isImage) {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked != null) {
        webFile = picked;
        if (!kIsWeb) file = uio.File(picked.path);
        fileType = 'image';
      }
    } else if (isVideo) {
      final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
      if (picked != null) {
        webFile = picked;
        if (!kIsWeb) file = uio.File(picked.path);
        fileType = 'video';
      }
    } else if (isPdf) {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result != null) {
        if (kIsWeb) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "PDF upload on Web is coming soon. Try Image/Video!",
              ),
            ),
          );
          return;
        } else if (result.files.single.path != null) {
          file = uio.File(result.files.single.path!);
          fileType = 'raw';
        }
      }
    }

    if (webFile != null || file != null) {
      setState(() {
        isUploading = true;
        uploadProgress = 0.0;
        uploadingType = isImage ? "image" : (isVideo ? "video" : "pdf");
      });

      String? fileUrl = await _cloudinaryService.uploadMediaFile(
        file: kIsWeb ? null : file,
        webFile: webFile,
        fileType: fileType,
        onProgress: (sent, total) {
          setState(() {
            if (total > 0) {
              uploadProgress = sent / total;
            }
          });
        },
      );

      setState(() {
        isUploading = false;
      });

      if (fileUrl != null) {
        Map<String, dynamic> messageMap = {
          "message": fileUrl,
          "sendBy": myEmail,
          "type": uploadingType,
          "time": DateTime.now().millisecondsSinceEpoch,
        };
        _dbService.addConversationMessages(widget.chatRoomId, messageMap);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Failed to upload file.")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // প্রিমিয়াম ক্লিন চ্যাট ব্যাকগ্রাউন্ড
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.blueAccent.withOpacity(0.1),
              child: Text(
                widget.receiverName.isNotEmpty ? widget.receiverName[0].toUpperCase() : "?",
                style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.receiverName,
                style: const TextStyle(
                  fontSize: 16, 
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF64748B), size: 22),
            onPressed: () => _makeCall(false),
          ),
          IconButton(
            icon: const Icon(Icons.videocam_rounded, color: Color(0xFF64748B), size: 24),
            onPressed: () => _makeCall(true),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _dbService.getConversationMessages(widget.chatRoomId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
                }

                var docs = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  itemCount: docs.length + (isUploading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (isUploading && index == 0) {
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                        alignment: Alignment.centerRight,
                        child: Container(
                          width: 220,
                          height: uploadingType == "image" ? 220 : 130,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  color: Colors.grey[300],
                                  child: Center(
                                    child: Icon(
                                      uploadingType == "image"
                                          ? Icons.image_rounded
                                          : Icons.videocam_rounded,
                                      size: 44,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    value: uploadProgress,
                                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                                    backgroundColor: Colors.white24,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    "${(uploadProgress * 100).toStringAsFixed(0)}% Sending...",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    int actualIndex = isUploading ? index - 1 : index;
                    var ds = docs[actualIndex];
                    String messageId = ds.id;
                    bool isMe = ds["sendBy"] == myEmail;

                    List deletedBy = ds.data().toString().contains('deletedBy')
                        ? ds["deletedBy"]
                        : [];
                    if (deletedBy.contains(myEmail)) {
                      return const SizedBox.shrink();
                    }

                    Map<String, dynamic>? dataMap =
                        ds.data() as Map<String, dynamic>?;
                    String messageType =
                        (dataMap != null && dataMap.containsKey("type"))
                        ? ds["type"]
                        : "text";

                    return GestureDetector(
                      onLongPress: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            title: const Text("Delete Message?", style: TextStyle(fontWeight: FontWeight.bold)),
                            content: const Text("Are you sure you want to delete this message?"),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  _dbService.deleteMessageForMe(
                                    widget.chatRoomId,
                                    messageId,
                                    myEmail,
                                  );
                                  Navigator.pop(context);
                                },
                                child: const Text("Delete for Me", style: TextStyle(color: Color(0xFF64748B))),
                              ),
                              if (isMe)
                                TextButton(
                                  onPressed: () {
                                    _dbService.deleteMessageForEveryone(
                                      widget.chatRoomId,
                                      messageId,
                                    );
                                    Navigator.pop(context);
                                  },
                                  child: const Text(
                                    "Delete for Everyone",
                                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text("Cancel"),
                              ),
                            ],
                          ),
                        );
                      },
                      child: MediaMessageTile(
                        message: ds["message"],
                        type: messageType,
                        isMe: isMe,
                      ),
                    );
                  },
                );
              },
            ),
          ),
          
          // ====== 📥 মডার্ন এবং স্লিক মেসেজ ইনপুট বার ======
          Container(
            padding: const EdgeInsets.only(left: 8, right: 8, bottom: 20, top: 8),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, -2),
                )
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.blueAccent, size: 28),
                  onPressed: pickAndSendMedia,
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _messageController,
                      style: const TextStyle(fontSize: 15),
                      maxLines: null,
                      decoration: const InputDecoration(
                        hintText: "Type a message...",
                        hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                      onSubmitted: (value) => sendTextMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.blueAccent,
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    onPressed: sendTextMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MediaMessageTile extends StatelessWidget {
  final String message;
  final String type;
  final bool isMe;

  const MediaMessageTile({
    super.key,
    required this.message,
    required this.type,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    Widget chatContent;

    if (type == "image") {
      chatContent = ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          message,
          width: 220,
          height: 220,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: 220,
              height: 220,
              color: Colors.grey[200],
              child: const Center(child: CircularProgressIndicator(color: Colors.blueAccent)),
            );
          },
        ),
      );
    } else if (type == "video") {
      chatContent = ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 220,
          height: 130,
          color: const Color(0xFF0F172A),
          child: const Center(
            child: Icon(Icons.play_circle_filled_rounded, color: Colors.white, size: 48),
          ),
        ),
      );
    } else if (type == "pdf") {
      chatContent = Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        width: 220,
        decoration: BoxDecoration(
          color: isMe ? Colors.blueAccent.withOpacity(0.15) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                "PDF Document",
                style: TextStyle(color: Color(0xFF1E293B), fontWeight: FontWeight.w500, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    } else {
      chatContent = Text(
        message,
        style: TextStyle(
          color: isMe ? Colors.white : const Color(0xFF1E293B),
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onTap: () {
          if (type != 'text') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MediaViewPage(url: message, type: type),
              ),
            );
          }
        },
        child: Container(
          padding: type == "text"
              ? const EdgeInsets.symmetric(horizontal: 16, vertical: 10)
              : EdgeInsets.zero,
          decoration: BoxDecoration(
            color: type == "text"
                ? (isMe ? Colors.blueAccent : Colors.white)
                : Colors.transparent,
            boxShadow: type == "text" && !isMe
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(4),
              bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(20),
            ),
          ),
          child: chatContent,
        ),
      ),
    );
  }
}