import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Timer? _timer;
  double _capital = 125.4;
  int _rupturas = 3;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        setState(() {
          _capital += (_random.nextDouble() * 2) - 0.5; // Simulate small shifts
          if (_random.nextDouble() > 0.8) _rupturas += 1; // Occasionally more ruptures prevented
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Lakehouse: Visão Ouro',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.sync, size: 12, color: Colors.greenAccent),
                  SizedBox(width: 4),
                  Text('LIVE', style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildKPI(context, 'Capital Empatado', 'R\$ ${_capital.toStringAsFixed(1)}K', Icons.attach_money, Colors.greenAccent)),
            const SizedBox(width: 16),
            Expanded(child: _buildKPI(context, 'Rupturas Evitadas', '$_rupturas itens', Icons.shield, Colors.blueAccent)),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Curva ABC Inteligente',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 250,
          child: PieChart(
            PieChartData(
              sectionsSpace: 4,
              centerSpaceRadius: 40,
              sections: [
                PieChartSectionData(color: Colors.redAccent, value: 70, title: 'A (70%)', radius: 50, titleStyle: const TextStyle(fontWeight: FontWeight.bold)),
                PieChartSectionData(color: Colors.orangeAccent, value: 20, title: 'B (20%)', radius: 40, titleStyle: const TextStyle(fontWeight: FontWeight.bold)),
                PieChartSectionData(color: Colors.blueAccent, value: 10, title: 'C (10%)', radius: 30, titleStyle: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Tendência de Demanda (30 dias)',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: const FlTitlesData(
                leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22)),
                topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: [
                    FlSpot(0, 10 + (_capital % 5)),
                    FlSpot(1, 15 - (_capital % 3)),
                    FlSpot(2, 12 + (_capital % 4)),
                    FlSpot(3, 22 - (_capital % 2)),
                    FlSpot(4, 25 + (_capital % 6)),
                  ],
                  isCurved: true,
                  color: Theme.of(context).primaryColor,
                  barWidth: 4,
                  isStrokeCapRound: true,
                  belowBarData: BarAreaData(
                    show: true,
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKPI(BuildContext context, String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
