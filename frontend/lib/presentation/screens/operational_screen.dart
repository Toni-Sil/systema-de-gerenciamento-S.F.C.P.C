import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/providers/operational_provider.dart';

class OperationalScreen extends StatefulWidget {
  const OperationalScreen({super.key});

  @override
  State<OperationalScreen> createState() => _OperationalScreenState();
}

class _OperationalScreenState extends State<OperationalScreen> {
  void _showAddProductDialog() {
    final nameController = TextEditingController();
    final codeController = TextEditingController();
    final locationController = TextEditingController();
    String selectedCategory = 'Tecidos';
    final operationalProvider = Provider.of<OperationalProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Novo Registro (Produto/Ferramenta)'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Descrição/Nome'),
              ),
              TextField(
                controller: codeController,
                decoration: const InputDecoration(labelText: 'Código SKU'),
              ),
              DropdownButtonFormField<String>(
                initialValue: selectedCategory,
                items: ['Tecidos', 'Espumas', 'Ferragens', 'Madeiras', 'Ferramentas']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) => selectedCategory = val!,
                decoration: const InputDecoration(labelText: 'Categoria'),
              ),
              TextField(
                controller: locationController,
                decoration: const InputDecoration(labelText: 'Localização (Corredor/Prat)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              operationalProvider.addItem(InventoryItem(
                code: codeController.text,
                category: selectedCategory,
                description: nameController.text,
                balance: "0 UN",
                location: locationController.text,
                isLowStock: false,
              ));
              Navigator.pop(context);
            },
            child: const Text('Cadastrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final operationalProvider = Provider.of<OperationalProvider>(context);
    final items = operationalProvider.items;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddProductDialog,
        backgroundColor: Theme.of(context).colorScheme.secondary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Buscar por código, Corredor...',
                      prefixIcon: const Icon(Icons.search),
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
                IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.surface,
                  ),
                  icon: const Icon(Icons.filter_list),
                  onPressed: () {},
                )
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                await Future.delayed(const Duration(seconds: 1));
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(content: Text('Estoque Atualizado!')),
                  );
                }
              },
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: items.length,
                itemBuilder: (context, index) {
                final item = items[index];
                final lowStock = item.isLowStock;

                return Dismissible(
                  key: Key(item.code),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (direction) async {
                    return await showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Confirmar Exclusão'),
                        content: Text('Deseja remover "${item.description}" do estoque?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancelar'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Excluir'),
                          ),
                        ],
                      ),
                    );
                  },
                  onDismissed: (direction) {
                    operationalProvider.removeItem(item.code);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${item.description} removido.')),
                    );
                  },
                  child: Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: Border(
                      left: BorderSide(
                        color: lowStock ? Colors.redAccent : Theme.of(context).primaryColor,
                        width: 4,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              _getIconForCategory(item.category),
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.description,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${item.code} • ${item.category}',
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on, size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(
                                      item.location,
                                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                item.balance,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: lowStock ? Colors.redAccent : Colors.white,
                                ),
                              ),
                              if (lowStock)
                                Container(
                                  margin: const EdgeInsets.only(top: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'Repor Urgent.',
                                    style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
      ),
    );
  }

  IconData _getIconForCategory(String category) {
    if (category == 'Tecidos') return Icons.layers;
    if (category == 'Espumas') return Icons.cloud;
    if (category == 'Ferragens') return Icons.build;
    if (category == 'Ferramentas') return Icons.handyman;
    return Icons.weekend;
  }
}
