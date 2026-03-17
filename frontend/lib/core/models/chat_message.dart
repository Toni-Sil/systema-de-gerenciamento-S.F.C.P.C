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

  bool get hasText => !isLoading && text.isNotEmpty;

  factory ChatMessage.typing() => ChatMessage(
        text: '',
        role: MessageRole.agent,
        timestamp: DateTime.now(),
        isLoading: true,
      );

  /// Saudação enriquecida com resumo financeiro e de estoque
  factory ChatMessage.greeting(
    String name, {
    String? lowStockItem,
    String? financialAlert,  // vencimentos próximos
    String? restockAlert,    // custo de reposição
  }) {
    final parts = <String>['Olá, $name!'];

    if (financialAlert != null && financialAlert.isNotEmpty) {
      parts.add(financialAlert);
    }
    if (restockAlert != null && restockAlert.isNotEmpty) {
      parts.add(restockAlert);
    }
    if (financialAlert == null && restockAlert == null) {
      if (lowStockItem != null) {
        parts.add(
            'O nível de estoque de **$lowStockItem** está baixo. Posso sugerir um pedido ao fornecedor?');
      } else {
        parts.add('Tudo em ordem por aqui. Como posso ajudar hoje?');
      }
    }

    return ChatMessage(
      text: parts.join(' '),
      role: MessageRole.agent,
      timestamp: DateTime.now(),
    );
  }
}
