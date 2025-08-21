import 'package:flutter/material.dart';
import 'chat_screen.dart';
import '../Schedule/schedule_detail_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class TravelHomePage extends StatefulWidget {
  const TravelHomePage({super.key});

  @override
  State<TravelHomePage> createState() => _TravelHomePageState();
}

class _TravelHomePageState extends State<TravelHomePage> {
  final _searchController = TextEditingController();
  int _selectedIndex = 0;
  final List<Map<String, dynamic>> _savedTrips = [];

  String _currentLocation = '위치 정보 로딩 중...';
  bool _isLocationPermissionGranted = false; // 위치 권한 상태

  @override
  void initState() {
    super.initState();
    // 3. 화면이 시작될 때 위치를 가져오는 함수를 호출합니다.
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    // 위치 서비스 활성화 여부 확인
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() => _currentLocation = '위치 서비스가 비활성화되었습니다.');
      return;
    }

    // 위치 권한 확인 및 요청
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() => _currentLocation = '위치 권한이 거부되었습니다.');
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      setState(() => _currentLocation = '위치 권한이 영구적으로 거부되었습니다.');
      return;
    }

    // 모든 권한이 허용되었을 때
    setState(() => _isLocationPermissionGranted = true);
    
    try {
      // 현재 위치(위도, 경도)를 가져옵니다.
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // 위도, 경도를 주소로 변환합니다. (geocoding 패키지 사용)
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        // 예: "서울특별시 중구" 와 같은 형식으로 주소를 만듭니다.
        final address = '${place.administrativeArea} ${place.locality}';
        setState(() {
          _currentLocation = address;
        });
      }
    } catch (e) {
      print("위치 정보 가져오기 오류: $e");
      setState(() => _currentLocation = '위치를 가져올 수 없습니다.');
    }
  }

  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _navigateToChatScreen(String query) async {
    if (query.isEmpty) return;

    final startLocation = _isLocationPermissionGranted ? _currentLocation : '충청북도 청주';

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          searchQuery: query,
          startLocation: startLocation,
          ),
      ),
    );

    // ChatScreen에서 "일정 저장" 버튼을 눌러 데이터를 반환했다면,
    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        _savedTrips.add({
          'title': query, // 여행 제목
          'key_events': result['key_events'] ?? [], // 핵심 일정
          'full_schedule': result['full_schedule'] ?? [], // 전체 상세 일정
        });
      });
    }
    _searchController.clear();
  }
 
  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url)) {
      // URL을 열 수 없는 경우 사용자에게 알림
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$urlString 주소를 열 수 없습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> widgetOptions = <Widget>[
      _buildHomePageContent(),
      const Center(child: Text('저장 페이지')),
      const Center(child: Text('내 여행 페이지')),
      const Center(child: Text('마이 페이지')),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: const Text(''),
        actions: [
          IconButton(icon: const Icon(Icons.notifications_none, color: Colors.black), onPressed: () {}),
          IconButton(icon: const Icon(Icons.person_outline, color: Colors.black), onPressed: () {}),
        ],
      ),
      body: widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite_border), label: '저장'),
          BottomNavigationBarItem(icon: Icon(Icons.explore_outlined), label: '내 여행'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: '마이'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        showSelectedLabels: true,
        showUnselectedLabels: true,
      ),
    );
  }

  Widget _buildHomePageContent() {
     return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('어디로 떠나볼까요?', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.15), spreadRadius: 2, blurRadius: 10, offset: const Offset(0, 3))],
              ),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(icon: Icon(Icons.search, color: Colors.grey), hintText: '나라, 도시, 여행지 검색', border: InputBorder.none),
                onSubmitted: _navigateToChatScreen,
              ),
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // 각 CategoryIcon을 InkWell로 감싸서 탭 기능을 추가합니다.
                InkWell(
                  onTap: () => _launchURL('https://kr.trip.com/flights/'),
                  borderRadius: BorderRadius.circular(20),
                  child: const CategoryIcon(icon: Icons.flight, label: '항공권'),
                ),
                InkWell(
                  onTap: () => _launchURL('https://www.goodchoice.kr/'),
                  borderRadius: BorderRadius.circular(20),
                  child: const CategoryIcon(icon: Icons.hotel, label: '숙소'),
                ),
                InkWell(
                  onTap: () => _launchURL('https://www.socar.kr/'),
                  borderRadius: BorderRadius.circular(20),
                  child: const CategoryIcon(icon: Icons.directions_car, label: '렌터카'),
                ),
                InkWell(
                  onTap: () => _launchURL('https://ticket.interpark.com/'),
                  borderRadius: BorderRadius.circular(20),
                  child: const CategoryIcon(icon: Icons.local_offer, label: '투어·티켓'),
                ),
              ],
            ),
            const SizedBox(height: 40),
            const Text('여행 목록', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),

            _savedTrips.isEmpty
              ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(40.0),
                  child:Text('아직 생성된 일정이 없습니다. \n 검색창에 여행지를 입력해보세요!', textAlign : TextAlign.center, style: TextStyle(color: Colors.grey)),
                ),
              )
            : SizedBox(
              height: 250,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _savedTrips.length,
                    itemBuilder: (context, index) {
                      final trip = _savedTrips[index];
                      return Padding(
                        padding: const EdgeInsets.only(right: 15.0),
                        child: TravelCard(
                          tripData: trip,
                        ),
                      );
                    },
                  ),
                ),
          ],
        ),
      ),
    );
  }
}


class CategoryIcon extends StatelessWidget {
  const CategoryIcon({super.key, required this.icon, required this.label});
  final IconData icon;
  final String label;
  
  @override
  Widget build(BuildContext context) {
    return Column(children: [Icon(icon, size: 30), const SizedBox(height: 8), Text(label)]);
  }
}

class TravelCard extends StatelessWidget {
  final Map<String, dynamic> tripData;

  const TravelCard({
    super.key,
    required this.tripData,
  });

  @override
  Widget build(BuildContext context) {
    // 카드에 표시할 데이터 추출
    final title = tripData['title'] ?? '제목 없음';
    final keyEvents = List<Map<String, String>>.from(tripData['key_events'] ?? []);
    final fullSchedule = List<Map<String, String>>.from(tripData['full_schedule'] ?? []);
    
    // 첫날과 마지막 날짜 추출 - 데이터가 비어있을 경우 안전장치
    final startDate = fullSchedule.isNotEmpty ? (fullSchedule.first['date'] ?? '날짜 미정') : '날짜 미정';
    final endDate = fullSchedule.isNotEmpty ? (fullSchedule.last['date'] ?? '날짜 미정') : '날짜 미정';

    return InkWell(
      // 4. InkWell로 감싸서 탭 효과와 onTap 기능을 추가
      onTap: () {
        // 5. 카드를 탭하면 TimeGridTable 위젯을 포함한 새 화면으로 이동
        if (fullSchedule.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TimeGridTable(
                scheduleData: fullSchedule,
              ),
            ),
          );
        } else {
          // 데이터가 없을 경우 사용자에게 알림 (선택적)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('상세 일정 데이터가 없습니다.')),
          );
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          image: const DecorationImage(
            image: NetworkImage('https://images.unsplash.com/photo-1506748686214-e9df14d4d9d0'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(Colors.black45, BlendMode.darken),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 상단: 여행 제목과 날짜
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '$startDate ~ $endDate',
                    style: const TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ],
              ),
              // 하단: 핵심 일정 요약 (최대 3개)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: keyEvents.take(3).map((event) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      '• ${event['title']}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
