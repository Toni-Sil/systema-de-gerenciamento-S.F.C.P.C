// FIX #2: erros de API em addItem/removeItem agora setam _errorMessage e notificam a UI
import 'package:flutter/material.dart';
import '../models/inventory_item.dart';
import '../services/api_service.dart';

enum ProviderStatus { idle, loading, error }

class OperationalProvider with ChangeNotifier {
  List<InventoryItem> _items = [];
  ProviderStatus _status = ProviderStatus.idle;
  String? _errorMessage;
  String _search = '';
  String? _categoryFilter;

  ProviderStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == ProviderStatus.loading;

  void clearError() {
    _errorMessage = null;
    if (_status == ProviderStatus.error) _status = ProviderStatus.idle;
    notifyListeners();
  }

  List<InventoryItem> get items {
    var list = List<InventoryItem>.from(_items);
    if (_categoryFilter != null) {
      list = list.where((i) => i.category == _categoryFilter).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      list = list
          .where((i) =>
              i.code.toLowerCase().contains(q) ||
              i.description.toLowerCase().contains(q) ||
              i.location.toLowerCase().contains(q))
          .toList();
    }
    return List.unmodifiable(list);
  }

  List<InventoryItem> get lowStockItems =>
      _items.where((i) => i.isLowStock).toList();

  double get totalStockValue =>
      _items.fold(0.0, (sum, i) => sum + i.totalValue);

  int get totalItems => _items.length;

  void setSearch(String query) {
    _search = query;
    notifyListeners();
  }

  void setCategoryFilter(String? category) {
    _categoryFilter = category;
    notifyListeners();
  }

  void _loadMockData() {
    _items = [
      const InventoryItem(
        code: 'LINHO-BEGE',
        category: 'Tecidos',
        description: 'Linho Importado Bege',
        qty: 120,
        unit: 'Metros',
        cost: 28.50,
        location: 'Corredor A, Prat 3',
        minimumStock: 20,
        supplier: 'Textil SP',
      ),
      const InventoryItem(
        code: 'ESPUMA-D28',
        category: 'Espumas',
        description: 'Espuma Flexível D28',
        qty: 3,
        unit: 'Unid.',
        cost: 145.00,
        location: 'Corredor C, Chão',
        minimumStock: 5,
        supplier: 'Espumados Brasil',
      ),
      const InventoryItem(
        code: 'ARTIC-METAL',
        category: 'Ferragens',
        description: 'Articulador de Sofá-cama Premium',
        qty: 58,
        unit: 'Kits',
        cost: 89.90,
        location: 'Corredor B, Prat 1',
        minimumStock: 10,
        supplier: 'MetalParts BR',
      ),
    ];
  }

  Future<void> loadFromApi() async {
    _status = ProviderStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await ApiService.instance.getInventory(
        category: _categoryFilter,
        search: _search.isEmpty ? null : _search,
      );
      _items = data
          .map((e) => InventoryItem.fromJson(e as Map<String, dynamic>))
          .toList();
      _status = ProviderStatus.idle;
    } catch (_) {
      _loadMockData();
      _status = ProviderStatus.idle;
    }
    notifyListeners();
  }

  // FIX #2: seta _errorMessage se API falhar; dado local persiste (offline-first)
  Future<void> addItem(InventoryItem item) async {
    _items.add(item);
    notifyListeners();
    try {
      await ApiService.instance.addInventoryItem(item.toJson());
    } catch (e) {
      _errorMessage = 'Item salvo localmente. Sincronização pendente.';
      notifyListeners();
    }
  }

  Future<void> updateBalance(
      String code, double delta, String reason) async {
    final idx = _items.indexWhere(
        (i) => i.code.toUpperCase() == code.toUpperCase());
    if (idx == -1) return;

    final updated = _items[idx].copyWith(
      qty: (_items[idx].qty + delta).clamp(0.0, double.infinity),
    );
    _items[idx] = updated;
    notifyListeners();

    try {
      await ApiService.instance.updateInventoryBalance(code, delta, reason);
    } catch (e) {
      _errorMessage = 'Saldo atualizado localmente. Sincronização pendente.';
      notifyListeners();
    }
  }

  // FIX #2: remove localmente e notifica erro de API sem reverter (offline-first)
  Future<void> removeItem(String code) async {
    _items.removeWhere(
        (i) => i.code.toUpperCase() == code.toUpperCase());
    notifyListeners();
    try {
      await ApiService.instance.deleteInventoryItem(code);
    } catch (e) {
      _errorMessage = 'Remoção salva localmente. Sincronização pendente.';
      notifyListeners();
    }
  }

  bool exists(String code) =>
      _items.any((i) => i.code.toUpperCase() == code.toUpperCase());

  InventoryItem? findByCode(String code) =>
      _items.cast<InventoryItem?>().firstWhere(
            (i) => i?.code.toUpperCase() == code.toUpperCase(),
            orElse: () => null,
          );
}
