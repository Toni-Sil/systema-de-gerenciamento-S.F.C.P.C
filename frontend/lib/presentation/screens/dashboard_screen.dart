import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';
import '../widgets/kpi_card.dart';
import '../widgets/glass_card.dart';
import '../widgets/skeleton_loader.dart';
import '../widgets/section_header.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _loading = true;
  Timer? _timer;
  double _capital = 125.4;
  int _rupturas = 3;
  int _totalItems = 248;
  double _giro = 4.2;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    // Simula carregamento inicial com skeleton
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _loading = false);
    });
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        setState(() {
          _capital += (_random.nextDouble() * 2) - 0.5;
          _giro += (_random.nextDouble() * 0.1) - 0.05;
          if (_random.nextDouble() > 0.85) _rupturas += 1;
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
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.gradientBg),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 8),
                _loading ? _buildSkeletons() : _buildContent(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      pinned: true,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Lakehouse', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          Text('Visão Gold · Tempo Real', style: TextStyle(fontSize: 12, color: AppColors.neonCyan.withValues(alpha: 0.8))),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.neonGreen.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.neonGreen.withValues(alpha: 0.4)),
          ),
          child: const Row(
            children: [
              Icon(Icons.circle, size: 6, color: AppColors.neonGreen),
              SizedBox(width: 5),
              Text('LIVE', style: TextStyle(color: AppColors.neonGreen, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletons() {
    return Column(
      children: [
        Row(
          children: const [
            Expanded(child: KpiCardSkeleton()),
            SizedBox(width: 12),
            Expanded(child: KpiCardSkeleton()),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: const [
            Expanded(child: KpiCardSkeleton()),
            SizedBox(width: 12),
            Expanded(child: KpiCardSkeleton()),
          ],
        ),
        const SizedBox(height: 24),
        const SkeletonLoader(height: 280),
      ],
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // KPI Grid 2x2
        Row(
          children: [
            Expanded(
              child: KpiCard(
                title: 'Capital Empatado',
                value: 'R\$ ${_capital.toStringAsFixed(1)}K',
                subtitle: 'Em estoque ativo',
                icon: Icons.attach_money,
                gradientColors: const [AppColors.neonCyan, AppColors.neonPurple],
                trend: '+2.4%',
                trendUp: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: KpiCard(
                title: 'Rupturas Evitadas',
                value: '$_rupturas itens',
                subtitle: 'Hoje',
                icon: Icons.shield_outlined,
                gradientColors: const [AppColors.neonGreen, AppColors.neonCyan],
                trend: 'IA ativa',
                trendUp: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: KpiCard(
                title: 'Total de Itens',
                value: '$_totalItems',
                subtitle: 'Cadastrados',
                icon: Icons.inventory_2_outlined,
                gradientColors: const [AppColors.neonPurple, AppColors.neonRed],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: KpiCard(
                title: 'Giro de Estoque',
                value: '${_giro.toStringAsFixed(1)}x',
                subtitle: 'Últimos 30 dias',
                icon: Icons.loop_outlined,
                gradientColors: const [AppColors.neonAmber, AppColors.neonGreen],
                trend: '+0.3x',
                trendUp: true,
              ),
            ),
          ],
        ),

        const SizedBox(height: 28),
        const SectionHeader(title: 'Curva ABC Inteligente', showLive: true),
        const SizedBox(height: 16),
        GlassCard(
          child: SizedBox(
            height: 220,
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 50,
                sections: [
                  PieChartSectionData(
                    color: AppColors.neonRed,
                    value: 70,
                    title: 'A\n70%',
                    radius: 55,
                    titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  PieChartSectionData(
                    color: AppColors.neonAmber,
                    value: 20,
                    title: 'B\n20%',
                    radius: 45,
                    titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  PieChartSectionData(
                    color: AppColors.neonCyan,
                    value: 10,
                    title: 'C\n10%',
                    radius: 35,
                    titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 28),
        SectionHeader(
          title: 'Tendência de Demanda',
          actionLabel: 'Ver tudo',
          onAction: () {},
        ),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.fromLTRB(12, 20, 16, 12),
          child: SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.border, strokeWidth: 1),
                  drawVerticalLine: false,
                ),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (v, _) {
                        final labels = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex'];
                        final i = v.toInt();
                        if (i < 0 || i >= labels.length) return const SizedBox();
                        return Text(labels[i], style: const TextStyle(fontSize: 11, color: AppColors.textLow));
                      },
                    ),
                  ),
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
                    gradient: const LinearGradient(
                      colors: [AppColors.neonCyan, AppColors.neonPurple],
                    ),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                        radius: 4,
                        color: AppColors.neonCyan,
                        strokeWidth: 2,
                        strokeColor: AppColors.bgCard,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AppColors.neonCyan.withValues(alpha: 0.25),
                          AppColors.neonPurple.withValues(alpha: 0.05),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 100),
      ],
    );
  }
}
