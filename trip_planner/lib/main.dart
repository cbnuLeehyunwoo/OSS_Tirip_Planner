import 'package:flutter/material.dart';
import 'package:trip_planner/WetherAPI/openMeteo.dart';

void main() {
  runApp(const WetherApp());
}

class WetherApp extends StatelessWidget {
  const WetherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: WetherCheckPage(),
    );
  }
}

class WetherCheckPage extends StatefulWidget {
  const WetherCheckPage({super.key});

  @override
  State<WetherCheckPage> createState() => _WetherCheckPageState();
}

class _WetherCheckPageState extends State<WetherCheckPage> {
  String? selectedCity;
  String? selectedDate;
  String? result;

  final cities = ["Daejeon", "Seoul", "Cheongju-si"];
  final dates = [
    "2025-08-15",
    "2025-08-13",
    "2025-08-19",
    "2025-08-20",
    "2025-08-21",
    "2025-08-25"
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("날씨 체크리스트")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("도시 선택",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ...cities.map(
              (city) => RadioListTile<String>(
                title: Text(city),
                value: city,
                groupValue: selectedCity,
                onChanged: (value) => setState(() => selectedCity = value),
              ),
            ),
            const SizedBox(height: 20),
            const Text("날짜 선택",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ...dates.map(
              (d) => RadioListTile<String>(
                title: Text(d),
                value: d,
                groupValue: selectedDate,
                onChanged: (value) => setState(() => selectedDate = value),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (selectedCity != null && selectedDate != null) {
                  final res =
                      await getDailyRainStatus(selectedCity!, selectedDate!);
                  setState(() => result = res ? "비가 올 예정 ☔" : "비 안 올 예정 🌤");
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("도시와 날짜를 모두 선택하세요.")),
                  );
                }
              },
              child: const Text("조회하기"),
            ),
            const SizedBox(height: 20),
            if (result != null)
              Text(
                "결과: $result",
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
          ],
        ),
      ),
    );
  }
}
