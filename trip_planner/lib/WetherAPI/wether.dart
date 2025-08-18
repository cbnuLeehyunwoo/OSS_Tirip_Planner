//api키가 안먹혀서 테스트 못해봄
import 'api.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

//예보구역코드
class Area {
  final String region;
  final String city;
  final String code;

  Area({
    required this.region,
    required this.city,
    required this.code,
  });
}

List<Area> allAreas = [
  Area(region: '서울·인천·경기도', city: '서울', code: '11B10101'),
  Area(region: '서울·인천·경기도', city: '인천', code: '11B20201'),
  Area(region: '서울·인천·경기도', city: '수원', code: '11B20601'),
  Area(region: '서울·인천·경기도', city: '성남', code: '11B20605'),
  Area(region: '서울·인천·경기도', city: '안양', code: '11B20602'),
  Area(region: '서울·인천·경기도', city: '광명', code: '11B10103'),
  Area(region: '서울·인천·경기도', city: '과천', code: '11B10102'),
  Area(region: '서울·인천·경기도', city: '평택', code: '11B20606'),
  Area(region: '서울·인천·경기도', city: '오산', code: '11B20603'),
  Area(region: '서울·인천·경기도', city: '의왕', code: '11B20609'),
  Area(region: '서울·인천·경기도', city: '용인', code: '11B20612'),
  Area(region: '서울·인천·경기도', city: '군포', code: '11B20610'),
  Area(region: '서울·인천·경기도', city: '안성', code: '11B20611'),
  Area(region: '서울·인천·경기도', city: '화성', code: '11B20604'),
  Area(region: '서울·인천·경기도', city: '양평', code: '11B20503'),
  Area(region: '서울·인천·경기도', city: '구리', code: '11B20501'),
  Area(region: '서울·인천·경기도', city: '남양주', code: '11B20502'),
  Area(region: '서울·인천·경기도', city: '하남', code: '11B20504'),
  Area(region: '서울·인천·경기도', city: '이천', code: '11B20701'),
  Area(region: '서울·인천·경기도', city: '여주', code: '11B20703'),
  Area(region: '서울·인천·경기도', city: '광주', code: '11B20702'),
  Area(region: '서울·인천·경기도', city: '의정부', code: '11B20301'),
  Area(region: '서울·인천·경기도', city: '고양', code: '11B20302'),
  Area(region: '서울·인천·경기도', city: '파주', code: '11B20305'),
  Area(region: '서울·인천·경기도', city: '양주', code: '11B20304'),
  Area(region: '서울·인천·경기도', city: '동두천', code: '11B20401'),
  Area(region: '서울·인천·경기도', city: '연천', code: '11B20402'),
  Area(region: '서울·인천·경기도', city: '포천', code: '11B20403'),
  Area(region: '서울·인천·경기도', city: '가평', code: '11B20404'),
  Area(region: '서울·인천·경기도', city: '강화', code: '11B20101'),
  Area(region: '서울·인천·경기도', city: '김포', code: '11B20102'),
  Area(region: '서울·인천·경기도', city: '시흥', code: '11B20202'),
  Area(region: '서울·인천·경기도', city: '부천', code: '11B20204'),
  Area(region: '서울·인천·경기도', city: '안산', code: '11B20203'),
  Area(region: '서울·인천·경기도', city: '백령도', code: '11A00101'),
  Area(region: '부산.울산.경상남도', city: '부산', code: '11H20201'),
  Area(region: '부산.울산.경상남도', city: '울산', code: '11H20101'),
  Area(region: '부산.울산.경상남도', city: '김해', code: '11H20304'),
  Area(region: '부산.울산.경상남도', city: '양산', code: '11H20102'),
  Area(region: '부산.울산.경상남도', city: '창원', code: '11H20301'),
  Area(region: '부산.울산.경상남도', city: '밀양', code: '11H20601'),
  Area(region: '부산.울산.경상남도', city: '함안', code: '11H20603'),
  Area(region: '부산.울산.경상남도', city: '창녕', code: '11H20604'),
  Area(region: '부산.울산.경상남도', city: '의령', code: '11H20602'),
  Area(region: '부산.울산.경상남도', city: '진주', code: '11H20701'),
  Area(region: '부산.울산.경상남도', city: '하동', code: '11H20704'),
  Area(region: '부산.울산.경상남도', city: '사천', code: '11H20402'),
  Area(region: '부산.울산.경상남도', city: '거창', code: '11H20502'),
  Area(region: '부산.울산.경상남도', city: '합천', code: '11H20503'),
  Area(region: '부산.울산.경상남도', city: '산청', code: '11H20703'),
  Area(region: '부산.울산.경상남도', city: '함양', code: '11H20501'),
  Area(region: '부산.울산.경상남도', city: '통영', code: '11H20401'),
  Area(region: '부산.울산.경상남도', city: '거제', code: '11H20403'),
  Area(region: '부산.울산.경상남도', city: '고성', code: '11H20404'),
  Area(region: '부산.울산.경상남도', city: '남해', code: '11H20405'),
  Area(region: '대구.경상북도', city: '대구', code: '11H10701'),
  Area(region: '대구.경상북도', city: '영천', code: '11H10702'),
  Area(region: '대구.경상북도', city: '경산', code: '11H10703'),
  Area(region: '대구.경상북도', city: '청도', code: '11H10704'),
  Area(region: '대구.경상북도', city: '칠곡', code: '11H10705'),
  Area(region: '대구.경상북도', city: '김천', code: '11H10601'),
  Area(region: '대구.경상북도', city: '구미', code: '11H10602'),
  Area(region: '대구.경상북도', city: '군위', code: '11H10707'),
  Area(region: '대구.경상북도', city: '고령', code: '11H10604'),
  Area(region: '대구.경상북도', city: '성주', code: '11H10605'),
  Area(region: '대구.경상북도', city: '안동', code: '11H10501'),
  Area(region: '대구.경상북도', city: '의성', code: '11H10502'),
  Area(region: '대구.경상북도', city: '청송', code: '11H10503'),
  Area(region: '대구.경상북도', city: '상주', code: '11H10302'),
  Area(region: '대구.경상북도', city: '문경', code: '11H10301'),
  Area(region: '대구.경상북도', city: '예천', code: '11H10303'),
  Area(region: '대구.경상북도', city: '영주', code: '11H10401'),
  Area(region: '대구.경상북도', city: '봉화', code: '11H10402'),
  Area(region: '대구.경상북도', city: '영양', code: '11H10403'),
  Area(region: '대구.경상북도', city: '울진', code: '11H10101'),
  Area(region: '대구.경상북도', city: '영덕', code: '11H10102'),
  Area(region: '대구.경상북도', city: '포항', code: '11H10201'),
  Area(region: '대구.경상북도', city: '경주', code: '11H10202'),
  Area(region: '대구.경상북도', city: '울릉도', code: '11E00101'),
  Area(region: '대구.경상북도', city: '독도', code: '11E00102'),
  Area(region: '광주.전라남도', city: '광주', code: '11F20501'),
  Area(region: '광주.전라남도', city: '나주', code: '11F20503'),
  Area(region: '광주.전라남도', city: '장성', code: '11F20502'),
  Area(region: '광주.전라남도', city: '담양', code: '11F20504'),
  Area(region: '광주.전라남도', city: '화순', code: '11F20505'),
  Area(region: '광주.전라남도', city: '영광', code: '21F20102'),
  Area(region: '광주.전라남도', city: '함평', code: '21F20101'),
  Area(region: '광주.전라남도', city: '목포', code: '21F20801'),
  Area(region: '광주.전라남도', city: '무안', code: '21F20804'),
  Area(region: '광주.전라남도', city: '영암', code: '21F20802'),
  Area(region: '광주.전라남도', city: '진도', code: '21F20201'),
  Area(region: '광주.전라남도', city: '신안', code: '21F20803'),
  Area(region: '광주.전라남도', city: '흑산도', code: '11F20701'),
  Area(region: '광주.전라남도', city: '순천', code: '11F20603'),
  Area(region: '광주.전라남도', city: '순천시', code: '11F20405'),
  Area(region: '광주.전라남도', city: '광양', code: '11F20402'),
  Area(region: '광주.전라남도', city: '구례', code: '11F20601'),
  Area(region: '광주.전라남도', city: '곡성', code: '11F20602'),
  Area(region: '광주.전라남도', city: '완도', code: '11F20301'),
  Area(region: '광주.전라남도', city: '강진', code: '11F20303'),
  Area(region: '광주.전라남도', city: '장흥', code: '11F20304'),
  Area(region: '광주.전라남도', city: '해남', code: '11F20302'),
  Area(region: '광주.전라남도', city: '여수', code: '11F20401'),
  Area(region: '광주.전라남도', city: '고흥', code: '11F20403'),
  Area(region: '광주.전라남도', city: '보성', code: '11F20404'),
  Area(region: '전북자치도', city: '전주', code: '11F10201'),
  Area(region: '전북자치도', city: '익산', code: '11F10202'),
  Area(region: '전북자치도', city: '군산', code: '21F10501'),
  Area(region: '전북자치도', city: '정읍', code: '11F10203'),
  Area(region: '전북자치도', city: '김제', code: '21F10502'),
  Area(region: '전북자치도', city: '남원', code: '11F10401'),
  Area(region: '전북자치도', city: '고창', code: '21F10601'),
  Area(region: '전북자치도', city: '무주', code: '11F10302'),
  Area(region: '전북자치도', city: '부안', code: '21F10602'),
  Area(region: '전북자치도', city: '순창', code: '11F10403'),
  Area(region: '전북자치도', city: '완주', code: '11F10204'),
  Area(region: '전북자치도', city: '임실', code: '11F10402'),
  Area(region: '전북자치도', city: '장수', code: '11F10301'),
  Area(region: '전북자치도', city: '진안', code: '11F10303'),
  Area(region: '대전.세종.충청남도', city: '대전', code: '11C20401'),
  Area(region: '대전.세종.충청남도', city: '세종', code: '11C20404'),
  Area(region: '대전.세종.충청남도', city: '공주', code: '11C20402'),
  Area(region: '대전.세종.충청남도', city: '논산', code: '11C20602'),
  Area(region: '대전.세종.충청남도', city: '계룡', code: '11C20403'),
  Area(region: '대전.세종.충청남도', city: '금산', code: '11C20601'),
  Area(region: '대전.세종.충청남도', city: '천안', code: '11C20301'),
  Area(region: '대전.세종.충청남도', city: '아산', code: '11C20302'),
  Area(region: '대전.세종.충청남도', city: '예산', code: '11C20303'),
  Area(region: '대전.세종.충청남도', city: '서산', code: '11C20101'),
  Area(region: '대전.세종.충청남도', city: '태안', code: '11C20102'),
  Area(region: '대전.세종.충청남도', city: '당진', code: '11C20103'),
  Area(region: '대전.세종.충청남도', city: '홍성', code: '11C20104'),
  Area(region: '대전.세종.충청남도', city: '보령', code: '11C20201'),
  Area(region: '대전.세종.충청남도', city: '서천', code: '11C20202'),
  Area(region: '대전.세종.충청남도', city: '청양', code: '11C20502'),
  Area(region: '대전.세종.충청남도', city: '부여', code: '11C20501'),
  Area(region: '충청북도', city: '청주', code: '11C10301'),
  Area(region: '충청북도', city: '증평', code: '11C10304'),
  Area(region: '충청북도', city: '괴산', code: '11C10303'),
  Area(region: '충청북도', city: '진천', code: '11C10102'),
  Area(region: '충청북도', city: '충주', code: '11C10101'),
  Area(region: '충청북도', city: '음성', code: '11C10103'),
  Area(region: '충청북도', city: '제천', code: '11C10201'),
  Area(region: '충청북도', city: '단양', code: '11C10202'),
  Area(region: '충청북도', city: '보은', code: '11C10302'),
  Area(region: '충청북도', city: '옥천', code: '11C10403'),
  Area(region: '충청북도', city: '영동', code: '11C10402'),
  Area(region: '충청북도', city: '추풍령', code: '11C10401'),
  Area(region: '강원도', city: '철원', code: '11D10101'),
  Area(region: '강원도', city: '화천', code: '11D10102'),
  Area(region: '강원도', city: '인제', code: '11D10201'),
  Area(region: '강원도', city: '양구', code: '11D10202'),
  Area(region: '강원도', city: '춘천', code: '11D10301'),
  Area(region: '강원도', city: '홍천', code: '11D10302'),
  Area(region: '강원도', city: '원주', code: '11D10401'),
  Area(region: '강원도', city: '횡성', code: '11D10402'),
  Area(region: '강원도', city: '영월', code: '11D10501'),
  Area(region: '강원도', city: '정선', code: '11D10502'),
  Area(region: '강원도', city: '평창', code: '11D10503'),
  Area(region: '강원도', city: '대관령', code: '11D20201'),
  Area(region: '강원도', city: '속초', code: '11D20401'),
  Area(region: '강원도', city: '고성', code: '11D20402'),
  Area(region: '강원도', city: '양양', code: '11D20403'),
  Area(region: '강원도', city: '강릉', code: '11D20501'),
  Area(region: '강원도', city: '동해', code: '11D20601'),
  Area(region: '강원도', city: '삼척', code: '11D20602'),
  Area(region: '강원도', city: '태백', code: '11D20301'),
  Area(region: '제주도', city: '제주', code: '11G00201'),
  Area(region: '제주도', city: '서귀포', code: '11G00401'),
  Area(region: '제주도', city: '성산', code: '11G00101'),
  Area(region: '제주도', city: '고산', code: '11G00501'),
  Area(region: '제주도', city: '성판악', code: '11G00302'),
  Area(region: '제주도', city: '이어도', code: '11G00601'),
  Area(region: '제주도', city: '추자도', code: '11G00800'),
  Area(region: '제주도', city: '산천단', code: '11G00901'),
  Area(region: '제주도', city: '한남', code: '11G01001'),
];

