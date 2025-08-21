import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math';

// 데이터 클래스
class Schedule {
  final DateTime dateTime;
  final String description;
  Schedule({required this.dateTime, required this.description});
}

// Custom Painter 클래스들 (TopDashedRectPainter, BottomDashedRectPainter)
class TopDashedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;

  TopDashedRectPainter({ required this.color, this.strokeWidth = 1.0, this.dashWidth = 5.0, this.dashSpace = 5.0 });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = strokeWidth..style = PaintingStyle.stroke;
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class BottomDashedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;

  BottomDashedRectPainter({ required this.color, this.strokeWidth = 1.0, this.dashWidth = 5.0, this.dashSpace = 5.0 });
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = strokeWidth..style = PaintingStyle.stroke;
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, size.height), Offset(startX + dashWidth, size.height), paint);
      startX += dashWidth + dashSpace;
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}


// 메인 위젯
class TimeGridTable extends StatefulWidget {
  final List<Map<String, String>> scheduleData;
  const TimeGridTable({super.key, required this.scheduleData});

  @override
  State<TimeGridTable> createState() => _TimeGridTableState();
}

class _TimeGridTableState extends State<TimeGridTable> {
  // 상태 변수
  List<Schedule> _schedules = [];
  Map<String, String> _scheduleLookup = {}; // 1. 빠른 조회를 위한 Map
  List<DateTime> _dates = [];
  int _startHour = 8;
  int _endHour = 22;

  final double cellWidth = 150;
  final double cellHeight = 60;

  @override
  void initState() {
    super.initState();
    // (디버깅용) 데이터가 제대로 전달되었는지 확인
    print('📊 TimeGridTable received ${widget.scheduleData.length} items.');
    _processData();
  }

