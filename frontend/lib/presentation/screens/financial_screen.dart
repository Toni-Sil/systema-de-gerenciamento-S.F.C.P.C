// v2: light mode adaptativo + _expensesData renomeado + extendBody padding
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/services/api_service.dart';
import 'package:frontend/core/providers/operational_provider.dart';
import 'package:frontend/presentation/theme/app_theme.dart';
import 'package:frontend/presentation/screens/whatsapp_report_screen.dart';

class FinancialScreen extends StatefulWidget {
  const FinancialScreen({super.key});

  @override
  State<FinancialScreen> createState() => _FinancialScreenState();
}

class _FinancialScreenState extends State<FinancialScreen> {
  bool _loading = true;
  String _period = '30d';
  Map<String, dynamic> _summary = {};
  List<Map<String, dynamic>> _transactions = [];

  final List<double> _revenuesData = [3200, 4100, 3800, 5500, 4900, 6200];
  final List<double> _expensesData = [1200, 1800, 1400, 2300, 1900, 2100];
  final List<String> _months = ['Out', 'Nov', 'Dez', 'Jan', 'Fev', 'Mar'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final summary = await ApiService.instance.getFinancialSummary();
      final txs =
          await ApiService.instance.getTransactions(period: _period);
      if (mounted) {
        setState(() {
          _summary = summary;
          _transactions = txs
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _summary = {
            'roi': 23450.0,
            'revenue': 28300.0,
            'expenses': 4850.0,
          };
          _transactions = [
            {
              'date': 'Ha 10 min',
              'title': 'Registro OCR Automatico',
              'category': 'Materia Prima',
              'description': 'Compra: Tecidos Finos LTDA',
              'value': -2300.0,
              'status': 'Pago',
            },
            {
              'date': 'Ontem',
              'title': 'Venda Orquestrada IA',
              'category': 'Vendas',
              'description': '2x Sofa-Cama Retratil Premium',
              'value': 5500.0,
              'status': 'Recebido',
            },
            {
              'date': '10 de Mar',
              'title': 'Custo Evitado (IA)',
              'category': 'Logistica',
              'description': 'Ruptura de Espuma D28 Prevenida',
              'value': 850.0,
              'status': 'Economia',
            },
          ];
          _loading = false;
        });
      }
    }
  }

  double get _roi => (_summary['roi'] as num? ?? 0).toDouble();
  double get _revenue => (_summary['revenue'] as num? ?? 0).toDouble();
  double get _expenses => (_summary['expenses'] as num? ?? 0).toDouble();

  @override
  Widget build(BuildContext context) {
    final op = Provider.of<OperationalProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.bgCard : AppColors.lgBgCard;
    final borderColor = isDark ? AppColors.border : AppColors.lgBorder;
    final textHigh = isDark ? AppColors.textHigh : AppColors.lgTextHigh;
    final textLow = isDark ? AppColors.textLow : AppColors.lgTextLow;
    final textMed = isDark ? AppColors.textMed : AppColors.lgTextMed;
    final surfaceColor = isDark ? AppColors.bgSurface : AppColors.lgBgSurface;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.neonCyan))
          : RefreshIndicator(
              color: AppColors.neonCyan,
              onRefresh: _loadData,
              child: ListView(
                // padding bottom adaptativo para nao ficar atras da GlassNavBar
                padding: EdgeInsets.fromLTRB(
                    16, 12, 16, MediaQuery.of(context).padding.bottom + 80),
                children: [
                  // ─ Card ROI
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.neonCyan
                              .withValues(alpha: isDark ? 0.25 : 0.12),
                          AppColors.neonPurple
                              .withValues(alpha: isDark ? 0.15 : 0.07),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: AppColors.neonCyan.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text('ROI Consolidado do Agente',
                                style: TextStyle(
                                    color: textLow, fontSize: 13)),
                            GestureDetector(
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const WhatsAppReportScreen())),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF25D366)
                                      .withValues(alpha: 0.15),
                                  borderRadius:
                                      BorderRadius.circular(20),
                                  border: Border.all(
                                      color: const Color(0xFF25D366)
                                          .withValues(alpha: 0.4)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.share,
                                        color: Color(0xFF25D366),
                                        size: 14),
                                    SizedBox(width: 5),
                                    Text('Exportar',
                                        style: TextStyle(
                                            color: Color(0xFF25D366),
                                            fontSize: 11,
                                            fontWeight:
                                                FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'R\$ ${_roi.toStringAsFixed(2).replaceAll('.', ',')}',
                          style: TextStyle(
                              color: textHigh,
                              fontSize: 32,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            _subKpi('Receitas + Economia',
                                'R\$ ${(_revenue / 1000).toStringAsFixed(1)}K',
                                AppColors.neonGreen),
                            _subKpi('Custos Registrados',
                                'R\$ ${(_expenses / 1000).toStringAsFixed(1)}K',
                                AppColors.neonRed),
                            _subKpi('Capital Estoque',
                                'R\$ ${(op.totalStockValue / 1000).toStringAsFixed(1)}K',
                                AppColors.neonAmber),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ─ Selector de periodo
                  Row(
                    children: [
                      Text('Grafico Financeiro',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: textHigh)),
                      const Spacer(),
                      ...[('7d', '7D'), ('30d', '30D'), ('90d', '3M')]
                          .map((p) => GestureDetector(
                                onTap: () {
                                  setState(() => _period = p.$1);
                                  _loadData();
                                },
                                child: Container(
                                  margin:
                                      const EdgeInsets.only(left: 6),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _period == p.$1
                                        ? AppColors.neonCyan
                                            .withValues(alpha: 0.2)
                                        : Colors.transparent,
                                    borderRadius:
                                        BorderRadius.circular(20),
                                    border: Border.all(
                                        color: _period == p.$1
                                            ? AppColors.neonCyan
                                            : borderColor),
                                  ),
                                  child: Text(p.$2,
                                      style: TextStyle(
                                          color: _period == p.$1
                                              ? AppColors.neonCyan
                                              : textLow,
                                          fontSize: 11,
                                          fontWeight:
                                              FontWeight.bold)),
                                ),
                              )),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ─ Grafico
                  Container(
                    padding: const EdgeInsets.fromLTRB(8, 20, 16, 12),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _legend(AppColors.neonGreen, 'Receitas',
                                textLow),
                            const SizedBox(width: 20),
                            _legend(
                                AppColors.neonRed, 'Despesas', textLow),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 180,
                          child: LineChart(
                            LineChartData(
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                getDrawingHorizontalLine: (_) => FlLine(
                                    color: borderColor, strokeWidth: 1),
                              ),
                              titlesData: FlTitlesData(
                                leftTitles: const AxisTitles(
                                    sideTitles: SideTitles(
                                        showTitles: false)),
                                topTitles: const AxisTitles(
                                    sideTitles: SideTitles(
                                        showTitles: false)),
                                rightTitles: const AxisTitles(
                                    sideTitles: SideTitles(
                                        showTitles: false)),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 22,
                                    getTitlesWidget: (v, _) {
                                      final i = v.toInt();
                                      if (i < 0 ||
                                          i >= _months.length) {
                                        return const SizedBox();
                                      }
                                      return Text(_months[i],
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: textLow));
                                    },
                                  ),
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: _revenuesData
                                      .asMap()
                                      .entries
                                      .map((e) => FlSpot(
                                          e.key.toDouble(), e.value))
                                      .toList(),
                                  isCurved: true,
                                  color: AppColors.neonGreen,
                                  barWidth: 3,
                                  dotData:
                                      const FlDotData(show: false),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    color: AppColors.neonGreen
                                        .withValues(alpha: 0.08),
                                  ),
                                ),
                                LineChartBarData(
                                  spots: _expensesData
                                      .asMap()
                                      .entries
                                      .map((e) => FlSpot(
                                          e.key.toDouble(), e.value))
                                      .toList(),
                                  isCurved: true,
                                  color: AppColors.neonRed,
                                  barWidth: 2,
                                  dashArray: [5, 4],
                                  dotData:
                                      const FlDotData(show: false),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ─ Timeline de transacoes
                  Text('Linha do Tempo',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textHigh)),
                  const SizedBox(height: 12),
                  ..._transactions.asMap().entries.map(
                        (e) => _txRow(e.value,
                            isLast: e.key == _transactions.length - 1,
                            textHigh: textHigh,
                            textMed: textMed,
                            textLow: textLow,
                            surfaceColor: surfaceColor,
                            borderColor: borderColor),
                      ),
                ],
              ),
            ),
    );
  }

  Widget _subKpi(String label, String value, Color color) {
    final isDark = true; // fallback; core cor sempre via accent
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textLow, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _legend(Color color, String label, Color textColor) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 3,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(fontSize: 11, color: textColor)),
      ],
    );
  }

  Widget _txRow(
    Map<String, dynamic> t, {
    required bool isLast,
    required Color textHigh,
    required Color textMed,
    required Color textLow,
    required Color surfaceColor,
    required Color borderColor,
  }) {
    final value = (t['value'] as num? ?? 0).toDouble();
    final isExpense = value < 0;
    final color = isExpense ? AppColors.neonRed : AppColors.neonGreen;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.only(top: 4),
              decoration:
                  BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            if (!isLast)
              Container(width: 2, height: 64, color: borderColor),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(t['title'] as String? ?? '',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: textHigh)),
                    Text(t['date'] as String? ?? '',
                        style:
                            TextStyle(color: textLow, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 3),
                Text(t['description'] as String? ?? '',
                    style: TextStyle(color: textMed, fontSize: 12)),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${value >= 0 ? '+' : ''}R\$ ${value.abs().toStringAsFixed(2).replaceAll('.', ',')}',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: color),
                    ),
                    Row(
                      children: [
                        _badge(
                            t['category'] as String? ?? '',
                            surfaceColor,
                            textLow),
                        const SizedBox(width: 6),
                        _badge(
                            t['status'] as String? ?? '',
                            color.withValues(alpha: 0.1),
                            color),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _badge(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(text,
          style: TextStyle(
              color: fg, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
