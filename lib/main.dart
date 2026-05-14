import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // FirebaseAuth ইম্পোর্ট করা হয়েছে
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/home_page.dart'; // HomePage ইম্পোর্ট করা হয়েছে

void main() async {
  // নিশ্চিত করা যে ফ্লাটার ইঞ্জিন ঠিকমতো ইনিশিয়ালাইজ হয়েছে
  WidgetsFlutterBinding.ensureInitialized();

  // ফায়ারবেস কানেক্ট করা
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chatting App',
      debugShowCheckedModeBanner: false, // ডান পাশের লাল ব্যানারটি সরানোর জন্য
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true, // আধুনিক ডিজাইনের জন্য
      ),
      // এখানে আপনার দেওয়া লজিকটি সেটআপ করা হয়েছে
      home: FirebaseAuth.instance.currentUser == null
          ? const LoginScreen()
          : const HomePage(),
    );
  }
}
