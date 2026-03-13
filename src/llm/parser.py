from pydantic import BaseModel, Field, ValidationError
from typing import Dict, Any, Optional

class LLMIntentSchema(BaseModel):
    """
    Simula um PydanticOutputParser do LangChain.
    Garante que qualquer resposta do modelo LLM esteja perfeitamente estruturada.
    """
    action: str = Field(description="A ação que o agente deve realizar (ex: Entry, Exit, RegisterExpense).")
    params: Optional[Dict[str, Any]] = Field(default=None, description="Parâmetros extraídos da intenção.")
    status: str = Field(description="Status da intenção (success, failed, needs_approval).")
    motivo: Optional[str] = Field(default=None, description="Justificativa heurística ou de falha do modelo.")
    data: Optional[Any] = Field(default=None, description="Payload de dados, ex: lista de saldos.")
    new_balance: Optional[float] = Field(default=None, description="Saldo resultante após movimentação.")

class LLMOuputValidator:
    """
    Classe para validar e formatar a saída de texto livre do LLM (Gemma/Llama-3)
    e forçá-la no modelo estrito do LangChain.
    """
    @staticmethod
    def validate_and_parse(raw_json: str) -> dict:
        import json
        try:
            parsed = json.loads(raw_json)
            # Validates against the Schema. If the LLM halucinates keys, it drops or fails.
            validated = LLMIntentSchema(**parsed)
            return validated.model_dump()
        except ValidationError as e:
            return {
                "action": "ParseError",
                "status": "failed",
                "motivo": f"LLM Alucinação detectada (Quebra de Contrato JSON): {e}"
            }
        except json.JSONDecodeError:
            return {
                "action": "FormatError",
                "status": "failed",
                "motivo": "LLM não respeitou o System Prompt de retornar JSON puro."
            }
