import 'package:url_launcher/url_launcher.dart';

/// Serviço de relatório financeiro do agente.
/// Envia relatório semanal formatado via WhatsApp usando url_launcher.
class FinancialAgentService {
  FinancialAgentService._();

  /// Número do gestor que recebe o relatório (formato internacional, sem +)
  /// Configure aqui ou via Settings no futuro.
  static const String _managerPhone = '5511900000000';

  /// Abre WhatsApp com o relatório semanal pré-preenchido.
  /// O usuário ainda precisa apertar Enviar — por design,
  /// para que o gestor revise antes de confirmar.
  static Future<void> sendWhatsAppReport(String reportText) async {
    final encoded = Uri.encodeComponent(reportText);
    final waUrl = Uri.parse('https://wa.me/$_managerPhone?text=$encoded');
    final waBusiness =
        Uri.parse('https://wa.me/$_managerPhone?text=$encoded');

    // Tenta WhatsApp Business primeiro, depois WhatsApp normal
    if (await canLaunchUrl(waBusiness)) {
      await launchUrl(waBusiness,
          mode: LaunchMode.externalApplication);
    } else if (await canLaunchUrl(waUrl)) {
      await launchUrl(waUrl, mode: LaunchMode.externalApplication);
    }
  }
}
