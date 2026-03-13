# Plano de Continuidade de Negócios (PCN) e BIA — S.F.C.P.C

Este documento define os parâmetros de resiliência para o sistema multi-tenant de gestão de estoque.

## 1. BIA (Business Impact Analysis)

| Processo Crítico | Impacto (Financeiro/Operacional) | Dependências | RTO | RPO |
| :--- | :--- | :--- | :--- | :--- |
| Baixa de Estoque (Saída) | Alto - Interrupção de vendas/expedição | PostgreSQL, API | 1 hora | 0 (Zero Loss) |
| Registro de Entrada | Médio - Atraso no recebimento | PostgreSQL | 4 horas | 15 min |
| Alertas de Validade | Baixo/Médio - Risco de perda | EDA (Kafka/Rabbit) | 8 horas | 1 hora |

## 2. Estratégia de Continuidade (PCN)

### PRIC (Plano de Resposta a Incidentes Críticos)
- **Papéis**: Time DevOps (Infra), Gestor de Operações (Comunicação).
- **Gatilhos**: Latência > 5s por 5 min; Taxa de erro > 5% global ou > 10% por tenant.
- **Comunicação**: Status page automática e canal slack de emergência.

### PRD (Plano de Recuperação de Desastres)
1. **Restauração de Banco**: Backup Point-in-Time (PITR) via PostgreSQL (AWS RDS/GCP Cloud SQL).
2. **Ordem de Subida**: API Gateway -> Auth -> Catálogo -> Movimentações -> EDA Consumers.
3. **Validação**: Teste de "Sanity Check" via health-checks automáticos.

## 3. Resiliência Multi-tenant
- **Isolamento de Carga**: Implementado via Rate Limiting por tenant (60 RPM base).
- **Circuit Breakers**: Implementar no Gateway para evitar que um serviço lento derrube o sistema.
