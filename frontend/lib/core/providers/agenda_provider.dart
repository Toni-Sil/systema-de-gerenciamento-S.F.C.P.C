import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/agenda_event.dart';
import '../services/notification_service.dart';
import '../utils/uid.dart';

class AgendaProvider extends ChangeNotifier {
  List<AgendaEvent> _events = [];
  DateTime _selectedDay = DateTime.now();
  bool _isLoading = false;
  String? _lastVoiceResult;

  List<AgendaEvent> get events => List.unmodifiable(_events);
  DateTime get selectedDay => _selectedDay;
  bool get isLoading => _isLoading;
  String? get lastVoiceResult => _lastVoiceResult;

  List<AgendaEvent> get todayEvents {
    final now = DateTime.now();
    return _events
        .where((e) =>
            e.dateTime.year == now.year &&
            e.dateTime.month == now.month &&
            e.dateTime.day == now.day &&
            e.status != EventStatus.cancelado)
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  List<AgendaEvent> get selectedDayEvents {
    return _events
        .where((e) =>
            e.dateTime.year == _selectedDay.year &&
            e.dateTime.month == _selectedDay.month &&
            e.dateTime.day == _selectedDay.day &&
            e.status != EventStatus.cancelado)
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  List<AgendaEvent> get upcomingEvents {
    final now = DateTime.now();
    return _events
        .where((e) =>
            e.dateTime.isAfter(now) && e.status == EventStatus.pendente)
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  int get todayCount => todayEvents.length;
  int get urgentCount => todayEvents.where((e) => e.isUrgent).length;

  // NOVO: eventos financeiros vencendo em até 3 dias
  List<AgendaEvent> get dueSoonEvents =>
      _events.where((e) => e.isDueSoon).toList()
        ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

  int get dueSoonCount => dueSoonEvents.length;

  // NOVO: total de valores financeiros vencendo em breve
  double get dueSoonTotalAmount => dueSoonEvents.fold(
        0.0,
        (sum, e) => sum + (e.financialAmount ?? 0.0),
      );

  Future<void> init() async {
    await _loadFromPrefs();
    await NotificationService.instance.init();
    await _rescheduleAllNotifications();
    // Agenda notificações de vencimento financeiro ao inicializar
    await _scheduleFinancialDueAlerts();
  }

  void setSelectedDay(DateTime day) {
    _selectedDay = day;
    notifyListeners();
  }

  Future<void> addEvent(AgendaEvent event) async {
    _events.add(event);
    _events.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    await _saveToPrefs();
    if (event.notifyBefore) {
      await NotificationService.instance.scheduleEventNotification(event);
    }
    // Se for evento financeiro, agenda também alerta de vencimento
    if (event.category == EventCategory.financeiro) {
      await _scheduleFinancialDueAlert(event);
    }
    notifyListeners();
  }

  Future<void> updateEvent(AgendaEvent updated) async {
    final idx = _events.indexWhere((e) => e.id == updated.id);
    if (idx == -1) return;
    await NotificationService.instance.cancelNotification(updated.id);
    _events[idx] = updated;
    _events.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    await _saveToPrefs();
    if (updated.notifyBefore) {
      await NotificationService.instance.scheduleEventNotification(updated);
    }
    if (updated.category == EventCategory.financeiro) {
      await _scheduleFinancialDueAlert(updated);
    }
    notifyListeners();
  }

  Future<void> deleteEvent(String id) async {
    await NotificationService.instance.cancelNotification(id);
    _events.removeWhere((e) => e.id == id);
    await _saveToPrefs();
    notifyListeners();
  }

  Future<void> markCompleted(String id) async {
    final idx = _events.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    _events[idx] = _events[idx].copyWith(status: EventStatus.concluido);
    await _saveToPrefs();
    notifyListeners();
  }

  Future<String> processVoiceCommand(String transcript) async {
    _isLoading = true;
    notifyListeners();
    try {
      final trimmed = transcript.trim();
      if (trimmed.length < 3) {
        _lastVoiceResult =
            'Não entendi. Tente: "Reunião com fornecedor amanhã às 14h"';
      } else {
        final event = _parseVoiceTranscript(trimmed);
        if (event != null) {
          await addEvent(event);
          _lastVoiceResult =
              '✅ Agendado: "${event.title}" para ${event.formattedDate} às ${event.formattedTime}';
        } else {
          _lastVoiceResult =
              'Não consegui identificar o evento. Tente incluir uma hora ou data.';
        }
      }
    } catch (e, st) {
      debugPrint('[AgendaProvider] processVoiceCommand error: $e\n$st');
      _lastVoiceResult = 'Erro interno ao processar comando.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return _lastVoiceResult!;
  }

  AgendaEvent? _parseVoiceTranscript(String text) {
    final lower = text.toLowerCase();
    int hour = 9;
    int minute = 0;
    final now = DateTime.now();
    DateTime eventDate;

    final hourRegex =
        RegExp(r'(\d{1,2})h(oras?)?\s*(\d{2})?|(\d{1,2}):(\d{2})');
    final hourMatch = hourRegex.firstMatch(lower);
    if (hourMatch != null) {
      if (hourMatch.group(4) != null) {
        hour = int.tryParse(hourMatch.group(4)!) ?? 9;
        minute = int.tryParse(hourMatch.group(5) ?? '0') ?? 0;
      } else {
        hour = int.tryParse(hourMatch.group(1)!) ?? 9;
        minute = int.tryParse(hourMatch.group(3) ?? '0') ?? 0;
      }
      hour = hour.clamp(0, 23);
      minute = minute.clamp(0, 59);
    }

    if (lower.contains('hoje')) {
      eventDate = DateTime(now.year, now.month, now.day, hour, minute);
    } else if (lower.contains('amanhã') || lower.contains('amanha')) {
      final t = now.add(const Duration(days: 1));
      eventDate = DateTime(t.year, t.month, t.day, hour, minute);
    } else if (lower.contains('segunda')) {
      eventDate = _nextWeekday(DateTime.monday, hour, minute);
    } else if (lower.contains('terça') || lower.contains('terca')) {
      eventDate = _nextWeekday(DateTime.tuesday, hour, minute);
    } else if (lower.contains('quarta')) {
      eventDate = _nextWeekday(DateTime.wednesday, hour, minute);
    } else if (lower.contains('quinta')) {
      eventDate = _nextWeekday(DateTime.thursday, hour, minute);
    } else if (lower.contains('sexta')) {
      eventDate = _nextWeekday(DateTime.friday, hour, minute);
    } else if (lower.contains('sábado') || lower.contains('sabado')) {
      eventDate = _nextWeekday(DateTime.saturday, hour, minute);
    } else if (lower.contains('domingo')) {
      eventDate = _nextWeekday(DateTime.sunday, hour, minute);
    } else {
      eventDate = DateTime(now.year, now.month, now.day, hour, minute);
    }

    EventCategory category = EventCategory.outro;
    EventPriority priority = EventPriority.normal;

    if (lower.contains('reunião') || lower.contains('reuniao')) {
      category = EventCategory.reuniao;
    } else if (lower.contains('entrega')) {
      category = EventCategory.entrega;
    } else if (lower.contains('reposição') ||
        lower.contains('reposit') ||
        lower.contains('estoque') ||
        lower.contains('repor')) {
      category = EventCategory.reposicao;
    } else if (lower.contains('pagamento') ||
        lower.contains('financeiro') ||
        lower.contains('boleto') ||
        lower.contains('fatura')) {
      category = EventCategory.financeiro;
      priority = EventPriority.alta;
    } else if (lower.contains('pessoal') || lower.contains('particular')) {
      category = EventCategory.pessoal;
    }

    if (lower.contains('urgente') || lower.contains('importante')) {
      priority = EventPriority.urgente;
    }

    String title = text
        .replaceAll(
          RegExp(
            r'(hoje|amanh[aã]|segunda(-feira)?|ter[cç]a(-feira)?|quarta(-feira)?|quinta(-feira)?|sexta(-feira)?|s[áa]bado|domingo|\d{1,2}h(oras?)?(\s*\d{2})?|\d{1,2}:\d{2}|urgente|importante)',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();

    if (title.length < 3) return null;
    title = title[0].toUpperCase() + title.substring(1);

    // Tenta extrair valor financeiro do transcript (ex: "R$ 350,00" ou "350 reais")
    double? extractedAmount;
    final moneyRegex = RegExp(
        r'R\$\s*([\d.,]+)|([\d.,]+)\s*reais',
        caseSensitive: false);
    final moneyMatch = moneyRegex.firstMatch(lower);
    if (moneyMatch != null) {
      final raw =
          (moneyMatch.group(1) ?? moneyMatch.group(2) ?? '')
              .replaceAll('.', '')
              .replaceAll(',', '.');
      extractedAmount = double.tryParse(raw);
    }

    return AgendaEvent(
      id: Uid.generate(),
      title: title,
      dateTime: eventDate,
      category: category,
      priority: priority,
      isVoiceCreated: true,
      notifyBefore: true,
      notifyMinutes: 30,
      financialAmount: extractedAmount,
    );
  }

  DateTime _nextWeekday(int weekday, int hour, int minute) {
    var date = DateTime.now().add(const Duration(days: 1));
    while (date.weekday != weekday) {
      date = date.add(const Duration(days: 1));
    }
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  Future<void> _rescheduleAllNotifications() async {
    for (final event in _events) {
      if (event.notifyBefore &&
          event.status == EventStatus.pendente &&
          !event.isPast) {
        try {
          await NotificationService.instance.scheduleEventNotification(event);
        } catch (e) {
          debugPrint(
              '[AgendaProvider] falha ao reagendar notif ${event.id}: $e');
        }
      }
    }
  }

  /// Agenda alertas de vencimento para TODOS os eventos financeiros pendentes
  Future<void> _scheduleFinancialDueAlerts() async {
    for (final event in _events) {
      if (event.category == EventCategory.financeiro) {
        await _scheduleFinancialDueAlert(event);
      }
    }
  }

  /// Agenda notificação 3 dias antes do vencimento financeiro
  Future<void> _scheduleFinancialDueAlert(AgendaEvent event) async {
    if (event.isPast ||
        event.status == EventStatus.cancelado ||
        event.status == EventStatus.concluido) return;
    try {
      final alertDate = event.dateTime.subtract(const Duration(days: 3));
      if (alertDate.isAfter(DateTime.now())) {
        final alertEvent = event.copyWith(
          id: '${event.id}_due_alert',
          title: '⚠️ Vencimento em 3 dias: ${event.title}'
              '${event.financialAmount != null ? ' (R\$ ${event.financialAmount!.toStringAsFixed(2)})' : ''}',
          dateTime: alertDate,
          notifyMinutes: 0,
        );
        await NotificationService.instance
            .scheduleEventNotification(alertEvent);
      }
    } catch (e) {
      debugPrint('[AgendaProvider] _scheduleFinancialDueAlert error: $e');
    }
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _events.map((e) => jsonEncode(e.toJson())).toList();
      await prefs.setStringList('agenda_events', list);
    } catch (e) {
      debugPrint('[AgendaProvider] _saveToPrefs error: $e');
    }
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('agenda_events') ?? [];
      _events = list
          .map((s) {
            try {
              return AgendaEvent.fromJson(
                  jsonDecode(s) as Map<String, dynamic>);
            } catch (_) {
              return null;
            }
          })
          .whereType<AgendaEvent>()
          .toList();
    } catch (e) {
      debugPrint('[AgendaProvider] _loadFromPrefs error: $e');
      _events = [];
    }
    notifyListeners();
  }

  /// Resumo de hoje para o agente (agenda)
  String get todaySummaryForAgent {
    if (todayEvents.isEmpty) return 'Nenhum evento agendado para hoje.';
    final sb = StringBuffer(
        'Agenda de hoje (${todayEvents.length} evento(s)):\n');
    for (final e in todayEvents) {
      sb.writeln('- ${e.formattedTime}: ${e.title} [${e.priority.name}]');
    }
    return sb.toString();
  }

  /// NOVO: Resumo financeiro para o agente (vencimentos próximos)
  String get financialSummaryForAgent {
    if (dueSoonEvents.isEmpty) return '';
    final sb = StringBuffer(
        '⚠️ ${dueSoonEvents.length} vencimento(s) nos próximos 3 dias:\n');
    for (final e in dueSoonEvents) {
      final valor = e.financialAmount != null
          ? ' — R\$ ${e.financialAmount!.toStringAsFixed(2)}'
          : '';
      final dias = e.dateTime.difference(DateTime.now()).inDays;
      final quando = dias == 0 ? 'hoje' : 'em $dias dia(s)';
      sb.writeln('- ${e.title}$valor [$quando]');
    }
    if (dueSoonTotalAmount > 0) {
      sb.writeln(
          'Total a pagar: R\$ ${dueSoonTotalAmount.toStringAsFixed(2)}');
    }
    return sb.toString();
  }

  /// NOVO: Relatório semanal completo (agenda + financeiro) para WhatsApp
  String weeklyReportText(String companyName) {
    final now = DateTime.now();
    final nextWeek = now.add(const Duration(days: 7));
    final weekEvents = _events
        .where((e) =>
            e.dateTime.isAfter(now) &&
            e.dateTime.isBefore(nextWeek) &&
            e.status != EventStatus.cancelado)
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    final financialEvents =
        weekEvents.where((e) => e.category == EventCategory.financeiro);
    final totalFinancial =
        financialEvents.fold(0.0, (s, e) => s + (e.financialAmount ?? 0.0));

    final sb = StringBuffer();
    sb.writeln('📊 *Relatório Semanal — $companyName*');
    sb.writeln(
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')} – ${nextWeek.day.toString().padLeft(2, '0')}/${nextWeek.month.toString().padLeft(2, '0')}/${nextWeek.year}');
    sb.writeln();
    if (weekEvents.isEmpty) {
      sb.writeln('Nenhum evento na próxima semana.');
    } else {
      sb.writeln('🗓️ *Agenda (${weekEvents.length} evento(s))*');
      for (final e in weekEvents) {
        final valor = e.financialAmount != null
            ? ' — R\$ ${e.financialAmount!.toStringAsFixed(2)}'
            : '';
        sb.writeln(
            '- ${e.formattedDate} ${e.formattedTime}: ${e.title}$valor');
      }
      sb.writeln();
    }
    if (totalFinancial > 0) {
      sb.writeln('💰 *Compromissos Financeiros: R\$ ${totalFinancial.toStringAsFixed(2)}*');
    }
    sb.writeln();
    sb.writeln('_Gerado automaticamente pelo Agente S.F.C.P.C_');
    return sb.toString();
  }
}
