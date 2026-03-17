import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/agenda_event.dart';
import '../services/notification_service.dart';

class AgendaProvider extends ChangeNotifier {
  List<AgendaEvent> _events = [];
  bool _isLoading = false;
  String _filter = 'all'; // 'all' | 'today' | 'pending' | 'done'

  List<AgendaEvent> get events => _filtered;
  bool get isLoading => _isLoading;
  String get filter => _filter;

  List<AgendaEvent> get _filtered {
    final sorted = List<AgendaEvent>.from(_events)
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    switch (_filter) {
      case 'today':
        return sorted.where((e) => e.isToday).toList();
      case 'pending':
        return sorted
            .where((e) => e.status == EventStatus.pending)
            .toList();
      case 'done':
        return sorted
            .where((e) => e.status == EventStatus.done)
            .toList();
      default:
        return sorted;
    }
  }

  List<AgendaEvent> get todayEvents =>
      _events.where((e) => e.isToday && e.status == EventStatus.pending).toList()
        ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

  List<AgendaEvent> get upcomingEvents {
    final now = DateTime.now();
    return _events
        .where((e) =>
            e.dateTime.isAfter(now) && e.status == EventStatus.pending)
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  int get todayCount => todayEvents.length;

  void setFilter(String f) {
    _filter = f;
    notifyListeners();
  }

  Future<void> init() async {
    _isLoading = true;
    notifyListeners();
    await _loadFromPrefs();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> addEvent(AgendaEvent event) async {
    _events.add(event);
    if (event.notifyBefore) {
      await NotificationService.scheduleEventNotification(event);
    }
    await _saveToPrefs();
    notifyListeners();
  }

  Future<void> updateEvent(AgendaEvent updated) async {
    final idx = _events.indexWhere((e) => e.id == updated.id);
    if (idx == -1) return;
    await NotificationService.cancelNotification(updated.id);
    _events[idx] = updated;
    if (updated.notifyBefore && updated.status == EventStatus.pending) {
      await NotificationService.scheduleEventNotification(updated);
    }
    await _saveToPrefs();
    notifyListeners();
  }

  Future<void> deleteEvent(String id) async {
    await NotificationService.cancelNotification(id);
    _events.removeWhere((e) => e.id == id);
    await _saveToPrefs();
    notifyListeners();
  }

  Future<void> markDone(String id) async {
    final idx = _events.indexWhere((e) => e.id == id);
    if (idx == -1) return;
    _events[idx].status = EventStatus.done;
    await NotificationService.cancelNotification(id);
    await _saveToPrefs();
    notifyListeners();
  }

  Future<void> sendTodaySummaryNotification() async {
    if (todayEvents.isEmpty) return;
    await NotificationService.showSummaryNotification(
      title: 'Agenda do dia — ${todayEvents.length} compromisso(s)',
      body: todayEvents
          .take(3)
          .map((e) => '• ${e.timeLabel} ${e.title}')
          .join('\n'),
    );
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('agenda_events');
    if (raw == null) {
      _events = _mockEvents();
      return;
    }
    try {
      final list = jsonDecode(raw) as List;
      _events = list.map((e) => AgendaEvent.fromJson(e)).toList();
    } catch (_) {
      _events = _mockEvents();
    }
  }

  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'agenda_events', jsonEncode(_events.map((e) => e.toJson()).toList()));
  }

  List<AgendaEvent> _mockEvents() {
    final now = DateTime.now();
    return [
      AgendaEvent(
        id: 'mock_1',
        title: 'Reunião com fornecedor de espumas',
        description: 'Confirmar pedido lote #2024',
        dateTime: DateTime(now.year, now.month, now.day, 10, 0),
        priority: EventPriority.high,
        notifyMinutesBefore: 30,
        createdBy: 'agent',
      ),
      AgendaEvent(
        id: 'mock_2',
        title: 'Contagem de estoque — tecidos',
        dateTime: DateTime(now.year, now.month, now.day, 14, 30),
        priority: EventPriority.medium,
        createdBy: 'user',
      ),
      AgendaEvent(
        id: 'mock_3',
        title: 'Enviar relatório semanal',
        dateTime: now.add(const Duration(days: 1, hours: 9)),
        priority: EventPriority.medium,
        createdBy: 'agent',
      ),
    ];
  }
}
