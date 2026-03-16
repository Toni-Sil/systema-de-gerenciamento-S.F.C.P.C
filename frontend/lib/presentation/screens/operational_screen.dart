// PR-C — OperationalScreen: busca real, filtro por categoria, scanner, validação
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/models/inventory_item.dart';
import 'package:frontend/core/providers/operational_provider.dart';
import 'package:frontend/presentation/theme/app_theme.dart';
import 'package:frontend/presentation/screens/barcode_scanner_screen.dart';

class OperationalScreen extends StatefulWidget {
  const OperationalScreen({super.key});

  @override
  State<OperationalScreen> createState() => _OperationalScreenState();
}

class _OperationalScreenState extends State<OperationalScreen> {
  final _searchCtrl = TextEditingController();
  final _categories = [
    'Todos', 'Tecidos', 'Espumas', 'Ferragens', 'Madeiras', 'Ferramentas'
  ];
  String _selectedCategory = 'Todos';
  bool _filterOpen = false;

  @override
  void initState() {
    super.initState();
    // Carrega da API ao abrir (com fallback mock offline)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<OperationalProvider>(context, listen: false).loadFromApi();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ─── Scanner ─────────────────────────────────────────────────────────────

  void _openScanner() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BarcodeScannerScreen(
          onDetected: (code) {
            HapticFeedback.mediumImpact();
            _searchCtrl.text = code;
            Provider.of<OperationalProvider>(context, listen: false)
                .setSearch(code);
          },
        ),
      ),
    );
  }

  // ─── Dialog adicionar item ───────────────────────────────────────────────────

  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    final locationCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final minCtrl = TextEditingController();
    final supplierCtrl = TextEditingController();
    String category = 'Tecidos';
    String unit = 'UN';
    final formKey = GlobalKey<FormState>();
    final op = Provider.of<OperationalProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
              16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
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
                          borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Novo Item',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textHigh)),
                  const SizedBox(height: 16),
                  // Nome
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Descrição / Nome *'),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Obrigatório' : null,
                  ),
                  const SizedBox(height: 10),
                  // Código
                  TextFormField(
                    controller: codeCtrl,
                    decoration: InputDecoration(
                      labelText: 'Código SKU *',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.qr_code_scanner,
                            color: AppColors.neonCyan),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _openScanner();
                        },
                      ),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Obrigatório' : null,
                  ),
                  const SizedBox(height: 10),
                  // Categoria
                  DropdownButtonFormField<String>(
                    value: category,
                    items: _categories
                        .where((c) => c != 'Todos')
                        .map((c) =>
                            DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setSheet(() => category = v!),
                    decoration:
                        const InputDecoration(labelText: 'Categoria *'),
                  ),
                  const SizedBox(height: 10),
                  // Qty + Unidade
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: qtyCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Qtd. Inicial *'),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Obrigatório';
                            if (double.tryParse(v) == null) return 'Número inválido';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: unit,
                          items: ['UN', 'Metros', 'Kits', 'Kg', 'L']
                              .map((u) => DropdownMenuItem(
                                  value: u, child: Text(u)))
                              .toList(),
                          onChanged: (v) => setSheet(() => unit = v!),
                          decoration:
                              const InputDecoration(labelText: 'Unid.'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Custo unitário
                  TextFormField(
                    controller: costCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Custo Unitário (R\$)',
                        prefixText: 'R\$ '),
                  ),
                  const SizedBox(height: 10),
                  // Estoque mínimo
                  TextFormField(
                    controller: minCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Estoque Mínimo (alerta)'),
                  ),
                  const SizedBox(height: 10),
                  // Fornecedor
                  TextFormField(
                    controller: supplierCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Fornecedor'),
                  ),
                  const SizedBox(height: 10),
                  // Localização
                  TextFormField(
                    controller: locationCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Localização (Corredor/Prat)'),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (!formKey.currentState!.validate()) return;
                        HapticFeedback.lightImpact();
                        op.addItem(InventoryItem(
                          code: codeCtrl.text.trim().toUpperCase(),
                          category: category,
                          description: nameCtrl.text.trim(),
                          qty: double.tryParse(qtyCtrl.text) ?? 0,
                          unit: unit,
                          cost:
                              double.tryParse(costCtrl.text) ?? 0,
                          location: locationCtrl.text.trim(),
                          minimumStock:
                              double.tryParse(minCtrl.text) ?? 5,
                          supplier: supplierCtrl.text.trim().isEmpty
                              ? null
                              : supplierCtrl.text.trim(),
                        ));
                        Navigator.pop(ctx);
                      },
                      child: const Text('Cadastrar Item'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Dialog de movimentação (entrada/saída) ───────────────────────────────

  void _showMovementSheet(InventoryItem item) {
    final qtyCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    bool isEntry = true;
    final op = Provider.of<OperationalProvider>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
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
                        borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 16),
              Text('Movimentação — ${item.description}',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textHigh)),
              const SizedBox(height: 4),
              Text('Saldo atual: ${item.balanceLabel}',
                  style: const TextStyle(
                      color: AppColors.textLow, fontSize: 13)),
              const SizedBox(height: 16),
              // Toggle Entrada / Saída
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setSheet(() => isEntry = true),
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isEntry
                              ? AppColors.neonGreen.withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: isEntry
                                  ? AppColors.neonGreen
                                  : AppColors.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add,
                                color: isEntry
                                    ? AppColors.neonGreen
                                    : AppColors.textLow,
                                size: 18),
                            const SizedBox(width: 6),
                            Text('Entrada',
                                style: TextStyle(
                                    color: isEntry
                                        ? AppColors.neonGreen
                                        : AppColors.textLow,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setSheet(() => isEntry = false),
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: !isEntry
                              ? AppColors.neonRed.withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: !isEntry
                                  ? AppColors.neonRed
                                  : AppColors.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.remove,
                                color: !isEntry
                                    ? AppColors.neonRed
                                    : AppColors.textLow,
                                size: 18),
                            const SizedBox(width: 6),
                            Text('Saída',
                                style: TextStyle(
                                    color: !isEntry
                                        ? AppColors.neonRed
                                        : AppColors.textLow,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                    labelText: 'Quantidade (${item.unit})',
                    prefixIcon: Icon(
                        isEntry ? Icons.add_circle : Icons.remove_circle,
                        color: isEntry
                            ? AppColors.neonGreen
                            : AppColors.neonRed)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(
                    labelText: 'Motivo (ex: Produção, Devolução)'),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isEntry ? AppColors.neonGreen : AppColors.neonRed,
                    foregroundColor: AppColors.bgDeep,
                  ),
                  onPressed: () {
                    final qty = double.tryParse(qtyCtrl.text);
                    if (qty == null || qty <= 0) return;
                    final delta = isEntry ? qty : -qty;
                    op.updateBalance(item.code, delta,
                        reasonCtrl.text.isEmpty ? (isEntry ? 'Entrada' : 'Saída') : reasonCtrl.text);
                    HapticFeedback.lightImpact();
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            '${isEntry ? '+' : '-'}${qty.toInt()} ${item.unit} em ${item.description}'),
                        backgroundColor: isEntry
                            ? AppColors.neonGreen
                            : AppColors.neonRed,
                      ),
                    );
                  },
                  child: Text(
                      isEntry ? 'Confirmar Entrada' : 'Confirmar Saída',
                      style:
                          const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final op = Provider.of<OperationalProvider>(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: AppColors.neonCyan,
        child: const Icon(Icons.add, color: AppColors.bgDeep),
      ),
      body: Column(
        children: [
          // ─ Barra de busca + scanner + filtro
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) {
                      op.setSearch(v);
                    },
                    decoration: InputDecoration(
                      hintText: 'Buscar código, nome, corredor…',
                      prefixIcon:
                          const Icon(Icons.search, color: AppColors.textLow),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close,
                                  color: AppColors.textLow, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                op.setSearch('');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Botão scanner
                IconButton(
                  style: IconButton.styleFrom(
                      backgroundColor: AppColors.neonCyan.withValues(alpha: 0.12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  icon: const Icon(Icons.qr_code_scanner,
                      color: AppColors.neonCyan),
                  onPressed: _openScanner,
                  tooltip: 'Escanear código',
                ),
                const SizedBox(width: 4),
                // Botão filtro
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: _filterOpen
                        ? AppColors.neonPurple.withValues(alpha: 0.2)
                        : Theme.of(context).colorScheme.surface,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: Icon(Icons.filter_list,
                      color: _filterOpen
                          ? AppColors.neonPurple
                          : AppColors.textLow),
                  onPressed: () =>
                      setState(() => _filterOpen = !_filterOpen),
                ),
              ],
            ),
          ),

          // ─ Chips de categoria (expansível)
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            child: _filterOpen
                ? SizedBox(
                    height: 48,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      itemCount: _categories.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: 8),
                      itemBuilder: (_, i) {
                        final cat = _categories[i];
                        final active = cat == _selectedCategory;
                        return ChoiceChip(
                          label: Text(cat),
                          selected: active,
                          onSelected: (_) {
                            setState(
                                () => _selectedCategory = cat);
                            op.setCategoryFilter(
                                cat == 'Todos' ? null : cat);
                          },
                          selectedColor:
                              AppColors.neonPurple.withValues(alpha: 0.2),
                          labelStyle: TextStyle(
                              color: active
                                  ? AppColors.neonPurple
                                  : AppColors.textLow,
                              fontWeight: active
                                  ? FontWeight.bold
                                  : FontWeight.normal),
                          side: BorderSide(
                              color: active
                                  ? AppColors.neonPurple
                                      .withValues(alpha: 0.6)
                                  : AppColors.border),
                          backgroundColor: AppColors.bgSurface,
                        );
                      },
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // ─ KPI rápido
          if (!op.isLoading)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _kpiChip(
                      '${op.totalItems} itens',
                      Icons.inventory_2_outlined,
                      AppColors.neonCyan),
                  const SizedBox(width: 8),
                  _kpiChip(
                      '${op.lowStockItems.length} reposicões',
                      Icons.warning_amber,
                      op.lowStockItems.isEmpty
                          ? AppColors.neonGreen
                          : AppColors.neonRed),
                  const SizedBox(width: 8),
                  _kpiChip(
                      'R\$ ${(op.totalStockValue / 1000).toStringAsFixed(1)}K',
                      Icons.attach_money,
                      AppColors.neonAmber),
                ],
              ),
            ),

          // ─ Loading
          if (op.isLoading)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(color: AppColors.neonCyan),
              ),
            )
          else

          // ─ Lista
          Expanded(
            child: RefreshIndicator(
              color: AppColors.neonCyan,
              onRefresh: () => op.loadFromApi(),
              child: op.items.isEmpty
                  ? _emptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      itemCount: op.items.length,
                      itemBuilder: (ctx, i) =>
                          _itemCard(ctx, op.items[i], op),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Widgets auxiliares ─────────────────────────────────────────────────────

  Widget _kpiChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined,
              size: 64,
              color: AppColors.textLow.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          const Text('Nenhum item encontrado',
              style:
                  TextStyle(color: AppColors.textLow, fontSize: 15)),
          const SizedBox(height: 8),
          const Text('Ajuste a busca ou adicione um novo item',
              style:
                  TextStyle(color: AppColors.textLow, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _itemCard(
      BuildContext ctx, InventoryItem item, OperationalProvider op) {
    final lowStock = item.isLowStock;
    final statusColor =
        lowStock ? AppColors.neonRed : AppColors.neonGreen;

    return Dismissible(
      key: Key(item.code),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async => await showDialog<bool>(
        context: ctx,
        builder: (_) => AlertDialog(
          title: const Text('Confirmar Exclusão'),
          content:
              Text('Remover "${item.description}" do estoque?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Excluir')),
          ],
        ),
      ),
      onDismissed: (_) {
        op.removeItem(item.code);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${item.description} removido.')));
      },
      child: GestureDetector(
        onTap: () => _showMovementSheet(item),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border(
              left: BorderSide(color: statusColor, width: 4),
              top: BorderSide(
                  color: AppColors.border.withValues(alpha: 0.5)),
              right: BorderSide(
                  color: AppColors.border.withValues(alpha: 0.5)),
              bottom: BorderSide(
                  color: AppColors.border.withValues(alpha: 0.5)),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Ícone categoria
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_iconForCategory(item.category),
                      color: statusColor, size: 22),
                ),
                const SizedBox(width: 14),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.description,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppColors.textHigh)),
                      const SizedBox(height: 3),
                      Text(
                          '${item.code} • ${item.category}',
                          style: const TextStyle(
                              color: AppColors.textLow,
                              fontSize: 11)),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(Icons.location_on,
                              size: 12,
                              color: AppColors.textLow),
                          const SizedBox(width: 3),
                          Text(item.location,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textLow)),
                          if (item.supplier != null) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.local_shipping,
                                size: 12,
                                color: AppColors.textLow),
                            const SizedBox(width: 3),
                            Text(item.supplier!,
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textLow)),
                          ]
                        ],
                      ),
                    ],
                  ),
                ),
                // Saldo + badge
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(item.balanceLabel,
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: statusColor)),
                    const SizedBox(height: 4),
                    if (item.cost > 0)
                      Text(
                          'R\$ ${item.totalValue.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textLow)),
                    if (lowStock)
                      Container(
                        margin: const EdgeInsets.only(top: 5),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.neonRed
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text('Repor',
                            style: TextStyle(
                                color: AppColors.neonRed,
                                fontSize: 9,
                                fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _iconForCategory(String cat) {
    switch (cat) {
      case 'Tecidos': return Icons.layers;
      case 'Espumas': return Icons.cloud;
      case 'Ferragens': return Icons.build;
      case 'Ferramentas': return Icons.handyman;
      case 'Madeiras': return Icons.forest;
      default: return Icons.weekend;
    }
  }
}
