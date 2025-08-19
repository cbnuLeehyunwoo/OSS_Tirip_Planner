import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:flutter/material.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 이미지에 나타난 부산 서면 일대의 임의의 좌표들
    List<NLatLng> points = [];
    points.add(NLatLng(35.1555, 129.0592)); // 1번 지점
    points.add(NLatLng(35.1630, 129.0520)); // 2번 지점
    points.add(NLatLng(35.1585, 129.0720)); // 3번 지점
    

    final safeAreaPadding = MediaQuery.paddingOf(context);

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text("Naver Map 연결",
              style: TextStyle(color: Colors.white, fontSize: 20)),
          backgroundColor: Colors.green,
        ),
        body: Container(
          width: 400,
          height: 400,
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          child: NaverMap(
            options: NaverMapViewOptions(
              contentPadding: safeAreaPadding,
              initialCameraPosition: NCameraPosition(target: points[0], zoom: 14),
            ),
            onMapReady: (controller) {
              // 이미지와 유사하게 여러 마커를 만듭니다.
              var markers = [];

              for(int i = 0; i<points.length;i++){
                markers.add(
                  NMarker(
                    id: "point${i+1}",
                    position: points[i],
                    caption: NOverlayCaption(
                      text: "${i+1}",
                      textSize: 20,
                      color: Colors.white,
                      haloColor: Colors.black
                    ),
                    captionAligns: [NAlign.top],
                    captionOffset: -30,
                    icon: NOverlayImage.fromAssetImage("assets/MarkerImage.png"),
                    size: const Size(40, 60), // 비율 2 : 3
                  )
                );
              }
              

              for(int i = 0;i<markers.length;i++){
                controller.addOverlay(markers[i]);
              } 
              
              
              // 1번, 2번, 3번 지점을 연결하는 폴리라인을 추가합니다.
              final polyline = NPolylineOverlay(
                id: "tour_route",
                coords: points,
                color: const Color.fromARGB(100, 0, 0, 255),
                width: 3,
                lineCap: NLineCap.round,
                pattern: [6, 3], // 10dp 실선, 5dp 공백
              );

              // 폴리라인을 지도에 추가합니다.
              controller.addOverlay(polyline);

              print("naver map is ready!");
            },
          ),
        ),
      ),
    );
  }
}


