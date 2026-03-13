from typing import Dict, Any
import logging

logger = logging.getLogger(__name__)

class MLOpsMonitor:
    """
    Monitora a saúde dos modelos de ML e qualidade dos dados.
    """
    
    @staticmethod
    def check_data_drift(baseline_stats: Dict[str, Any], current_stats: Dict[str, Any]) -> bool:
        """
        Detecta se a distribuição dos dados de entrada mudou significativamente.
        """
        # MVP: Simulação simples baseada em volume total
        drift_threshold = 0.5 # 50% de mudança
        
        b_volume = baseline_stats.get("total_volume", 0)
        c_volume = current_stats.get("total_volume", 0)
        
        if b_volume == 0: return False
        
        drift = abs(c_volume - b_volume) / b_volume
        if drift > drift_threshold:
            logger.warning(f" [MLOPS ALERT] Data Drift detectado! Desvio de {drift:.2%}")
            return True
        return False

    @staticmethod
    def check_model_accuracy(y_true: float, y_pred: float, threshold: float = 0.2) -> bool:
        """
        Detecta queda na acurácia do modelo.
        """
        if y_true == 0: return False
        
        error = abs(y_true - y_pred) / y_true
        if error > threshold:
            logger.warning(f" [MLOPS ALERT] Model Drift detectado! Erro de {error:.2%}")
            return True
        return False
