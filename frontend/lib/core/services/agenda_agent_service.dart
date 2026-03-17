import '../models/agenda_event.dart';
import 'api_service.dart';

/// Agente IA especializado em agenda — interpreta intenções e sugere/cria eventos
class AgendaAgentService {
  static Future<AgendaAgentResponse> processMessage({
    required String userMessage,
    required List<AgendaEvent> currentEvents,
  }) async {
    // Tenta enviar para o backend IA
    try {
      final res = await ApiService.instance.post(
        '/api/v1/agenda/agent',
        body: {
          'message': userMessage,
          'events': currentEvents.map((e) => e.toJson()).toList(),
        },
      );
      return AgendaAgentResponse(
        message: res['message'] ?? 'Compromisso criado!',
        suggestedEvent: res['event'] != null
            ? AgendaEvent.fromJson(res['event'])
            : null,
        action: res['action'] ?? 'none',
      );
    } catch (_) {
      // Fallback offline: interpreta localmente
      return _offlineFallback(userMessage, currentEvents);
    }
  }

  static AgendaAgentResponse _offlineFallback(
      String msg, List<AgendaEvent> events) {
    final lower = msg.toLowerCase();

    // Listar eventos de hoje
    if (lower.contains('hoje') &&
        (lower.contains('lista') ||
            lower.contains('tem') ||
            lower.contains('quais') ||
            lower.contains('agenda'))) {
      final today = events.where((e) => e.isToday).toList()
        ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
      if (today.isEmpty) {
        return AgendaAgentResponse(
          message: 'Você não tem compromissos hoje. Agenda livre! 🎉',
          action: 'list',
        );
      }
      final list = today.map((e) => '• ${e.timeLabel} — ${e.title}').join('\n');
      return AgendaAgentResponse(
        message: 'Sua agenda hoje:\n$list',
        action: 'list',
      );
    }

    // Próximo compromisso
    if (lower.contains('próximo') || lower.contains('proximo')) {
      final upcoming = events
          .where((e) =>
              e.dateTime.isAfter(DateTime.now()) &&
              e.status == EventStatus.pending)
          .toList()
        ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
      if (upcoming.isEmpty) {
        return AgendaAgentResponse(
          message: 'Não há compromissos futuros agendados.',
          action: 'list',
        );
      }
      final next = upcoming.first;
      return AgendaAgentResponse(
        message:
            'Seu próximo compromisso: **${next.title}** em ${next.dateLabel} às ${next.timeLabel}.',
        action: 'list',
      );
    }

    // Criar evento por texto
    if (lower.contains('agendar') ||
        lower.contains('marcar') ||
        lower.contains('criar') ||
        lower.contains('adicionar') ||
        lower.contains('lembra')) {
      final parsed = _parseTextEvent(msg);
      return AgendaAgentResponse(
        message:
            'Entendido! Vou agendar: **${parsed.title}** para ${parsed.dateLabel} às ${parsed.timeLabel}. Confirma?',
        suggestedEvent: parsed,
        action: 'create',
      );
    }

    return AgendaAgentResponse(
      message:
          'Posso ajudar com sua agenda! Tente: \"Quais compromissos tenho hoje?\", \"Agendar reunião amanhã às 14h\" ou \"Qual é meu próximo compromisso?\"',
      action: 'help',
    );
  }

  static AgendaEvent _parseTextEvent(String text) {
    final now = DateTime.now();
    final lower = text.toLowerCase();
    DateTime dateTime = now.add(const Duration(hours: 1));

    if (lower.contains('amanhã') || lower.contains('amanha')) {
      dateTime = DateTime(now.year, now.month, now.day + 1, 9, 0);
    }

    final timeMatch =
        RegExp(r'(\d{1,2})(?:h|:)(\d{0,2})').firstMatch(lower);
    if (timeMatch != null) {
      final h = int.tryParse(timeMatch.group(1) ?? '9') ?? 9;
      final m = int.tryParse(timeMatch.group(2) ?? '0') ?? 0;
      dateTime = DateTime(dateTime.year, dateTime.month, dateTime.day, h, m);
    }

    String title = text
        .replaceAll(RegExp(r'agendar|marcar|criar|adicionar|lembra',
            caseSensitive: false),
            '')
        .replaceAll(RegExp(r'amanhã|amanha|hoje', caseSensitive: false), '')
        .replaceAll(RegExp(r'\d{1,2}(?:h|:)\d{0,2}'), '')
        .replaceAll(RegExp(r'às|as|horas|hora'), '')
        .trim();
    if (title.isEmpty) title = text.trim();

    return AgendaEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title[0].toUpperCase() + title.substring(1),
      dateTime: dateTime,
      priority: EventPriority.medium,
      createdBy: 'agent',
    );
  }
}

class AgendaAgentResponse {
  final String message;
  final AgendaEvent? suggestedEvent;
  final String action;

  AgendaAgentResponse({
    required this.message,
    this.suggestedEvent,
    required this.action,
  });
}
