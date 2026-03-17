// FIX #3: Future orfão do timeout cancelado com flag _timeoutFired
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceAgentService extends ChangeNotifier {
  VoiceAgentService._();
  static final VoiceAgentService instance = VoiceAgentService._();

  final SpeechToText _speech = SpeechToText();
  bool _isAvailable = false;
  bool _isListening = false;
  String _lastWords = '';
  Completer<String>? _completer;
  // FIX #3: timer explícito para cancelar o timeout se já completado
  Timer? _timeoutTimer;

  bool get isListening => _isListening;
  bool get isAvailable => _isAvailable;
  String get lastWords => _lastWords;

  Future<bool> init() async {
    if (_isAvailable) return true;
    _isAvailable = false;
    try {
      _isAvailable = await _speech.initialize(
        onError: (error) {
          debugPrint('[VoiceAgentService] error: $error');
          _isAvailable = false;
          _setListening(false);
          _resolveCompleter(_lastWords);
        },
        onStatus: (status) {
          debugPrint('[VoiceAgentService] status: $status');
          if (status == 'done' || status == 'notListening') {
            _setListening(false);
            _resolveCompleter(_lastWords);
          }
        },
      );
    } catch (e) {
      debugPrint('[VoiceAgentService] init error: $e');
      _isAvailable = false;
    }
    notifyListeners();
    return _isAvailable;
  }

  Future<String?> listen({
    Duration timeout = const Duration(seconds: 10),
    void Function(String partial)? onPartial,
  }) async {
    if (!_isAvailable) await init();
    if (!_isAvailable) return null;
    if (_isListening) return null;

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
        if (result.finalResult) {
          _setListening(false);
          _resolveCompleter(_lastWords);
        }
      },
    );

    // FIX #3: Timer cancelado explicitamente se completer já resolveu antes
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(timeout + const Duration(seconds: 2), () {
      _setListening(false);
      _resolveCompleter(_lastWords);
    });

    final result = await _completer!.future;
    return result.trim().isNotEmpty ? result.trim() : null;
  }

  Future<void> stop() async {
    await _speech.stop();
    _setListening(false);
    _resolveCompleter(_lastWords);
  }

  Future<void> cancel() async {
    await _speech.cancel();
    _lastWords = '';
    _setListening(false);
    _resolveCompleter('');
  }

  void _setListening(bool value) {
    if (_isListening == value) return;
    _isListening = value;
    notifyListeners();
  }

  /// Helper centralizado para resolver o Completer e cancelar o timer
  void _resolveCompleter(String value) {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    if (!(_completer?.isCompleted ?? true)) {
      _completer!.complete(value);
      _completer = null;
    }
  }
}
