from typing import List, Dict, Any

class ABCAnalysis:
    """
    Implementação da Curva ABC baseada no Princípio de Pareto (Pure Python).
    """
    
    @staticmethod
    def calculate(products_data: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """
        Classifica produtos em A (80% valor/volume), B (15%), C (5%).
        """
        if not products_data:
            return []
            
        # Ordena por total_balance descrescente
        sorted_data = sorted(products_data, key=lambda x: x["total_balance"], reverse=True)
        
        total_volume = sum(item["total_balance"] for item in sorted_data)
        if total_volume == 0:
            for item in sorted_data: item["abc_class"] = "C"
            return sorted_data
            
        running_sum = 0
        for item in sorted_data:
            running_sum += item["total_balance"]
            cumulative_perc = (running_sum / total_volume) * 100
            
            if cumulative_perc <= 80:
                item["abc_class"] = "A"
            elif cumulative_perc <= 95:
                item["abc_class"] = "B"
            else:
                item["abc_class"] = "C"
                
            item["cumulative_perc"] = cumulative_perc
            
        return sorted_data