  // 부모 위젯으로부터 데이터가 변경될 때를 대비한 라이프사이클 메서드
  @override
  void didUpdateWidget(covariant TimeGridTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.scheduleData != oldWidget.scheduleData) {
      _processData();
    }
  }

  // 데이터 처리 로직을 하나의 함수로 통합
  void _processData() {
    // 2. 데이터 파싱
    final List<Schedule> parsedSchedules = [];
    for (var data in widget.scheduleData) {
      try {
        final date = data['date']!;
        final time = data['time']!;
        final description = data['title']!;
        final dateTime = DateFormat('yyyy-MM-dd HH:mm').parse('$date $time');
        parsedSchedules.add(Schedule(dateTime: dateTime, description: description));
      } catch (e) {
        print('데이터 파싱 오류: $data, 오류: $e');
      }
    }
    _schedules = parsedSchedules;

    // 3. 날짜 헤더 생성
    if (_schedules.isNotEmpty) {
      final uniqueDatesSet = _schedules.map((s) => DateTime(s.dateTime.year, s.dateTime.month, s.dateTime.day)).toSet();
      _dates = uniqueDatesSet.toList()..sort();
    }

    // 4. 시간 범위 계산
    if (_schedules.isNotEmpty) {
      final hours = _schedules.map((s) => s.dateTime.hour).toList();
      _startHour = hours.reduce(min);
      _endHour = hours.reduce(max);
      if (_startHour > 0) _startHour--;
      if (_endHour < 23) _endHour++;
    }

    // 5. 빠른 조회를 위한 Map 생성
    _scheduleLookup.clear();
    for (var schedule in _schedules) {
      final key = DateFormat('yyyy-MM-dd HH:mm').format(schedule.dateTime);
      _scheduleLookup[key] = schedule.description;
    }
    // 동작 확인용
    print('🗺️ Schedule Lookup Map: $_scheduleLookup');
    
    // 6. 모든 데이터 처리가 끝난 후, 마지막에 단 한번만 setState 호출
    setState(() {});
  }

  // 7. build 메서드의 구조를 안정적으로 변경
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('상세 여행 일정표'),
      ),
      body: _schedules.isEmpty
          ? const Center(child: CircularProgressIndicator())
          // Stack과 여러 ScrollView를 사용하여 고정 헤더 효과와 스크롤 구현
          : SingleChildScrollView(
              child: Stack(
                children: [
                  // 그리드 내용 (시간축 + 날짜 열들)
                  Padding(
                    padding: const EdgeInsets.only(top: 50.0), // 헤더 높이만큼 아래로 밀기
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTimeAxis(),
                          ..._dates.map((date) => _buildDateColumn(date)).toList(),
                        ],
                      ),
                    ),
                  ),
                  // 날짜 헤더 (내용 위에 겹쳐짐)
                  Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: _buildHeaderRow(),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // --- UI를 그리는 헬퍼 함수들 ---

  Widget _buildHeaderRow() {
    return Row(
      children: [
        _buildHeaderCell(text: '', width: 60, color: Colors.grey.shade100),
        ..._dates.map((date) => _buildHeaderCell(
          text: DateFormat('MM/dd(E)', 'ko_KR').format(date),
          width: cellWidth,
          color: Colors.grey.shade100,
        )),
      ],
    );
  }

  Widget _buildTimeAxis() {
    List<Widget> cells = [];
    // startHour부터 endHour까지만 루프를 돌도록 수정
    for (int i = _startHour; i <= _endHour; i++) {
      cells.add(_buildTimeCell(text: '${i.toString().padLeft(2, '0')}:00', isDashed: false));
      // 마지막 시간 바로 다음의 점선은 그리지 않음
      if (i < _endHour) {
        cells.add(_buildTimeCell(text: '', isDashed: true));
      }
    }
    return Column(children: cells);
  }

  Widget _buildDateColumn(DateTime date) {
    List<Widget> cells = [];
    for (int i = _startHour; i <= _endHour; i++) {
      cells.add(_buildDataCell(date: date, hour: i, minute: 0, isDashed: false));
      if (i < _endHour) {
        cells.add(_buildDataCell(date: date, hour: i, minute: 30, isDashed: true));
      }
    }
    return Column(children: cells);
  }

  // 8. _buildDataCell의 로직을 효율적이고 명확하게 수정
  Widget _buildDataCell({ required DateTime date, required int hour, required int minute, required bool isDashed }) {
    final key = DateFormat('yyyy-MM-dd HH:mm').format(DateTime(date.year, date.month, date.day, hour, minute));
    // Map에서 바로 값을 찾아와서 매우 빠름
    final title = _scheduleLookup[key];
    
    bool isKeyEvent = title != null && title != '취침' && title != '숙소에서 휴식 또는 자유시간';

    return Container(
      width: cellWidth,
      height: cellHeight,
      decoration: BoxDecoration(
        color: isKeyEvent ? Colors.blue.shade50 : Colors.transparent,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
          left: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      padding: const EdgeInsets.all(4.0),
      child: Center(
        child: title != null
            ? Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: isKeyEvent ? Colors.black87 : Colors.grey.shade400,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              )
            : const SizedBox.shrink(),
      ),
    );
  }
  
  // 헤더 행 (요일)
  Widget _buildHeaderCell({required String text, required double width, required Color color}) {
    return Container(
      width: width,
      height: 50,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: Colors.grey.shade300, width: 0.5),
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildTimeCell({required String text, required bool isDashed}) {
    return Container(
        width: 60,
        height: cellHeight,
        decoration: BoxDecoration(
          border: isDashed
              ? Border(
            left: BorderSide(color: Colors.grey.shade300, width: 0.5),
            right: BorderSide(color: Colors.grey.shade300, width: 0.5),
            bottom: BorderSide(color: Colors.grey.shade300, width: 0.5),
          )
              : Border(
            left: BorderSide(color: Colors.grey.shade300, width: 0.5),
            right: BorderSide(color: Colors.grey.shade300, width: 0.5),
            top: BorderSide(color: Colors.grey.shade300, width: 0.5),
          ),
        ),
        child: isDashed
            ? CustomPaint(
          painter: TopDashedRectPainter(
            color: Colors.grey.shade300,
            dashWidth: 8,
            dashSpace: 4,
            strokeWidth: 1,
          ),
          child: Container(
            alignment: Alignment.center,
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
        )
            : CustomPaint(
          painter: BottomDashedRectPainter(
            color: Colors.grey.shade300,
            dashWidth: 8,
            dashSpace: 4,
            strokeWidth: 1,
          ),
          child: Container(
            alignment: Alignment.center,
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
        ));
  }
}
