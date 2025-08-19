import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:naver_map_test/map_page.dart';

// NaverMap 위젯을 실행하기 이전에 초기화가 꼭 필요합니다.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  final String naverClientId = dotenv.env['NAVER_CLIENT_ID'] ?? '';

  await FlutterNaverMap().init(
      clientId: naverClientId,
      onAuthFailed: (ex) {
        switch (ex) {
          case NQuotaExceededException(:final message):
            print("사용량 초과 (message: $message)");
            break;
          case NUnauthorizedClientException() ||
                NClientUnspecifiedException() ||
                NAnotherAuthFailedException():
            print("인증 실패: $ex");
            break;
        }
      });

  runApp(const MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MapScreen();
  }
}