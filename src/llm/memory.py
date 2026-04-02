"""Módulo de memória de contexto conversacional para o AgentOrchestrator.

Implementa um histórico de sessão por tenant (multi-turn) usando uma
estrutura simples de lista em memória, pronta para ser trocada por
Redis ou outro backend persistente sem alterar a interface.
"""
from collections import deque
from typing import Deque, Dict, List
from uuid import UUID
import threading

# Tamanho máximo do histórico por sessão (evita crescimento ilimitado)
MAX_HISTORY = 20

# Store global: { str(tenant_id): deque([{"role": "user"|"assistant", "content": str}]) }
_store: Dict[str, Deque[dict]] = {}
_lock = threading.Lock()


def _key(tenant_id: UUID) -> str:
    return str(tenant_id)


def add_message(tenant_id: UUID, role: str, content: str) -> None:
    """Adiciona uma mensagem ao histórico da sessão do tenant."""
    k = _key(tenant_id)
    with _lock:
        if k not in _store:
            _store[k] = deque(maxlen=MAX_HISTORY)
        _store[k].append({"role": role, "content": content})


def get_history(tenant_id: UUID) -> List[dict]:
    """Retorna o histórico completo da sessão do tenant."""
    k = _key(tenant_id)
    with _lock:
        return list(_store.get(k, []))


def clear_history(tenant_id: UUID) -> None:
    """Limpa o histórico da sessão (ex: logout ou comando 'resetar conversa')."""
    k = _key(tenant_id)
    with _lock:
        if k in _store:
            del _store[k]


def get_context_summary(tenant_id: UUID) -> str:
    """Retorna um resumo textual do contexto recente para injetar no prompt do LLM."""
    history = get_history(tenant_id)
    if not history:
        return ""
    lines = []
    for msg in history[-6:]:  # últimas 6 trocas para não inflar o prompt
        prefix = "Usuário" if msg["role"] == "user" else "Assistente"
        lines.append(f"{prefix}: {msg['content']}")
    return "\n".join(lines)


def get_last_product_context(tenant_id: UUID) -> str | None:
    """Extrai o último código de produto mencionado no histórico (para resolver referências como 'esse produto')."""
    history = get_history(tenant_id)
    for msg in reversed(history):
        content = msg.get("content", "")
        # Procura padrão de código como 'TEC-001', 'ESP-023', etc.
        import re
        match = re.search(r'\b([A-Z]{2,6}-\d{2,6})\b', content)
        if match:
            return match.group(1)
    return None
