// Sprint 4 — Offline Mode com Hive + sync automático ao reconectar
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';

class OfflineSyncService {
  static const _queueBox = 'offline_queue';
  static const _cacheBox = 'data_cache';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox<Map>(_queueBox);
    await Hive.openBox<Map>(_cacheBox);
  }

  /// Verifica conectividade
  static Future<bool> isOnline() async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }

  /// Salva operação local quando offline
  static Future<void> enqueue({
    required String action,
    required Map<String, dynamic> payload,
  }) async {
    final box = Hive.box<Map>(_queueBox);
    await box.add({
      'action': action,
      'payload': payload,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Sincroniza fila pendente com o servidor
  static Future<int> syncPending(Future<bool> Function(Map item) syncFn) async {
    if (!await isOnline()) return 0;
    final box = Hive.box<Map>(_queueBox);
    int synced = 0;
    final keys = box.keys.toList();
    for (final key in keys) {
      final item = box.get(key);
      if (item == null) continue;
      final success = await syncFn(Map<String, dynamic>.from(item));
      if (success) {
        await box.delete(key);
        synced++;
      }
    }
    return synced;
  }

  /// Quantidade de operações pendentes
  static int get pendingCount => Hive.box<Map>(_queueBox).length;

  /// Cache de dados para modo offline
  static Future<void> cacheData(String key, Map<String, dynamic> data) async {
    await Hive.box<Map>(_cacheBox).put(key, data);
  }

  static Map<String, dynamic>? getCached(String key) {
    final raw = Hive.box<Map>(_cacheBox).get(key);
    return raw != null ? Map<String, dynamic>.from(raw) : null;
  }
}
