import 'package:speech_to_text/speech_to_text.dart';

/// Serviço de reconhecimento de voz para criação de eventos
class VoiceAgentService {
  VoiceAgentService._();
  static final VoiceAgentService instance = VoiceAgentService._();

  final SpeechToText _speech = SpeechToText();
  bool _isAvailable = false;
  bool _isListening = false;
  String _lastWords = '';

  bool get isListening => _isListening;
  bool get isAvailable => _isAvailable;
  String get lastWords => _lastWords;

  Future<bool> init() async {
    _isAvailable = await _speech.initialize(
      onError: (error) => _isListening = false,
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          _isListening = false;
        }
      },
    );
    return _isAvailable;
  }

  Future<String?> listen({
    Duration timeout = const Duration(seconds: 8),
    void Function(String partial)? onPartial,
  }) async {
    if (!_isAvailable) await init();
    if (!_isAvailable) return null;

    _lastWords = '';
    _isListening = true;

    final completer = Future<String>(() async {
      await _speech.listen(
        localeId: 'pt_BR',
        listenFor: timeout,
        pauseFor: const Duration(seconds: 3),
        onResult: (result) {
          _lastWords = result.recognizedWords;
          if (onPartial != null) onPartial(_lastWords);
        },
      );
      // Aguarda o listen terminar
      await Future.delayed(timeout + const Duration(seconds: 1));
      return _lastWords;
    });

    final result = await completer;
    _isListening = false;
    return result.isNotEmpty ? result : null;
  }

  Future<void> stop() async {
    await _speech.stop();
    _isListening = false;
  }

  Future<void> cancel() async {
    await _speech.cancel();
    _isListening = false;
  }
}
