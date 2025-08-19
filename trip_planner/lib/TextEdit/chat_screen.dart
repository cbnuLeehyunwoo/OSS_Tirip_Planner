import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

// 메시지를 보낸 주체를 구분하기 위한 열거형(enum)
enum ChatAuthor { bot, user }

// 하나의 채팅 메시지를 표현하는 데이터 클래스
class ChatMessage {
  final String text;
  final ChatAuthor author;
  // 버튼과 같은 특수 위젯을 메시지에 포함시키기 위함
  final Widget? actionWidget;

  ChatMessage(this.text, {required this.author, this.actionWidget});
}

class ChatScreen extends StatefulWidget {
  final String searchQuery;

  const ChatScreen({
    super.key,
    required this.searchQuery,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  // 사용자의 응답을 저장할 데이터
  DateTimeRange? _selectedDateRange;
  String? _selectedTheme;

  @override
  void initState() {
    super.initState();
    // 화면이 시작되면 챗봇의 첫인사와 함께 대화를 시작합니다.
    _startConversation();
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      actionWidget: Wrap( // 버튼이 많을 경우 줄바꿈을 위해 Wrap 사용
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

  // 테마 선택 버튼을 생성하는 헬퍼 위젯
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

  // 사용자가 테마를 선택했을 때 호출되는 함수
  void _onThemeSelected(String theme) {
    _selectedTheme = (theme == '건너뛰기') ? null : theme;
    
    // 5. 사용자의 응답(테마)을 채팅에 추가
    _addUserMessage(theme);

    // 6. 모든 정보를 받았으므로 일정 생성 시작
    Future.delayed(const Duration(milliseconds: 800), _generateSchedule);
  }

  // 3단계: 일정 생성 및 결과 출력
  void _generateSchedule() async {
    _addBotMessage('알겠습니다! AI가 멋진 여행 계획을 만들고 있어요. 잠시만 기다려주세요...');

    try {
      final scheduleResult = await _fetchScheduleFromAI();

      // 서버에서 받은 데이터에서 '핵심 일정'과 '전체 일정'을 분리합니다.
      final List<dynamic> keyEvents = scheduleResult['key_events'] ?? [];
      final List<dynamic> fullSchedule = scheduleResult['full_schedule'] ?? [];

      if (keyEvents.isNotEmpty) {
        // '핵심 일정'을 표시할 위젯을 생성합니다.
        final scheduleWidget = _buildScheduleDisplayWidget(
          keyEvents.map((item) => Map<String, String>.from(item)).toList()
        );

        // 생성된 위젯을 채팅 메시지에 담아 표시합니다.
        _addBotMessage(
          'AI 추천 핵심 일정이 생성되었어요! 전체 상세 일정은 데이터로 저장되었습니다.',
          actionWidget: scheduleWidget
        );

        print('--- AI로부터 받은 전체 상세 일정 (${fullSchedule.length}개) ---');
        // print(fullSchedule); // 너무 길어서 주석 처리, 필요시 활성화
        print('------------------------------------');
        
      } else {
        _addBotMessage('죄송합니다. 일정을 생성하는 데 실패했어요. 다시 시도해 주세요.');
      }
    } catch (e) {
      print('--- API 호출 오류 ---');
      print(e);
      _addBotMessage('죄송합니다. 서버에 문제가 발생했어요. 잠시 후 다시 시도해 주세요.');
    }
  }
  
  Future<Map<String, dynamic>> _fetchScheduleFromAI() async {
    final String baseUrl = dotenv.env['API_BASE_URL'] ?? ''; 
    final url = Uri.parse('$baseUrl/generate-schedule');
    final requestBody = {
      'destination': widget.searchQuery,
      'startDate': DateFormat('yyyy-MM-dd').format(_selectedDateRange!.start),
      'endDate': DateFormat('yyyy-MM-dd').format(_selectedDateRange!.end),
      'theme': _selectedTheme,
    };

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: jsonEncode(requestBody),
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      throw Exception('서버로부터 데이터를 불러오는 데 실패했습니다. 상태 코드: ${response.statusCode}');
    }
  }

  // 3. 핵심 일정을 표시할 UI 위젯을 생성하는 함수
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


  // --- 아래는 채팅 UI를 위한 헬퍼 함수들 ---

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
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildChatBubble(message);
              },
            ),
          ),
          // 현재는 버튼으로만 입력하므로 텍스트 입력창은 비활성화
          // const Divider(height: 1.0),
          // Container(decoration: BoxDecoration(color: Theme.of(context).cardColor)),
        ],
      ),
    );
  }

  // 채팅 말풍선을 그리는 위젯
  Widget _buildChatBubble(ChatMessage message) {
    final isBot = message.author == ChatAuthor.bot;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: isBot ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isBot)
            const CircleAvatar(child: Icon(Icons.android)), // 봇 프로필 아이콘
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