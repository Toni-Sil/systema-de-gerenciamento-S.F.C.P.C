from typing import List, Dict, Any
from datetime import datetime

class DemandForecasting:
    """
    Previsão de demanda simples baseada em média móvel (Pure Python).
    """
    
    @staticmethod
    def predict_next_period(movement_history: List[Dict[str, Any]], days: int = 30) -> Dict[str, float]:
        """
        Prediz a demanda esperada para os próximos 'days' dias.
        """
        if not movement_history:
            return {}
            
        # Filtra apenas saídas e agrupa por produto
        exits = [m for m in movement_history if m["type"] == "EXIT"]
        if not exits:
            return {}
            
        product_totals = {}
        min_date = None
        max_date = None
        
        for m in exits:
            pid = str(m["product_id"])
            product_totals[pid] = product_totals.get(pid, 0) + m["quantity"]
            
            dt = m["created_at"]
            if min_date is None or dt < min_date: min_date = dt
            if max_date is None or dt > max_date: max_date = dt
            
        # Calcula intervalo de dias no histórico
        if min_date == max_date:
            time_delta = 1
        else:
            time_delta = (max_date - min_date).days + 1
            
        predictions = {}
        for pid, total in product_totals.items():
            daily_avg = total / time_delta
            raw_prediction = daily_avg * days
            
            # Apply Niche Rules (Sofa-bed safety stock padding)
            # Extracted from the history if available, else defaulting to basic prediction
            category = None
            for m in exits:
                if str(m["product_id"]) == pid:
                    # In a real app we'd fetch the product details from DB or Gold Layer cache
                    # For MVP simulation, we look at the raw_prediction logic rules
                    pass
                    
            # Simulating specific domain logic rules:
            padding = 1.0 # 0% by default
            
            # If we had the category injected in movement history we could do:
            # if category == "TECIDOS": padding = 1.10
            # elif category == "ESPUMAS": padding = 1.05
            
            predictions[pid] = round(raw_prediction * padding, 2)
            
        return predictions
