import 'dart:math';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../models/agenda_event.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(initSettings);

    // Solicita permissão (Android 13+)
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // Cria canal de alta importância
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            'agenda_channel',
            'Agenda S.F.C.P.C',
            description: 'Notificações de compromissos da agenda',
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
          ),
        );

    _initialized = true;
  }

  static Future<void> scheduleEventNotification(AgendaEvent event) async {
    final notifyAt = event.dateTime
        .subtract(Duration(minutes: event.notifyMinutesBefore));
    if (notifyAt.isBefore(DateTime.now())) return;

    final id = _idFromString(event.id);

    await _plugin.zonedSchedule(
      id,
      '⏰ ${event.title}',
      '${event.notifyMinutesBefore} min • ${event.timeLabel}'
          '${event.location != null ? ' • ${event.location}' : ''}',
      tz.TZDateTime.from(notifyAt, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'agenda_channel',
          'Agenda S.F.C.P.C',
          importance: Importance.high,
          priority: Priority.high,
          color: event.priorityColor,
          styleInformation: BigTextStyleInformation(
            event.description ?? event.title,
            summaryText: event.priorityLabel,
          ),
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: null,
    );
  }

  static Future<void> showSummaryNotification({
    required String title,
    required String body,
  }) async {
    await _plugin.show(
      0,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'agenda_channel',
          'Agenda S.F.C.P.C',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(''),
        ),
      ),
    );
  }

  static Future<void> cancelNotification(String eventId) async {
    await _plugin.cancel(_idFromString(eventId));
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  static int _idFromString(String s) =>
      s.hashCode.abs() % (pow(2, 31).toInt() - 1);
}
