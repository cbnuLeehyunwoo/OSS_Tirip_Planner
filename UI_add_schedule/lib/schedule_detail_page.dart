// schedule_detail_page.dart
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'dart:math';

// 일정 데이터를 담을 클래스
class Schedule {
  final DateTime dateTime;
  final String description;

  Schedule({required this.dateTime, required this.description});
}

// 점선 테두리를 그리는 CustomPainter
class DashedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;

  DashedRectPainter({
    required this.color,
    this.strokeWidth = 1.0,
    this.dashWidth = 5.0,
    this.dashSpace = 5.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }

    double startY = 0;
    while (startY < size.height) {
      canvas.drawLine(Offset(0, startY), Offset(0, startY + dashWidth), paint);
      startY += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

// 상단과 하단에만 점선을 그리는 CustomPainter
class TopDashedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;

  TopDashedRectPainter({
    required this.color,
    this.strokeWidth = 1.0,
    this.dashWidth = 5.0,
    this.dashSpace = 5.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    double startX = 0;

    // 상단 점선 그리기
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, 0),
        Offset(startX + dashWidth, 0),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class BottomDashedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;

  BottomDashedRectPainter({
    required this.color,
    this.strokeWidth = 1.0,
    this.dashWidth = 5.0,
    this.dashSpace = 5.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    double startX = 0;

    // 하단 점선 그리기
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, size.height),
        Offset(startX + dashWidth, size.height),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

// 주간 일정표 위젯
class TimeGridTable extends StatefulWidget {
  const TimeGridTable({super.key});

  @override
  State<TimeGridTable> createState() => _TimeGridTableState();
}

class _TimeGridTableState extends State<TimeGridTable> {
  final scheduleData = [
    {"date": "2025-08-18", "time": "08:00", "title": "Travel from 충청북도 청주 to 부산"},
    {"date": "2025-08-18", "time": "12:00", "title": "Explore the 광장 시장 (Gwangjang Market)"},
    {"date": "2025-08-18", "time": "16:00", "title": "Enjoy a traditional Korean bath (Jjimjilbang) at a local spa"},
    {"date": "2025-08-18", "time": "19:00", "title": "Dinner at a seafood restaurant near the river"},
    {"date": "2025-08-19", "time": "12:00", "title": "Explore Gwonge오m (Museum of Korean Traditional Arts)"},
    {"date": "2025-08-19", "time": "15:00", "title": "Wangan-dong Market (Shopping and street food)"},
    {"date": "2025-08-19", "time": "18:00", "title": "Sunset at Busan Beach"},
    {"date": "2025-08-19", "time": "20:00", "title": "Dinner in Jagalchi Fish Market"},
    {"date": "2025-08-20", "time": "12:00", "title": "Explore Haeundae Beach"},
    {"date": "2025-08-20", "time": "14:00", "title": "Shop for souvenirs at Bukchon Hanok Village"},
    {"date": "2025-08-20", "time": "18:00", "title": "Enjoy a traditional Korean tea ceremony"},
    {"date": "2025-08-21", "time": "11:00", "title": "Explore the Jagalchi Fish Market"},
    {"date": "2025-08-21", "time": "14:00", "title": "Shopping and Street Food in Namdaemun Market"},
    {"date": "2025-08-21", "time": "18:00", "title": "Enjoy a Traditional Korean BBQ Dinner"}
  ];

  List<Schedule> _schedules = [];
  List<DateTime> _dates = [];
  int _startHour = 0; // 시작 시간 (최소 시간)
  int _endHour = 24; // 종료 시간 (최대 시간)

  double cellWidth = 120; // 각 셀의 너비
  double cellHeight = 40; // 각 셀의 높이

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('ko_KR', null);
    _parseScheduleData();
    _generateDayHeaders();
    _calculateTimeRange();
  }

  void _parseScheduleData() {
    final List<Schedule> parsedSchedules = [];
    for (var data in scheduleData) {
      try {
        final date = data['date'] as String;
        final time = data['time'] as String;
        final description = data['title'] as String;
        final dateTime = DateTime(
          int.parse(date.split('-')[0]),
          int.parse(date.split('-')[1]),
          int.parse(date.split('-')[2]),
          int.parse(time.split(':')[0]),
          int.parse(time.split(':')[1]),
        );
        parsedSchedules.add(Schedule(dateTime: dateTime, description: description));
      } catch (e) {
        print('데이터 파싱 오류: $data, 오류: $e');
      }
    }
    setState(() {
      _schedules = parsedSchedules;
    });
  }

  void _generateDayHeaders() {
    if (_schedules.isNotEmpty) {
      _schedules.sort((a, b) => a.dateTime.compareTo(b.dateTime));
      final firstDate = _schedules.first.dateTime;
      final lastDate = _schedules.last.dateTime;

      _dates.clear();
      for (var d = firstDate; d.day <= lastDate.day; d = d.add(const Duration(days: 1))) {
        _dates.add(d);
      }
    } else {
      final today = DateTime.now();
      _dates = List.generate(7, (index) => today.add(Duration(days: index)));
    }
  }

  void _calculateTimeRange() {
    if (_schedules.isNotEmpty) {
      final List<int> minutesOfDay = _schedules.map((schedule) {
        return schedule.dateTime.hour * 60 + schedule.dateTime.minute;
      }).toList();

      final int minMinutes = minutesOfDay.reduce(min);
      final int maxMinutes = minutesOfDay.reduce(max);

      _startHour = minMinutes ~/ 60;
      _endHour = maxMinutes ~/ 60;
    } else {
      _startHour = 0;
      _endHour = 24;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('여행 일정표'),
      ),
      body: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          children: [
            _buildHeaderRow(),
            Expanded(child: _buildGridBody()),
          ],
        ),
      ),
    );
  }

  // 헤더 행 (요일)
  Widget _buildHeaderRow() {
    List<Widget> cells = [
      _buildHeaderCell(text: '', width: 60, color: Colors.grey.shade100),
      ..._dates.map((date) => _buildHeaderCell(
        text: DateFormat('MM/dd(E)', 'ko_KR').format(date),
        width: cellWidth,
        color: Colors.grey.shade100,
      )),
    ];
    return Row(children: cells);
  }

  // 시간축과 일정 그리드를 포함하는 본문
  Widget _buildGridBody() {
    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTimeAxis(),
          ..._dates.map((date) => _buildDateColumn(date)).toList(),
        ],
      ),
    );
  }

  // 시간 축 (세로)
  Widget _buildTimeAxis() {
    List<Widget> cells = [];
    for (int i = _startHour; i <= _endHour; i++) {
      cells.add(_buildTimeCell(text: '${i.toString().padLeft(2, '0')}:00', isDashed: false));
      cells.add(_buildTimeCell(text: '', isDashed: true));
    }
    return Column(children: cells);
  }

  // 날짜별 일정 열 (세로)
  Widget _buildDateColumn(DateTime date) {
    List<Widget> cells = [];
    for (int i = _startHour; i <= _endHour; i++) {
      cells.add(_buildDataCell(
        date: date,
        hour: i,
        minute: 0,
        isDashed: false,
      ));
      cells.add(_buildDataCell(
        date: date,
        hour: i,
        minute: 30,
        isDashed: true,
      ));
    }
    return Column(children: cells);
  }

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

  Widget _buildDataCell({
    required DateTime date,
    required int hour,
    required int minute,
    required bool isDashed,
  }) {
    final schedulesInThisCell = _schedules.where((s) {
      final cellStartTime = DateTime(date.year, date.month, date.day, hour, minute);
      final cellEndTime = cellStartTime.add(const Duration(minutes: 30));

      return s.dateTime.isAfter(cellStartTime.subtract(const Duration(seconds: 1))) && s.dateTime.isBefore(cellEndTime);
    }).toList();

    for (int i = 0; i < schedulesInThisCell.length; i++) {
      print(schedulesInThisCell[i].dateTime.toString() + " " + schedulesInThisCell[i].description);
    }

    final schedule = schedulesInThisCell.isNotEmpty ? schedulesInThisCell.first : null;

    if (schedule != null) {
      return Container(
        width: cellWidth,
        height: cellHeight,
        color: Colors.blue.shade50,
        padding: const EdgeInsets.all(4.0),
        child: Center(
          child: Text(
            schedule.description,
            style: const TextStyle(fontSize: 10),
          ),
        ),
      );
    } else {
      return Container(
        width: cellWidth,
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
          child: const SizedBox.shrink(),
        )
            : CustomPaint(
          painter: BottomDashedRectPainter(
            color: Colors.grey.shade300,
            dashWidth: 8,
            dashSpace: 4,
            strokeWidth: 1,
          ),
          child: const SizedBox.shrink(),
        ),
      );
    }
  }
}

// 이 부분이 새로운 페이지 위젯입니다. travel_schedule_page.dart에서 이 위젯을 호출합니다.
class ScheduleDetailPage extends StatelessWidget {
  final Map<String, String> schedule;

  const ScheduleDetailPage({super.key, required this.schedule});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: TimeGridTable(),
    );
  }
}