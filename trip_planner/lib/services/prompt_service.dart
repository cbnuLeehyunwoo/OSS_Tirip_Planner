// /home/hyunwoo/OSS_Tirip_Planner/trip_planner/lib/services/prompt_service.dart

// 가상 데이터 모델입니다. 실제 프로젝트의 모델에 맞게 수정해야 합니다.
class TripInfo {
  final String destination;
  final int numberOfPeople;
  final DateTime startDate;
  final DateTime endDate;

  TripInfo({
    required this.destination,
    required this.numberOfPeople,
    required this.startDate,
    required this.endDate,
  });
}

class Place {
  final String name;
  final double latitude;  // Y좌표 (위도)
  final double longitude; // X좌표 (경도)
  final String type;      // '관광지', '맛집', '숙소'
  final bool? isOpen;     // 개폐여부 (null일 수 있음)

  Place({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.type,
    this.isOpen,
  });
}

class PromptService {
  static String generateTripPrompt({
    required TripInfo tripInfo,
    required List<Place> places,
  }) {
    // 여행 기간 계산
    final duration = tripInfo.endDate.difference(tripInfo.startDate).inDays + 1;

    // 프롬프트의 각 부분을 리스트로 만들어 나중에 합칩니다.
    final promptParts = <String>[];

    // 1. AI의 역할과 목표 정의
    promptParts.add(
      '당신은 전문 여행 플래너입니다. 아래 정보를 바탕으로 최적의 여행 계획을 생성해주세요.'
    );
    promptParts.add('---');

    // 2. 기본 여행 정보 제공
    promptParts.add('**1. 기본 여행 정보:**');
    promptParts.add('- 여행지: ${tripInfo.destination}');
    promptParts.add('- 여행 인원: ${tripInfo.numberOfPeople}명');
    promptParts.add('- 여행 기간: ${tripInfo.startDate.toLocal().toString().split(' ')[0]} ~ ${tripInfo.endDate.toLocal().toString().split(' ')[0]} ($duration일)');
    promptParts.add('---');

    // 3. 선택 가능한 장소 목록 제공 (좌표 및 추가 정보 포함)
    promptParts.add('**2. 선택 가능한 장소 목록:**');
    promptParts.add('각 장소의 정보는 [이름: 위도(Y), 경도(X), 영업 여부] 형식입니다.');

    final touristSpots = places.where((p) => p.type == '관광지').toList();
    final restaurants = places.where((p) => p.type == '맛집').toList();
    final accommodations = places.where((p) => p.type == '숙소').toList();

    if (touristSpots.isNotEmpty) {
      promptParts.add('\n* 관광지:');
      for (final place in touristSpots) {
        promptParts.add(
          '- ${place.name}: '
          '${place.latitude}, ${place.longitude}'
          '${place.isOpen == null ? '' : (place.isOpen! ? ', 영업 중' : ', 영업 종료')}'
        );
      }
    }
    if (restaurants.isNotEmpty) {
      promptParts.add('\n* 맛집:');
      for (final place in restaurants) {
        promptParts.add('- ${place.name}: ${place.latitude}, ${place.longitude}');
      }
    }
    if (accommodations.isNotEmpty) {
      promptParts.add('\n* 숙소:');
      for (final place in accommodations) {
        promptParts.add('- ${place.name}: ${place.latitude}, ${place.longitude}');
      }
    }
    promptParts.add('---');

    // 4. 핵심 요구사항 명시 (경로 최적화)
    promptParts.add('**3. 핵심 요구사항:**');
    promptParts.add(
      '1. 위 장소 목록을 활용하여 $duration일간의 여행 계획을 세워주세요, 제공된 장소 리스트외에는 절대 다른 장소를 사용하지 마세요.'
    );
    promptParts.add(
      '2. 각 장소의 위도, 경도를 고려하여 이동 시간과 비용이 최소화되는 **최적의 동선**으로 일정을 구성해주세요.'
    );
    promptParts.add(
      '3. 각 날짜별로 방문할 장소 순서와 추천 활동을 시간대별로 정리해주세요.'
    );
    promptParts.add(
      '4. 아침, 점심, 저녁 식사를 할 맛집도 일정에 포함시켜주세요.'
    );
    promptParts.add(
      '5. 영업이 종료된 관광지는 계획에 포함하지 마세요.'
    );
    promptParts.add('---');

    // 5. 최종 출력 형식 요구
    promptParts.add('**4. 출력 형식:**');
    promptParts.add('결과는 "7/18/09:00~11:00 : 청주 상당산성"과 같이 {날짜 : 관광지}의 딕셔너리 형식으로 작성해주세요.' );

    // 모든 부분을 하나의 문자열로 합칩니다.
    return promptParts.join('\n');
  }
}