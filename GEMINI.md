# S.F.C.P.C - Systema de Gerenciamento

## Overview
Project for a SaaS multi-tenant inventory management system with AI and LLM capabilities.

## Technical Stack
- **Backend**: Python (FastAPI/Flask)
- **Database**: PostgreSQL (with Multi-tenancy)
- **Messaging**: Kafka/RabbitMQ
- **Observability**: Prometheus, Grafana, ELK Stack
- **AI/ML**: Scikit-learn, PyTorch/TensorFlow, Unsloth (Fine-tuning)
- **LLM**: Llama-3 / Gemma (via LangChain)
- **Architecture**: Medallion Architecture (Bronze, Silver, Gold), Event-Driven Architecture (EDA)

## Multi-tenancy Decision
- **Model**: `tenant_id` per record (Scalable, requires rigorous application checks).

## Domain Model
- **Products (Sofa-Bed Niche)**: code, description, category (tecidos, espumas, madeiras, ferragens), attributes (tonalidade, densidade, metragem), unit, validity, batch, location (corredor/prateleira).
- **Movements**: entry, exit, transfer, adjustment.
- **Stock**: balance by product, batch, location.
- **Payments/Invoices**: financial inputs tied to user, tenant, and transaction (entries/exits) linked to OCR ingestion.
- **Encrypted Vault**: Isolated directories per `tenant_id` for storing signed PDFs and physical invoices strictly following LGPD.

## Coding Standards
- Use Type Hints in Python.
- Structured logging with `tenant_id` and `request_id`.
- Function Calling for structured JSON output in AI tasks.
- MCP (Model Context Protocol) for tool integration.

## Fases de Implementação (Roadmap)

### Fase 0 — Definições e Alinhamento (O "MVP de Verdade")
- **Foco Principal**: Controlar o básico: cadastro, movimentações e alertas essenciais.
- **Mapeamento**: Identificar as personas (compradores, auditores) e os fluxos de entrada, saída, ajuste e inventário.
- **KPIs Iniciais**: Definir métricas como ruptura, excesso, giro e lead time.

### Fase 1 — Fundamentos do Produto (Domínio e Dados)
- **Modelagem**: Definir entidades de produtos (código, descrição, validade, lote), movimentações e saldo atual por local.
- **Auditoria de Dados**: Corrigir erros e padronizar unidades e descrições antes da implantação para garantir que os algoritmos futuros funcionem corretamente.

### Fase 2 — Arquitetura SaaS Multi-tenant (Isolamento e Segurança)
- **Modelo de Tenancy**: Escolher entre banco por cliente, schema por cliente ou tenant_id por registro baseado em custo e escala.
- **Isolamento em Duas Camadas**: Implementar segmentação na infraestrutura (redes e chaves segregadas) e na aplicação (validação obrigatória de tenant_id em cada acesso).
- **Segurança**: Tratar microsserviços como limites de segurança com privilégio mínimo e proteger APIs com rate limiting por cliente.

### Fase 3 — Serviços, APIs e Eventos (Execução)
- **Construção**: Desenvolver microsserviços de catálogo, movimentações e alertas usando frameworks como FastAPI ou Flask.
- **Arquitetura de Eventos (EDA)**: Usar Kafka ou RabbitMQ para sincronização em tempo real entre estoque, vendas e produção.
- **Observabilidade**: Implementar os três pilares (métricas, logs estruturados e tracing distribuído) para monitorar latência e erros por cliente.

### Fase 4 — Operação, Continuidade e Resiliência
- **DevOps**: Estabelecer pipelines de CI/CD automatizados com testes de segurança e estratégias de rollout seguro (canary/blue-green).
- **Continuidade (BIA/PCN)**: Definir o RTO e RPO por processo e formalizar planos de resposta a incidentes (PRIC) e recuperação de desastres (PRD).
- **Anti-Dominó**: Garantir que a falha em um cliente não afete os demais através de circuit breakers e isolamento de filas.

### Fase 5 — Inteligência (ML) e MLOps
- **Pipeline de ML**: Capturar histórico de vendas para treinar modelos de previsão de demanda e classificação (Curva ABC).
- **Monitoramento de Drift**: Acompanhar a queda de acurácia (model drift) e mudanças no perfil dos dados (data drift), automatizando o retreino periódico.

### Fase 6 — Interface por Linguagem Natural (LLM Agêntico) e Visão (OCR)
- **Operação via Chat**: Integrar modelos como Llama-3 ou Gemma para comandos como "dar entrada de 10 unidades do item X".
- **Validação**: Utilizar LangChain e System Prompts (OWASP, Json Estrito) para garantir que a IA gere saídas em JSON estruturado para as APIs.
- **Ingestão Multimodal (OCR)**: Integrar Tesseract/Vision API para ler notas fiscais (PDFs/Imagens), extrair {item, qtde, valor} e submeter ao AgentOrchestrator.
- **Fine-Tuning (Unsloth)**: Planejar ajuste fino em modelos locais para fixar vocabulário logístico específico da operação do S.F.C.P.C.

### Fase 7 — Governança e IA Responsável
- **Conformidade LGPD**: Alinhar o sistema à LGPD implementando Criptografia de Dados Financeiros (Notas Fiscais em Repouso/Trânsito) e políticas de retenção.
- **Supervisão Humana**: Implementar aprovação manual para ações de alto risco identificadas pela IA, como compras automáticas ou descartes.
- **ROI e Custos**: Monitorar o retorno financeiro com Dashboards Inteligentes gerados pela IA cruzando o Módulo Financeiro (Margem, Custo de Armazenagem) com rupturas de estoque.

### Fase 8 — Dashboards Financeiros e Alertas
- **Resumo Inteligente**: Módulo de IA consumindo a Lakehouse (Gold Layer) para sumarizar ganhos e perdas operacionais automaticamente.
- **Alertas Preditivos do Gestor**: Notificar líderes em tempo real quando gastos processados do OCR ou movimentações excederem limites anômalos.
