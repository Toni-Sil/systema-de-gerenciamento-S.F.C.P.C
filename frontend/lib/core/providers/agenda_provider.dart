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
    if (idx == -1) return;
    await NotificationService.instance.cancelNotification(updated.id);
    _events[idx] = updated;
    _events.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    await _saveToPrefs();
    if (updated.notifyBefore) {
      await NotificationService.instance.scheduleEventNotification(updated);
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
      // FIX: valida transcript mínimo de 3 chars antes de parsear
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

    // Hora: aceita "14h", "14:30", "14 horas", "14h30"
    final hourRegex =
        RegExp(r'(\d{1,2})h(oras?)?\s*(\d{2})?|(\d{1,2}):(\d{2})');
    final hourMatch = hourRegex.firstMatch(lower);
    if (hourMatch != null) {
      if (hourMatch.group(4) != null) {
        // formato HH:MM
        hour = int.tryParse(hourMatch.group(4)!) ?? 9;
        minute = int.tryParse(hourMatch.group(5) ?? '0') ?? 0;
      } else {
        hour = int.tryParse(hourMatch.group(1)!) ?? 9;
        minute = int.tryParse(hourMatch.group(3) ?? '0') ?? 0;
      }
      // Validação de range
      hour = hour.clamp(0, 23);
      minute = minute.clamp(0, 59);
    }

    // Data
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
      // Sem data específica: assume hoje
      eventDate = DateTime(now.year, now.month, now.day, hour, minute);
    }

    // Categoria
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

    // Título: remove palavras de contexto temporal
    String title = text
        .replaceAll(
          RegExp(
            r'(hoje|amanh[aã]|segunda(-feira)?|ter[cç]a(-feira)?|quarta(-feira)?|quinta(-feira)?|sexta(-feira)?|s[aá]bado|domingo|\d{1,2}h(oras?)?(\s*\d{2})?|\d{1,2}:\d{2}|urgente|importante)',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();

    // FIX: rejeita títulos muito curtos ou vazios — retorna null para não criar lixo
    if (title.length < 3) return null;

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
    var date = DateTime.now().add(const Duration(days: 1));
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
              return AgendaEvent.fromJson(jsonDecode(s) as Map<String, dynamic>);
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

  String get todaySummaryForAgent {
    if (todayEvents.isEmpty) return 'Nenhum evento agendado para hoje.';
    final sb = StringBuffer(
        'Agenda de hoje (${todayEvents.length} evento(s)):\n');
    for (final e in todayEvents) {
      sb.writeln('- ${e.formattedTime}: ${e.title} [${e.priority.name}]');
    }
    return sb.toString();
  }
}
