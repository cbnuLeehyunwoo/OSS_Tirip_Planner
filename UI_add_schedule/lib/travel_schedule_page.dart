// travel_schedule_page.dart
import 'package:flutter/material.dart';
import 'package:schedule_detail_page.dart';

class TravelSchedulePage extends StatefulWidget {
  const TravelSchedulePage({super.key});

  @override
  State<TravelSchedulePage> createState() => _TravelSchedulePageState();
}

class _TravelSchedulePageState extends State<TravelSchedulePage> {
  // 일정 목록을 담을 리스트
  final List<Map<String, String>> _schedules = [];

  // 로딩 상태를 관리하는 변수
  bool _isLoading = false;
  int _scheduleCount = 0;

  // "일정 추가" 버튼을 누르면 호출되는 함수
  void _addSchedule() async {
    // 1. 로딩 상태를 true로 설정하고 화면을 갱신합니다.
    setState(() {
      _isLoading = true;
    });

    try {
      // 2. AI로부터 데이터를 받아오는 비동기 작업을 시뮬레이션합니다.
      // 실제 앱에서는 이곳에 AI 모델 API 호출 로직이 들어갑니다.
      final newScheduleData = await _fetchScheduleFromAI();

      // 3. AI 작업이 성공적으로 끝나면 데이터를 리스트에 추가하고 화면을 갱신합니다.
      setState(() {
        _schedules.add(newScheduleData);
        _isLoading = false; // 로딩 상태를 false로 변경
      });
    } catch (e) {
      // 4. 에러가 발생했을 경우 로딩 상태를 해제하고 사용자에게 알립니다.
      print('일정 생성 중 오류가 발생했습니다: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // AI로부터 가상의 데이터를 받아오는 함수 (실제로는 API 통신 로직)
  Future<Map<String, String>> _fetchScheduleFromAI() async {
    // 2초 동안 기다린 후 데이터를 반환하는 것을 시뮬레이션합니다.
    await Future.delayed(const Duration(seconds: 2));

    // AI가 생성한 가상의 일정 데이터를 반환합니다.
    _scheduleCount++;
    return {
      'title': 'AI 생성 일정 $_scheduleCount',
      'date': '2025.11.01 ~ 2025.11.05',
      'location': '런던, 파리, 로마',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // 뒤로가기 기능
          },
        ),
        title: const Text('여행 일정'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 로딩 상태일 때 로딩 바를 보여줍니다.
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: LinearProgressIndicator(),
            ),

          // 동적으로 늘어나는 일정 목록
          Expanded(
            child: _schedules.isEmpty && !_isLoading
                ? const Center(
              child: Text(
                '아직 일정이 없습니다.\nAI에게 일정을 만들어달라고 해보세요!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
                : ListView.builder(
              itemCount: _schedules.length,
              itemBuilder: (context, index) {
                final schedule = _schedules[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 8.0),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ScheduleDetailPage(schedule: schedule),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7F7),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE0E0E0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            schedule['title']!,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF333333),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '날짜: ${schedule['date']!}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF666666),
                            ),
                          ),
                          Text(
                            '장소: ${schedule['location']!}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF666666),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          // 하단의 "일정 추가" 버튼
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                // 로딩 중일 때는 버튼 비활성화
                onPressed: _isLoading ? null : _addSchedule,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: _isLoading
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(Icons.add),
                label: Text(
                  _isLoading ? '생성 중...' : '일정 추가',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}