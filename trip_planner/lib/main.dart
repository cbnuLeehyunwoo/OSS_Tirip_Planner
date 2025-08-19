import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'TextEdit/travel_home_page.dart'; // 홈 페이지를 별도 파일에서 가져옵니다.

Future<void> main() async {
  await dotenv.load(fileName: ".env");
  
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
      // 분리된 TravelHomePage 위젯을 사용합니다.
      home: const TravelHomePage(),
    );
  }
}