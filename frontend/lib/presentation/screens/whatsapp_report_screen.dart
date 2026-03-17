/// WhatsAppReportScreen
/// Gera relatorio financeiro formatado e envia via backend -> Evolution API.
/// NAO usa url_launcher. Toda comunicacao e server-side.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/providers/operational_provider.dart';
import 'package:frontend/core/services/financial_agent_service.dart';
import 'package:frontend/presentation/theme/app_theme.dart';

class WhatsAppReportScreen extends StatefulWidget {
  const WhatsAppReportScreen({super.key});

  @override
  State<WhatsAppReportScreen> createState() => _WhatsAppReportScreenState();
}

class _WhatsAppReportScreenState extends State<WhatsAppReportScreen> {
  bool _sending = false;
  bool _sent = false;
  String _statusMsg = '';
  String _waStatus = '...';

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final s = await FinancialAgentService.checkWhatsAppStatus();
    if (mounted) setState(() => _waStatus = s);
  }

  String _buildReport(OperationalProvider op) {
    final now = DateTime.now();
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final lines = [
      '\u{1F4CA} *Relatorio S.F.C.P.C*',
      'Gerado em: $dateStr',
      '',
      '\u{1F4E6} *Estoque*',
      '- Total de itens: ${op.totalItems}',
      '- Valor total: R\$ ${op.totalStockValue.toStringAsFixed(2)}',
      '- Itens criticos: ${op.lowStockItems.length}',
      '',
    ];

    if (op.lowStockItems.isNotEmpty) {
      lines.add('\u26A0\uFE0F *Itens para reposicao*');
      for (final item in op.lowStockItems.take(5)) {
        lines.add(
            '- ${item.description}: ${item.qty}/${item.minimumStock} ${item.unit}');
      }
      if (op.lowStockItems.length > 5) {
        lines.add('  ...e mais ${op.lowStockItems.length - 5} item(s).');
      }
      lines.add('');
    }

    lines.add('_Agente S.F.C.P.C \u2014 Automatico_');
    return lines.join('\n');
  }

  Future<void> _send() async {
    final op = Provider.of<OperationalProvider>(context, listen: false);
    final report = _buildReport(op);
    setState(() {
      _sending = true;
      _statusMsg = 'Enviando...';
    });
    final ok = await FinancialAgentService.sendWhatsAppReport(report);
    if (mounted) {
      setState(() {
        _sending = false;
        _sent = ok;
        _statusMsg = ok
            ? 'Relatorio enviado com sucesso! \u2714\uFE0F'
            : 'Falha no envio. Verifique a conexao com o servidor.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final op = Provider.of<OperationalProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textHigh = isDark ? AppColors.textHigh : AppColors.lgTextHigh;
    final textLow = isDark ? AppColors.textLow : AppColors.lgTextLow;
    final cardColor = isDark ? AppColors.bgCard : AppColors.lgBgCard;
    final borderColor = isDark ? AppColors.border : AppColors.lgBorder;
    final surfaceColor = isDark ? AppColors.bgSurface : AppColors.lgBgSurface;
    final waConnected = _waStatus == 'open';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatorio via WhatsApp'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Status da instancia
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: waConnected
                        ? AppColors.neonGreen
                        : _waStatus == '...'
                            ? AppColors.neonAmber
                            : AppColors.neonRed,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Evolution API: $_waStatus',
                  style: TextStyle(color: textHigh, fontSize: 13),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.refresh, color: textLow, size: 18),
                  onPressed: _checkStatus,
                  tooltip: 'Verificar conexao',
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Preview do relatorio
          Text('Preview do Relatorio',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: textHigh)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: Text(
              _buildReport(op),
              style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: textLow,
                  height: 1.6),
            ),
          ),

          const SizedBox(height: 24),

          // Status de envio
          if (_statusMsg.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _sent
                    ? AppColors.neonGreen.withValues(alpha: 0.1)
                    : AppColors.neonRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: _sent
                        ? AppColors.neonGreen.withValues(alpha: 0.4)
                        : AppColors.neonRed.withValues(alpha: 0.4)),
              ),
              child: Text(_statusMsg,
                  style: TextStyle(
                      color: _sent ? AppColors.neonGreen : AppColors.neonRed,
                      fontWeight: FontWeight.w600)),
            ),

          // Botao enviar
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _sending ? null : _send,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.whatsapp),
              label: Text(
                _sending ? 'Enviando...' : 'Enviar para Gestor',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
