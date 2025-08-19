import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum ChatAuthor { bot, user }

class ChatMessage {
  final String text;
  final ChatAuthor author;
  final Widget? actionWidget;

  ChatMessage(this.text, {required this.author, this.actionWidget});
}

class ChatScreen extends StatefulWidget {
  final String searchQuery;
  const ChatScreen({super.key, required this.searchQuery});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  // --- 상태 변수 ---
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final List<ChatMessage> _messages = [];

  DateTimeRange? _selectedDateRange;
  String? _selectedTheme;
  String? _tripId; // 생성된 여행 문서의 ID를 저장

  List<Map<String, String>> _keyEvents = [];

  // --- 날씨 기능 관련 변수 ---
  Timer? _weatherTimer;
  double? _lat;
  double? _lon;
  bool _isCheckingWeather = false;

  @override
  void initState() {
    super.initState();
    _startConversation();
  }

  @override
  void dispose() {
    _weatherTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // --- 대화 흐름 관리 ---
  void _startConversation() {
    _addBotMessage('안녕하세요! ${widget.searchQuery} 여행 계획을 도와드릴게요.');
    Future.delayed(const Duration(milliseconds: 1200), _askForDate);
  }

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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Future<void> _showDatePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: '여행 시작일과 종료일을 선택하세요',
    );
    if (picked != null) {
      _selectedDateRange = picked;
      final startDate = DateFormat('yyyy년 MM월 dd일').format(picked.start);
      final endDate = DateFormat('yyyy년 MM월 dd일').format(picked.end);
      _addUserMessage('$startDate ~ $endDate');
      Future.delayed(const Duration(milliseconds: 800), _askForTheme);
    }
  }

  void _askForTheme() {
    _addBotMessage(
      '어떤 테마의 여행을 원하세요?',
      actionWidget: Wrap(
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
      child: Text(theme),
      style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.blueAccent,
          side: const BorderSide(color: Colors.blueAccent),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _onThemeSelected(String theme) {
    _selectedTheme = (theme == '건너뛰기') ? null : theme;
    _addUserMessage(theme);
    Future.delayed(const Duration(milliseconds: 800), _generateSchedule);
  }

  // --- 데이터 처리 및 API 호출 ---

  // 최초 일정 생성
  void _generateSchedule() async {
    if (_selectedDateRange == null) {
      _addBotMessage('오류: 날짜가 선택되지 않았습니다. 다시 시도해 주세요.');
      return;
    }
    if (FirebaseAuth.instance.currentUser == null) {
      _addBotMessage('오류: 사용자 인증 정보를 찾을 수 없습니다. 앱을 재시작해 주세요.');
      return;
    }

    _addBotMessage('알겠습니다! AI가 멋진 여행 계획을 만들고 있어요. 잠시만 기다려주세요...');

    try {
      DocumentReference tripDocRef = await FirebaseFirestore.instance.collection('trips').add({
        'destination': widget.searchQuery,
        'startDate': DateFormat('yyyy-MM-dd').format(_selectedDateRange!.start),
        'endDate': DateFormat('yyyy-MM-dd').format(_selectedDateRange!.end),
        'theme': _selectedTheme,
        'status': 'processing',
        'createdAt': FieldValue.serverTimestamp(),
        'userId': FirebaseAuth.instance.currentUser!.uid,
      });

      _tripId = tripDocRef.id;

      final String baseUrl = dotenv.env['API_BASE_URL'] ?? '';
      await http.post(
        Uri.parse('$baseUrl/generate-schedule-from-db'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'tripId': _tripId}),
      );

      _listenForSchedule(_tripId!);

    } catch (e) {
      _handleAPIError(e);
    }
  }

  // 일정 수정 (사용자 입력 또는 날씨 변화)
  void _regenerateSchedule({required String contingency}) async {
    if (_tripId == null) {
      _addBotMessage('오류: 수정할 기존 일정이 없습니다.');
      return;
    }
    _addBotMessage('알겠습니다. "$contingency" 상황에 맞게 일정을 다시 조정해 볼게요!');
    try {
      final String baseUrl = dotenv.env['API_BASE_URL'] ?? '';
      await http.post(
        Uri.parse('$baseUrl/generate-schedule-from-db'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'tripId': _tripId, 'contingency': contingency}),
      );
      // 기존 리스너가 DB 변경을 감지하여 자동으로 UI를 업데이트합니다.
    } catch (e) {
      _handleAPIError(e);
    }
  }

  // Firestore 리스너
  void _listenForSchedule(String tripId) {
    FirebaseFirestore.instance.collection('trips').doc(tripId).snapshots().listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data()!;
        final status = data['status'];

        if (status == 'completed') {
          final List<dynamic> keyEventsData = data['key_events'] ?? [];
          if (keyEventsData.isNotEmpty) {
            setState(() {
              _keyEvents = keyEventsData.map((item) => Map<String, String>.from(item)).toList();
            });
            final scheduleWidget = _buildScheduleDisplayWidget(_keyEvents);
            _addBotMessage(
              'AI 추천 일정이 도착했어요! 궁금한 점이나 변경사항을 입력해주세요.',
              actionWidget: scheduleWidget
            );
            _getCoordinatesAndStartWeatherTimer(); // 일정이 생성되면 날씨 확인 시작
          } else {
            _addBotMessage('죄송합니다. 일정을 생성했지만, 추천 장소가 없네요.');
          }
        } else if (status == 'error') {
          _addBotMessage('죄송합니다. 서버에서 일정 생성 중 오류가 발생했어요.');
        }
      }
    }).onError((error) {
      _handleAPIError(error);
    });
  }

  void _handleAPIError(Object e) {
    print('--- API 또는 리스너 오류 ---\n$e');
    _addBotMessage('죄송합니다. 서버와 통신 중 문제가 발생했어요. 잠시 후 다시 시도해 주세요.');
  }

  // --- 날씨 관련 기능 ---
  Future<void> _getCoordinatesAndStartWeatherTimer() async {
    _weatherTimer?.cancel();
    final apiKey = dotenv.env['OPENWEATHER_API_KEY'];
    if (apiKey == null) return;

    try {
      final geoUrl = Uri.parse('http://api.openweathermap.org/geo/1.0/direct?q=${widget.searchQuery}&limit=1&appid=$apiKey');
      final response = await http.get(geoUrl);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          setState(() {
            _lat = data[0]['lat'];
            _lon = data[0]['lon'];
          });
          print('좌표 획득 성공: lat=$_lat, lon=$_lon. 날씨 확인을 시작합니다.');
          _startWeatherCheckTimer();
        }
      }
    } catch (e) {
      print('좌표 획득 중 오류: $e');
    }
  }

  void _startWeatherCheckTimer() {
    _weatherTimer = Timer.periodic(const Duration(minutes: 30), (timer) {
      _checkForRain();
    });
    _checkForRain();
  }
  
  Future<void> _checkForRain() async {
    if (_isCheckingWeather || _lat == null || _lon == null || _keyEvents.isEmpty) return;
    setState(() { _isCheckingWeather = true; });

    final apiKey = dotenv.env['OPENWEATHER_API_KEY']!;
    final weatherUrl = Uri.parse('http://api.openweathermap.org/data/2.5/forecast?lat=$_lat&lon=$_lon&appid=$apiKey&units=metric');

    try {
      final response = await http.get(weatherUrl);
      if (response.statusCode == 200) {
        final forecastData = jsonDecode(response.body)['list'];
        for (var event in _keyEvents) {
          final eventTime = DateFormat('yyyy-MM-dd HH:mm').parse('${event["date"]} ${event["time"]}');
          for (var forecast in forecastData) {
            final forecastTime = DateTime.fromMillisecondsSinceEpoch(forecast['dt'] * 1000);
            if (forecastTime.isAfter(eventTime.subtract(const Duration(hours: 2)))) &&
                forecastTime.isBefore(eventTime.add(const Duration(hours: 2)))) {
              final weatherCondition = forecast['weather'][0]['main'].toString().toLowerCase();
              if (weatherCondition == 'rain' || weatherCondition == 'drizzle' || weatherCondition == 'thunderstorm') {
                final contingency = '앗, "${event['title']}" 일정 시간에 비가 올 것 같아요! 실내 활동으로 바꾸는 게 좋겠어요.';
                _addBotMessage(contingency);
                _regenerateSchedule(contingency: contingency);
                setState(() { _isCheckingWeather = false; });
                return;
              }
            }
          }
        }
      }
    } catch (e) {
      print('날씨 확인 중 오류: $e');
    }
    setState(() { _isCheckingWeather = false; });
  }

  // --- UI 위젯 빌더 ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.searchQuery} 여행 계획'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) => _buildChatBubble(_messages[index]),
            ),
          ),
          const Divider(height: 1.0),
          _buildTextComposer(),
        ],
      ),
    );
  }

  Widget _buildTextComposer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      decoration: BoxDecoration(color: Theme.of(context).cardColor),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              onSubmitted: _handleUserSubmit,
              decoration: const InputDecoration.collapsed(hintText: "궁금한 점이나 변경사항을 입력하세요"),
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

  void _handleUserSubmit(String text) {
    if (text.trim().isEmpty) return;
    _addUserMessage(text);
    _textController.clear();
    _regenerateSchedule(contingency: text);
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
            ...schedule.map((item) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: ListTile(
                  leading: const Icon(Icons.check_circle_outline, color: Colors.blueAccent),
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

  void _addBotMessage(String text, {Widget? actionWidget}) {
    setState(() {
      _messages.add(ChatMessage(text, author: ChatAuthor.bot, actionWidget: actionWidget));
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

  Widget _buildChatBubble(ChatMessage message) {
    final isBot = message.author == ChatAuthor.bot;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: isBot ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isBot) const CircleAvatar(child: Icon(Icons.android)),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: isBot ? CrossAxisAlignment.start : CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: isBot ? Colors.grey.shade200 : Colors.blueAccent,
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(color: isBot ? Colors.black87 : Colors.white),
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
