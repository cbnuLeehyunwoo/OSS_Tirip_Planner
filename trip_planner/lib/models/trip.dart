class Trip {
  final int id;
  final String destinationCity;
  final DateTime startDate;
  final DateTime endDate;
  final List<ItineraryItem> items; // 중첩된 구조도 표현 가능

  Trip({
    required this.id,
    required this.destinationCity,
    required this.startDate,
    required this.endDate,
    required this.items,
  });

  // 백엔드 API로부터 받은 JSON을 Trip 객체로 변환하는 팩토리 생성자
  factory Trip.fromJson(Map<String, dynamic> json) {
    // items 리스트 처리
    var itemList = json['items'] as List;
    List<ItineraryItem> itineraryItems = itemList.map((i) => ItineraryItem.fromJson(i)).toList();

    return Trip(
      id: json['id'],
      destinationCity: json['destination_city'],
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      items: itineraryItems,
    );
  }

  // Trip 객체를 JSON으로 변환하는 메소드 (API로 보낼 때 사용)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'destination_city': destinationCity,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'items': items.map((item) => item.toJson()).toList(),
    };
  }
}

// ItineraryItem 모델도 유사하게 만듭니다.
class ItineraryItem {
  final int id;
  final String title; // 예시 필드
  // ... 기타 필드

  ItineraryItem({required this.id, required this.title});

  factory ItineraryItem.fromJson(Map<String, dynamic> json) {
    return ItineraryItem(id: json['id'], title: json['title']);
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'title': title};
  }
}