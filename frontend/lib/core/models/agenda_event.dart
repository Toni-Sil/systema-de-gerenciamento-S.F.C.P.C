import 'package:flutter/material.dart';

enum EventPriority { baixa, normal, alta, urgente }
enum EventStatus { pendente, confirmado, cancelado, concluido }
enum EventCategory { reuniao, entrega, reposicao, financeiro, pessoal, outro }

class AgendaEvent {
  final String id;
  final String title;
  final String? description;
  final DateTime dateTime;
  final Duration? duration;
  final EventPriority priority;
  final EventStatus status;
  final EventCategory category;
  final bool notifyBefore; // notificar antes
  final int notifyMinutes; // quantos minutos antes
  final String? location;
  final bool isVoiceCreated;

  const AgendaEvent({
    required this.id,
    required this.title,
    this.description,
    required this.dateTime,
    this.duration,
    this.priority = EventPriority.normal,
    this.status = EventStatus.pendente,
    this.category = EventCategory.outro,
    this.notifyBefore = true,
    this.notifyMinutes = 30,
    this.location,
    this.isVoiceCreated = false,
  });

  AgendaEvent copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? dateTime,
    Duration? duration,
    EventPriority? priority,
    EventStatus? status,
    EventCategory? category,
    bool? notifyBefore,
    int? notifyMinutes,
    String? location,
    bool? isVoiceCreated,
  }) {
    return AgendaEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      dateTime: dateTime ?? this.dateTime,
      duration: duration ?? this.duration,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      category: category ?? this.category,
      notifyBefore: notifyBefore ?? this.notifyBefore,
      notifyMinutes: notifyMinutes ?? this.notifyMinutes,
      location: location ?? this.location,
      isVoiceCreated: isVoiceCreated ?? this.isVoiceCreated,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'dateTime': dateTime.toIso8601String(),
        'durationMinutes': duration?.inMinutes,
        'priority': priority.name,
        'status': status.name,
        'category': category.name,
        'notifyBefore': notifyBefore,
        'notifyMinutes': notifyMinutes,
        'location': location,
        'isVoiceCreated': isVoiceCreated,
      };

  factory AgendaEvent.fromJson(Map<String, dynamic> json) => AgendaEvent(
        id: json['id'],
        title: json['title'],
        description: json['description'],
        dateTime: DateTime.parse(json['dateTime']),
        duration: json['durationMinutes'] != null
            ? Duration(minutes: json['durationMinutes'])
            : null,
        priority: EventPriority.values.firstWhere(
            (e) => e.name == json['priority'],
            orElse: () => EventPriority.normal),
        status: EventStatus.values.firstWhere(
            (e) => e.name == json['status'],
            orElse: () => EventStatus.pendente),
        category: EventCategory.values.firstWhere(
            (e) => e.name == json['category'],
            orElse: () => EventCategory.outro),
        notifyBefore: json['notifyBefore'] ?? true,
        notifyMinutes: json['notifyMinutes'] ?? 30,
        location: json['location'],
        isVoiceCreated: json['isVoiceCreated'] ?? false,
      );

  bool get isToday {
    final now = DateTime.now();
    return dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day;
  }

  bool get isPast => dateTime.isBefore(DateTime.now());
  bool get isUrgent => priority == EventPriority.urgente;

  Color get priorityColor {
    switch (priority) {
      case EventPriority.baixa:
        return const Color(0xFF10B981);
      case EventPriority.normal:
        return const Color(0xFF00E5FF);
      case EventPriority.alta:
        return const Color(0xFFF59E0B);
      case EventPriority.urgente:
        return const Color(0xFFEF4444);
    }
  }

  IconData get categoryIcon {
    switch (category) {
      case EventCategory.reuniao:
        return Icons.people_outline;
      case EventCategory.entrega:
        return Icons.local_shipping_outlined;
      case EventCategory.reposicao:
        return Icons.inventory_2_outlined;
      case EventCategory.financeiro:
        return Icons.account_balance_wallet_outlined;
      case EventCategory.pessoal:
        return Icons.person_outline;
      case EventCategory.outro:
        return Icons.event_outlined;
    }
  }

  String get formattedTime {
    final h = dateTime.hour.toString().padLeft(2, '0');
    final m = dateTime.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String get formattedDate {
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
  }
}
