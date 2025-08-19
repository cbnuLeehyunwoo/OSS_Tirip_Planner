import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'TextEdit/travel_home_page.dart'; 
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  // Flutter 엔진과 위젯 트리를 바인딩합니다.
  WidgetsFlutterBinding.ensureInitialized();

  // .env 파일을 로드합니다.
  await dotenv.load(fileName: ".env");

  // Firebase를 초기화합니다.
  await Firebase.initializeApp();

  // 익명으로 Firebase에 로그인합니다.
  try {
    await FirebaseAuth.instance.signInAnonymously();
    print("Signed in with temporary account.");
  } catch (e) {
    print("Failed to sign in anonymously: $e");
  }
  
  runApp(const TravelApp());
}

class TravelApp extends StatelessWidget {
  const TravelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cats Travel Planner',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF9F9F9),
        fontFamily: 'Pretendard',
      ),
      home: const TravelHomePage(),
    );
  }
}
