import 'package:flutter/material.dart';

enum EventPriority { low, medium, high, urgent }

enum EventStatus { pending, done, cancelled }

class AgendaEvent {
  final String id;
  final String title;
  final String? description;
  final DateTime dateTime;
  final Duration? duration;
  final EventPriority priority;
  EventStatus status;
  final bool notifyBefore; // notificar antes
  final int notifyMinutesBefore;
  final String? location;
  final String? createdBy; // 'user' | 'agent'

  AgendaEvent({
    required this.id,
    required this.title,
    this.description,
    required this.dateTime,
    this.duration,
    this.priority = EventPriority.medium,
    this.status = EventStatus.pending,
    this.notifyBefore = true,
    this.notifyMinutesBefore = 15,
    this.location,
    this.createdBy = 'user',
  });

  bool get isToday {
    final now = DateTime.now();
    return dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day;
  }

  bool get isPast => dateTime.isBefore(DateTime.now());

  bool get isUrgent => priority == EventPriority.urgent;

  Color get priorityColor {
    switch (priority) {
      case EventPriority.low:
        return const Color(0xFF10B981);
      case EventPriority.medium:
        return const Color(0xFF00E5FF);
      case EventPriority.high:
        return const Color(0xFFF59E0B);
      case EventPriority.urgent:
        return const Color(0xFFEF4444);
    }
  }

  String get priorityLabel {
    switch (priority) {
      case EventPriority.low:
        return 'Baixa';
      case EventPriority.medium:
        return 'Média';
      case EventPriority.high:
        return 'Alta';
      case EventPriority.urgent:
        return 'Urgente';
    }
  }

  String get timeLabel {
    final h = dateTime.hour.toString().padLeft(2, '0');
    final m = dateTime.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String get dateLabel {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final eventDay = DateTime(dateTime.year, dateTime.month, dateTime.day);
    if (eventDay == today) return 'Hoje';
    if (eventDay == tomorrow) return 'Amanhã';
    const months = [
      '', 'Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun',
      'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'
    ];
    return '${dateTime.day} ${months[dateTime.month]}';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'dateTime': dateTime.toIso8601String(),
        'duration': duration?.inMinutes,
        'priority': priority.name,
        'status': status.name,
        'notifyBefore': notifyBefore,
        'notifyMinutesBefore': notifyMinutesBefore,
        'location': location,
        'createdBy': createdBy,
      };

  factory AgendaEvent.fromJson(Map<String, dynamic> json) => AgendaEvent(
        id: json['id'],
        title: json['title'],
        description: json['description'],
        dateTime: DateTime.parse(json['dateTime']),
        duration: json['duration'] != null
            ? Duration(minutes: json['duration'])
            : null,
        priority: EventPriority.values
            .firstWhere((e) => e.name == json['priority'],
                orElse: () => EventPriority.medium),
        status: EventStatus.values
            .firstWhere((e) => e.name == json['status'],
                orElse: () => EventStatus.pending),
        notifyBefore: json['notifyBefore'] ?? true,
        notifyMinutesBefore: json['notifyMinutesBefore'] ?? 15,
        location: json['location'],
        createdBy: json['createdBy'] ?? 'user',
      );

  AgendaEvent copyWith({
    String? title,
    String? description,
    DateTime? dateTime,
    Duration? duration,
    EventPriority? priority,
    EventStatus? status,
    bool? notifyBefore,
    int? notifyMinutesBefore,
    String? location,
  }) =>
      AgendaEvent(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        dateTime: dateTime ?? this.dateTime,
        duration: duration ?? this.duration,
        priority: priority ?? this.priority,
        status: status ?? this.status,
        notifyBefore: notifyBefore ?? this.notifyBefore,
        notifyMinutesBefore:
            notifyMinutesBefore ?? this.notifyMinutesBefore,
        location: location ?? this.location,
        createdBy: createdBy,
      );
}
