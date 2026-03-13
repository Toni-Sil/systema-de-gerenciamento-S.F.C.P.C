// Sprint 2 — WhatsApp Nativo + Compartilhamento de Relatório
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/section_header.dart';

class WhatsAppReportScreen extends StatefulWidget {
  const WhatsAppReportScreen({super.key});

  @override
  State<WhatsAppReportScreen> createState() => _WhatsAppReportScreenState();
}

class _WhatsAppReportScreenState extends State<WhatsAppReportScreen> {
  final _phoneCtrl = TextEditingController();
  bool _sending = false;

  // Mensagem padrão de relatório
  String _buildReport() {
    final now = DateTime.now();
    return '''
*📦 Relatório S.F.C.P.C*
_${now.day}/${now.month}/${now.year} ${now.hour}:${now.minute.toString().padLeft(2, '0')}_

*Resumo do Estoque:*
• Total de Itens: 248
• Capital Empatado: R\$ 125.4K
• Rupturas Evitadas Hoje: 3
• Giro Médio: 4.2x

*⚠️ Itens em Reposição Urgente:*
• TEC-001 Tecido Floral — 2m restantes
• ESP-012 Espuma D33 — 1 peça

_Gerado automaticamente pelo S.F.C.P.C AI_ 🤖
    '''.trim();
  }

  Future<void> _sendWhatsApp() async {
    final phone = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    final msg = Uri.encodeComponent(_buildReport());
    final url = phone.isNotEmpty
        ? 'https://wa.me/55$phone?text=$msg'
        : 'https://wa.me/?text=$msg';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('WhatsApp não encontrado no dispositivo.')),
        );
      }
    }
  }

  Future<void> _generateAndSharePdf() async {
    setState(() => _sending = true);
    try {
      final pdf = pw.Document();
      final now = DateTime.now();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Relatório de Estoque — S.F.C.P.C',
                  style: pw.TextStyle(
                      fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text(
                  '${now.day}/${now.month}/${now.year}  ${now.hour}:${now.minute.toString().padLeft(2, '0')}',
                  style: const pw.TextStyle(
                      fontSize: 11, color: PdfColors.grey600)),
              pw.Divider(height: 24),
              _pdfRow('Total de Itens', '248'),
              _pdfRow('Capital Empatado', 'R\$ 125.400,00'),
              _pdfRow('Giro Médio (30d)', '4.2x'),
              _pdfRow('Rupturas Evitadas', '3 hoje'),
              pw.SizedBox(height: 24),
              pw.Text('Itens em Reposição Urgente',
                  style: pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              _pdfRow('TEC-001 Tecido Floral', '2m restantes — URGENTE'),
              _pdfRow('ESP-012 Espuma D33', '1 peça restante — URGENTE'),
              pw.Spacer(),
              pw.Divider(),
              pw.Text('Gerado por S.F.C.P.C AI',
                  style: const pw.TextStyle(
                      fontSize: 9, color: PdfColors.grey500)),
            ],
          ),
        ),
      );

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/relatorio_sfcpc_${now.millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Relatório S.F.C.P.C — ${now.day}/${now.month}/${now.year}',
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  pw.Widget _pdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 12)),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 12, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        title: const Text('WhatsApp & Relatórios'),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Preview do relatório
          const SectionHeader(title: 'Preview do Relatório', showLive: true),
          const SizedBox(height: 12),
          GlassCard(
            borderColor: const Color(0xFF25D366).withValues(alpha: 0.4),
            child: Text(
              _buildReport(),
              style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: AppColors.textMed,
                  height: 1.5),
            ),
          ),

          const SizedBox(height: 24),
          const SectionHeader(title: 'Enviar via WhatsApp'),
          const SizedBox(height: 12),
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Telefone (opcional — deixe em branco para escolher)',
              prefixIcon: Icon(Icons.phone, color: Color(0xFF25D366)),
              hintText: '11987654321',
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _sendWhatsApp,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            icon: const Icon(Icons.whatsapp),
            label: const Text('Enviar pelo WhatsApp',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),

          const SizedBox(height: 24),
          const SectionHeader(title: 'Exportar PDF'),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _sending ? null : _generateAndSharePdf,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.neonPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.picture_as_pdf),
            label: Text(_sending ? 'Gerando PDF...' : 'Exportar e Compartilhar PDF',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ],
      ),
    );
  }
}
