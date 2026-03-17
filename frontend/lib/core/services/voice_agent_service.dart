import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Serviço de reconhecimento de voz — singleton seguro com Completer real.
class VoiceAgentService extends ChangeNotifier {
  VoiceAgentService._();
  static final VoiceAgentService instance = VoiceAgentService._();

  final SpeechToText _speech = SpeechToText();
  bool _isAvailable = false;
  bool _isListening = false;
  String _lastWords = '';
  Completer<String>? _completer;

  bool get isListening => _isListening;
  bool get isAvailable => _isAvailable;
  String get lastWords => _lastWords;

  Future<bool> init() async {
    if (_isAvailable) return true;
    _isAvailable = await _speech.initialize(
      onError: (error) {
        debugPrint('[VoiceAgentService] error: $error');
        _setListening(false);
        _completer?.complete(_lastWords);
        _completer = null;
      },
      onStatus: (status) {
        debugPrint('[VoiceAgentService] status: $status');
        if (status == 'done' || status == 'notListening') {
          _setListening(false);
          // FIX: completa com o último resultado reconhecido ao parar
          _completer?.complete(_lastWords);
          _completer = null;
        }
      },
    );
    notifyListeners();
    return _isAvailable;
  }

  /// Ouve até silêncio ou [timeout], retorna transcript ou null.
  /// FIX: usa Completer real em vez de Future.delayed fixo.
  Future<String?> listen({
    Duration timeout = const Duration(seconds: 10),
    void Function(String partial)? onPartial,
  }) async {
    if (!_isAvailable) await init();
    if (!_isAvailable) return null;
    if (_isListening) return null; // já está ouvindo

    _lastWords = '';
    _completer = Completer<String>();
    _setListening(true);

    await _speech.listen(
      localeId: 'pt_BR',
      listenFor: timeout,
      pauseFor: const Duration(seconds: 2),
      onResult: (result) {
        _lastWords = result.recognizedWords;
        if (onPartial != null) onPartial(_lastWords);
        // FIX: se resultado final chegar, completa imediatamente
        if (result.finalResult) {
          _setListening(false);
          if (!(_completer?.isCompleted ?? true)) {
            _completer!.complete(_lastWords);
            _completer = null;
          }
        }
      },
    );

    // Timeout de segurança: completa após timeout + 2s se nada aconteceu
    Future.delayed(timeout + const Duration(seconds: 2), () {
      if (!(_completer?.isCompleted ?? true)) {
        _completer!.complete(_lastWords);
        _completer = null;
        _setListening(false);
      }
    });

    final result = await _completer!.future;
    return result.trim().isNotEmpty ? result.trim() : null;
  }

  Future<void> stop() async {
    await _speech.stop();
    _setListening(false);
    if (!(_completer?.isCompleted ?? true)) {
      _completer!.complete(_lastWords);
      _completer = null;
    }
  }

  Future<void> cancel() async {
    await _speech.cancel();
    _lastWords = '';
    _setListening(false);
    if (!(_completer?.isCompleted ?? true)) {
      _completer!.complete('');
      _completer = null;
    }
  }

  void _setListening(bool value) {
    if (_isListening == value) return;
    _isListening = value;
    notifyListeners();
  }
}
