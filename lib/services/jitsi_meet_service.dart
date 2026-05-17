import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';

class JitsiMeetService {
  final JitsiMeet _jitsiMeet = JitsiMeet();

  /// ভিডিও বা অডিও কল শুরু করার মেইন মেথড
  void startCall({
    required String roomName,
    required String userName,
    required String userEmail,
    required String userAvatar,
    required bool isVideoCall,
  }) async {
    try {
      // কলের বিভিন্ন অপশন সেট করা (যেমন: অডিও বা ভিডিও অন/অফ থাকবে কিনা)
      var options = JitsiMeetConferenceOptions(
        room: roomName,
        serverURL: "https://meet.jit.si", // জিটসির ফ্রি পাবলিক সার্ভার
        configOverrides: {
          "startWithAudioMuted": false,
          "startWithVideoMuted": !isVideoCall, // অডিও কল হলে ভিডিও অফ থাকবে
        },
        featureFlags: {
          "unmuteBodyButton": true,
          "chat.enabled": false, // জিটসির ইন্টারনাল চ্যাট অফ রাখা হয়েছে
          "invite.enabled": false,
        },
        userInfo: JitsiMeetUserInfo(
          displayName: userName,
          email: userEmail,
          avatar: userAvatar,
        ),
      );

      // কল স্ক্রিন ওপেন করা
      await _jitsiMeet.join(options);
    } catch (error) {
      print("Jitsi Meet Call Error: \$error");
    }
  }
}
