// Sprint 4 — IA Previsão de Demanda (local + API /forecast)
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/section_header.dart';
import '../widgets/kpi_card.dart';

class ForecastScreen extends StatefulWidget {
  const ForecastScreen({super.key});

  @override
  State<ForecastScreen> createState() => _ForecastScreenState();
}

class _ForecastScreenState extends State<ForecastScreen> {
  bool _loading = false;
  String _selectedItem = 'Tecido Floral 140cm';

  final List<String> _items = [
    'Tecido Floral 140cm',
    'Espuma D33 10cm',
    'Tecido Veludo Verde',
    'Ferragem Dobradiça 80mm',
  ];

  // Mock forecast data (integrar com GET /api/v1/forecast/{item_code})
  final Map<String, List<double>> _historico = {
    'Tecido Floral 140cm': [45, 52, 48, 61, 58, 70],
    'Espuma D33 10cm': [20, 25, 18, 30, 28, 35],
    'Tecido Veludo Verde': [8, 12, 5, 9, 7, 11],
    'Ferragem Dobradiça 80mm': [100, 95, 110, 88, 92, 105],
  };

  final Map<String, List<double>> _previsao = {
    'Tecido Floral 140cm': [72, 68, 75, 80],
    'Espuma D33 10cm': [32, 38, 35, 42],
    'Tecido Veludo Verde': [13, 10, 14, 16],
    'Ferragem Dobradiça 80mm': [98, 102, 95, 108],
  };

  List<double> get hist => _historico[_selectedItem] ?? [];
  List<double> get prev => _previsao[_selectedItem] ?? [];

  double get avgHist => hist.isEmpty ? 0 : hist.reduce((a, b) => a + b) / hist.length;
  double get peakPrev => prev.isEmpty ? 0 : prev.reduce(max);
  double get trend {
    if (hist.length < 2) return 0;
    return ((hist.last - hist.first) / hist.first) * 100;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        title: const Text('IA Previsão de Demanda'),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // Seletor de item
          DropdownButtonFormField<String>(
            value: _selectedItem,
            items: _items
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() => _selectedItem = v!),
            decoration: const InputDecoration(
              labelText: 'Selecione o Item',
              prefixIcon: Icon(Icons.inventory_2_outlined,
                  color: AppColors.neonCyan),
            ),
          ),
          const SizedBox(height: 20),

          // KPIs de Forecast
          Row(
            children: [
              Expanded(
                child: KpiCard(
                  title: 'Média Histórica',
                  value: '${avgHist.toStringAsFixed(0)}/mês',
                  icon: Icons.history,
                  gradientColors: const [AppColors.neonCyan, AppColors.neonPurple],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: KpiCard(
                  title: 'Pico Previsto',
                  value: '${peakPrev.toStringAsFixed(0)}/mês',
                  icon: Icons.trending_up,
                  gradientColors: const [AppColors.neonAmber, AppColors.neonGreen],
                  trend: '${trend >= 0 ? '+' : ''}${trend.toStringAsFixed(1)}%',
                  trendUp: trend >= 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Gráfico histórico + previsão
          const SectionHeader(title: 'Histórico vs Previsão IA'),
          const SizedBox(height: 12),
          GlassCard(
            padding: const EdgeInsets.fromLTRB(12, 20, 16, 12),
            child: Column(
              children: [
                // Legenda
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _legend(AppColors.neonCyan, 'Histórico (6 meses)'),
                    const SizedBox(width: 16),
                    _legend(AppColors.neonAmber, 'Previsão IA (4 meses)'),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        getDrawingHorizontalLine: (_) =>
                            const FlLine(color: AppColors.border, strokeWidth: 1),
                        drawVerticalLine: false,
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 24,
                            getTitlesWidget: (v, _) {
                              final labels = [
                                'Out', 'Nov', 'Dez', 'Jan', 'Fev', 'Mar',
                                'Abr', 'Mai', 'Jun', 'Jul'
                              ];
                              final i = v.toInt();
                              if (i < 0 || i >= labels.length) return const SizedBox();
                              return Text(labels[i],
                                  style: const TextStyle(
                                      fontSize: 10, color: AppColors.textLow));
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        // Linha histórico
                        LineChartBarData(
                          spots: hist
                              .asMap()
                              .entries
                              .map((e) => FlSpot(e.key.toDouble(), e.value))
                              .toList(),
                          isCurved: true,
                          gradient: const LinearGradient(
                              colors: [AppColors.neonCyan, AppColors.neonPurple]),
                          barWidth: 3,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(colors: [
                              AppColors.neonCyan.withValues(alpha: 0.2),
                              AppColors.neonCyan.withValues(alpha: 0.02),
                            ], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                          ),
                        ),
                        // Linha previsão (tracejada)
                        LineChartBarData(
                          spots: prev
                              .asMap()
                              .entries
                              .map((e) => FlSpot(
                                  (hist.length - 1 + e.key).toDouble(),
                                  e.value))
                              .toList(),
                          isCurved: true,
                          gradient: const LinearGradient(
                              colors: [AppColors.neonAmber, AppColors.neonRed]),
                          barWidth: 2,
                          dashArray: [6, 4],
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (_, __, ___, ____) =>
                                FlDotCirclePainter(
                                    radius: 4,
                                    color: AppColors.neonAmber,
                                    strokeWidth: 0),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          // Recomendação IA
          const SectionHeader(title: 'Recomendação IA'),
          const SizedBox(height: 12),
          GlassCard(
            borderColor: AppColors.neonGreen.withValues(alpha: 0.4),
            gradientColors: const [AppColors.neonGreen, AppColors.neonCyan],
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.neonGreen.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.psychology,
                      color: AppColors.neonGreen, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Agente de Compras',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textHigh,
                              fontSize: 14)),
                      const SizedBox(height: 6),
                      Text(
                        'Pico de ${peakPrev.toStringAsFixed(0)} unidades previsto em Mai/26. '
                        'Recomendo comprar ${(peakPrev * 1.2).toStringAsFixed(0)} unidades '
                        'até 15/04 para garantir cobertura de 6 semanas.',
                        style: const TextStyle(
                            color: AppColors.textMed,
                            fontSize: 13,
                            height: 1.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      children: [
        Container(width: 16, height: 3, color: color,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(fontSize: 11, color: AppColors.textLow)),
      ],
    );
  }
}
