import 'package:hive_flutter/hive_flutter.dart';

/// Serviço de sincronização offline usando Hive.
/// Inicializa o banco local e exposes boxes usados pelos providers.
class OfflineSyncService {
  OfflineSyncService._();

  static const String _boxInventory = 'inventory';
  static const String _boxTransactions = 'transactions';
  static const String _boxSettings = 'settings';

  static Future<void> init() async {
    await Hive.initFlutter();
    // Abre boxes base — outros boxes são abertos sob demanda
    await Hive.openBox<dynamic>(_boxInventory);
    await Hive.openBox<dynamic>(_boxTransactions);
    await Hive.openBox<dynamic>(_boxSettings);
  }

  static Box<dynamic> get inventoryBox => Hive.box<dynamic>(_boxInventory);
  static Box<dynamic> get transactionsBox => Hive.box<dynamic>(_boxTransactions);
  static Box<dynamic> get settingsBox => Hive.box<dynamic>(_boxSettings);

  /// Limpa todos os dados locais (logout / reset)
  static Future<void> clearAll() async {
    await inventoryBox.clear();
    await transactionsBox.clear();
    await settingsBox.clear();
  }
}