//지역명을 기반으로 예보구역코드 조회
String? getCodeByCity(String cityName) {
  for (Area area in allAreas) {
    if (area.city == cityName) {
      return area.code;
    }
  }
  return null;
}

//api키 및 url
final String apiKey = wetherAPIKey;
final String apiUrl = 'https://apihub.kma.go.kr/api/typ01/url/fct_medm_reg.php';

Future<String> getWetherAPI(String cityN, String time1, String time2) async {
  String? cityC = getCodeByCity(cityN);
  if (cityC == null) return '도시 코드 없음';

  final Uri uri = Uri.parse('$apiUrl?reg=$cityC&tmfc=0&tmef1=$time1&tmef2=$time2&mode=0&disp=0&authKey=$apiKey');

  try {
    final response = await http.get(uri);
    if (response.statusCode != 200) return 'API 요청 실패: ${response.statusCode}';

    final data = json.decode(response.body);
    final items = data['response']['body']['items']['item'];
    if (items == null || (items is List && items.isEmpty)) return '데이터 없음';

    final firstItem = items is List ? items[0] : items;
    final precipitationCode = firstItem['PRE'] ?? '정보없음';
    final precipitationProbability = firstItem['RN_ST'] ?? '정보없음';

    return '강수유무 코드: $precipitationCode, 강수확률: $precipitationProbability%';
  } catch (e) {
    return '오류 발생: $e';
  }
}
