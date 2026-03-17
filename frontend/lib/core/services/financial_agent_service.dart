import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Servico de relatorio financeiro do agente.
/// Envia relatorio semanal formatado via backend -> Evolution API -> WhatsApp.
/// O envio e 100% automatico, sem interacao do usuario.
class FinancialAgentService {
  FinancialAgentService._();

  static const _baseUrlKey = 'api_base_url';
  static const _defaultBase = 'https://localhost:8000';
  static const _tokenKey = 'auth_token';

  static Future<String> _baseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(_baseUrlKey) ?? _defaultBase;
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  static Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  /// Envia o relatorio para o backend que repassa via Evolution API.
  /// Retorna true se bem-sucedido.
  static Future<bool> sendWhatsAppReport(
    String reportText, {
    String? jid, // opcional: numero especifico. Padrao: WHATSAPP_MANAGER_JID do .env
  }) async {
    try {
      final base = await _baseUrl();
      final token = await _token();
      final resp = await http
          .post(
            Uri.parse('$base/whatsapp/send-report'),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'report_text': reportText,
              if (jid != null) 'jid': jid,
            }),
          )
          .timeout(const Duration(seconds: 20));

      return resp.statusCode == 200 || resp.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  /// Verifica se a instancia WhatsApp esta conectada.
  static Future<String> checkWhatsAppStatus() async {
    try {
      final base = await _baseUrl();
      final resp = await http
          .get(
            Uri.parse('$base/whatsapp/status'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return data['state'] as String? ??
            data['status'] as String? ??
            'unknown';
      }
      return 'error';
    } catch (_) {
      return 'offline';
    }
  }
}
