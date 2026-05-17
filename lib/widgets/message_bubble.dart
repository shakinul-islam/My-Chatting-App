import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';

class MessageBubble extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isMe;
  final String messageId;
  final String chatRoomId;
  final String myEmail;
  final Function(Map<String, dynamic>)? onReply;

  const MessageBubble({
    super.key,
    required this.data,
    required this.isMe,
    required this.messageId,
    required this.chatRoomId,
    required this.myEmail,
    this.onReply,
  });

  // ==================== 🕒 টাইম ফরম্যাটার (HH:MM AM/PM) ====================
  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return "";
    DateTime dateTime = timestamp.toDate();
    int hour = dateTime.hour;
    int minute = dateTime.minute;
    String ampm = hour >= 12 ? 'PM' : 'AM';

    hour = hour % 12;
    hour = hour == 0 ? 12 : hour;
    String minuteStr = minute < 10 ? '0$minute' : '$minute';

    return '$hour:$minuteStr $ampm';
  }

  // ==================== ✔✔ কাস্টম মেসেজ স্ট্যাটাস জেনারেটর ====================
  Widget _buildTickStatus(String status, Color defaultColor) {
    if (status == 'read') {
      return const Icon(Icons.done_all, size: 15, color: Colors.blueAccent);
    } else if (status == 'delivered') {
      return Icon(Icons.done_all, size: 15, color: defaultColor);
    } else {
      return Icon(Icons.done, size: 15, color: defaultColor);
    }
  }

  // ==================== 😊 Reaction Picker Menu ====================
  void _showReactionDialog(BuildContext context) {
    final List<String> emojis = ["❤️", "👍", "😂", "😮", "😢", "🙏"];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        elevation: 8,
        backgroundColor: Theme.of(context).canvasColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: emojis.map((emoji) {
            return GestureDetector(
              onTap: () async {
                Navigator.pop(context);
                await FirebaseFirestore.instance
                    .collection("chatrooms")
                    .doc(chatRoomId)
                    .collection("chats")
                    .doc(messageId)
                    .update({"reaction": emoji});
              },
              child: Transform.scale(
                scale: 1.1,
                child: Text(emoji, style: const TextStyle(fontSize: 26)),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ==================== 🛠️ Message Options Menu (Unified) ====================
  void _showOptionsMenu(BuildContext context, String currentMsgType) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.4),
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    "Message Options",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Colors.grey,
                    ),
                  ),
                ),
                const Divider(height: 1),
                if (currentMsgType != 'deleted') ...[
                  ListTile(
                    leading: const Icon(
                      Icons.reply_rounded,
                      color: Colors.blue,
                    ),
                    title: const Text(
                      "Reply",
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      if (onReply != null) {
                        onReply!(data);
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.add_reaction_outlined,
                      color: Colors.purple,
                    ),
                    title: const Text(
                      "Add Reaction",
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _showReactionDialog(context);
                    },
                  ),
                ],
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.orange,
                  ),
                  title: const Text(
                    "Delete for me",
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await FirebaseFirestore.instance
                        .collection("chatrooms")
                        .doc(chatRoomId)
                        .collection("chats")
                        .doc(messageId)
                        .update({
                          "deletedBy": FieldValue.arrayUnion([myEmail]),
                        });
                  },
                ),
                if (isMe && currentMsgType != 'deleted')
                  ListTile(
                    leading: const Icon(
                      Icons.delete_forever_rounded,
                      color: Colors.redAccent,
                    ),
                    title: const Text(
                      "Delete for everyone",
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      await FirebaseFirestore.instance
                          .collection("chatrooms")
                          .doc(chatRoomId)
                          .collection("chats")
                          .doc(messageId)
                          .update({
                            "message": "🚫 This message was deleted",
                            "type": "deleted",
                            "fileName": "",
                            "reaction": "",
                            "repliedTo": null,
                          });

                      await FirebaseFirestore.instance
                          .collection("chatrooms")
                          .doc(chatRoomId)
                          .update({"lastMessage": "🚫 Message deleted"});
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==================== 🔄 Reply Message UI Component ====================
  Widget _buildReplyHeader(Map<String, dynamic>? repliedTo) {
    if (repliedTo == null) return const SizedBox.shrink();

    String senderName = repliedTo['sender'] == myEmail ? "You" : "Other";
    String msgPreview = "Attachment";

    if (repliedTo['type'] == 'text') {
      msgPreview = repliedTo['message'] ?? "";
    } else if (repliedTo['type'] == 'image') {
      msgPreview = "📸 Photo";
    } else if (repliedTo['type'] == 'video') {
      msgPreview = "🎥 Video";
    } else if (repliedTo['type'] == 'document') {
      msgPreview = "📄 Document";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isMe
            ? Colors.black.withOpacity(0.1)
            : Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: isMe ? Colors.white70 : Colors.blueAccent,
            width: 3.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            senderName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isMe ? Colors.white.withOpacity(0.9) : Colors.blue[800],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            msgPreview,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: isMe ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== Cross-Platform Download Mechanism ====================
  Future<void> _downloadFile(
    BuildContext context,
    String url,
    String fileName,
  ) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Opening file attachment link...")),
      );
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw "Could not launch $url";
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error opening file: $e")));
      }
    }
  }

  // ==================== Full Screen Image View ====================
  void _openFullImageView(
    BuildContext context,
    String imageUrl,
    String fileName,
  ) {
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                maxScale: 4.0,
                child: Image.network(imageUrl, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              left: 10,
              right: 10,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Row(
                    children: [
                      Text(
                        fileName.length > 15
                            ? "${fileName.substring(0, 12)}..."
                            : fileName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        icon: const Icon(
                          Icons.download_for_offline_rounded,
                          color: Colors.blueAccent,
                          size: 28,
                        ),
                        onPressed: () =>
                            _downloadFile(context, imageUrl, fileName),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String type = data['type'] ?? 'text';
    String message = data['message'] ?? '';
    String fileName = data['fileName'] ?? 'Attachment';
    List<dynamic> deletedBy = data['deletedBy'] ?? [];
    String status = data['status'] ?? 'sent';
    Timestamp? timestamp = data['timestamp'] as Timestamp?;

    String reaction = data['reaction'] ?? '';
    Map<String, dynamic>? repliedTo = data['repliedTo'] != null
        ? Map<String, dynamic>.from(data['repliedTo'])
        : null;

    if (deletedBy.contains(myEmail)) {
      return const SizedBox.shrink();
    }

    if (!isMe && status != 'read') {
      FirebaseFirestore.instance
          .collection("chatrooms")
          .doc(chatRoomId)
          .collection("chats")
          .doc(messageId)
          .update({"status": "read"});
    }

    Widget timeAndTickWidget({Color? textColor}) {
      Color defaultColor = isMe ? Colors.white60 : Colors.black38;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatTimestamp(timestamp),
            style: TextStyle(fontSize: 10, color: textColor ?? defaultColor),
          ),
          if (isMe && type != 'deleted') ...[
            const SizedBox(width: 4),
            _buildTickStatus(status, defaultColor),
          ],
        ],
      );
    }

    Widget contentWidget;

    if (type == 'deleted') {
      contentWidget = Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.block_rounded, size: 16, color: Colors.grey[400]),
            const SizedBox(width: 6),
            Text(
              message,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }
    // ==================== 📸 IMAGE BUBBLE ====================
    else if (type == 'image') {
      contentWidget = ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            GestureDetector(
              onTap: () => _openFullImageView(context, message, fileName),
              child: Image.network(
                message,
                width: 240,
                height: 260,
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              bottom: 8,
              right: 8,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  color: Colors.black.withOpacity(0.5),
                  child: timeAndTickWidget(
                    textColor: Colors.white.withOpacity(0.85),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    // ==================== 🎥 VIDEO BUBBLE ====================
    else if (type == 'video') {
      contentWidget = Container(
        width: 240,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFFE3F2FD) : Colors.grey[200],
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (repliedTo != null) _buildReplyHeader(repliedTo),
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.redAccent.withOpacity(0.15),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.redAccent,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    fileName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.arrow_circle_down_rounded,
                    size: 24,
                    color: Colors.black54,
                  ),
                  onPressed: () => _downloadFile(context, message, fileName),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Align(alignment: Alignment.bottomRight, child: timeAndTickWidget()),
          ],
        ),
      );
    }
    // ==================== 📁 DOCUMENT BUBBLE ====================
    else if (type == 'document') {
      contentWidget = Container(
        width: 240,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFFE8F5E9) : Colors.grey[200],
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (repliedTo != null) _buildReplyHeader(repliedTo),
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.green.withOpacity(0.15),
                  child: const Icon(
                    Icons.description_rounded,
                    color: Colors.green,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    fileName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.arrow_circle_down_rounded,
                    size: 24,
                    color: Colors.black54,
                  ),
                  onPressed: () => _downloadFile(context, message, fileName),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Align(alignment: Alignment.bottomRight, child: timeAndTickWidget()),
          ],
        ),
      );
    }
    // ==================== 💬 TEXT BUBBLE ====================
    else {
      contentWidget = Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF007AFF) : const Color(0xFFF2F2F7),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (repliedTo != null) _buildReplyHeader(repliedTo),
            LayoutBuilder(
              builder: (context, constraints) {
                final textSpan = TextSpan(
                  text: message,
                  style: TextStyle(
                    color: isMe ? Colors.white : Colors.black87,
                    fontSize: 15.5,
                  ),
                );
                final textPainter = TextPainter(
                  text: textSpan,
                  textDirection: TextDirection.ltr,
                )..layout(maxWidth: constraints.maxWidth - 65);

                bool isLongMessage =
                    textPainter.didExceedMaxLines || message.length > 30;

                if (isLongMessage) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        message,
                        style: TextStyle(
                          color: isMe ? Colors.white : Colors.black87,
                          fontSize: 15.5,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: timeAndTickWidget(),
                      ),
                    ],
                  );
                } else {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          message,
                          style: TextStyle(
                            color: isMe ? Colors.white : Colors.black87,
                            fontSize: 15.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: timeAndTickWidget(),
                      ),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onLongPress: () => _showOptionsMenu(context, type),
      onDoubleTap: () => _showReactionDialog(context),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              margin: EdgeInsets.only(
                left: isMe ? 50 : 14,
                right: isMe ? 14 : 50,
                top: reaction.isNotEmpty ? 14 : 4,
                bottom: reaction.isNotEmpty ? 14 : 4,
              ),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.73,
              ),
              child: contentWidget,
            ),
            if (reaction.isNotEmpty)
              Positioned(
                bottom: -6,
                right: isMe ? 22 : null,
                left: !isMe ? 22 : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(reaction, style: const TextStyle(fontSize: 12.5)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
