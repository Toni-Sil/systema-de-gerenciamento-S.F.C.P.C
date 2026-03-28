# Guia de Deploy

## Dokploy (Hostinger VPS)

### 1. Pré-requisitos
- VPS com Docker instalado
- Dokploy configurado
- Domínio apontado para o servidor

### 2. Variáveis de Ambiente no Dokploy

Configure no painel do Dokploy:

```env
JWT_SECRET_KEY=<gerado com: openssl rand -hex 32>
POSTGRES_USER=sfcpc
POSTGRES_PASSWORD=<senha-forte>
POSTGRES_DB=sfcpc
GEMINI_API_KEY=<sua-chave-gemini>
ALLOWED_ORIGINS=https://seudominio.com
LLM_PROVIDER=gemini
```

### 3. Deploy

O deploy é automático via webhook GitHub Actions ao fazer push para `main`.

Para deploy manual:
```bash
docker compose -f docker-compose.yml pull
docker compose -f docker-compose.yml up -d --build
docker compose exec api alembic upgrade head
```

### 4. Verificação
```bash
docker compose ps
docker compose logs api --tail=50
curl http://localhost:8000/health
```

### 5. Rollback
```bash
docker compose down
git checkout <commit-anterior>
docker compose up -d --build
```

## Serviços e Portas

| Serviço | Porta | Uso |
|---------|-------|-----|
| Frontend | 80 | Interface web |
| Backend API | 8000 | REST API |
| PostgreSQL | 5432 | Banco (interno) |
| RabbitMQ | 5672 / 15672 | Mensageria |
| Prometheus | 9090 | Métricas |
| Grafana | 3001 | Dashboards |
