import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ১. চ্যাট রুম তৈরি বা খুঁজে বের করার ফাংশন
  Future<void> createChatRoom(
    String chatRoomId,
    Map<String, dynamic> chatRoomMap,
  ) async {
    try {
      // SetOptions(merge: true) ব্যবহার করা হয়েছে যাতে পুরনো ডেটা মুছে না যায়
      await _db
          .collection("chatrooms")
          .doc(chatRoomId)
          .set(chatRoomMap, SetOptions(merge: true));
    } catch (e) {
      print("createChatRoom Error: ${e.toString()}");
    }
  }

  // ২. নির্দিষ্ট চ্যাট রুমে মেসেজ পাঠানো এবং হোমস্ক্রিন (Recent Chat) আপডেট করা
  Future<void> addConversationMessages(
    String chatRoomId,
    Map<String, dynamic> messageMap,
  ) async {
    try {
      // চ্যাটরুমের ভেতর 'chats' সাব-কালেকশনে মেসেজটি সেভ করা (চ্যাটবক্সের মেসেজ লিস্টের জন্য)
      await _db
          .collection("chatrooms")
          .doc(chatRoomId)
          .collection("chats")
          .add(messageMap);

      // চ্যাটরুমের মেইন ডকুমেন্টে শেষ মেসেজ এবং সময় আপডেট করা (হোমস্ক্রিনের রিসেন্ট লিস্টের জন্য)
      await _db.collection("chatrooms").doc(chatRoomId).update({
        "lastMessage": messageMap['message'],
        "lastMessageSendBy": messageMap['sendBy'],
        "lastMessageTime":
            messageMap['time'], // এটি সর্টিং এর জন্য অত্যন্ত গুরুত্বপূর্ণ
      });
    } catch (e) {
      // যদি কোনো কারণে ডকুমেন্টটি আগে তৈরি না থাকে বা 'update' এরর দেয়, তবে fallback হিসেবে set ব্যবহার করা যায়
      print("Error updating recent chat: ${e.toString()}");

      // Fallback: ডকুমেন্ট না থাকলে তৈরি করে নিবে
      await _db.collection("chatrooms").doc(chatRoomId).set({
        "lastMessage": messageMap['message'],
        "lastMessageTime": messageMap['time'],
      }, SetOptions(merge: true));
    }
  }

  // ৩. নির্দিষ্ট চ্যাট রুমের মেসেজগুলো রিয়েল-টাইমে পড়ার স্ট্রিম
  Stream<QuerySnapshot> getConversationMessages(String chatRoomId) {
    return _db
        .collection("chatrooms")
        .doc(chatRoomId)
        .collection("chats")
        .orderBy("time", descending: true)
        .snapshots();
  }

  // ৪. ইউজার নাম দিয়ে সার্চ করার ফাংশন
  Future<QuerySnapshot> searchUserByName(String name) async {
    try {
      return await _db.collection('users').where('name', isEqualTo: name).get();
    } catch (e) {
      print("searchUserByName Error: ${e.toString()}");
      rethrow;
    }
  }

  // ৫. গ্লোবাল মেসেজ পাঠানোর ফাংশন (যদি প্রয়োজন হয়)
  Future<void> sendMessage(String message, String senderEmail) async {
    try {
      await _db.collection('messages').add({
        'text': message,
        'sender': senderEmail,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Error sending global message: ${e.toString()}");
    }
  }

  // ৬. গ্লোবাল মেসেজ স্ট্রিম
  Stream<QuerySnapshot> getMessages() {
    return _db
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }
}
