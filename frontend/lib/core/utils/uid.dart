// FIX #7: gerador de IDs únicos para evitar colisão por millisecondsSinceEpoch
class Uid {
  Uid._();
  static int _counter = 0;

  /// Retorna ID único combinando timestamp + contador incremental.
  /// Formato: "<ms>_<counter>" — garantido único mesmo em ráfaga de criações.
  static String generate() {
    _counter = (_counter + 1) % 99999;
    return '${DateTime.now().millisecondsSinceEpoch}_$_counter';
  }
}
