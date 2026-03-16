// Model separado — InventoryItem com tipos corretos
class InventoryItem {
  final String code;
  final String category;
  final String description;
  final double qty;
  final String unit;
  final double cost;
  final String location;
  final double minimumStock;
  final String? supplier;
  final String? lotNumber;

  const InventoryItem({
    required this.code,
    required this.category,
    required this.description,
    required this.qty,
    required this.unit,
    required this.location,
    this.cost = 0.0,
    this.minimumStock = 5.0,
    this.supplier,
    this.lotNumber,
  });

  bool get isLowStock => qty <= minimumStock;

  /// Saldo formatado para exibição
  String get balanceLabel => '${qty % 1 == 0 ? qty.toInt() : qty} $unit';

  /// Valor total do item em estoque
  double get totalValue => qty * cost;

  InventoryItem copyWith({
    double? qty,
    double? cost,
    String? location,
    String? supplier,
    String? lotNumber,
    double? minimumStock,
  }) {
    return InventoryItem(
      code: code,
      category: category,
      description: description,
      qty: qty ?? this.qty,
      unit: unit,
      cost: cost ?? this.cost,
      location: location ?? this.location,
      minimumStock: minimumStock ?? this.minimumStock,
      supplier: supplier ?? this.supplier,
      lotNumber: lotNumber ?? this.lotNumber,
    );
  }

  /// Serialização para cache offline / API
  Map<String, dynamic> toJson() => {
        'code': code,
        'category': category,
        'description': description,
        'qty': qty,
        'unit': unit,
        'cost': cost,
        'location': location,
        'minimum_stock': minimumStock,
        'supplier': supplier,
        'lot_number': lotNumber,
      };

  factory InventoryItem.fromJson(Map<String, dynamic> json) => InventoryItem(
        code: json['code'] as String,
        category: json['category'] as String,
        description: json['description'] as String,
        qty: (json['qty'] as num).toDouble(),
        unit: json['unit'] as String,
        cost: (json['cost'] as num? ?? 0).toDouble(),
        location: json['location'] as String,
        minimumStock: (json['minimum_stock'] as num? ?? 5).toDouble(),
        supplier: json['supplier'] as String?,
        lotNumber: json['lot_number'] as String?,
      );
}
