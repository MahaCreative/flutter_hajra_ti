import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Monitoring Kebocoran Pipa',
      theme: ThemeData.dark(),
      home: const FlowrateDashboard(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class FlowrateDashboard extends StatefulWidget {
  const FlowrateDashboard({super.key});

  @override
  State<FlowrateDashboard> createState() => _FlowrateDashboardState();
}

class _FlowrateDashboardState extends State<FlowrateDashboard> {
  final List<double> flowUtama = [];
  final List<double> flowCabang1 = [];
  final List<double> flowCabang2 = [];

  String statusCabang1 = "normal";
  String statusCabang2 = "normal";

  Timer? timer;

  @override
  void initState() {
    super.initState();
    fetchData();
    timer = Timer.periodic(const Duration(seconds: 1), (_) => fetchData());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> fetchData() async {
    try {
      final response = await http.get(
        Uri.parse("https://sdnsimbuang2.site/api/get-mon-air"),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        double fUtama = double.tryParse(data['flow_rate_utama']) ?? 0.0;
        double fCabang1 = double.tryParse(data['flow_rate_cabang_1']) ?? 0.0;
        double fCabang2 = double.tryParse(data['flow_rate_cabang_2']) ?? 0.0;

        setState(() {
          if (flowUtama.length >= 20) flowUtama.removeAt(0);
          if (flowCabang1.length >= 20) flowCabang1.removeAt(0);
          if (flowCabang2.length >= 20) flowCabang2.removeAt(0);

          flowUtama.add(fUtama);
          flowCabang1.add(fCabang1);
          flowCabang2.add(fCabang2);

          statusCabang1 = data['status_cabang_1'] ?? "normal";
          statusCabang2 = data['status_cabang_2'] ?? "normal";
        });
      }
    } catch (e) {
      print("Error fetching data: $e");
    }
  }

  Widget debitCard(String title, double value, {String? status}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.water_drop, color: Colors.blue, size: 28),
                const SizedBox(width: 8),
                Text(
                  "${value.toStringAsFixed(2)} L/min",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (status != null)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: status == "normal" ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget buildCombinedChart() {
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 100,
        borderData: FlBorderData(show: true),
        gridData: FlGridData(show: true),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 40),
          ),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          // Flow Utama
          LineChartBarData(
            spots: flowUtama
                .asMap()
                .entries
                .map((e) => FlSpot(e.key.toDouble(), e.value))
                .toList(),
            isCurved: true,
            color: Colors.blueAccent,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.blueAccent.withOpacity(0.3),
            ),
          ),

          // Flow Cabang 1
          LineChartBarData(
            spots: flowCabang1
                .asMap()
                .entries
                .map((e) => FlSpot(e.key.toDouble(), e.value))
                .toList(),
            isCurved: true,
            color: Colors.orangeAccent,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.orangeAccent.withOpacity(0.3),
            ),
          ),

          // Flow Cabang 2
          LineChartBarData(
            spots: flowCabang2
                .asMap()
                .entries
                .map((e) => FlSpot(e.key.toDouble(), e.value))
                .toList(),
            isCurved: true,
            color: Colors.greenAccent,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.greenAccent.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 14)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    double latestUtama = flowUtama.isNotEmpty ? flowUtama.last : 0.0;
    double latestCabang1 = flowCabang1.isNotEmpty ? flowCabang1.last : 0.0;
    double latestCabang2 = flowCabang2.isNotEmpty ? flowCabang2.last : 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text("Monitoring Kebocoran Pipa")),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: ListView(
          children: [
            const Text(
              "PDAM Kota Mamuju",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            // Card Flowrate Utama (dipindah ke atas)
            debitCard("Flowrate Utama", latestUtama),

            const SizedBox(height: 12),

            // Card Cabang 1 & 2
            Row(
              children: [
                Expanded(
                  child: debitCard(
                    "Cabang 1",
                    latestCabang1,
                    status: statusCabang1,
                  ),
                ),
                Expanded(
                  child: debitCard(
                    "Cabang 2",
                    latestCabang2,
                    status: statusCabang2,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Grafik gabungan + Legend
            SizedBox(
              height: 320,
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Expanded(child: buildCombinedChart()),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildLegendItem(Colors.blueAccent, "Flow Utama"),
                          const SizedBox(width: 12),
                          _buildLegendItem(Colors.orangeAccent, "Cabang 1"),
                          const SizedBox(width: 12),
                          _buildLegendItem(Colors.greenAccent, "Cabang 2"),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
