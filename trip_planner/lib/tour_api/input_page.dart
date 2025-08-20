import 'package:flutter/material.dart';
import 'tour_api.dart';

class RegionSelector extends StatefulWidget{
  const RegionSelector({super.key});

  @override
  State<RegionSelector> createState() => _RegionSelectorState();
}

class _RegionSelectorState extends State<RegionSelector> {
  // 로딩 상태 및 데이터 관리
  bool _isLoadingAreas = true;
  List<dynamic> _areas = []; // 시/도 목록
  List<dynamic> _sigungus = []; // 시/군/구 목록

  // 사용자가 선택한 값 관리
  dynamic _selectedArea; // 선택된 시/도
  dynamic _selectedSigungu; // 선택된 시/군/구

  List<dynamic> _tourData = [];

  @override
  void initState() {
    super.initState();
    _fetchAreas(); // 위젯이 생성될 때 시/도 목록을 불러옴
  }

  // 시/도 목록 불러오기
  void _fetchAreas() async {
    try {
      final areas = await getAreaCodes();
      setState(() {
        _areas = areas;
        _isLoadingAreas = false;
      });
    } catch (e) {
      // 에러 처리
      setState(() {
        _isLoadingAreas = false;
      });
    }
  }

  // 시/군/구 목록 불러오기
  void _fetchSigungus(String areaCode) async {
    final sigungus = await getAreaCodes(areaCode: areaCode);
    setState(() {
      _sigungus = sigungus;
    });
  }

  // 최종 검색 실행
  void _searchTours() async {
    if (_selectedArea == null) {
      // 사용자에게 지역을 선택하라는 메시지 표시
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('시/도를 선택해주세요.')),
      );
      return;
    }
    
    final areaCode = _selectedArea['code'];
    final sigunguCode = _selectedSigungu?['code']; // 시군구는 선택사항일 수 있음

    print('Searching for tours in Area: $areaCode, Sigungu: $sigunguCode');

    setState(() {
      _isLoadingAreas = true;
    });

    final data = await getTourData(areaCode, sigunguCode);
    try{
      setState(() {
        _tourData = data;
        _isLoadingAreas = false;
      });
    }
    catch(e){
      setState(() {
        _isLoadingAreas = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('데이터를 불러오는데 실패했습니다: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 1. 시/도 선택 드롭다운
          if (_isLoadingAreas)
            const CircularProgressIndicator()
          else
            DropdownButton<dynamic>(
              isExpanded: true,
              hint: const Text('시/도를 선택하세요'),
              value: _selectedArea,
              items: _areas.map<DropdownMenuItem<dynamic>>((area) {
                return DropdownMenuItem<dynamic>(
                  value: area,
                  child: Text(area['name']),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedArea = value;
                  _selectedSigungu = null; // 시/도 변경 시 시/군/구 선택 초기화
                  _sigungus = []; // 시/군/구 목록 초기화
                  if (value != null) {
                    _fetchSigungus(value['code']); // 선택된 시/도의 시/군/구 목록 불러오기
                  }
                });
              },
            ),
          const SizedBox(height: 20),

          // 2. 시/군/구 선택 드롭다운
          // 시/도를 선택했고, 시/군/구 목록이 있을 때만 보임
          if (_selectedArea != null && _sigungus.isNotEmpty)
            DropdownButton<dynamic>(
              isExpanded: true,
              hint: const Text('시/군/구를 선택하세요'),
              value: _selectedSigungu,
              items: _sigungus.map<DropdownMenuItem<dynamic>>((sigungu) {
                return DropdownMenuItem<dynamic>(
                  value: sigungu,
                  child: Text(sigungu['name']),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedSigungu = value;
                });
              },
            ),
          const SizedBox(height: 40),

          // 3. 검색 버튼
          ElevatedButton(
            onPressed: _searchTours,
            child: const Text('이 지역으로 검색하기'),
          ),
          const SizedBox(height: 20,),
          _isLoadingAreas
            ? const CircularProgressIndicator()
            : Expanded(
              child: ListView.builder(
                itemCount: _tourData.length,
                itemBuilder: (context,index){
                  final item = _tourData[index];

                  return ListTile(
                    title: Text(item['title']),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['mapx']),
                        Text(item['mapy']),
                        
                      ],
                    ),
                    
                  );
                },
              )),
        ],
      ),
    );
  }
}