import 'package:flutter/material.dart';

class FinancialScreen extends StatelessWidget {
  const FinancialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock Timeline Data representing OCR injections
    final List<Map<String, dynamic>> transactions = [
      {
        "date": "Há 10 min",
        "title": "Registro OCR Automático",
        "category": "Matéria Prima",
        "description": "Compra: Tecidos Finos LTDA",
        "value": "R\$ -2.300,00",
        "isExpense": true,
        "status": "Pago",
      },
      {
        "date": "Ontem",
        "title": "Venda Orquestrada IA",
        "category": "Vendas",
        "description": "2x Sofá-Cama Retrátil Premium",
        "value": "R\$ +5.500,00",
        "isExpense": false,
        "status": "Recebido",
      },
      {
        "date": "10 de Mar",
        "title": "Custo Evitado (IA)",
        "category": "Logística",
        "description": "Ruptura de Espuma D28 Prevenida",
        "value": "R\$ +850,00",
        "isExpense": false,
        "status": "Economia",
      },
    ];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).primaryColor,
                  Theme.of(context).primaryColor.withValues(alpha: 0.6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'ROI Consolidado do Agente',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 8),
                const Text(
                  'R\$ 23.450,00',
                  style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSubKPI('Receitas + Economia', 'R\$ 28.300', Colors.white),
                    _buildSubKPI('Custos Registrados', 'R\$ 4.850', Colors.redAccent.shade100),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Linha do Tempo (IA Financeira)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await Future.delayed(const Duration(seconds: 1));
              },
              child: ListView.builder(
                itemCount: transactions.length,
                itemBuilder: (context, index) {
                final t = transactions[index];
                final isExpense = t['isExpense'] as bool;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isExpense ? Colors.redAccent : Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                        if (index < transactions.length - 1)
                          Container(
                            width: 2,
                            height: 60,
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  t['title'],
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                ),
                                Text(
                                  t['date'],
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              t['description'],
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  t['value'],
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: isExpense ? Colors.redAccent : Theme.of(context).colorScheme.secondary,
                                  ),
                                ),
                                Row(
                                  children: [
                                    _buildSmallBadge(t['category'], Colors.grey.withValues(alpha: 0.2), Colors.white70),
                                    const SizedBox(width: 8),
                                    _buildSmallBadge(
                                      t['status'],
                                      isExpense ? Colors.redAccent.withValues(alpha: 0.1) : Colors.greenAccent.withValues(alpha: 0.1),
                                      isExpense ? Colors.redAccent : Colors.greenAccent,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
      ),
    );
  }

  Widget _buildSubKPI(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildSmallBadge(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
