import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../models/agenda_event.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: (details) {},
    );

    // Solicita permissão (Android 13+)
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    _initialized = true;
  }

  Future<void> scheduleEventNotification(AgendaEvent event) async {
    if (!_initialized) await init();

    final notifyAt = event.dateTime
        .subtract(Duration(minutes: event.notifyMinutes));

    if (notifyAt.isBefore(DateTime.now())) return;

    final id = _eventToNotificationId(event.id);

    const androidDetails = AndroidNotificationDetails(
      'agenda_channel',
      'Agenda S.F.C.P.C',
      channelDescription: 'Lembretes de eventos da agenda',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      color: Color(0xFF00E5FF),
    );

    await _plugin.zonedSchedule(
      id,
      '⏰ Lembrete: ${event.title}',
      '${event.formattedTime} — em ${event.notifyMinutes} minutos'
          '${event.location != null ? ' • ${event.location}' : ''}',
      tz.TZDateTime.from(notifyAt, tz.local),
      const NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> showImmediateNotification({
    required String title,
    required String body,
    int id = 0,
  }) async {
    if (!_initialized) await init();
    const androidDetails = AndroidNotificationDetails(
      'agenda_channel',
      'Agenda S.F.C.P.C',
      channelDescription: 'Lembretes de eventos da agenda',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    await _plugin.show(
        id, title, body, const NotificationDetails(android: androidDetails));
  }

  Future<void> showDailySummary(String summary) async {
    await showImmediateNotification(
      title: '📅 Sua agenda de hoje',
      body: summary,
      id: 9999,
    );
  }

  Future<void> cancelNotification(String eventId) async {
    await _plugin.cancel(_eventToNotificationId(eventId));
  }

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  int _eventToNotificationId(String id) {
    return id.hashCode.abs() % 100000;
  }
}

// Import necessário para Color
import 'dart:ui' show Color;
