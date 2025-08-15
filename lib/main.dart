import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:tour_api_test/input_page.dart';

Future<void> main() async {
  print('앱 시작!');
  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    print('MyApp 위젯 빌드됨!');
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('문자열 입력'),
        ),
        body: const Center(
          child: RegionSelector(),
        ),
      ),
    );
  }
}

