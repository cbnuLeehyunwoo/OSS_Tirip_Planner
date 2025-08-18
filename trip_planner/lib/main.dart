import 'package:flutter/material.dart';
import 'TextEdit/travel_home_page.dart'; 
import 'package:flutter_dotenv/flutter_dotenv.dart';

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
      home: const TravelHomePage(),
    );
  }
}