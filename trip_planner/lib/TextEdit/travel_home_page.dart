// lib/TextEdit/travel_home_page.dart (최종 확인 코드)
import 'package:flutter/material.dart';
import 'chat_screen.dart'; // 같은 폴더에 있으므로 이 경로가 올바릅니다.

class TravelHomePage extends StatefulWidget {
  const TravelHomePage({super.key});

  @override
  State<TravelHomePage> createState() => _TravelHomePageState();
}

class _TravelHomePageState extends State<TravelHomePage> {
  final _searchController = TextEditingController();
  int _selectedIndex = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _navigateToChatScreen(String query) {
    if (query.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(searchQuery: query),
        ),
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
    // 여기에 홈 화면 UI 코드가 들어갑니다 (이전과 동일).
    // ... UI 코드 생략 ...
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
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                CategoryIcon(icon: Icons.flight, label: '항공권'),
                CategoryIcon(icon: Icons.hotel, label: '숙소'),
                CategoryIcon(icon: Icons.directions_car, label: '렌터카'),
                CategoryIcon(icon: Icons.local_offer, label: '투어·티켓'),
              ],
            ),
            const SizedBox(height: 40),
            // ... (나머지 UI 코드)
          ],
        ),
      ),
    );
  }
}

// CategoryIcon, TravelCard 위젯 (이전과 동일)
class CategoryIcon extends StatelessWidget { /* ... */ 
  const CategoryIcon({super.key, required this.icon, required this.label});
  final IconData icon;
  final String label;
  
  @override
  Widget build(BuildContext context) {
    return Column(children: [Icon(icon, size: 30), const SizedBox(height: 8), Text(label)]);
  }
}
class TravelCard extends StatelessWidget { /* ... */ 
  const TravelCard({super.key, required this.imageUrl, required this.city, required this.description});
  final String imageUrl;
  final String city;
  final String description;

  @override
  Widget build(BuildContext context) {
    // 카드 UI 구현
    return SizedBox(width: 200, child: Card(child: Center(child: Text(city))));
  }
}