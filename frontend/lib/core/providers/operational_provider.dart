import 'package:flutter/material.dart';

class InventoryItem {
  final String code;
  final String category;
  final String description;
  final String balance;
  final String location;
  final bool isLowStock;

  InventoryItem({
    required this.code,
    required this.category,
    required this.description,
    required this.balance,
    required this.location,
    this.isLowStock = false,
  });

  InventoryItem copyWith({
    String? balance,
    bool? isLowStock,
  }) {
    return InventoryItem(
      code: code,
      category: category,
      description: description,
      balance: balance ?? this.balance,
      location: location,
      isLowStock: isLowStock ?? this.isLowStock,
    );
  }
}

class OperationalProvider with ChangeNotifier {
  final List<InventoryItem> _items = [
    InventoryItem(
      code: "LINHO-BEGE",
      category: "Tecidos",
      description: "Linho Importado Bege",
      balance: "120 Metros",
      location: "Corredor A, Prat 3",
    ),
    InventoryItem(
      code: "ESPUMA-D28",
      category: "Espumas",
      description: "Espuma Flexível D28",
      balance: "15 Unid.",
      location: "Corredor C, Chão",
      isLowStock: true,
    ),
    InventoryItem(
      code: "ARTIC-METAL",
      category: "Ferragens",
      description: "Articulador de Sofá-cama Premium",
      balance: "58 Kits",
      location: "Corredor B, Prat 1",
    ),
  ];

  List<InventoryItem> get items => List.unmodifiable(_items);

  void addItem(InventoryItem item) {
    _items.add(item);
    notifyListeners();
  }

  void removeItem(String code) {
    _items.removeWhere((i) => i.code == code);
    notifyListeners();
  }

  bool exists(String code) {
    return _items.any((i) => i.code.toUpperCase() == code.toUpperCase());
  }
}
