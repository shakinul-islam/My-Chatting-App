import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ১. চ্যাট রুম তৈরি বা খুঁজে বের করার ফাংশন
  Future<void> createChatRoom(
    String chatRoomId,
    Map<String, dynamic> chatRoomMap,
  ) async {
    try {
      // SetOptions(merge: true) ব্যবহার করা হয়েছে যাতে পুরনো ডেটা মুছে না যায়
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
      // শুরুতে ডিলিটের জন্য একটি খালি লিস্ট দিয়ে রাখা হচ্ছে
      messageMap['deletedBy'] = [];

      // চ্যাটরুমের ভেতর 'chats' সাব-কালেকশনে মেসেজটি সেভ করা
      await _db
          .collection("chatrooms")
          .doc(chatRoomId)
          .collection("chats")
          .add(messageMap);

      // চ্যাটরুমের লাস্ট মেসেজ নির্ধারণ করা (টেক্সট নাকি মিডিয়া ফাইল)
      String lastMsg = messageMap['type'] == 'text'
          ? messageMap['message']
          : "📁 Media file";

      // চ্যাটরুমের মেইন ডকুমেন্টে শেষ মেসেজ এবং সময় আপডেট করা
      await _db.collection("chatrooms").doc(chatRoomId).set({
        "lastMessage": lastMsg,
        "lastMessageSendBy": messageMap['sendBy'],
        "lastMessageTime":
            messageMap['time'], // সর্টিং এর জন্য অত্যন্ত গুরুত্বপূর্ণ
      }, SetOptions(merge: true));
    } catch (e) {
      print("Error updating recent chat: ${e.toString()}");
    }
  }

  // ৩. নির্দিষ্ট চ্যাট রুমের মেসেজগুলো রিয়েল-টাইমে পড়ার স্ট্রিম
  Stream<QuerySnapshot> getConversationMessages(String chatRoomId) {
    return _db
        .collection("chatrooms")
        .doc(chatRoomId)
        .collection("chats")
        .orderBy("time", descending: true)
        .snapshots();
  }

  // ৪. Delete for Me (মেসেজটি শুধু নিজের জন্য হাইড করা)
  Future<void> deleteMessageForMe(
    String chatRoomId,
    String messageId,
    String myEmail,
  ) async {
    try {
      await _db
          .collection("chatrooms")
          .doc(chatRoomId)
          .collection("chats")
          .doc(messageId)
          .update({
            "deletedBy": FieldValue.arrayUnion([myEmail]),
          });
    } catch (e) {
      print("deleteMessageForMe Error: ${e.toString()}");
    }
  }

  // ৫. Delete for Everyone (মেসেজটি পার্মানেন্টলি সবার জন্য ডিলিট করা)
  Future<void> deleteMessageForEveryone(
    String chatRoomId,
    String messageId,
  ) async {
    try {
      await _db
          .collection("chatrooms")
          .doc(chatRoomId)
          .collection("chats")
          .doc(messageId)
          .delete();
    } catch (e) {
      print("deleteMessageForEveryone Error: ${e.toString()}");
    }
  }

  // ৬. সম্পূর্ণ কনভারসেশন ডিলিট করা (Homepage এর জন্য)
  Future<void> deleteEntireConversation(String chatRoomId) async {
    try {
      var chatsCollection = _db
          .collection("chatrooms")
          .doc(chatRoomId)
          .collection("chats");

      var snapshots = await chatsCollection.get();

      // সাব-কালেকশনের সব মেসেজ একটা একটা করে ডিলিট করা হচ্ছে
      for (var doc in snapshots.docs) {
        await doc.reference.delete();
      }

      // চ্যাট রুমের মেইন ডকুমেন্টটি ডিলিট করা (যাতে রিসেন্ট চ্যাট লিস্ট থেকে চলে যায়)
      await _db.collection("chatrooms").doc(chatRoomId).delete();
    } catch (e) {
      print("deleteEntireConversation Error: ${e.toString()}");
    }
  }

  // ৭. ইউজার নাম দিয়ে সার্চ করার ফাংশন
  Future<QuerySnapshot> searchUserByName(String name) async {
    try {
      return await _db.collection('users').where('name', isEqualTo: name).get();
    } catch (e) {
      print("searchUserByName Error: ${e.toString()}");
      rethrow;
    }
  }

  // ৮. গ্লোবাল মেসেজ পাঠানোর ফাংশন
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

  // ৯. গ্লোবাল মেসেজ স্ট্রিম
  Stream<QuerySnapshot> getMessages() {
    return _db
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }
}
