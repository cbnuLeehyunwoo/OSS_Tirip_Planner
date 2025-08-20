import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

Future<List<dynamic>> getTourData(String area, String sigungu) async {

  final apiKey = dotenv.env['TOUR_API_KEY']; // 발급받은 API 키
  final appName = 'tourPlaner';
  final url = Uri.https(
    'apis.data.go.kr', // 도메인
    '/B551011/KorService2/areaBasedList2', // 경로
    {
      'numOfRows': '20',
      'pageNo': '1',
      'MobileOS': 'AND',
      'MobileApp': appName,
      '_type': 'json',
      'contentTypeId': '12', // 관광지 타입 (12:관광지,14:문화시설,15:축제공연행사,25:여행코스,28:레포츠,32:숙박,38:쇼핑,39:음식점)
      'areaCode': area,
      'sigunguCode': sigungu,
      'serviceKey': apiKey, 
    },
  );
  final response = await http.get(url);

  if (response.statusCode == 200) {
    // 성공적으로 데이터를 받아왔을 때
    final data = json.decode(utf8.decode(response.bodyBytes));
    final items = data['response']['body']['items']['item'];
    if (items == null){
      return []; //검색 결과가 없을 때 빈 리스트 반환
    }
    else if(items is List){
      return items;// 결과가 여러 개일 경우 그대로 반환
    }
    else{
      return [items]; // 결과가 1개여서 Map인 경우, 리스트에 담아서 반환
    }
    
  } else {
    // 오류 발생 시
    throw Exception('Failed to load tour data: ${response.statusCode}');
  }
}

Future<List<dynamic>> getRestaurantData(String area, String sigungu) async {

  final apiKey = dotenv.env['TOUR_API_KEY']; // 발급받은 API 키
  final appName = 'tourPlaner';
  final url = Uri.https(
    'apis.data.go.kr', // 도메인
    '/B551011/KorService2/areaBasedList2', // 경로
    {
      'numOfRows': '20',
      'pageNo': '1',
      'MobileOS': 'AND',
      'MobileApp': appName,
      '_type': 'json',
      'contentTypeId': '39', // 관광지 타입 (12:관광지,14:문화시설,15:축제공연행사,25:여행코스,28:레포츠,32:숙박,38:쇼핑,39:음식점)
      'areaCode': area,
      'sigunguCode': sigungu,
      'serviceKey': apiKey, 
    },
  );
  final response = await http.get(url);

  if (response.statusCode == 200) {
    // 성공적으로 데이터를 받아왔을 때
    final data = json.decode(utf8.decode(response.bodyBytes));
    final items = data['response']['body']['items']['item'];
    if (items == null){
      return []; //검색 결과가 없을 때 빈 리스트 반환
    }
    else if(items is List){
      return items;// 결과가 여러 개일 경우 그대로 반환
    }
    else{
      return [items]; // 결과가 1개여서 Map인 경우, 리스트에 담아서 반환
    }
    
  } else {
    // 오류 발생 시
    throw Exception('Failed to load tour data: ${response.statusCode}');
  }
}

Future<List<dynamic>> getAccommodationData(String area, String sigungu) async {

  final apiKey = dotenv.env['TOUR_API_KEY']; // 발급받은 API 키
  final appName = 'tourPlaner';
  final url = Uri.https(
    'apis.data.go.kr', // 도메인
    '/B551011/KorService2/areaBasedList2', // 경로
    {
      'numOfRows': '20',
      'pageNo': '1',
      'MobileOS': 'AND',
      'MobileApp': appName,
      '_type': 'json',
      'contentTypeId': '32', // 관광지 타입 (12:관광지,14:문화시설,15:축제공연행사,25:여행코스,28:레포츠,32:숙박,38:쇼핑,39:음식점)
      'areaCode': area,
      'sigunguCode': sigungu,
      'serviceKey': apiKey, 
    },
  );
  final response = await http.get(url);

  if (response.statusCode == 200) {
    // 성공적으로 데이터를 받아왔을 때
    final data = json.decode(utf8.decode(response.bodyBytes));
    final items = data['response']['body']['items']['item'];
    if (items == null){
      return []; //검색 결과가 없을 때 빈 리스트 반환
    }
    else if(items is List){
      return items;// 결과가 여러 개일 경우 그대로 반환
    }
    else{
      return [items]; // 결과가 1개여서 Map인 경우, 리스트에 담아서 반환
    }
    
  } else {
    // 오류 발생 시
    throw Exception('Failed to load tour data: ${response.statusCode}');
  }
}

Future<List<dynamic>> getAreaCodes({String? areaCode}) async {
  final apiKey = dotenv.env['TOUR_API_KEY'];
  final appName = 'tourPlaner';

  final queryParams = {
    'serviceKey': apiKey!,
    'numOfRows': '100', // 모든 지역 정보를 가져오기 위해 넉넉하게 설정
    'pageNo': '1',
    'MobileOS': 'AND',
    'MobileApp': appName,
    '_type': 'json',
  };

  // areaCode가 제공되면, 해당 지역의 시/군/구 목록을 조회
  if (areaCode != null) {
    queryParams['areaCode'] = areaCode;
  }

  final url = Uri.https(
    'apis.data.go.kr',
    '/B551011/KorService2/areaCode2', // 지역 코드 조회 오퍼레이션
    queryParams,
  );

  final response = await http.get(url);

  
  if (response.statusCode == 200) {
    final data = json.decode(utf8.decode(response.bodyBytes));
    if (data['response']?['body']?['items']?['item'] != null) {
      return data['response']['body']['items']['item'];
    }
  }
  // 실패하거나 데이터가 없으면 빈 리스트 반환
  return [];
}


Future<dynamic> getDetailData(String contentID,String contentTypeId) async {

  final apiKey = dotenv.env['TOUR_API_KEY']; // 발급받은 API 키
  final appName = 'tourPlaner';
  final url = Uri.https(
    'apis.data.go.kr', // 도메인
    '/B551011/KorService2/detailIntro2', // 경로
    {
      'MobileOS': 'AND',
      'MobileApp': appName,
      '_type': 'json',
      'contentId': contentID,
      'contentTypeId': contentTypeId, // 관광지 타입 (12:관광지,14:문화시설,15:축제공연행사,25:여행코스,28:레포츠,32:숙박,38:쇼핑,39:음식점)
      'numOfRows': '20',
      'pageNo': '1',
      'serviceKey': apiKey, 
    },
  );
  final response = await http.get(url);

  if (response.statusCode == 200) {
    // 성공적으로 데이터를 받아왔을 때
    print('API 호출 성공: ${response.statusCode}');
    final data = json.decode(utf8.decode(response.bodyBytes));
    final items = data['response']['body']['items']['item'];
    if (items == null){
      return []; //검색 결과가 없을 때 빈 리스트 반환
    }
    else if(items is List){
      return items;// 결과가 여러 개일 경우 그대로 반환
    }
    else{
      return [items]; // 결과가 1개여서 Map인 경우, 리스트에 담아서 반환
    }
  } else {
    // 오류 발생 시
    throw Exception('Failed to load tour data: ${response.statusCode}');
  }
}