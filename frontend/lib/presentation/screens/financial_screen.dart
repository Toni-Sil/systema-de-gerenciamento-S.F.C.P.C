// FinancialScreen v3 — _subKpi usa textLow real do contexto + formatação pt-BR
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
  final List<double> _expensesData  = [1200, 1800, 1400, 2300, 1900, 2100];
  final List<String> _months        = ['Out', 'Nov', 'Dez', 'Jan', 'Fev', 'Mar'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final summary = await ApiService.instance.getFinancialSummary();
      final txs     = await ApiService.instance.getTransactions(period: _period);
      if (mounted) {
        setState(() {
          _summary      = summary;
          _transactions = txs.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          _loading      = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _summary = {
            'roi':      23450.0,
            'revenue':  28300.0,
            'expenses':  4850.0,
          };
          _transactions = [
            {
              'date':        'Há 10 min',
              'title':       'Registro OCR Automático',
              'category':    'Matéria-Prima',
              'description': 'Compra: Tecidos Finos LTDA',
              'value':       -2300.0,
              'status':      'Pago',
            },
            {
              'date':        'Ontem',
              'title':       'Venda Orquestrada IA',
              'category':    'Vendas',
              'description': '2× Sofá-Cama Retrátil Premium',
              'value':       5500.0,
              'status':      'Recebido',
            },
            {
              'date':        '10 de Mar',
              'title':       'Custo Evitado (IA)',
              'category':    'Logística',
              'description': 'Ruptura de Espuma D28 Prevenida',
              'value':       850.0,
              'status':      'Economia',
            },
          ];
          _loading = false;
        });
      }
    }
  }

  double get _roi      => (_summary['roi']      as num? ?? 0).toDouble();
  double get _revenue  => (_summary['revenue']  as num? ?? 0).toDouble();
  double get _expenses => (_summary['expenses'] as num? ?? 0).toDouble();

  /// Formata valor em pt-BR com prefixo R$
  String _fmtBR(double v) =>
      'R\$ ${v.toStringAsFixed(2).replaceAll('.', ',').replaceAllMapped(
            RegExp(r'(\d)(?=(\d{3})+,)'),
            (m) => '${m[1]}.',
          )}';

  String _fmtK(double v) {
    final k = v / 1000;
    return k >= 10
        ? 'R\$ ${k.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+\b)'), (m) => '${m[1]}.')}K'
        : 'R\$ ${k.toStringAsFixed(1).replaceAll(".", ",")}K';
  }

  @override
  Widget build(BuildContext context) {
    final op      = Provider.of<OperationalProvider>(context, listen: false);
    final isDark  = Theme.of(context).brightness == Brightness.dark;

    // ── Tokens canônicos ──────────────────────────────────────────────
    final cardColor   = isDark ? AppColors.bgCard      : AppColors.lgBgCard;
    final borderColor = isDark ? AppColors.border      : AppColors.lgBorder;
    final textHigh    = isDark ? AppColors.textHigh    : AppColors.lgTextHigh;
    final textLow     = isDark ? AppColors.textLow     : AppColors.lgTextLow;
    final textMed     = isDark ? AppColors.textMed     : AppColors.lgTextMed;
    final surfaceColor= isDark ? AppColors.bgSurface   : AppColors.lgBgSurface;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.neonCyan))
          : RefreshIndicator(
              color: AppColors.neonCyan,
              onRefresh: _loadData,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                    16, 12, 16, MediaQuery.of(context).padding.bottom + 100),
                children: [
                  // ── Card ROI ───────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(20),
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
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final compact = constraints.maxWidth < 380;
                            final exportButton = GestureDetector(
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const WhatsAppReportScreen())),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: compact ? 8 : 10,
                                    vertical: compact ? 4 : 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF25D366)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: const Color(0xFF25D366)
                                          .withValues(alpha: 0.4)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.share,
                                        color: Color(0xFF25D366), size: 14),
                                    const SizedBox(width: 5),
                                    Text('Exportar',
                                        style: TextStyle(
                                            color: const Color(0xFF25D366),
                                            fontSize: compact ? 10 : 11,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            );

                            return Flex(
                              direction:
                                  compact ? Axis.vertical : Axis.horizontal,
                              crossAxisAlignment: compact
                                  ? CrossAxisAlignment.start
                                  : CrossAxisAlignment.center,
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    'ROI Consolidado do Agente',
                                    style: TextStyle(
                                        color: textLow, fontSize: 13),
                                  ),
                                ),
                                SizedBox(
                                    height: compact ? 10 : 0,
                                    width: compact ? 0 : 12),
                                exportButton,
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        // ── Valor ROI formatado pt-BR ──────────────────
                        Text(
                          _fmtBR(_roi),
                          style: TextStyle(
                              color: textHigh,
                              fontSize: 30,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Atualizado: período de $_period',
                          style: TextStyle(color: textLow, fontSize: 11),
                        ),
                        const SizedBox(height: 16),
                        // ── Sub-KPIs — textLow real passado como parâmetro ──
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final compact = constraints.maxWidth < 360;
                            final children = [
                              _subKpi(
                                  'Receitas + Econ.',
                                  _fmtK(_revenue),
                                  AppColors.neonGreen,
                                  textLow),
                              _subKpi(
                                  'Custos Reg.',
                                  _fmtK(_expenses),
                                  AppColors.neonRed,
                                  textLow),
                              _subKpi(
                                  'Cap. Estoque',
                                  _fmtK(op.totalStockValue),
                                  AppColors.neonAmber,
                                  textLow),
                            ];

                            if (compact) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: children
                                    .map((child) => Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 10),
                                          child: child,
                                        ))
                                    .toList(),
                              );
                            }

                            return Row(
                              children: children
                                  .map((child) => Expanded(child: child))
                                  .toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Selector de período ────────────────────────────
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 10,
                    children: [
                      Text('Gráfico Financeiro',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: textHigh)),
                      Wrap(
                        spacing: 6,
                        children: [
                          ('7d', '7D'),
                          ('30d', '30D'),
                          ('90d', '3M')
                        ].map((p) => GestureDetector(
                            onTap: () {
                              setState(() => _period = p.$1);
                              _loadData();
                            },
                            child: Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _period == p.$1
                                    ? AppColors.neonCyan
                                        .withValues(alpha: 0.2)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
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
                                      fontWeight: FontWeight.bold)),
                            ),
                          )).toList(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── Gráfico ────────────────────────────────────────
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
                            _legend(
                                AppColors.neonGreen, 'Receitas', textLow),
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
                                    sideTitles:
                                        SideTitles(showTitles: false)),
                                topTitles: const AxisTitles(
                                    sideTitles:
                                        SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(
                                    sideTitles:
                                        SideTitles(showTitles: false)),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 22,
                                    getTitlesWidget: (v, _) {
                                      final i = v.toInt();
                                      if (i < 0 || i >= _months.length) {
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

                  // ── Timeline de transações ─────────────────────────
                  Text('Linha do Tempo',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: textHigh)),
                  const SizedBox(height: 12),
                  ..._transactions.asMap().entries.map(
                        (e) => _txRow(
                          e.value,
                          isLast: e.key == _transactions.length - 1,
                          textHigh: textHigh,
                          textMed: textMed,
                          textLow: textLow,
                          surfaceColor: surfaceColor,
                          borderColor: borderColor,
                        ),
                      ),
                ],
              ),
            ),
    );
  }

  /// Sub-KPI dentro do card de ROI — recebe textLow real do contexto
  Widget _subKpi(
      String label, String value, Color accentColor, Color labelColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(color: labelColor, fontSize: 10),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 3),
        Text(value,
            style: TextStyle(
                color: accentColor,
                fontSize: 13,
                fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _legend(Color color, String label, Color textColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 14,
            height: 3,
            decoration:
                BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 11, color: textColor)),
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
    final value     = (t['value'] as num? ?? 0).toDouble();
    final isExpense = value < 0;
    final color     = isExpense ? AppColors.neonRed : AppColors.neonGreen;

    // Formata valor pt-BR com sinal
    final valueStr = '${value >= 0 ? "+" : ""}R\$ '
        '${value.abs().toStringAsFixed(2).replaceAll(".", ",").replaceAllMapped(RegExp(r"(\d)(?=(\d{3})+,)"), (m) => "${m[1]}.")}';

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
                    Expanded(
                      child: Text(
                        t['title'] as String? ?? '',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: textHigh),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(t['date'] as String? ?? '',
                        style: TextStyle(color: textLow, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 3),
                Text(t['description'] as String? ?? '',
                    style: TextStyle(color: textMed, fontSize: 12)),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(valueStr,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: color)),
                    Row(
                      mainAxisSize: MainAxisSize.min,
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
