// Sprint 3 — Rastreio de Lote e Serial (Tecidos, Espumas, etc.)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/section_header.dart';

class LotTrackingScreen extends StatefulWidget {
  const LotTrackingScreen({super.key});

  @override
  State<LotTrackingScreen> createState() => _LotTrackingScreenState();
}

class _LotTrackingScreenState extends State<LotTrackingScreen> {
  // Mock data — integrar com API /lots endpoint
  final List<_LotItem> _lots = [
    _LotItem(
        lot: 'LOT-2026-001',
        product: 'Tecido Floral 140cm',
        category: 'Tecidos',
        supplier: 'Textil São Paulo',
        qty: '150m',
        entryDate: '10/03/2026',
        expiry: null,
        status: LotStatus.active),
    _LotItem(
        lot: 'LOT-2026-002',
        product: 'Espuma D33 10cm',
        category: 'Espumas',
        supplier: 'Espumados Brasil',
        qty: '40 peças',
        entryDate: '08/03/2026',
        expiry: '08/03/2027',
        status: LotStatus.active),
    _LotItem(
        lot: 'LOT-2025-048',
        product: 'Tecido Veludo Verde',
        category: 'Tecidos',
        supplier: 'Textil São Paulo',
        qty: '2m',
        entryDate: '15/11/2025',
        expiry: null,
        status: LotStatus.lowStock),
    _LotItem(
        lot: 'LOT-2025-032',
        product: 'Ferragem Dobradiça 80mm',
        category: 'Ferragens',
        supplier: 'MetalParts BR',
        qty: '0 un',
        entryDate: '01/09/2025',
        expiry: null,
        status: LotStatus.depleted),
  ];

  String _filter = 'Todos';
  final _categories = ['Todos', 'Tecidos', 'Espumas', 'Ferragens', 'Madeiras'];

  List<_LotItem> get _filtered => _filter == 'Todos'
      ? _lots
      : _lots.where((l) => l.category == _filter).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        title: const Text('Rastreio de Lotes'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: AppColors.neonCyan),
            onPressed: _showAddLotSheet,
            tooltip: 'Novo Lote',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtro por categoria
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final cat = _categories[i];
                final active = cat == _filter;
                return ChoiceChip(
                  label: Text(cat),
                  selected: active,
                  onSelected: (_) => setState(() => _filter = cat),
                  selectedColor: AppColors.neonCyan.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: active ? AppColors.neonCyan : AppColors.textLow,
                    fontWeight:
                        active ? FontWeight.bold : FontWeight.normal,
                  ),
                  side: BorderSide(
                      color: active
                          ? AppColors.neonCyan.withValues(alpha: 0.5)
                          : AppColors.border),
                  backgroundColor: AppColors.bgSurface,
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          // Lista de lotes
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filtered.length,
              itemBuilder: (_, i) => _LotCard(lot: _filtered[i]),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddLotSheet() {
    final lotCtrl = TextEditingController();
    final productCtrl = TextEditingController();
    final supplierCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Registrar Novo Lote',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textHigh)),
            const SizedBox(height: 16),
            TextField(
                controller: lotCtrl,
                decoration: const InputDecoration(labelText: 'Número do Lote')),
            const SizedBox(height: 10),
            TextField(
                controller: productCtrl,
                decoration: const InputDecoration(labelText: 'Produto/Material')),
            const SizedBox(height: 10),
            TextField(
                controller: supplierCtrl,
                decoration: const InputDecoration(labelText: 'Fornecedor')),
            const SizedBox(height: 10),
            TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Quantidade (ex: 100m, 50 un)')),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                  setState(() {
                    _lots.insert(
                      0,
                      _LotItem(
                        lot: lotCtrl.text.isEmpty
                            ? 'LOT-${DateTime.now().millisecondsSinceEpoch}'
                            : lotCtrl.text,
                        product: productCtrl.text,
                        category: 'Tecidos',
                        supplier: supplierCtrl.text,
                        qty: qtyCtrl.text,
                        entryDate:
                            '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                        expiry: null,
                        status: LotStatus.active,
                      ),
                    );
                  });
                },
                child: const Text('Registrar Lote'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LotCard extends StatelessWidget {
  final _LotItem lot;
  const _LotCard({required this.lot});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (lot.status) {
      LotStatus.active => AppColors.neonGreen,
      LotStatus.lowStock => AppColors.neonAmber,
      LotStatus.depleted => AppColors.neonRed,
    };
    final statusLabel = switch (lot.status) {
      LotStatus.active => 'Ativo',
      LotStatus.lowStock => 'Baixo',
      LotStatus.depleted => 'Esgotado',
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        borderColor: statusColor.withValues(alpha: 0.3),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.inventory_2_outlined, color: statusColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lot.product,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textHigh,
                          fontSize: 14)),
                  const SizedBox(height: 2),
                  Text('${lot.lot}  •  ${lot.supplier}',
                      style: const TextStyle(
                          color: AppColors.textLow, fontSize: 11)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 11, color: AppColors.textLow),
                      const SizedBox(width: 3),
                      Text('Entrada: ${lot.entryDate}',
                          style: const TextStyle(
                              color: AppColors.textLow, fontSize: 11)),
                      if (lot.expiry != null) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.event, size: 11, color: AppColors.neonAmber),
                        const SizedBox(width: 3),
                        Text('Venc: ${lot.expiry}',
                            style: const TextStyle(
                                color: AppColors.neonAmber, fontSize: 11)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(lot.qty,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                        fontSize: 16)),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(statusLabel,
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum LotStatus { active, lowStock, depleted }

class _LotItem {
  final String lot;
  final String product;
  final String category;
  final String supplier;
  final String qty;
  final String entryDate;
  final String? expiry;
  final LotStatus status;
  const _LotItem({
    required this.lot,
    required this.product,
    required this.category,
    required this.supplier,
    required this.qty,
    required this.entryDate,
    required this.expiry,
    required this.status,
  });
}
