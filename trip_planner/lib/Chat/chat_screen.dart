import 'dart:async'; // Timer를 위해 필요
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

enum ChatAuthor { bot, user }

class ChatMessage {
  final String text;
  final ChatAuthor author;
  // 버튼과 같은 특수 위젯을 메시지에 포함시키기 위함
  final Widget? actionWidget;

  ChatMessage(this.text, {required this.author, this.actionWidget});
}

class ChatScreen extends StatefulWidget {
  final String searchQuery;
  final String startLocation;
  const ChatScreen({
    super.key, 
    required this.searchQuery,
    required this.startLocation,
    });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // --- 상태 변수 ---
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController =
      TextEditingController(); // 1. 사용자 입력을 위한 컨트롤러 추가
  final List<ChatMessage> _messages = [];

  DateTimeRange? _selectedDateRange;
  String? _selectedTheme;
  List<Map<String, String>> _fullSchedule = [];
  List<Map<String, String>> _keyEvents = [];

  // --- 날씨 기능 관련 변수 ---
  Timer? _weatherTimer; // 2. 30분마다 날씨를 확인할 타이머
  double? _lat;
  double? _lon;
  bool _isCheckingWeather = false; // 중복 확인 방지 플래그

  @override
  void initState() {
    super.initState();
    _startConversation();
  }

  @override
  void dispose() {
    _weatherTimer?.cancel(); // 3. 화면 종료 시 타이머를 반드시 취소하여 메모리 누수 방지
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // 대화의 흐름을 시작하는 함수
  void _startConversation() {
    // 1. 초기 메시지 추가 (봇)
    _addBotMessage('안녕하세요! ${widget.searchQuery} 여행 계획을 도와드릴게요.');

    // 2. 딜레이를 주어 실제 대화처럼 보이게 한 후, 날짜 질문 시작
    Future.delayed(const Duration(milliseconds: 1200), _askForDate);
  }

  // 1단계: 날짜 질문
  void _askForDate() {
    _addBotMessage(
      '언제 여행을 떠나시나요?',
      actionWidget: ElevatedButton.icon(
        icon: const Icon(Icons.calendar_today),
        label: const Text('날짜 선택하기'),
        onPressed: _showDatePicker,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  // DateRangePicker를 화면에 표시하는 함수
  Future<void> _showDatePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: '여행 시작일과 종료일을 선택하세요',
    );

    if (picked != null) {
      _selectedDateRange = picked;
      // 날짜 포맷을 예쁘게 변경
      final startDate = DateFormat('yyyy년 MM월 dd일').format(picked.start);
      final endDate = DateFormat('yyyy년 MM월 dd일').format(picked.end);

      // 3. 사용자의 응답(날짜)을 채팅에 추가
      _addUserMessage('$startDate ~ $endDate');

      // 4. 다음 단계(테마 질문)로 진행
      Future.delayed(const Duration(milliseconds: 800), _askForTheme);
    }
  }

  // 2단계: 테마 질문
  void _askForTheme() {
    _addBotMessage(
      '어떤 테마의 여행을 원하세요?',
      actionWidget: Wrap(
        // 버튼이 많을 경우 줄바꿈을 위해 Wrap 사용
        spacing: 8.0,
        runSpacing: 4.0,
        children: [
          _buildThemeButton('힐링'),
          _buildThemeButton('맛집 탐방'),
          _buildThemeButton('액티비티'),
          _buildThemeButton('건너뛰기'),
        ],
      ),
    );
  }

  Widget _buildThemeButton(String theme) {
    return ElevatedButton(
      onPressed: () => _onThemeSelected(theme),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.blueAccent,
        side: const BorderSide(color: Colors.blueAccent),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(theme),
    );
  }

  void _onThemeSelected(String theme) {
    _selectedTheme = (theme == '건너뛰기') ? null : theme;

    // 5. 사용자의 응답(테마)을 채팅에 추가
    _addUserMessage(theme);

    // 6. 모든 정보를 받았으므로 일정 생성 시작
    Future.delayed(const Duration(milliseconds: 800), _generateSchedule);
  }

  // 최초 일정 생성
  void _generateSchedule() async {
    _addBotMessage('알겠습니다! AI가 멋진 여행 계획을 만들고 있어요. 잠시만 기다려주세요...');
    try {
      final scheduleResult = await _fetchScheduleFromAI();
      await _handleAIScheduleResponse(scheduleResult); // await 추가
    } catch (e) {
      _handleAPIError(e);
    }
  }

  // 일정 수정 (사용자 입력 또는 날씨 변화로 호출)
  void _regenerateSchedule({required String contingency}) async {
    _addBotMessage('알겠습니다. "${contingency}" 상황에 맞게 일정을 다시 조정해 볼게요!');
    try {
      final scheduleResult = await _fetchScheduleFromAI(
        contingency: contingency,
        existingSchedule: _keyEvents,
      );
      await _handleAIScheduleResponse(scheduleResult); // await 추가
    } catch (e) {
      _handleAPIError(e);
    }
  }

  // AI 응답 처리 (날씨 타이머 시작 로직 추가)
  Future<void> _handleAIScheduleResponse(
    Map<String, dynamic> scheduleResult,
  ) async {
    final List<dynamic> keyEventsData = scheduleResult['key_events'] ?? [];
    final List<dynamic> fullScheduleData =
        scheduleResult['full_schedule'] ?? [];

    if (fullScheduleData.isNotEmpty) {
    
    // 3. 데이터를 Dart 타입으로 변환합니다.
    final newKeyEvents = keyEventsData.map((item) => Map<String, String>.from(item)).toList();
    final newFullSchedule = fullScheduleData.map((item) => Map<String, String>.from(item)).toList();
    
    final scheduleWidget = _buildScheduleDisplayWidget(
      newKeyEvents.isNotEmpty ? newKeyEvents : newFullSchedule.take(5).toList()
    );

    setState(() {
      // 5. 새로운 일정으로 상태를 업데이트합니다 (기억 갱신).
      _keyEvents = newKeyEvents;
      _fullSchedule = newFullSchedule;
    });
    
    // 6. 봇 메시지를 추가합니다.
    _addBotMessage(
      '새로운 추천 일정이 도착했어요! 궁금한 점이나 변경하고 싶은 점이 있다면 아래에 입력해주세요.',
      actionWidget: scheduleWidget
    );

    // 7. 날씨 타이머를 시작/재시작합니다.
    await _getCoordinatesAndStartWeatherTimer();

    } else {
    // 서버로부터 full_schedule 조차 받지 못한 경우 (진짜 실패)
    _addBotMessage('죄송합니다. 일정을 생성하는 데 실패했어요. 다시 시도해 주세요.');
    }
  }

  void _handleAPIError(Object e) {
    // 역할 1: 개발자에게 알리기 (자세한 기술 정보)
    print('--- API 호출 오류 --- \n$e');

    // 역할 2: 사용자에게 알리기 (친절한 안내 메시지)
    _addBotMessage('죄송합니다. 서버에 문제가 발생했어요. 잠시 후 다시 시도해 주세요.');
  }

  Future<Map<String, dynamic>> _fetchScheduleFromAI({
    String? contingency,
    List<Map<String, String>>? existingSchedule,
  }) async {
    final baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:5000';
    final url = Uri.parse('$baseUrl/generate-schedule');
    final Map<String, dynamic> requestBody = {
      'start_location' : widget.startLocation,
      'destination': widget.searchQuery,
      'startDate': DateFormat('yyyy-MM-dd').format(_selectedDateRange!.start),
      'endDate': DateFormat('yyyy-MM-dd').format(_selectedDateRange!.end),
      'theme': _selectedTheme,
    };

    if (contingency != null && existingSchedule != null) {
    requestBody['contingency'] = contingency;
    requestBody['existing_key_events'] = existingSchedule;
    }

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode(requestBody),
    );

    print('✅ 서버로부터 받은 응답 코드: ${response.statusCode}');
    print('📦 서버로부터 받은 내용: ${utf8.decode(response.bodyBytes)}');

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception(
        '서버로부터 데이터를 불러오는 데 실패했습니다. 상태 코드: ${response.statusCode}',
      );
    }
  }

