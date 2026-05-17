import 'package:dio/dio.dart'
    as dio; // Dio এর কনফ্লিক্ট এড়াতে অ্যালিয়াস ব্যবহার করা হয়েছে
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:universal_io/io.dart' as uio;
import 'package:file_picker/file_picker.dart'; // FilePicker সাপোর্ট করার জন্য যুক্ত করা হয়েছে

class CloudinaryService {
  final String cloudName = "dnthfbpe7";
  final String uploadPreset = "chat_preset";
  final dio.Dio _dio = dio.Dio();

  // ==================== ১. আপনার আগের এক্সিস্টিং মেথড (ImagePicker এর জন্য) ====================
  Future<String?> uploadMediaFile({
    uio.File? file, // মোবাইলের জন্য (universal_io)
    XFile? webFile, // ক্রোমের (Web) জন্য
    required String fileType,
    required Function(int, int) onProgress,
  }) async {
    try {
      String url = "https://api.cloudinary.com/v1_1/$cloudName/auto/upload";
      dio.FormData formData;

      // যদি ক্রোম বা ওয়েব ব্রাউজার হয় এবং webFile থাকে
      if (kIsWeb && webFile != null) {
        final bytes = await webFile.readAsBytes();
        formData = dio.FormData.fromMap({
          "file": dio.MultipartFile.fromBytes(bytes, filename: webFile.name),
          "upload_preset": uploadPreset,
        });
      }
      // যদি মোবাইল বা অ্যান্ড্রয়েড হয় এবং নরমাল ফাইল থাকে
      else if (file != null) {
        formData = dio.FormData.fromMap({
          "file": await dio.MultipartFile.fromFile(file.path),
          "upload_preset": uploadPreset,
        });
      } else {
        return null;
      }

      dio.Response response = await _dio.post(
        url,
        data: formData,
        onReceiveProgress: onProgress,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data["secure_url"];
      }
      return null;
    } catch (e) {
      print("Cloudinary Upload Error: $e");
      return null;
    }
  }

  // ==================== ২. চ্যাট স্ক্রিনের FilePicker (PlatformFile) এর জন্য মেথড ====================
  Future<String?> uploadMedia({
    required PlatformFile pickedFile,
    required Function(double) onProgress,
  }) async {
    try {
      String url = "https://api.cloudinary.com/v1_1/$cloudName/auto/upload";
      dio.FormData formData;

      if (kIsWeb) {
        if (pickedFile.bytes == null) {
          throw Exception("ফাইল ডেটা পাওয়া যায়নি।");
        }
        formData = dio.FormData.fromMap({
          "file": dio.MultipartFile.fromBytes(
            pickedFile.bytes!,
            filename: pickedFile.name,
          ),
          "upload_preset": uploadPreset,
        });
      } else {
        if (pickedFile.path == null) throw Exception("ফাইল পাথ পাওয়া যায়নি।");
        formData = dio.FormData.fromMap({
          "file": await dio.MultipartFile.fromFile(
            pickedFile.path!,
            filename: pickedFile.name,
          ),
          "upload_preset": uploadPreset,
        });
      }

      // এখানে আপনার গ্লোবাল _dio ব্যবহার করা হয়েছে এবং ফাইল পাঠানোর (onSendProgress) প্রোগ্রেস ট্র্যাক করা হচ্ছে
      dio.Response response = await _dio.post(
        url,
        data: formData,
        onSendProgress: (sent, total) {
          if (total > 0) {
            double progress = (sent / total) * 100;
            onProgress(
              progress,
            ); // চ্যাট স্ক্রিনে সরাসরি পার্সেন্টেজ (%) পাঠাবে
          }
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data['secure_url'];
      } else {
        throw Exception("Cloudinary Upload Failed");
      }
    } catch (e) {
      print("Cloudinary Chat Upload Error: $e");
      rethrow; // চ্যাট স্ক্রিনের try-catch ব্লকে এররটি পাস করার জন্য
    }
  }
}
