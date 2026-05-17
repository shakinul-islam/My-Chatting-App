import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';
import 'package:permission_handler/permission_handler.dart';

class CallService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ==================== Singleton Pattern ====================
  static final CallService _instance = CallService._internal();
  factory CallService() => _instance;
  CallService._internal();

  // ==================== 1. Permission Handler ====================
  /// ক্যামেরা ও মাইক্রোফোন পারমিশন চেক এবং রিকোয়েস্ট করার মেথড
  Future<bool> checkCallPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.microphone,
    ].request();

    return statuses[Permission.camera]!.isGranted &&
        statuses[Permission.microphone]!.isGranted;
  }

  // ==================== 2. Initiate Call (Caller End) ====================
  /// কলার এন্ড থেকে কল তৈরি করে ফায়ারস্টোরে পুশ করার মেথড
  Future<void> makeCall({
    required BuildContext context,
    required String receiverEmail,
    required String receiverName,
    required String callType, // 'audio' অথবা 'video'
  }) async {
    // পারমিশন চেক করা
    bool hasPermission = await checkCallPermissions();
    if (!hasPermission) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Camera and Microphone permissions are required."),
          ),
        );
      }
      return;
    }

    String? myEmail = _auth.currentUser?.email;
    String myUid = _auth.currentUser!.uid;

    if (myEmail == null) return;

    // ডাটাবেজ থেকে নিজের নাম রিড করা
    String myName = _auth.currentUser?.displayName ?? myEmail;
    var myUserDoc = await _firestore
        .collection('users')
        .where('email', isEqualTo: myEmail)
        .get();
    if (myUserDoc.docs.isNotEmpty) {
      myName = myUserDoc.docs.first.data()['name'] ?? myName;
    }

    // রিসিভারের রিয়েল UID খুঁজে বের করা
    var receiverUserDoc = await _firestore
        .collection('users')
        .where('email', isEqualTo: receiverEmail)
        .get();
    if (receiverUserDoc.docs.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Receiver could not be found.")),
        );
      }
      return;
    }
    String receiverUid = receiverUserDoc.docs.first.id;

    // ওয়ান-টু-ওয়ান হোয়াটসঅ্যাপ কলের জন্য ইউনিক ও ম্যাচিং রুম আইডি
    String channelId =
        'whatsapp_call_${myUid}_${DateTime.now().millisecondsSinceEpoch}';
    DocumentReference callRef = _firestore.collection('calls').doc();
    String callId = callRef.id;

    Map<String, dynamic> callData = {
      'callId': callId,
      'callerId': myUid,
      'callerName': myName,
      'receiverId': receiverUid,
      'channelId': channelId,
      'status': 'ringing',
      'type': callType, // 'audio' or 'video'
      'timestamp': FieldValue.serverTimestamp(),
    };

    // ফায়ারস্টোরে কলের এন্ট্রি পুশ করা (যার ফলে রিসিভারের স্ক্রিনে রিং বাজবে)
    await callRef.set(callData);

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Calling $receiverName...")));
    }

    // কলার নিজে লাইভ পিটুপি চ্যানেলে কানেক্ট হয়ে রিসিভারের জন্য অপেক্ষা করবে
    await _connectToP2PChannel(channelId: channelId, callType: callType);
  }

  // ==================== 3. Receiver End (Join Call) ====================
  /// ইনকামিং কলে রিসিভার জয়েন করার এক্সটার্নাল মেথড (HomePage থেকে কল হবে)
  Future<void> joinIncomingCall({
    required String? channelId,
    required String callType,
  }) async {
    if (channelId == null || channelId.isEmpty) {
      debugPrint("Error: Channel ID is null or empty.");
      return;
    }
    await _connectToP2PChannel(channelId: channelId, callType: callType);
  }

  // ==================== 4. Core P2P Connection Engine ====================
  /// হোয়াটসঅ্যাপের মতো ওয়ান-টু-ওয়ান ডেডিকেটেড চ্যানেল কানেকশন সেটআপ
  Future<void> _connectToP2PChannel({
    required String channelId,
    required String callType,
  }) async {
    var jitsiMeet = JitsiMeet();

    var options = JitsiMeetConferenceOptions(
      room: channelId,
      configOverrides: {
        // কন্ডিশনাল ক্যামেরা হ্যান্ডলিং
        "startWithAudioMuted": false,
        "startWithVideoMuted": callType == 'audio' ? true : false,

        // ওয়ান-টু-ওয়ান কল অপটিমাইজেশন (মিটিং লুক রিমুভ করার জন্য)
        "p2p.enabled": true, // Peer-to-Peer ডিরেক্ট কানেকশন চালু
        "prejoin.enabled": false, // জয়েন করার আগের বাড়তি স্ক্রিন স্কিপ হবে
        "disableRemoteMute": true, // একে অপরকে মিউট করার অপশন বন্ধ
        "toolbarButtons": [
          'microphone',
          'camera',
          'hangup',
          'tileview',
          'togglecamera',
        ], // হোয়াটসঅ্যাপের মতো মিনিমাল কল কন্ট্রোল টুলবার
      },
      featureFlags: {
        "unstable.debug-monitor": false,
        "welcomepage.enabled": false,
        "chat.enabled": false, // কলিং স্ক্রিনের ভেতর টেক্সট চ্যাট বন্ধ
        "invite.enabled": false, // থার্ড পারসন ইনভাইট করার অপশন হাইড
        "raise-hand.enabled": false, // হাত তোলার অপশন হাইড
        "recording.enabled": false,
      },
    );

    debugPrint(
      "Launching One-on-One Live Session via CallService: $channelId ($callType)",
    );

    try {
      await jitsiMeet.join(options);
    } catch (e) {
      debugPrint("Error joining Jitsi Meet Call Channel: $e");
    }
  }
}