  Widget _buildScheduleDisplayWidget(List<Map<String, String>> schedule) {
    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.only(top: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '✨ AI 추천 핵심 일정',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 16.0),
            // ... (spread operator)를 사용하여 Column 안에 리스트의 모든 위젯을 펼쳐 넣습니다.
            ...schedule.map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: ListTile(
                  leading: const Icon(
                    Icons.check_circle_outline,
                    color: Colors.blueAccent,
                  ),
                  title: Text(item['title'] ?? '알 수 없는 일정'),
                  subtitle: Text('${item['date']} / ${item['time']}'),
                  dense: true,
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
  
  // --- 돌발 상황 처리 로직 ---
  void _handleUserSubmit(String text) {
    if (text.trim().isEmpty) return;

    _addUserMessage(text);
    _textController.clear();

    // 사용자의 입력을 '돌발 상황'으로 간주하여 일정 수정을 요청
    _regenerateSchedule(contingency: text);
  }

  // --- ☀️ 실시간 날씨 처리 로직 ---

  // 5. 도시 이름으로 위도/경도를 조회하고, 성공 시 날씨 타이머 시작
  Future<void> _getCoordinatesAndStartWeatherTimer() async {
    _weatherTimer?.cancel(); // 기존 타이머가 있다면 취소
    final apiKey = dotenv.env['OPENWEATHER_API_KEY'];
    if (apiKey == null) {
      print('날씨 API 키가 .env 파일에 없습니다.');
      return;
    }

    try {
      // OpenWeatherMap의 Geocoding API 사용
      final geoUrl = Uri.parse(
        'http://api.openweathermap.org/geo/1.0/direct?q=${widget.searchQuery}&limit=1&appid=$apiKey',
      );
      final response = await http.get(geoUrl);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          setState(() {
            _lat = data[0]['lat'];
            _lon = data[0]['lon'];
          });
          print('좌표 획득 성공: lat=$_lat, lon=$_lon. 날씨 확인을 시작합니다.');
          _startWeatherCheckTimer(); // 좌표 획득 후 타이머 시작
        }
      }
    } catch (e) {
      print('좌표 획득 중 오류: $e');
    }
  }

