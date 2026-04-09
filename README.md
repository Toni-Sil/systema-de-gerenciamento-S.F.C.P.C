# 🛋️ S.F.C.P.C — Sistema de Gestão de Estoque

> **Sistema de gerenciamento de estoque inteligente para empresas de produção de sofá-camas, com ML, OCR e agente WhatsApp integrado.**

[![CI](https://github.com/Toni-Sil/systema-de-gerenciamento-S.F.C.P.C/actions/workflows/ci.yml/badge.svg)](https://github.com/Toni-Sil/systema-de-gerenciamento-S.F.C.P.C/actions/workflows/ci.yml)
[![Python 3.12](https://img.shields.io/badge/Python-3.12-blue?logo=python)](https://www.python.org/)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.115+-green?logo=fastapi)](https://fastapi.tiangolo.com/)
[![React 18](https://img.shields.io/badge/React-18-61DAFB?logo=react)](https://react.dev/)
[![Tailwind CSS](https://img.shields.io/badge/Tailwind-3-38BDF8?logo=tailwindcss)](https://tailwindcss.com/)
[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker)](https://docs.docker.com/compose/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## 📋 Índice

- [Visão Geral](#visão-geral)
- [Stack Tecnológico](#stack-tecnológico)
- [Funcionalidades](#funcionalidades)
- [Arquitetura](#arquitetura)
- [Início Rápido](#início-rápido)
- [Variáveis de Ambiente](#variáveis-de-ambiente)
- [Estrutura do Projeto](#estrutura-do-projeto)
- [Testes](#testes)
- [Deploy em Produção](#deploy-em-produção)
- [Contribuição](#contribuição)

---

## 🌟 Visão Geral

O **S.F.C.P.C** é um ERP leve e modular para gestão de estoque industrial, projetado para empresas de manufatura de sofás. Combina um backend Python assíncrono de alta performance com um frontend React moderno, inteligência artificial para forecasting de demanda e automação via WhatsApp.

---

## 🛠️ Stack Tecnológico

| Camada | Tecnologia |
|--------|------------|
| **Frontend** | React 18 + Vite + Tailwind CSS + shadcn/ui |
| **Backend** | FastAPI + SQLAlchemy 2 (async) + Alembic |
| **Banco de Dados** | PostgreSQL 16 |
| **Mensageria** | RabbitMQ 3 (EDA) |
| **ML/IA** | scikit-learn · Gemini Vision (OCR) |
| **Observability** | Prometheus + Grafana |
| **Deploy** | Docker Compose · Dokploy |
| **CI/CD** | GitHub Actions |

---

## ✨ Funcionalidades

- 📦 **Gestão de Estoque** — CRUD completo com movimentações e histórico
- 📊 **Dashboard Analítico** — KPIs em tempo real, gráficos de tendência
- 🤖 **Agente WhatsApp** — Consultas e alertas via Evolution API
- 🔮 **Forecasting ML** — Previsão de demanda com scikit-learn
- 🏷️ **Análise ABC** — Classificação automática de produtos por valor
- 📷 **OCR de Notas** — Leitura automática de notas fiscais via Gemini Vision
- 🏢 **Multi-tenant** — Isolamento completo por empresa
- 📈 **Relatórios Dinâmicos** — Exportação instantânea de Estoque e Financeiro para CSV (Excel)
- 📡 **Prometheus + Grafana** — Métricas de performance e negócio

---

## 🏗️ Arquitetura

```
┌─────────────────────────────────────────────────────────────────┐
│                         FRONTEND (React/Vite)                    │
│          Dashboard · Estoque · Financeiro · Relatórios           │
└──────────────────────┬──────────────────────────────────────────┘
                       │ HTTP / REST
┌──────────────────────▼──────────────────────────────────────────┐
│                      BACKEND (FastAPI)                           │
│  Auth · Stock · Financial · ML Pipeline · OCR · WhatsApp Agent  │
└────┬──────────────┬──────────────┬────────────────┬─────────────┘
     │              │              │                │
  PostgreSQL    RabbitMQ      Gemini API      Evolution API
  (dados)       (eventos)     (IA/OCR)        (WhatsApp)
     │
  Prometheus ──► Grafana
```

**Padrão Medallion** aplicado aos dados:
```
Bronze (raw) → Silver (validated) → Gold (aggregated/ML-ready)
```

---

## 🚀 Início Rápido

### Pré-requisitos
- Docker 24+ e Docker Compose v2
- Git

### 1. Clone o repositório
```bash
git clone https://github.com/Toni-Sil/systema-de-gerenciamento-S.F.C.P.C.git
cd systema-de-gerenciamento-S.F.C.P.C
```

### 2. Configure as variáveis de ambiente
```bash
cp .env.example .env
# Edite o .env com suas credenciais
```

### 3. Suba os serviços
```bash
docker compose up -d
```

### 4. Acesse
| Serviço | URL |
|---------|-----|
| **Frontend** | http://localhost |
| **API Docs** | http://localhost:8000/docs |
| **Grafana** | http://localhost:3001 (admin/admin) |
| **Prometheus** | http://localhost:9090 |
| **RabbitMQ** | http://localhost:15672 (guest/guest) |

---

## 🔐 Variáveis de Ambiente

Veja o arquivo [`.env.example`](.env.example) para a lista completa. As principais:

| Variável | Descrição | Exemplo |
|----------|-----------|--------|
| `JWT_SECRET_KEY` | Chave secreta JWT | `openssl rand -hex 32` |
| `DATABASE_URL` | URL do PostgreSQL | `postgresql+asyncpg://...` |
| `GEMINI_API_KEY` | API Key do Gemini (OCR/LLM) | `AIza...` |
| `POSTGRES_PASSWORD` | Senha do banco | `strongpassword` |
| `ALLOWED_ORIGINS` | CORS origins | `http://localhost` |

---

## 📁 Estrutura do Projeto

```
systema-de-gerenciamento-S.F.C.P.C/
├── src/                        # Backend FastAPI
│   ├── auth/                   # JWT + multi-tenant
│   ├── db/                     # ORM models + sessions
│   ├── services/               # Business logic
│   ├── ml/                     # ABC analysis + forecasting
│   ├── llm/                    # Gemini agent
│   ├── vision/                 # OCR service
│   ├── messaging/              # RabbitMQ producer
│   ├── middleware/             # Rate limiter + tenant
│   └── routes/                 # API endpoints
├── frontend/                   # React + Vite + shadcn
│   ├── src/
│   │   ├── components/         # UI components
│   │   ├── pages/              # Dashboard, Stock, etc.
│   │   ├── hooks/              # Custom hooks
│   │   └── lib/                # Utils + API client
│   ├── Dockerfile              # Multi-stage build
│   └── nginx.conf              # Production server
├── migrations/                 # Alembic migrations
├── tests/                      # pytest test suite
├── infra/                      # Prometheus + Grafana
├── data/                       # Bronze/Silver/Gold data
├── docs/                       # Architecture docs
├── docker-compose.yml          # All services
├── Dockerfile                  # Backend image
└── .env.example                # Environment template
```

---

## 🧪 Testes

### Backend (pytest)
```bash
# Instalar dependências
pip install -r requirements.txt

# Rodar todos os testes
pytest tests/ -v --cov=src --cov-report=term-missing

# Rodar teste específico
pytest tests/test_stock_service.py -v
```

### Frontend (Vitest)
```bash
cd frontend
npm install

# Testes unitários
npm run test

# Testes E2E (Playwright)
npm run test:e2e
```

---

## 🌐 Deploy em Produção

### Dokploy (Hostinger VPS)
```bash
# 1. Configure as variáveis no painel Dokploy
# 2. Conecte o repositório GitHub
# 3. Deploy automático via webhook no push para main
```

### Manual
```bash
docker compose -f docker-compose.yml up -d --build
```

---

## 🤝 Contribuição

1. Fork o repositório
2. Crie uma branch: `git checkout -b feat/minha-feature`
3. Commit: `git commit -m 'feat: adiciona minha feature'`
4. Push: `git push origin feat/minha-feature`
5. Abra um Pull Request

Convenção de commits: [Conventional Commits](https://www.conventionalcommits.org/)

---

<p align="center">
  Feito com ❤️ por <a href="https://github.com/Toni-Sil">Toni Sil</a>
</p>
