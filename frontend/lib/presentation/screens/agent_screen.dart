import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/providers/user_provider.dart';
import 'package:frontend/core/providers/operational_provider.dart';

class AgentScreen extends StatefulWidget {
  const AgentScreen({super.key});

  @override
  State<AgentScreen> createState() => _AgentScreenState();
}

class _AgentScreenState extends State<AgentScreen> {
  final TextEditingController _controller = TextEditingController();
  late List<String> _messages;
  bool _isUploadingReceipt = false;

  @override
  void initState() {
    super.initState();
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    _messages = [
      "Olá ${userProvider.adminName}! O nível de estoque da Espuma D28 está baixo. Posso sugerir um pedido ao fornecedor?",
    ];
  }

  void _triggerDocumentUpload() {
    setState(() {
      _isUploadingReceipt = true;
    });
    // Simulate Document analysis delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isUploadingReceipt = false;
        });
        _showLiquidGlassOCRConfirm(isDocument: true);
      }
    });
  }

  void _triggerReceiptUpload() {
    setState(() {
      _isUploadingReceipt = true;
    });
    // Simulate OCR delay
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isUploadingReceipt = false;
        });
        _showLiquidGlassOCRConfirm(isDocument: false);
      }
    });
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
            border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                "Anexar Comprovante",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildAttachmentOption(
                    context,
                    icon: Icons.camera_alt,
                    label: "Câmera / Scan",
                    color: Colors.cyanAccent,
                    onTap: () {
                      Navigator.pop(context);
                      _showCameraScan(context);
                    },
                  ),
                  _buildAttachmentOption(
                    context,
                    icon: Icons.attach_file,
                    label: "PDF / Nota",
                    color: Theme.of(context).colorScheme.secondary,
                    onTap: () {
                      Navigator.pop(context);
                      _triggerDocumentUpload();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAttachmentOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _showLiquidGlassOCRConfirm({bool isDocument = false}) {
    final operationalProvider = Provider.of<OperationalProvider>(context, listen: false);
    
    // Mock data for the "new item" case
    const mockExtractedCode = "TECH-WH-01";
    const mockExtractedDesc = "Tecido White Tech 2026";
    final itemExists = operationalProvider.exists(mockExtractedCode);

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
            ),
            title: Text(isDocument ? 'Documento Analisado (IA)' : 'Comprovante Extraído (IA)'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Item: $mockExtractedDesc", style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text("Código: $mockExtractedCode"),
                const SizedBox(height: 8),
                Text(isDocument ? "Origem: Nota Online / PDF" : "Origem: Captura Câmera"),
                const SizedBox(height: 16),
                if (!itemExists)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orangeAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Atenção: Este item não consta no seu estoque atual.",
                            style: TextStyle(color: Colors.orangeAccent, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                Text(itemExists 
                  ? "Deseja atualizar o saldo no sistema?" 
                  : "Deseja registrar este novo item automaticamente?"),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Ignorar', style: TextStyle(color: Colors.grey)),
              ),
              if (!itemExists)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                  ),
                  onPressed: () {
                    operationalProvider.addItem(InventoryItem(
                      code: mockExtractedCode,
                      category: "Tecidos",
                      description: mockExtractedDesc,
                      balance: "100 UN", // Initial balance from doc
                      location: "Triagem / Entrada",
                    ));
                    Navigator.pop(context);
                    setState(() {
                      _messages.add('IA: Novo produto "$mockExtractedDesc" registrado com sucesso no estoque. Localização: Triagem.');
                    });
                  },
                  child: const Text('Registrar Novo', style: TextStyle(color: Colors.black)),
                ),
              if (itemExists)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      _messages.add('IA: Saldo do item "$mockExtractedCode" atualizado conforme documento.');
                    });
                  },
                  child: const Text('Atualizar Saldo'),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    
    // Ensure the first message is always updated with the current name if it hasn't been modified much
    // Or simpler: display the greeting as a separate widget or handle it in the list
    
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final isUser = index % 2 != 0;
              String displayMessage = _messages[index];
              
              // Personalize the very first bot message dynamically
              if (index == 0) {
                displayMessage = "Olá ${userProvider.adminName}! O nível de estoque da Espuma D28 está baixo. Posso sugerir um pedido ao fornecedor?";
              }

              return Align(
                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUser
                        ? Theme.of(context).primaryColor.withValues(alpha: 0.8)
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
                      bottomRight: isUser ? Radius.zero : const Radius.circular(16),
                    ),
                  ),
                  child: Text(
                    displayMessage,
                    style: TextStyle(
                      color: isUser ? Colors.white : Colors.white70,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (_isUploadingReceipt)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: LinearProgressIndicator(color: Colors.greenAccent),
          ),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.add_circle_outline, size: 28),
                color: Colors.cyanAccent,
                onPressed: _showAttachmentMenu,
                tooltip: 'Anexar...',
              ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: 'Perguntar ao Agente...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onSubmitted: (value) {
                    if (value.isNotEmpty) {
                      setState(() {
                        _messages.add(value);
                        _controller.clear();
                      });
                    }
                  },
                ),
              ),
              IconButton(
                onPressed: () {
                  if (_controller.text.isNotEmpty) {
                    setState(() {
                      _messages.add(_controller.text);
                      _controller.clear();
                    });
                  }
                },
                icon: const Icon(Icons.send, color: Colors.cyanAccent),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showCameraScan(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Câmera Scan',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              // Mock Camera Feed (Blurred Background)
              Center(
                child: Opacity(
                  opacity: 0.5,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.document_scanner, size: 100, color: Colors.white.withValues(alpha: 0.1)),
                      const SizedBox(height: 20),
                      const Text('Posicione a Nota Fiscal', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ),
              // Scanning Frame
              Center(
                child: Container(
                  width: 300,
                  height: 400,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.cyanAccent, width: 2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              // Animated Scanning Line
              TweenAnimationBuilder(
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(seconds: 2),
                builder: (context, double value, child) {
                  return Positioned(
                    top: 150 + (value * 350),
                    left: (MediaQuery.of(context).size.width - 280) / 2,
                    child: Container(
                      width: 280,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.cyanAccent,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.cyanAccent.withValues(alpha: 0.5),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  );
                },
                onEnd: () {
                  // Restart animation or show result
                },
              ),
              Positioned(
                top: 60,
                left: 20,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                ),
              ),
              Positioned(
                bottom: 80,
                left: 0,
                right: 0,
                child: Center(
                  child: FloatingActionButton.extended(
                    backgroundColor: Colors.cyanAccent,
                    onPressed: () {
                      Navigator.pop(context);
                      _triggerReceiptUpload();
                    },
                    label: const Text('CAPTURAR', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    icon: const Icon(Icons.camera, color: Colors.black),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
