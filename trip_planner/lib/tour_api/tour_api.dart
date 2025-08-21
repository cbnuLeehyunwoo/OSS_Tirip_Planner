import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

// 공통 에러 핸들러 및 JSON 파서
dynamic _parseResponse(http.Response response) {
  try {
    // UTF-8로 디코딩하여 JSON 파싱
    final data = json.decode(utf8.decode(response.bodyBytes));
    return data['response']?['body']?['items']?['item'];
  } on FormatException {
    // JSON 파싱 실패 시, XML 오류 응답일 가능성이 높음
    print("Tour API가 JSON이 아닌 응답을 반환했습니다. API 키가 유효한지 확인하세요.");
    print("응답 내용: ${utf8.decode(response.bodyBytes)}");
    throw Exception('API 응답 형식이 잘못되었습니다. API 키를 확인해주세요.');
  }
}

Future<List<dynamic>> _fetchData(String contentTypeId, String area, String sigungu) async {
  final apiKey = dotenv.env['TOUR_API_KEY'];
  if (apiKey == null || apiKey == 'YOUR_TOUR_API_KEY_HERE') {
    throw Exception('Tour API 키가 .env 파일에 설정되지 않았습니다.');
  }

  final url = Uri.https(
    'apis.data.go.kr',
    '/B551011/KorService2/areaBasedList2',
    {
      'numOfRows': '20',
      'pageNo': '1',
      'MobileOS': 'AND',
      'MobileApp': 'tourPlaner',
      '_type': 'json',
      'contentTypeId': contentTypeId,
      'areaCode': area,
      'sigunguCode': sigungu,
      'serviceKey': apiKey,
    },
  );

  final response = await http.get(url);

  if (response.statusCode == 200) {
    final items = _parseResponse(response);
    if (items == null) return [];
    if (items is List) return items;
    return [items];
  } else {
    throw Exception('Failed to load tour data: ${response.statusCode}');
  }
}

Future<List<dynamic>> getTourData(String area, String sigungu) => _fetchData('12', area, sigungu);
Future<List<dynamic>> getRestaurantData(String area, String sigungu) => _fetchData('39', area, sigungu);
Future<List<dynamic>> getAccommodationData(String area, String sigungu) => _fetchData('32', area, sigungu);

Future<List<dynamic>> getAreaCodes({String? areaCode}) async {
  final apiKey = dotenv.env['TOUR_API_KEY'];
  if (apiKey == null || apiKey == 'YOUR_TOUR_API_KEY_HERE') {
    throw Exception('Tour API 키가 .env 파일에 설정되지 않았습니다.');
  }

  final queryParams = {
    'serviceKey': apiKey,
    'numOfRows': '100',
    'pageNo': '1',
    'MobileOS': 'AND',
    'MobileApp': 'tourPlaner',
    '_type': 'json',
  };

  if (areaCode != null) {
    queryParams['areaCode'] = areaCode;
  }

  final url = Uri.https(
    'apis.data.go.kr',
    '/B551011/KorService2/areaCode2',
    queryParams,
  );

  final response = await http.get(url);

  if (response.statusCode == 200) {
    return _parseResponse(response) ?? [];
  }
  return [];
}

Future<dynamic> getDetailData(String contentID, String contentTypeId) async {
  final apiKey = dotenv.env['TOUR_API_KEY'];
  if (apiKey == null || apiKey == 'YOUR_TOUR_API_KEY_HERE') {
    throw Exception('Tour API 키가 .env 파일에 설정되지 않았습니다.');
  }

  final url = Uri.https(
    'apis.data.go.kr',
    '/B551011/KorService2/detailIntro2',
    {
      'MobileOS': 'AND',
      'MobileApp': 'tourPlaner',
      '_type': 'json',
      'contentId': contentID,
      'contentTypeId': contentTypeId,
      'serviceKey': apiKey,
    },
  );

  final response = await http.get(url);

  if (response.statusCode == 200) {
    final items = _parseResponse(response);
    if (items == null) return [];
    if (items is List) return items;
    return [items];
  } else {
    throw Exception('Failed to load detail data: ${response.statusCode}');
  }
}
