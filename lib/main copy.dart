import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MQTT Flowrate Monitor',
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
  late MqttServerClient client;

  // Data flowrate max 30 titik
  final List<double> flowrateUtama = [];
  final List<double> flowrateCabang1 = [];
  final List<double> flowrateCabang2 = [];

  // Status cabang
  String statusCabang1 = "normal";
  String statusCabang2 = "normal";

  // Status koneksi MQTT
  String mqttStatus = "Disconnected";

  // Pesan terakhir dari MQTT
  String lastMessage = "";

  @override
  void initState() {
    super.initState();
    setupMqttClient();
  }

  void setupMqttClient() async {
    mqttStatus = "Connecting...";
    setState(() {});

    client = MqttServerClient('test.mosquitto.org', '');
    client.logging(on: false);
    client.keepAlivePeriod = 20;
    client.onDisconnected = onDisconnected;

    final connMess = MqttConnectMessage()
        .withClientIdentifier(
          'flutter_client_${DateTime.now().millisecondsSinceEpoch}',
        )
        .startClean()
        .withWillQos(MqttQos.atLeastOnce);

    client.connectionMessage = connMess;

    try {
      await client.connect();
    } catch (e) {
      print('MQTT client connection failed - $e');
      mqttStatus = "Connection Failed";
      setState(() {});
      client.disconnect();
      return;
    }

    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      print('MQTT client connected');
      mqttStatus = "Connected";
      setState(() {});
      client.subscribe('sistem/kebocoran', MqttQos.atLeastOnce);
      client.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
        final recMess = c[0].payload as MqttPublishMessage;
        final pt = MqttPublishPayload.bytesToStringAsString(
          recMess.payload.message,
        );

        lastMessage = pt;
        setState(() {});

        if (c[0].topic == 'sistem/kebocoran') {
          final Map<String, dynamic> data = json.decode(pt);
          double fUtama = (data['flowRateUtama'] as num).toDouble();
          double fCabang1 = (data['flowRateCabang1'] as num).toDouble();
          double fCabang2 = (data['flowRateCabang2'] as num).toDouble();
          String sCabang1 = data['statusCabang1'] ?? "normal";
          String sCabang2 = data['statusCabang2'] ?? "normal";
          setState(() {
            if (flowrateUtama.length >= 30) flowrateUtama.removeAt(0);
            if (flowrateCabang1.length >= 30) flowrateCabang1.removeAt(0);
            if (flowrateCabang2.length >= 30) flowrateCabang2.removeAt(0);
            flowrateUtama.add(fUtama);
            flowrateCabang1.add(fCabang1);
            flowrateCabang2.add(fCabang2);
            statusCabang1 = sCabang1;
            statusCabang2 = sCabang2;
          });
        }
      });
    } else {
      print(
        'MQTT client connection failed - disconnecting, status is ${client.connectionStatus}',
      );
      mqttStatus = "Disconnected";
      setState(() {});
      client.disconnect();
    }
  }

  void onDisconnected() {
    print('MQTT client disconnected');
    mqttStatus = "Disconnected";
    setState(() {});
  }

  @override
  void dispose() {
    client.disconnect();
    super.dispose();
  }

  Widget statusCard(String title, String status) {
    Color statusColor = status == "normal" ? Colors.green : Colors.red;
    return Card(
      color: statusColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: double.infinity,
        height: 80,
        child: Center(
          child: Text(
            '$title: ${status.toUpperCase()}',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Flowrate & Branch Status')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "MQTT Status: $mqttStatus",
              style: TextStyle(
                fontSize: 16,
                color: mqttStatus == "Connected" ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Last message: $lastMessage",
              style: const TextStyle(fontSize: 14, color: Colors.white70),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            statusCard("Status Cabang 1", statusCabang1),
            const SizedBox(height: 12),
            statusCard("Status Cabang 2", statusCabang2),
            const SizedBox(height: 20),
            Expanded(
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: const Color(0xFF1c1c1c),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: 100,
                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 5,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                '${value.toInt()}',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 10,
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 20,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                '${value.toInt()}',
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 10,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: true,
                        horizontalInterval: 20,
                        verticalInterval: 5,
                      ),
                      borderData: FlBorderData(show: true),
                      lineBarsData: [
                        LineChartBarData(
                          spots: flowrateUtama
                              .asMap()
                              .entries
                              .map((e) => FlSpot(e.key.toDouble(), e.value))
                              .toList(),
                          isCurved: true,
                          color: Colors.blueAccent,
                          barWidth: 3,
                          dotData: FlDotData(show: false),
                        ),
                        LineChartBarData(
                          spots: flowrateCabang1
                              .asMap()
                              .entries
                              .map((e) => FlSpot(e.key.toDouble(), e.value))
                              .toList(),
                          isCurved: true,
                          color: Colors.orangeAccent,
                          barWidth: 3,
                          dotData: FlDotData(show: false),
                        ),
                        LineChartBarData(
                          spots: flowrateCabang2
                              .asMap()
                              .entries
                              .map((e) => FlSpot(e.key.toDouble(), e.value))
                              .toList(),
                          isCurved: true,
                          color: Colors.greenAccent,
                          barWidth: 3,
                          dotData: FlDotData(show: false),
                        ),
                      ],
                    ),
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
