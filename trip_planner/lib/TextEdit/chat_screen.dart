import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../tour_api/tour_api.dart';

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
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final List<ChatMessage> _messages = [];

  DateTimeRange? _selectedDateRange;
  String? _selectedTheme;
  String? _tripId;
  List<Map<String, String>> _keyEvents = [];

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
      ),
    );
  }

  Future<void> _showDatePicker() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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

  void _onThemeSelected(String theme) {
    _selectedTheme = (theme == '건너뛰기') ? null : theme;
    _addUserMessage(theme);
    Future.delayed(const Duration(milliseconds: 800), _fetchPlacesAndGenerateSchedule);
  }

  Future<void> _fetchPlacesAndGenerateSchedule() async {
    _addBotMessage('선택하신 지역의 실제 장소 정보를 가져오고 있어요...');
    try {
      final placesData = await _fetchAndFormatPlaces();
      if (placesData.values.every((list) => list.isEmpty)) {
        _addBotMessage('죄송합니다. 선택하신 지역의 장소 정보를 가져오는 데 실패했어요.');
        return;
      }
      _addBotMessage('장소 정보를 바탕으로 AI가 멋진 여행 계획을 만들고 있어요. 잠시만 기다려주세요...');

      if (_selectedDateRange == null || FirebaseAuth.instance.currentUser == null) {
        _handleAPIError('날짜 또는 사용자 정보가 없습니다.');
        return;
      }

      DocumentReference tripDocRef = await FirebaseFirestore.instance.collection('trips').add({
        'destination': widget.searchQuery,
        'startDate': DateFormat('yyyy-MM-dd').format(_selectedDateRange!.start),
        'endDate': DateFormat('yyyy-MM-dd').format(_selectedDateRange!.end),
        'theme': _selectedTheme,
        'tourist_spots_data': placesData['tourist_spots'],
        'restaurants_data': placesData['restaurants'],
        'accommodations_data': placesData['accommodations'],
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

  Future<Map<String, String>> _getAreaAndSigunguCode(String query) async {
    print('Searching for area and sigungu codes for query: $query');
    String areaCode = '1'; // Default to Seoul
    String sigunguCode = '';

    final areas = await getAreaCodes(); // Get all top-level areas
    print('Top-level areas fetched: ${areas.map((a) => a['name']).toList()}');

    // Try to find a direct match for areaCode (e.g., "서울", "경기도")
    for (var area in areas) {
      print('Checking top-level area: ${area['name']} (code: ${area['code']})');
      if (area['name'] == query) {
        areaCode = area['code'];
        print('Direct match found for area: $query, areaCode: $areaCode');
        return {'areaCode': areaCode, 'sigunguCode': sigunguCode};
      }
    }

    // If not a direct areaCode match, try to find it as a sigungu within a province
    for (var area in areas) {
      print('Fetching sigungus for area: ${area['name']} (code: ${area['code']})');
      final sigungus = await getAreaCodes(areaCode: area['code']);
      print('Sigungus for ${area['name']}: ${sigungus.map((s) => s['name']).toList()}');
      for (var sigungu in sigungus) {
        print('Checking sigungu: ${sigungu['name']} (code: ${sigungu['code']}) within ${area['name']}');
        if (sigungu['name'] == query) {
          areaCode = area['code']; // This is the province's areaCode
          sigunguCode = sigungu['code']; // This is the city's sigunguCode
          print('Sigungu match found for query: $query, areaCode: $areaCode, sigunguCode: $sigunguCode');
          return {'areaCode': areaCode, 'sigunguCode': sigunguCode};
        }
      }
    }

    print('No specific area/sigungu match found for $query. Defaulting to Seoul (areaCode: $areaCode, sigunguCode: $sigunguCode)');
    return {'areaCode': areaCode, 'sigunguCode': sigunguCode}; // Return default if no match
  }

  Future<Map<String, List<Map<String, dynamic>>>> _fetchAndFormatPlaces() async {
    final codes = await _getAreaAndSigunguCode(widget.searchQuery);
    final areaCode = codes['areaCode']!;
    final sigunguCode = codes['sigunguCode']!;

    final results = await Future.wait([
      getTourData(areaCode, sigunguCode),
      getRestaurantData(areaCode, sigunguCode),
      getAccommodationData(areaCode, sigunguCode)
    ]);

    final Map<String, List<Map<String, dynamic>>> formattedPlaces = {
      'tourist_spots': [],
      'restaurants': [],
      'accommodations': [],
    };

    final List<dynamic> tourPlaces = results[0];
    final List<dynamic> restaurantPlaces = results[1];
    final List<dynamic> accommodationPlaces = results[2];

    // 각 타입별로 상세 정보 조회 및 포맷팅
    for (var place in tourPlaces) {
      final formatted = await _formatPlaceDetail(place, '12');
      if (formatted != null) formattedPlaces['tourist_spots']!.add(formatted);
    }
    for (var place in restaurantPlaces) {
      final formatted = await _formatPlaceDetail(place, '39');
      if (formatted != null) formattedPlaces['restaurants']!.add(formatted);
    }
    for (var place in accommodationPlaces) {
      final formatted = await _formatPlaceDetail(place, '32');
      if (formatted != null) formattedPlaces['accommodations']!.add(formatted);
    }

    return formattedPlaces;
  }

  Future<Map<String, dynamic>?> _formatPlaceDetail(dynamic place, String typeId) async {
    try {
      final details = await getDetailData(place['contentid'], typeId);
      if (details.isNotEmpty) {
        final detail = details[0];
        String hours = '정보 없음';
        String restDate = '정보 없음';

        switch (typeId) {
          case '12': hours = detail['usetime'] ?? '정보 없음'; restDate = detail['restdate'] ?? '정보 없음'; break;
          case '39': hours = detail['opentimefood'] ?? '정보 없음'; restDate = detail['restdatefood'] ?? '정보 없음'; break;
          case '32': hours = '체크인: ${detail['checkintime'] ?? '-'}, 체크아웃: ${detail['checkouttime'] ?? '-'}'; restDate = '연중무휴'; break;
        }
        return {
          'name': place['title'],
          'hours': hours,
          'restDate': restDate,
          'mapx': place['mapx'], // Longitude
          'mapy': place['mapy'], // Latitude
        };
      }
    } catch (e) {
      print("장소[${place['title']}] 상세 정보 조회 실패: $e");
    }
    return null;
  }

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
    } catch (e) {
      _handleAPIError(e);
    }
  }

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
            _getCoordinatesAndStartWeatherTimer();
          } else {
            _addBotMessage('죄송합니다. AI가 추천 장소를 찾지 못했어요.');
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
          _startWeatherCheckTimer();
        }
      }
    } catch (e) {
      print('좌표 획득 중 오류: $e');
    }
  }

  void _startWeatherCheckTimer() {
    _weatherTimer = Timer.periodic(const Duration(minutes: 30), (timer) => _checkForRain());
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
            if (forecastTime.isAfter(eventTime.subtract(const Duration(hours: 2)))) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.searchQuery} 여행 계획'),
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
}
