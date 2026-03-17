import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/agenda_event.dart';
import '../services/notification_service.dart';

class AgendaProvider extends ChangeNotifier {
  List<AgendaEvent> _events = [];
  DateTime _selectedDay = DateTime.now();
  bool _isLoading = false;
  String? _lastVoiceResult;

  List<AgendaEvent> get events => _events;
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
  int get urgentCount =>
      todayEvents.where((e) => e.isUrgent).length;

  Future<void> init() async {
    await _loadFromPrefs();
    await NotificationService.instance.init();
    _rescheduleAllNotifications();
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
    notifyListeners();
  }

  Future<void> updateEvent(AgendaEvent updated) async {
    final idx = _events.indexWhere((e) => e.id == updated.id);
    if (idx != -1) {
      await NotificationService.instance.cancelNotification(updated.id);
      _events[idx] = updated;
      _events.sort((a, b) => a.dateTime.compareTo(b.dateTime));
      await _saveToPrefs();
      if (updated.notifyBefore) {
        await NotificationService.instance.scheduleEventNotification(updated);
      }
      notifyListeners();
    }
  }

  Future<void> deleteEvent(String id) async {
    await NotificationService.instance.cancelNotification(id);
    _events.removeWhere((e) => e.id == id);
    await _saveToPrefs();
    notifyListeners();
  }

  Future<void> markCompleted(String id) async {
    final idx = _events.indexWhere((e) => e.id == id);
    if (idx != -1) {
      _events[idx] = _events[idx].copyWith(status: EventStatus.concluido);
      await _saveToPrefs();
      notifyListeners();
    }
  }

  // Processa comando de voz em texto e cria evento
  Future<String> processVoiceCommand(String transcript) async {
    _isLoading = true;
    notifyListeners();

    try {
      final event = _parseVoiceTranscript(transcript);
      if (event != null) {
        await addEvent(event);
        _lastVoiceResult =
            'Agendado: "${event.title}" para ${event.formattedDate} às ${event.formattedTime}';
      } else {
        _lastVoiceResult =
            'Não entendi o evento. Tente: "Reunião com fornecedor amanhã às 14h"';
      }
    } catch (e) {
      _lastVoiceResult = 'Erro ao processar comando de voz.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return _lastVoiceResult!;
  }

  // Parser simples de linguagem natural
  AgendaEvent? _parseVoiceTranscript(String text) {
    final lower = text.toLowerCase();
    DateTime? eventDate;
    int hour = 9;
    int minute = 0;
    final now = DateTime.now();

    // Detectar hora (14h, 14:30, 14 horas)
    final hourRegex = RegExp(r'(\d{1,2})(?::?(\d{2}))?\s*h(oras?)?');
    final hourMatch = hourRegex.firstMatch(lower);
    if (hourMatch != null) {
      hour = int.tryParse(hourMatch.group(1) ?? '9') ?? 9;
      minute = int.tryParse(hourMatch.group(2) ?? '0') ?? 0;
    }

    // Detectar data
    if (lower.contains('hoje')) {
      eventDate = DateTime(now.year, now.month, now.day, hour, minute);
    } else if (lower.contains('amanhã') || lower.contains('amanha')) {
      final tomorrow = now.add(const Duration(days: 1));
      eventDate =
          DateTime(tomorrow.year, tomorrow.month, tomorrow.day, hour, minute);
    } else if (lower.contains('segunda')) {
      eventDate = _nextWeekday(1, hour, minute);
    } else if (lower.contains('terça') || lower.contains('terca')) {
      eventDate = _nextWeekday(2, hour, minute);
    } else if (lower.contains('quarta')) {
      eventDate = _nextWeekday(3, hour, minute);
    } else if (lower.contains('quinta')) {
      eventDate = _nextWeekday(4, hour, minute);
    } else if (lower.contains('sexta')) {
      eventDate = _nextWeekday(5, hour, minute);
    } else {
      // Sem data detectada: assume hoje
      eventDate = DateTime(now.year, now.month, now.day, hour, minute);
    }

    // Detectar categoria
    EventCategory category = EventCategory.outro;
    EventPriority priority = EventPriority.normal;

    if (lower.contains('reunião') || lower.contains('reuniao')) {
      category = EventCategory.reuniao;
    } else if (lower.contains('entrega')) {
      category = EventCategory.entrega;
    } else if (lower.contains('reposição') ||
        lower.contains('estoque') ||
        lower.contains('repor')) {
      category = EventCategory.reposicao;
    } else if (lower.contains('pagamento') ||
        lower.contains('financeiro') ||
        lower.contains('boleto')) {
      category = EventCategory.financeiro;
      priority = EventPriority.alta;
    }

    if (lower.contains('urgente') || lower.contains('importante')) {
      priority = EventPriority.urgente;
    }

    // Título: remove palavras de data/hora para deixar só o conteúdo
    String title = text
        .replaceAll(
            RegExp(
                r'(hoje|amanh[aã]|segunda|ter[cç]a|quarta|quinta|sexta|\d{1,2}h(oras?)?|\d{1,2}:\d{2})',
                caseSensitive: false),
            '')
        .trim();
    if (title.isEmpty) title = 'Evento';
    // Capitaliza primeira letra
    title = title[0].toUpperCase() + title.substring(1);

    return AgendaEvent(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      dateTime: eventDate,
      category: category,
      priority: priority,
      isVoiceCreated: true,
      notifyBefore: true,
      notifyMinutes: 30,
    );
  }

  DateTime _nextWeekday(int weekday, int hour, int minute) {
    final now = DateTime.now();
    var date = now;
    while (date.weekday != weekday) {
      date = date.add(const Duration(days: 1));
    }
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  void _rescheduleAllNotifications() {
    for (final event in _events) {
      if (event.notifyBefore &&
          event.status == EventStatus.pendente &&
          !event.isPast) {
        NotificationService.instance.scheduleEventNotification(event);
      }
    }
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _events.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList('agenda_events', list);
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('agenda_events') ?? [];
    _events = list
        .map((s) => AgendaEvent.fromJson(jsonDecode(s)))
        .toList();
    notifyListeners();
  }

  // Gera resumo do dia para o agente IA
  String get todaySummaryForAgent {
    if (todayEvents.isEmpty) return 'Nenhum evento agendado para hoje.';
    final sb = StringBuffer('Agenda de hoje (${todayEvents.length} evento(s)):\n');
    for (final e in todayEvents) {
      sb.writeln('- ${e.formattedTime}: ${e.title} [${e.priority.name}]');
    }
    return sb.toString();
  }
}
