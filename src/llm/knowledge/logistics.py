BUSINESS_NICHE = "Loja de Sofás-Cama específicos para Cabines de Caminhões."

TRUCK_MODELS = {
    "Volvo": ["FH 540", "FH 460", "VM 290", "VM 360"],
    "Volkswagen": [
        "Delivery 11.180", "Delivery 9.180", "Delivery 13.180", 
        "Constellation 26.260", "Constellation 17.210", "Constellation 31.320", 
        "Meteor 28.480", "eDelivery 14", "eDelivery 11"
    ],
    "Mercedes-Benz": [
        "Accelo 1017", "Accelo 817", "Atego 1719", "Atego 2429", 
        "Actros 2548", "Sprinter 417", "Sprinter 517"
    ],
    "Scania": ["R450", "R460", "R540", "R560"],
    "DAF": ["XF 530", "XF 480", "CF 310"],
}

# --- Novos Detalhes de Produção de Sofá-Cama ---
MATERIAL_SPECIFICS = {
    "Espumas": {
        "Densidades": ["D28 (Macio/Encosto)", "D33 (Médio/Assento)", "D45 (Firme/Base)"],
        "Unidade Comum": "Bloco ou Metro Linear (ML)",
        "Dica": "Sempre verifique se a densidade está no pedido para evitar erro de montagem."
    },
    "Tecidos": {
        "Tipos": ["Suede Animale", "Chenille", "Corino (Couro Sintético)", "Malha"],
        "Unidade Comum": "Metros (m)",
        "Largura Padrão": "1.40m ou 1.60m"
    },
    "Ferragens": {
        "Itens": ["Articulação Manual", "Trilho Deslizante", "Pé de Ferro", "Grampos 80/10"],
        "Unidade Comum": "Par ou Caixa"
    }
}

def get_truck_knowledge_hint() -> str:
    """Retorna uma string formatada com o conhecimento de caminhões e materiais para o Prompt."""
    hint = f"NICHE DE NEGÓCIO: {BUSINESS_NICHE}\n"
    hint += "CONHECIMENTO DE PRODUTO (Sofá-Cama):\n"
    for cat, info in MATERIAL_SPECIFICS.items():
        hint += f"- {cat}: {', '.join(info.get('Densidades', info.get('Tipos', info.get('Itens', []))))} | Unid: {info['Unidade Comum']}\n"
    
    hint += "\nFROTA COMPATÍVEL (Caminhões Brasil):\n"
    for brand, models in list(TRUCK_MODELS.items())[:4]: # Top 4 para não poluir
        hint += f"- {brand}: {', '.join(models)}\n"
    return hint
