import 'package:speech_to_text/speech_to_text.dart';

/// Serviço de reconhecimento de voz para criacao de eventos na agenda
class VoiceService {
  static final SpeechToText _speech = SpeechToText();
  static bool _available = false;

  static Future<bool> init() async {
    _available = await _speech.initialize(
      onError: (e) => {},
      onStatus: (s) => {},
    );
    return _available;
  }

  static bool get isAvailable => _available;
  static bool get isListening => _speech.isListening;

  static Future<void> startListening({
    required void Function(String text) onResult,
    void Function()? onDone,
  }) async {
    if (!_available) return;
    await _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          onResult(result.recognizedWords);
          onDone?.call();
        }
      },
      localeId: 'pt_BR',
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      listenOptions: SpeechListenOptions(
        partialResults: false,
        cancelOnError: true,
      ),
    );
  }

  static Future<void> stop() async {
    await _speech.stop();
  }

  /// Interpreta texto falado e extrai dados do evento
  /// Ex: "Reunião com fornecedor amanhã às 14 horas"
  static Map<String, dynamic> parseVoiceCommand(String text) {
    final lower = text.toLowerCase();
    DateTime? dateTime;
    EventDateHint hint = EventDateHint.none;

    // Detecta dia
    final now = DateTime.now();
    if (lower.contains('hoje')) {
      hint = EventDateHint.today;
    } else if (lower.contains('amanhã') || lower.contains('amanha')) {
      hint = EventDateHint.tomorrow;
    } else if (lower.contains('segunda')) {
      hint = EventDateHint.weekday;
    }

    // Detecta hora — padrões: "14 horas", "às 9", "09:30", "14h30"
    final timeRegex = RegExp(
        r'(\d{1,2})(?:[:h](\d{2}))?(?: horas?| h)?(?:\s*(?:da|de)\s+(?:manhã|tarde|noite))?');
    final match = timeRegex.firstMatch(lower);
    int hour = 9;
    int minute = 0;
    if (match != null) {
      hour = int.tryParse(match.group(1) ?? '9') ?? 9;
      minute = int.tryParse(match.group(2) ?? '0') ?? 0;
      if (lower.contains('tarde') && hour < 12) hour += 12;
      if (lower.contains('noite') && hour < 18) hour += 12;
    }

    final base = hint == EventDateHint.tomorrow
        ? now.add(const Duration(days: 1))
        : now;
    dateTime = DateTime(base.year, base.month, base.day, hour, minute);

    // Prioridade por palavras-chave
    String priority = 'medium';
    if (lower.contains('urgente') || lower.contains('importante')) {
      priority = 'urgent';
    } else if (lower.contains('rápido') || lower.contains('breve')) {
      priority = 'low';
    }

    // Título: remove palavras de data/hora do texto
    String title = text;
    for (final word in [
      'hoje', 'amanhã', 'amanha', 'às', 'as', 'horas', 'hora',
      'urgente', 'rápido', 'breve'
    ]) {
      title = title.replaceAll(RegExp(word, caseSensitive: false), '');
    }
    title = title.replaceAll(timeRegex, '').trim();
    if (title.isEmpty) title = text.trim();

    return {
      'title': _capitalize(title),
      'dateTime': dateTime,
      'priority': priority,
    };
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}

enum EventDateHint { none, today, tomorrow, weekday }
