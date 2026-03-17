import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:frontend/core/models/chat_message.dart';
import 'package:frontend/core/models/inventory_item.dart';
import 'package:frontend/core/providers/user_provider.dart';
import 'package:frontend/core/providers/operational_provider.dart';
import 'package:frontend/core/providers/agenda_provider.dart';
import 'package:frontend/core/services/api_service.dart';
import 'package:frontend/presentation/screens/barcode_scanner_screen.dart';
import 'package:frontend/presentation/theme/app_theme.dart';

class AgentScreen extends StatefulWidget {
  const AgentScreen({super.key});

  @override
  State<AgentScreen> createState() => _AgentScreenState();
}

class _AgentScreenState extends State<AgentScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final List<ChatMessage> _messages = [];
  bool _isSending = false;
  bool _isProcessingOcr = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final userProvider = context.read<UserProvider>();
      final opProvider = context.read<OperationalProvider>();
      final lowStock = opProvider.lowStockItems.firstOrNull;
      setState(() {
        _messages.add(ChatMessage.greeting(
          userProvider.adminName,
          lowStockItem: lowStock?.description,
        ));
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // FIX #1: injeta resumo da agenda como context no prompt do agente
  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isSending) return;
    _controller.clear();
    _focusNode.requestFocus();

    // Captura contexto da agenda antes de qualquer await
    final agendaSummary = context.read<AgendaProvider>().todaySummaryForAgent;

    setState(() {
      _messages.add(ChatMessage(
        text: text.trim(),
        role: MessageRole.user,
        timestamp: DateTime.now(),
      ));
      _messages.add(ChatMessage.typing());
      _isSending = true;
    });
    _scrollToBottom();

    try {
      final res = await ApiService.instance.sendAgentMessage(
        text.trim(),
        context: agendaSummary,
      );
      final reply = res['reply'] as String? ??
          res['message'] as String? ??
          'Entendido. Processando sua solicitação…';

      if (mounted) {
        setState(() {
          _messages.removeLast();
          _messages.add(ChatMessage(
            text: reply,
            role: MessageRole.agent,
            timestamp: DateTime.now(),
          ));
          _isSending = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.removeLast();
          _messages.add(ChatMessage(
            text:
                'Sem conexão com o servidor. Verifique a URL da API nas Configurações.',
            role: MessageRole.agent,
            timestamp: DateTime.now(),
          ));
          _isSending = false;
        });
        _scrollToBottom();
      }
    }
  }

  void _openScanner() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BarcodeScannerScreen(
          onDetected: (code) {
            HapticFeedback.mediumImpact();
            _sendMessage(
                'Escanei o código: $code. Qual é o status deste item no estoque?');
          },
        ),
      ),
    );
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
        decoration: BoxDecoration(
          color:
              Theme.of(ctx).colorScheme.surface.withValues(alpha: 0.97),
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
              top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2)),
            ),
            const Text('Anexar ao Agente',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.white)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _attachOption(ctx,
                    icon: Icons.qr_code_scanner,
                    label: 'Escanear\nCódigo',
                    color: AppColors.neonCyan,
                    onTap: () {
                      Navigator.pop(ctx);
                      _openScanner();
                    }),
                _attachOption(ctx,
                    icon: Icons.camera_alt,
                    label: 'Nota Fiscal\nCâmera',
                    color: AppColors.neonPurple,
                    onTap: () {
                      Navigator.pop(ctx);
                      _processOcr(isDocument: false);
                    }),
                _attachOption(ctx,
                    icon: Icons.attach_file,
                    label: 'PDF /\nDocumento',
                    color: AppColors.neonAmber,
                    onTap: () {
                      Navigator.pop(ctx);
                      _processOcr(isDocument: true);
                    }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _attachOption(BuildContext ctx,
      {required IconData icon,
      required String label,
      required Color color,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          Container(
            width: 68, height: 68,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 10),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Future<void> _processOcr({required bool isDocument}) async {
    setState(() => _isProcessingOcr = true);
    await Future.delayed(Duration(seconds: isDocument ? 2 : 3));
    if (!mounted) return;
    setState(() => _isProcessingOcr = false);
    _showOcrConfirmDialog(isDocument: isDocument);
  }

  void _showOcrConfirmDialog({required bool isDocument}) {
    final opProvider = context.read<OperationalProvider>();
    const extractedCode = 'TECH-WH-01';
    const extractedDesc = 'Tecido White Tech 2026';
    const extractedQty = 100.0;
    const extractedUnit = 'UN';
    final exists = opProvider.exists(extractedCode);

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: Theme.of(ctx)
              .colorScheme
              .surface
              .withValues(alpha: 0.85),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
                color: Colors.white.withValues(alpha: 0.18)),
          ),
          title: Row(
            children: [
              Icon(
                isDocument
                    ? Icons.picture_as_pdf
                    : Icons.document_scanner,
                color: AppColors.neonCyan,
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(isDocument
                  ? 'Documento Analisado (IA)'
                  : 'Comprovante Extraído (IA)'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ocrRow('Item', extractedDesc),
              _ocrRow('Código', extractedCode),
              _ocrRow('Quantidade', '$extractedQty $extractedUnit'),
              _ocrRow('Origem',
                  isDocument ? 'PDF / Nota Online' : 'Captura Câmera'),
              if (!exists) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color:
                            Colors.orangeAccent.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: Colors.orangeAccent, size: 16),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Item não encontrado no estoque atual.',
                          style: TextStyle(
                              color: Colors.orangeAccent,
                              fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                exists
                    ? 'Deseja dar entrada de $extractedQty $extractedUnit no saldo atual?'
                    : 'Deseja cadastrar este item automaticamente?',
                style: const TextStyle(
                    color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Ignorar',
                  style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    exists ? AppColors.neonCyan : Colors.orangeAccent,
                foregroundColor: AppColors.bgDeep,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                if (exists) {
                  opProvider.updateBalance(
                      extractedCode, extractedQty, 'Entrada via OCR');
                  _addAgentMessage(
                      'Entrada de ${extractedQty.toInt()} $extractedUnit registrada para "$extractedDesc" via OCR. Saldo atualizado ✔️');
                } else {
                  opProvider.addItem(const InventoryItem(
                    code: extractedCode,
                    category: 'Tecidos',
                    description: extractedDesc,
                    qty: extractedQty,
                    unit: extractedUnit,
                    location: 'Triagem / Entrada',
                  ));
                  _addAgentMessage(
                      'Novo item "$extractedDesc" cadastrado com $extractedQty $extractedUnit. Localização: Triagem ✔️');
                }
              },
              child: Text(exists ? 'Dar Entrada' : 'Cadastrar',
                  style:
                      const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ocrRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text('$label: ',
              style: const TextStyle(
                  color: AppColors.textLow,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    color: AppColors.textHigh, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  void _addAgentMessage(String text) {
    if (!mounted) return;
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        role: MessageRole.agent,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollCtrl,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            itemCount: _messages.length,
            itemBuilder: (ctx, i) => _buildBubble(_messages[i]),
          ),
        ),
        if (_isProcessingOcr)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.bgSurface,
            child: const Row(
              children: [
                SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.neonCyan),
                ),
                SizedBox(width: 12),
                Text('Processando OCR com IA…',
                    style: TextStyle(
                        color: AppColors.neonCyan, fontSize: 12)),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
                top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.08))),
          ),
          child: Row(
            children: [
              IconButton(
                icon:
                    const Icon(Icons.add_circle_outline, size: 26),
                color: AppColors.neonCyan,
                onPressed: _showAttachmentMenu,
                tooltip: 'Anexar',
              ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  textInputAction: TextInputAction.send,
                  onSubmitted: _sendMessage,
                  decoration: const InputDecoration(
                    hintText: 'Perguntar ao Agente…',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: _isSending
                    ? const SizedBox(
                        key: ValueKey('loading'),
                        width: 24, height: 24,
                        child: Padding(
                          padding: EdgeInsets.all(4),
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.neonCyan),
                        ),
                      )
                    : IconButton(
                        key: const ValueKey('send'),
                        icon: const Icon(Icons.send,
                            color: AppColors.neonCyan),
                        onPressed: () =>
                            _sendMessage(_controller.text),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBubble(ChatMessage msg) {
    if (msg.isLoading) return _buildTypingIndicator();
    final isUser = msg.isUser;
    final time =
        '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}';
    return Align(
      alignment:
          isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser
              ? Theme.of(context)
                  .primaryColor
                  .withValues(alpha: 0.85)
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: isUser
                ? const Radius.circular(18)
                : Radius.zero,
            bottomRight: isUser
                ? Radius.zero
                : const Radius.circular(18),
          ),
          border: isUser
              ? null
              : Border.all(
                  color:
                      AppColors.neonCyan.withValues(alpha: 0.15)),
        ),
        child: Column(
          crossAxisAlignment: isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(msg.text,
                style: TextStyle(
                  color: isUser ? Colors.white : Colors.white70,
                  fontSize: 14,
                  height: 1.45,
                )),
            const SizedBox(height: 4),
            Text(time,
                style: TextStyle(
                  fontSize: 10,
                  color: isUser
                      ? Colors.white.withValues(alpha: 0.5)
                      : AppColors.textLow,
                )),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
          ),
          border: Border.all(
              color: AppColors.neonCyan.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            3,
            (i) => _BouncingDot(
                delay: Duration(milliseconds: i * 180)),
          ),
        ),
      ),
    );
  }
}

// FIX #3: _BouncingDot sem repeat+forward conflitantes
class _BouncingDot extends StatefulWidget {
  final Duration delay;
  const _BouncingDot({required this.delay});

  @override
  State<_BouncingDot> createState() => _BouncingDotState();
}

class _BouncingDotState extends State<_BouncingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _anim = Tween<double>(begin: 0, end: -6).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    // FIX: inicia delayed sem chamar forward() depois de repeat()
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        transform: Matrix4.translationValues(0, _anim.value, 0),
        width: 7, height: 7,
        decoration: BoxDecoration(
          color: AppColors.neonCyan.withValues(alpha: 0.7),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
