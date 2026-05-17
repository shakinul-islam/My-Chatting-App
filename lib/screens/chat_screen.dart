import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import '../services/cloudinary_service.dart';
import '../widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  final String receiverEmail;
  final String receiverName;
  final String receiverImage;

  const ChatScreen({
    super.key,
    required this.receiverEmail,
    required this.receiverName,
    required this.receiverImage,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CloudinaryService _cloudinaryService = CloudinaryService();
  late String chatRoomId;

  bool _isUploading = false;
  double _uploadProgress = 0.0;

  // ==================== 🔄 Reply System State Variables ====================
  Map<String, dynamic>? _replyMessage;

  @override
  void initState() {
    super.initState();
    String myEmail = _auth.currentUser!.email!;
    chatRoomId = getChatRoomId(myEmail, widget.receiverEmail);

    // স্ক্রিন ওপেন হওয়ার সাথে সাথে মেসেজ রিড হিসেবে মার্ক করার চেষ্টা করবে
    _markMessagesAsSeen();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  String getChatRoomId(String a, String b) {
    return a.substring(0, 1).codeUnitAt(0) > b.substring(0, 1).codeUnitAt(0)
        ? "${b}_$a"
        : "${a}_$b";
  }

  // ==================== Real-time Message Seen Status Feature ====================
  void _markMessagesAsSeen() async {
    String myEmail = _auth.currentUser!.email!;

    final unreadMessagesQuery = await FirebaseFirestore.instance
        .collection("chatrooms")
        .doc(chatRoomId)
        .collection("chats")
        .where("sender", isNotEqualTo: myEmail)
        .where("status", isNotEqualTo: "seen")
        .get();

    if (unreadMessagesQuery.docs.isNotEmpty) {
      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var doc in unreadMessagesQuery.docs) {
        batch.update(doc.reference, {"status": "seen"});
      }
      await batch.commit();
    }
  }

  // ==================== Cloudinary Upload Trigger ====================
  Future<void> _processAndUploadMedia(
    PlatformFile pickedFile,
    String fileType,
  ) async {
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      String? downloadUrl = await _cloudinaryService.uploadMedia(
        pickedFile: pickedFile,
        onProgress: (progress) {
          setState(() {
            _uploadProgress = progress;
          });
        },
      );

      if (downloadUrl != null) {
        _sendMediaMessage(downloadUrl, fileType, pickedFile.name);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error uploading file: $e")));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _sendMediaMessage(
    String fileUrl,
    String fileType,
    String fileName,
  ) async {
    String myEmail = _auth.currentUser!.email!;

    // রিপ্লাই ডেটা প্রিপেয়ার করা হচ্ছে
    Map<String, dynamic>? currentReply = _replyMessage != null
        ? {
            "message": _replyMessage!['message'] ?? "",
            "sender": _replyMessage!['sender'] ?? "",
            "type": _replyMessage!['type'] ?? "text",
          }
        : null;

    Map<String, dynamic> messageMap = {
      "sender": myEmail,
      "message": fileUrl,
      "fileName": fileName,
      "type": fileType,
      "timestamp": FieldValue.serverTimestamp(),
      "deletedBy": [],
      "status": "delivered",
      "repliedTo": currentReply, // ফায়ারস্টোরে স্পেসিফিক রিপ্লাই ডেটা পুশ
    };

    // মেসেজ পাঠানোর সাথে সাথে ইনপুট প্যানেলের রিপ্লাই প্রিভিউ ক্লিয়ার হবে
    setState(() {
      _replyMessage = null;
    });

    await FirebaseFirestore.instance
        .collection("chatrooms")
        .doc(chatRoomId)
        .collection("chats")
        .add(messageMap);

    String previewText = "📁 Attachment";
    if (fileType == 'image') previewText = "📸 Photo";
    if (fileType == 'video') previewText = "🎥 Video";

    await FirebaseFirestore.instance
        .collection("chatrooms")
        .doc(chatRoomId)
        .update({
          "lastMessage": previewText,
          "lastMessageTime": FieldValue.serverTimestamp(),
        });
  }

  void _sendTextMessage() async {
    String msg = _messageController.text.trim();
    if (msg.isEmpty) return;

    _messageController.clear();
    String myEmail = _auth.currentUser!.email!;

    // রিপ্লাই ডেটা প্রিপেয়ার করা হচ্ছে
    Map<String, dynamic>? currentReply = _replyMessage != null
        ? {
            "message": _replyMessage!['message'] ?? "",
            "sender": _replyMessage!['sender'] ?? "",
            "type": _replyMessage!['type'] ?? "text",
          }
        : null;

    Map<String, dynamic> messageMap = {
      "sender": myEmail,
      "message": msg,
      "type": "text",
      "timestamp": FieldValue.serverTimestamp(),
      "deletedBy": [],
      "status": "delivered",
      "repliedTo": currentReply, // ফায়ারস্টোরে স্পেসিফিক রিপ্লাই ডেটা পুশ
    };

    // মেসেজ পাঠানোর সাথে সাথে ইনপুট প্যানেলের রিপ্লাই প্রিভিউ ক্লিয়ার হবে
    setState(() {
      _replyMessage = null;
    });

    await FirebaseFirestore.instance
        .collection("chatrooms")
        .doc(chatRoomId)
        .collection("chats")
        .add(messageMap);

    await FirebaseFirestore.instance
        .collection("chatrooms")
        .doc(chatRoomId)
        .update({
          "lastMessage": msg,
          "lastMessageTime": FieldValue.serverTimestamp(),
        });
  }

  // ==================== Attachment Selector Sheets ====================
  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildAttachmentOption(
                      icon: Icons.image_rounded,
                      color: Colors.purple,
                      label: "Photo",
                      onTap: () async {
                        Navigator.pop(context);
                        FilePickerResult? result = await FilePicker.platform
                            .pickFiles(type: FileType.image);
                        if (result != null) {
                          _processAndUploadMedia(result.files.single, 'image');
                        }
                      },
                    ),
                    _buildAttachmentOption(
                      icon: Icons.videocam_rounded,
                      color: Colors.pink,
                      label: "Video",
                      onTap: () async {
                        Navigator.pop(context);
                        FilePickerResult? result = await FilePicker.platform
                            .pickFiles(type: FileType.video);
                        if (result != null) {
                          _processAndUploadMedia(result.files.single, 'video');
                        }
                      },
                    ),
                    _buildAttachmentOption(
                      icon: Icons.insert_drive_file_rounded,
                      color: Colors.blue,
                      label: "Document",
                      onTap: () async {
                        Navigator.pop(context);
                        FilePickerResult? result = await FilePicker.platform
                            .pickFiles(type: FileType.any);
                        if (result != null) {
                          _processAndUploadMedia(result.files.single, 'document');
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: color.withOpacity(0.1),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(
            label, 
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13, color: Color(0xFF1E293B)),
          ),
        ],
      ),
    );
  }

  // ==================== 🔄 Reply Preview Widget above Input Field ====================
  Widget _buildReplyPreview() {
    if (_replyMessage == null) return const SizedBox.shrink();

    String myEmail = _auth.currentUser!.email!;
    String senderName = _replyMessage!['sender'] == myEmail
        ? "You"
        : widget.receiverName;
    String type = _replyMessage!['type'] ?? 'text';
    String textPreview = "";

    if (type == 'text') {
      textPreview = _replyMessage!['message'] ?? "";
    } else if (type == 'image') {
      textPreview = "📸 Photo";
    } else if (type == 'video') {
      textPreview = "🎥 Video";
    } else if (type == 'document') {
      textPreview = "📄 Document";
    } else {
      textPreview = "Attachment";
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Container(
              width: 4, 
              height: 36, 
              decoration: BoxDecoration(
                color: Colors.blueAccent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Replying to $senderName",
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    textPreview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF94A3B8)),
              onPressed: () {
                setState(() {
                  _replyMessage = null;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String myEmail = _auth.currentUser!.email!;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // প্রিমিয়াম ব্যাকগ্রাউন্ড কালার
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
              backgroundImage: widget.receiverImage.isNotEmpty
                  ? NetworkImage(widget.receiverImage)
                  : null,
              child: widget.receiverImage.isEmpty
                  ? const Icon(Icons.person_rounded, size: 20, color: Colors.blueAccent)
                  : null,
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
      ),
      body: Column(
        children: [
          if (_isUploading)
            Container(
              color: Colors.blue[50],
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _uploadProgress / 100,
                        backgroundColor: Colors.grey[200],
                        color: Colors.blueAccent,
                        minHeight: 5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    "${_uploadProgress.toStringAsFixed(0)}%",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.blueAccent,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("chatrooms")
                  .doc(chatRoomId)
                  .collection("chats")
                  .orderBy("timestamp", descending: true)
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
                        Text(
                          "👋", 
                          style: TextStyle(fontSize: 40),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Say Hi to ${widget.receiverName}!", 
                          style: TextStyle(color: Colors.grey[500], fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _markMessagesAsSeen();
                });

                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var ds = snapshot.data!.docs[index];
                    var data = ds.data() as Map<String, dynamic>;
                    bool isMe = data['sender'] == myEmail;
                    String messageId = ds.id;

                    return MessageBubble(
                      data: data,
                      isMe: isMe,
                      messageId: messageId,
                      chatRoomId: chatRoomId,
                      myEmail: myEmail,
                      onReply: (messageData) {
                        setState(() {
                          _replyMessage = messageData;
                        });
                      },
                    );
                  },
                );
              },
            ),
          ),

          // টেক্সট ইনপুট ফিল্ডের ঠিক উপরে রিপ্লাই প্রিভিউ প্যানেল সেট করা হলো
          _buildReplyPreview(),

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
                  icon: const Icon(
                    Icons.add_circle_outline_rounded,
                    color: Colors.blueAccent,
                    size: 28,
                  ),
                  onPressed: _showAttachmentMenu,
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
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                CircleAvatar(
                  backgroundColor: Colors.blueAccent,
                  radius: 22,
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    onPressed: _sendTextMessage,
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