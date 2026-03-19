// PR-D v2 — DashboardScreen: light/dark adaptativo + timeout no getForecast
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/providers/operational_provider.dart';
import 'package:frontend/core/services/api_service.dart';
import 'package:frontend/presentation/theme/app_theme.dart';
import 'package:frontend/presentation/widgets/shimmer_loading.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Timer? _refreshTimer;
  Map<String, dynamic> _forecast = {};
  bool _loadingForecast = true;

  final List<FlSpot> _trendSpots = [
    const FlSpot(0, 10),
    const FlSpot(1, 15),
    const FlSpot(2, 12),
    const FlSpot(3, 22),
    const FlSpot(4, 25),
    const FlSpot(5, 20),
  ];
  final List<String> _trendLabels = ['Out', 'Nov', 'Dez', 'Jan', 'Fev', 'Mar'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadForecast();
    });
    _refreshTimer = Timer.periodic(
        const Duration(seconds: 30), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadForecast() async {
    final op = Provider.of<OperationalProvider>(context, listen: false);
    final critical = op.lowStockItems.isNotEmpty
        ? op.lowStockItems.first
        : (op.items.isNotEmpty ? op.items.first : null);

    if (critical == null) {
      if (mounted) setState(() => _loadingForecast = false);
      return;
    }

    try {
      // FIX: timeout de 10s para não travar o dashboard
      final data = await ApiService.instance
          .getForecast(critical.code)
          .timeout(const Duration(seconds: 10));
      if (mounted) setState(() {
        _forecast = data;
        _loadingForecast = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingForecast = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final op = Provider.of<OperationalProvider>(context);

    final cardBg = isDark ? AppColors.bgCard : const Color(0xFFF5F5F5);
    final borderCol = isDark ? AppColors.border : const Color(0xFFDDDDDD);
    final textHigh = isDark ? AppColors.textHigh : const Color(0xFF1A1A1A);
    final textLow = isDark ? AppColors.textLow : const Color(0xFF757575);

    final capitalK = op.totalStockValue / 1000;
    final rupturasEvitadas = op.lowStockItems.length;
    final totalItens = op.totalItems;

    return RefreshIndicator(
      color: AppColors.neonCyan,
      onRefresh: () async {
        await op.loadFromApi();
        await _loadForecast();
      },
      child: ListView(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, MediaQuery.of(context).padding.bottom + 100),
        children: [
          // ─ Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Lakehouse: Visão Ouro',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textHigh),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.neonGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.neonGreen.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.sync, size: 12, color: AppColors.neonGreen),
                    SizedBox(width: 4),
                    Text('LIVE',
                        style: TextStyle(
                            color: AppColors.neonGreen,
                            fontSize: 10,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ─ KPIs
          Row(
            children: [
              Expanded(
                child: _kpiCard(
                  'Capital Estoque',
                  'R\$ ${capitalK.toStringAsFixed(1)}K',
                  Icons.attach_money,
                  AppColors.neonGreen,
                  cardBg: cardBg,
                  borderCol: borderCol,
                  textLow: textLow,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _kpiCard(
                  'Reposições Urgentes',
                  '$rupturasEvitadas itens',
                  Icons.warning_amber,
                  rupturasEvitadas > 0 ? AppColors.neonRed : AppColors.neonGreen,
                  cardBg: cardBg,
                  borderCol: borderCol,
                  textLow: textLow,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _kpiCard(
            'Total de Itens Cadastrados',
            '$totalItens produtos',
            Icons.inventory_2_outlined,
            AppColors.neonCyan,
            fullWidth: true,
            cardBg: cardBg,
            borderCol: borderCol,
            textLow: textLow,
          ),

          const SizedBox(height: 24),

          // ─ Curva ABC
          Text(
            'Curva ABC Inteligente',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: textHigh),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderCol),
            ),
            child: Column(
              children: [
                SizedBox(
                  height: 220,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 4,
                      centerSpaceRadius: 44,
                      sections: [
                        PieChartSectionData(
                          color: AppColors.neonRed,
                          value: 70,
                          title: 'A\n70%',
                          radius: 54,
                          titleStyle: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.white),
                        ),
                        PieChartSectionData(
                          color: AppColors.neonAmber,
                          value: 20,
                          title: 'B\n20%',
                          radius: 44,
                          titleStyle: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.white),
                        ),
                        PieChartSectionData(
                          color: AppColors.neonCyan,
                          value: 10,
                          title: 'C\n10%',
                          radius: 34,
                          titleStyle: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _abcLegend(AppColors.neonRed, 'A — Alto valor', textLow),
                    const SizedBox(width: 16),
                    _abcLegend(AppColors.neonAmber, 'B — Médio', textLow),
                    const SizedBox(width: 16),
                    _abcLegend(AppColors.neonCyan, 'C — Baixo', textLow),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ─ Tendência
          Text(
            'Tendência de Demanda (6 meses)',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: textHigh),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(8, 20, 16, 12),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderCol),
            ),
            child: SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) =>
                        FlLine(color: borderCol, strokeWidth: 1),
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
                        reservedSize: 22,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= _trendLabels.length) {
                            return const SizedBox();
                          }
                          return Text(_trendLabels[i],
                              style: TextStyle(
                                  fontSize: 10, color: textLow));
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _trendSpots,
                      isCurved: true,
                      color: AppColors.neonCyan,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.neonCyan.withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ─ Forecast IA
          if (_loadingForecast) ...[
            const SizedBox(height: 24),
            Text(
              'Forecast IA — Item Crítico',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: textHigh),
            ),
            const SizedBox(height: 12),
            const ShimmerLoading(height: 120, borderRadius: 16),
          ] else if (_forecast.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              'Forecast IA — Item Crítico',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: textHigh),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.neonAmber.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: (_forecast.entries
                    .take(4)
                    .map(
                      (e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(e.key,
                                style: TextStyle(
                                    color: textLow, fontSize: 12)),
                            Text(e.value.toString(),
                                style: TextStyle(
                                    color: textHigh,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    )
                    .toList()),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kpiCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    bool fullWidth = false,
    required Color cardBg,
    required Color borderCol,
    required Color textLow,
  }) {
    return Container(
      width: fullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: TextStyle(color: textLow, fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: fullWidth ? 20 : 22,
                  fontWeight: FontWeight.bold,
                  color: color)),
        ],
      ),
    );
  }

  Widget _abcLegend(Color color, String label, Color textColor) {
    return Row(
      children: [
        Container(
            width: 10,
            height: 10,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(fontSize: 11, color: textColor)),
      ],
    );
  }
}
