// DashboardScreen v3 — tokens AppColors.lg* canônicos + formatação pt-BR nas métricas
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

  // Formata valor em pt-BR: 1234.5 → "1.234,5" / em K: "1,2K"
  String _fmtK(double v) {
    final k = v / 1000;
    // garante separador de milhar apenas se >= 10K
    if (k >= 10) {
      final s = k.toStringAsFixed(0);
      return 'R\$ ${_addDotThousands(s)}K';
    }
    return 'R\$ ${k.toStringAsFixed(1).replaceAll(".", ",")}K';
  }

  String _addDotThousands(String s) {
    final result = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) result.write('.');
      result.write(s[i]);
    }
    return result.toString();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadForecast());
    _refreshTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => setState(() {}));
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

    // ── Tokens canônicos do AppColors (sem Color() inline) ──
    final cardBg   = isDark ? AppColors.bgCard    : AppColors.lgBgCard;
    final borderCol= isDark ? AppColors.border     : AppColors.lgBorder;
    final textHigh = isDark ? AppColors.textHigh   : AppColors.lgTextHigh;
    final textLow  = isDark ? AppColors.textLow    : AppColors.lgTextLow;

    final capitalK        = op.totalStockValue;
    final urgentes        = op.lowStockItems.length;
    final totalItens      = op.totalItems;
    final custoReposicao  = op.restockEstimatedCost;

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
          // ── Header ──────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Lakehouse: Visão Ouro',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: textHigh),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.neonGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.neonGreen.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
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

          // ── KPIs: linha 1 ────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _kpiCard(
                  label: 'Capital em Estoque',
                  value: _fmtK(capitalK),
                  icon: Icons.attach_money,
                  color: AppColors.neonGreen,
                  cardBg: cardBg,
                  borderCol: borderCol,
                  textLow: textLow,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _kpiCard(
                  label: 'Reposições Urgentes',
                  value: '$urgentes ${urgentes == 1 ? "item" : "itens"}',
                  icon: Icons.warning_amber_rounded,
                  color: urgentes > 0
                      ? AppColors.neonRed
                      : AppColors.neonGreen,
                  cardBg: cardBg,
                  borderCol: borderCol,
                  textLow: textLow,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── KPIs: linha 2 ────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _kpiCard(
                  label: 'Total de Produtos',
                  value: '$totalItens ${totalItens == 1 ? "item" : "itens"}',
                  icon: Icons.inventory_2_outlined,
                  color: AppColors.neonCyan,
                  cardBg: cardBg,
                  borderCol: borderCol,
                  textLow: textLow,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _kpiCard(
                  label: 'Custo Est. Reposição',
                  value: custoReposicao > 0
                      ? _fmtK(custoReposicao)
                      : 'Estoque OK',
                  icon: Icons.price_change_outlined,
                  color: custoReposicao > 0
                      ? AppColors.neonAmber
                      : AppColors.neonGreen,
                  cardBg: cardBg,
                  borderCol: borderCol,
                  textLow: textLow,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Curva ABC ────────────────────────────────────
          Text('Curva ABC Inteligente',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: textHigh)),
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
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _abcLegend(
                        AppColors.neonRed, 'A — Alto valor', textLow),
                    const SizedBox(width: 16),
                    _abcLegend(
                        AppColors.neonAmber, 'B — Médio', textLow),
                    const SizedBox(width: 16),
                    _abcLegend(
                        AppColors.neonCyan, 'C — Baixo', textLow),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Tendência ────────────────────────────────────
          Text('Tendência de Demanda (6 meses)',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: textHigh)),
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
                              style:
                                  TextStyle(fontSize: 10, color: textLow));
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
                        color:
                            AppColors.neonCyan.withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Forecast IA ──────────────────────────────────
          if (_loadingForecast) ...[
            const SizedBox(height: 24),
            Text('Forecast IA — Item Crítico',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: textHigh)),
            const SizedBox(height: 12),
            const ShimmerLoading(height: 120, borderRadius: 16),
          ] else if (_forecast.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Forecast IA — Item Crítico',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: textHigh)),
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
                children: _forecast.entries.take(4).map((e) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(e.key,
                            style:
                                TextStyle(color: textLow, fontSize: 12)),
                        Text(e.value.toString(),
                            style: TextStyle(
                                color: textHigh,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _kpiCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required Color cardBg,
    required Color borderCol,
    required Color textLow,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label,
                    style: TextStyle(color: textLow, fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(value,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _abcLegend(Color color, String label, Color textColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 10,
            height: 10,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11, color: textColor)),
      ],
    );
  }
}
