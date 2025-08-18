//Open-meteo api로 날씨구현.
import 'dart:convert';
import 'package:http/http.dart' as http;

/// 선택한 도시와 날짜(YYYY-MM-DD)를 넣으면 일별 비 올 여부 반환
Future<bool> getDailyRainStatus(String location, String date) async {
  try {
    // 1. 지명으로 위도/경도 찾기
    final geoUrl = Uri.https(
      'geocoding-api.open-meteo.com',
      '/v1/search',
      {'name': location, 'count': '1', 'language': 'ko'},
    );
    final geoRes = await http.get(geoUrl);
    
    if (geoRes.statusCode != 200) {
      print('getDailyRainStatus error: Failed to get geocoding data. Status code: ${geoRes.statusCode}');
      return false;
    }

    final geoData = jsonDecode(geoRes.body);
    if (geoData['results'] == null || geoData['results'].isEmpty) {
      print('getDailyRainStatus error: No location results found for "$location".');
      return false;
    }

    final latitude = geoData['results'][0]['latitude'];
    final longitude = geoData['results'][0]['longitude'];

    // 2. 위도/경도로 일별 날씨 예보 요청
    final wxUrl = Uri.https(
      'api.open-meteo.com',
      '/v1/forecast',
      {
        'latitude': '$latitude',
        'longitude': '$longitude',
        'daily': 'precipitation_sum,weathercode',
        'forecast_days': '16', 
        'timezone': 'Asia/Seoul',
      },
    );

    final wxRes = await http.get(wxUrl);
    if (wxRes.statusCode != 200) {
      print('getDailyRainStatus error: Failed to get weather data. Status code: ${wxRes.statusCode}');
      return false;
    }

    final wxData = jsonDecode(wxRes.body);
    final dates = List<String>.from(wxData['daily']['time']);
    final precipitationSums = List<double>.from(
        wxData['daily']['precipitation_sum'].map((e) => (e as num).toDouble()));
    final weatherCodes = List<int>.from(wxData['daily']['weathercode']);

    // 3. 선택한 날짜의 인덱스 찾기
    final dateIndex = dates.indexOf(date);
    if (dateIndex == -1) {
      print('getDailyRainStatus error: Date "$date" is out of the 16-day forecast range.');
      return false;
    }

    // 4. 강수량 또는 날씨 코드로 비 여부 판단
    final isPrecipitationExpected = precipitationSums[dateIndex] > 0;
    
    // WMO 코드 (Weather Code)
    // 51, 53, 55: 이슬비(Drizzle)
    // 61, 63, 65: 비(Rain)
    // 80, 81, 82: 소나기(Showers)
    // 95, 96, 99: 천둥 동반 비(Thunderstorm with rain/hail)
    final rainRelatedCodes = [51, 53, 55, 61, 63, 65, 80, 81, 82, 95, 96, 99];
    final isRainCode = rainRelatedCodes.contains(weatherCodes[dateIndex]);
    
    return isPrecipitationExpected || isRainCode;
    
  } catch (e) {
    print('getDailyRainStatus error: An unexpected error occurred: $e');
    return false;
  }
}