  // 6. 30분 간격의 타이머 설정
  void _startWeatherCheckTimer() {
    _weatherTimer = Timer.periodic(const Duration(minutes: 30), (timer) {
      print('정기 날씨 확인 실행...');
      _checkForRain();
    });
    // 앱 시작 시 즉시 한번 확인
    _checkForRain();
  }

  // 7. 날씨 API를 호출하여 비 예보 확인 및 일정 수정 제안
  Future<void> _checkForRain() async {
    if (_isCheckingWeather ||
        _lat == null ||
        _lon == null ||
        _keyEvents.isEmpty)
      return;

    setState(() {
      _isCheckingWeather = true;
    });

    final apiKey = dotenv.env['OPENWEATHER_API_KEY']!;
    // 5일/3시간 예보 API 사용
    final weatherUrl = Uri.parse(
      'http://api.openweathermap.org/data/2.5/forecast?lat=$_lat&lon=$_lon&appid=$apiKey&units=metric',
    );

    try {
      final response = await http.get(weatherUrl);
      if (response.statusCode == 200) {
        final forecastData = jsonDecode(response.body)['list'];

        for (var event in _keyEvents) {
          final eventTime = DateFormat(
            'yyyy-MM-dd HH:mm',
          ).parse('${event["date"]} ${event["time"]}');

          // 각 예보 시간대와 내 일정 시간을 비교
          for (var forecast in forecastData) {
            final forecastTime = DateTime.fromMillisecondsSinceEpoch(
              forecast['dt'] * 1000,
            );

            // 내 일정 시간 전후 2시간 내에 비 예보가 있는지 확인
            if (forecastTime.isAfter(
                  eventTime.subtract(const Duration(hours: 2)),
                ) &&
                forecastTime.isBefore(
                  eventTime.add(const Duration(hours: 2)),
                )) {
              final weatherCondition = forecast['weather'][0]['main']
                  .toString()
                  .toLowerCase();
              if (weatherCondition == 'rain' ||
                  weatherCondition == 'drizzle' ||
                  weatherCondition == 'thunderstorm') {
                final contingency =
                    '앗, "${event['title']}" 일정 시간에 비가 올 것 같아요! 실내 활동으로 바꾸는 게 좋겠어요.';

                // 봇이 먼저 말을 걸어 일정 수정을 제안
                _addBotMessage(contingency);
                _regenerateSchedule(contingency: contingency);

                setState(() {
                  _isCheckingWeather = false;
                });
                return; // 하나의 비 예보만 처리하고 함수 종료
              }
            }
          }
        }
      }
    } catch (e) {
      print('날씨 확인 중 오류: $e');
    }

    setState(() {
      _isCheckingWeather = false;
    });
  }

  // --- UI 위젯들 ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.searchQuery} 여행 계획'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          if (_fullSchedule.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.check_circle_outline),
            tooltip: '이 일정으로 확정하기',
            onPressed: () {
              Navigator.pop(context, {
                "key_events": _keyEvents,
                "full_schedule": _fullSchedule
              });
            },
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildChatBubble(message);
              },
            ),
          ),
          const Divider(height: 1.0),
          _buildTextComposer(),
        ],
      ),
    );
  }

  // 10. 텍스트 입력창 UI를 만드는 새로운 위젯
  Widget _buildTextComposer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      decoration: BoxDecoration(color: Theme.of(context).cardColor),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              onSubmitted: _handleUserSubmit, // 엔터키로도 전송 가능
              decoration: const InputDecoration.collapsed(
                hintText: "궁금한 점이나 변경사항을 입력하세요",
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: () => _handleUserSubmit(_textController.text),
          ),
        ],
      ),
    );
  }

  void _addBotMessage(String text, {Widget? actionWidget}) {
    setState(() {
      _messages.add(
        ChatMessage(text, author: ChatAuthor.bot, actionWidget: actionWidget),
      );
    });
    _scrollToBottom();
  }

  void _addUserMessage(String text) {
    setState(() {
      _messages.add(ChatMessage(text, author: ChatAuthor.user));
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // 채팅 말풍선을 그리는 위젯
  Widget _buildChatBubble(ChatMessage message) {
    final isBot = message.author == ChatAuthor.bot;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: isBot
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isBot)
            const CircleAvatar(child: Icon(Icons.android)), // 봇 프로필 아이콘
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: isBot
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: isBot ? Colors.grey.shade200 : Colors.blueAccent,
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: isBot ? Colors.black87 : Colors.white,
                    ),
                  ),
                ),
                if (message.actionWidget != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: message.actionWidget,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
