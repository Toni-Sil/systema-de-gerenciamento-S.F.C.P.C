// FIX #3: text é nullable quando isLoading=true, evitando bubble vazio
enum MessageRole { user, agent, system }

class ChatMessage {
  final String text;
  final MessageRole role;
  final DateTime timestamp;
  final bool isLoading;

  const ChatMessage({
    required this.text,
    required this.role,
    required this.timestamp,
    this.isLoading = false,
  });

  bool get isUser => role == MessageRole.user;
  bool get isAgent => role == MessageRole.agent;

  /// FIX #3: text vazio só é válido quando isLoading=true.
  /// Qualquer widget deve checar isLoading ANTES de acessar text.
  bool get hasText => !isLoading && text.isNotEmpty;

  /// Mensagem de loading do agente (typing indicator)
  factory ChatMessage.typing() => ChatMessage(
        text: '',
        role: MessageRole.agent,
        timestamp: DateTime.now(),
        isLoading: true,
      );

  /// Saudação inicial dinâmica
  factory ChatMessage.greeting(String name, {String? lowStockItem}) {
    final stock = lowStockItem != null
        ? ' O nível de estoque de **$lowStockItem** está baixo. Posso sugerir um pedido ao fornecedor?'
        : ' Como posso ajudar hoje?';
    return ChatMessage(
      text: 'Olá $name!$stock',
      role: MessageRole.agent,
      timestamp: DateTime.now(),
    );
  }
}
