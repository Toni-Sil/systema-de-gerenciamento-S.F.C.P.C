# S.F.C.P.C - Análise de Impacto nos Negócios (BIA) & Continuidade

Este documento formaliza os parâmetros de resiliência e as métricas de recuperação de desastres (Disaster Recovery) para a operação SaaS Multi-tenant focada no nicho de estofados.

## 1. Métricas de Recuperação (RTO e RPO)

Devido à natureza assíncrona orientada a eventos e à criticidade da logística física vs faturamento:

### Camada 1: Transacional (PostgreSQL) - Movimentações e Catálogo
- **RPO (Recovery Point Objective):** 5 minutos.
  - *Justificativa:* A perda de movimentações de estoque pode causar ruptura física ("furo de estoque"). Backups contínuos (WAL archiving) a cada 5m.
- **RTO (Recovery Time Objective):** 1 Hora.
  - *Justificativa:* Tempo hábil para restaurar master-slave ou instanciar novo cluster de banco sem interromper a expedição fabril significativamente.

### Camada 2: Mensageria (EventBus / Kafka)
- **RPO:** 1 Minuto (Replication Factor = 3).
- **RTO:** 15 Minutos.
  - *Mitigação:* As APIs devem possuir fallback para degradar graciosamente ou enfileirar em disco local temporariamente (circuit breaker) caso o broker caia.

### Camada 3: Inteligência e MLOps (Lakehouse)
- **RPO:** 24 Horas.
- **RTO:** 8 Horas.
  - *Justificativa:* Dados analíticos e modelos preditivos podem ser reconstruídos a partir do banco transacional sem pressa, não impactando a operação de "chão de fábrica".

---

## 2. Plano de Resposta a Incidentes (PRIC)

### Gatilhos e Classificação
- **P1 (Crítico):** Sistema indisponível para múltiplos tenants (Ex: Queda do API Gateway / Banco principal).
  - *Ação:* Acionamento imediato da Squad de SRE (Telefone/PagerDuty). Comunicação automática de "Manutenção" no portal do cliente.
- **P2 (Alto):** Atraso severo na mensageria assíncrona (Ex: Estoque físico atualizado, mas faturamento não reflete).
  - *Ação:* Escalonamento de brokers Kafka e reinício dos workers de consumo.
- **P3 (Médio):** Módulo de IA/LLM retornando timeout.
  - *Ação:* Fallback automático para navegação manual/CRUD tradicional pelos usuários até reestabelecimento da API do LLM.

---

## 3. Plano de Recuperação de Desastres (PRD)

### Cenário de Perda de Datacenter (Region Failure)
O sistema opera nativamente em Cloud (AWS/GCP) utilizando Multi-AZ. Em caso de perda total da região primária (Ex: us-east-1):
1. O tráfego (Route53/CloudFlare) é direcionado para a região Secundária (failover).
2. O Banco de Dados RDS promove a réplica global para Master.
3. Microsserviços sobem automaticamente via autoscaling rules a partir das imagens Docker no ECR.
4. **Tempo estimado para Full Recovery:** 45 Minutos.

### Cenário de Corrupção Lógica por Falha de Software (Bug Crítico)
Se um deploy corromper dados transacionais:
1. Isolar o Tenant afetado via painel Multi-tenant (bloqueio temporário).
2. Executar `point-in-time recovery` do banco de dados (restaurando dados de até 5m antes do deploy defeituoso).
3. Re-processar eventos presos em Dead Letter Queue (DLQ).
