import 'package:flutter/material.dart';

void main() {
  runApp(const TravelApp());
}

class TravelApp extends StatelessWidget {
  const TravelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cats Travel Planner',
      theme: ThemeData(
        // 피그마에서 정의한 주요 색상을 앱의 테마 색상으로 지정합니다.
        primarySwatch: Colors.blue,
        // 피그마의 배경색과 유사하게 설정합니다.
        scaffoldBackgroundColor: const Color(0xFFF9F9F9),
        fontFamily: 'Pretendard', // 예시 폰트, pubspec.yaml에 폰트 추가 후 사용 가능
      ),
      home: const TravelHomePage(),
    );
  }
}

class TravelHomePage extends StatelessWidget {
  const TravelHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar를 사용하여 상단 영역을 만듭니다.
      // elevation: 0으로 설정하여 그림자를 제거하고 디자인과 통일성을 줍니다.
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        // title 위치를 수동으로 조정하지 않기 위해 빈 Text를 넣습니다.
        title: const Text(''),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.black),
            onPressed: () {
              // 알림 버튼 기능
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_outline, color: Colors.black),
            onPressed: () {
              // 프로필 버튼 기능
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        // 스크롤 가능한 화면을 위해 SingleChildScrollView를 사용합니다.
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. 상단 타이틀
              const Text(
                '어디로 떠나볼까요?',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // 2. 검색창
              // Card와 유사한 효과를 위해 Container와 BoxDecoration을 사용합니다.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.15),
                      spreadRadius: 2,
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const TextField(
                  decoration: InputDecoration(
                    icon: Icon(Icons.search, color: Colors.grey),
                    hintText: '나라, 도시, 여행지 검색',
                    border: InputBorder.none, // 기본 밑줄 제거
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // 3. 카테고리 아이콘
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

              // 4. AI 추천 여행지 섹션
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'AI 추천 여행지',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: const Text(
                      '더보기',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              // 5. 추천 여행지 카드 리스트
              // 가로 스크롤을 위해 ListView를 사용합니다.
              SizedBox(
                height: 250,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: const [
                    TravelCard(
                      imageUrl:
                          'https://images.unsplash.com/photo-1502602898657-3e91760c0337?q=80&w=2940&auto=format&fit=crop',
                      city: '프랑스, 파리',
                      description: '낭만과 예술의 도시',
                    ),
                    SizedBox(width: 15),
                    TravelCard(
                      imageUrl:
                          'https://images.unsplash.com/photo-1513407030348-c983a97b98d8?q=80&w=2944&auto=format&fit=crop',
                      city: '일본, 도쿄',
                      description: '전통과 현대의 조화',
                    ),
                    SizedBox(width: 15),
                    TravelCard(
                      imageUrl:
                          'https://images.unsplash.com/photo-1523906834658-6e24ef2386f9?q=80&w=3166&auto=format&fit=crop',
                      city: '이탈리아, 베네치아',
                      description: '물의 도시, 낭만 여행',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // 아이템이 4개 이상일 때 필요
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_border),
            label: '저장',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore_outlined),
            label: '내 여행',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: '마이',
          ),
        ],
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.grey,
        showSelectedLabels: false, // 선택된 아이템의 라벨 숨기기
        showUnselectedLabels: false, // 선택되지 않은 아이템의 라벨 숨기기
      ),
    );
  }
}

// 카테고리 아이콘 위젯 (재사용을 위해 별도 클래스로 분리)
class CategoryIcon extends StatelessWidget {
  final IconData icon;
  final String label;

  const CategoryIcon({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 5,
              ),
            ],
          ),
          child: Icon(icon, size: 30, color: Colors.blueAccent),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

// 여행지 카드 위젯 (재사용을 위해 별도 클래스로 분리)
class TravelCard extends StatelessWidget {
  final String imageUrl;
  final String city;
  final String description;

  const TravelCard({
    super.key,
    required this.imageUrl,
    required this.city,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        image: DecorationImage(
          image: NetworkImage(imageUrl),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          // 이미지 위에 어두운 그라데이션을 추가하여 텍스트 가독성을 높입니다.
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                city,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                description,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
