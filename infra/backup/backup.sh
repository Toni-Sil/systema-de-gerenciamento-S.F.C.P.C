#!/usr/bin/env bash
# =============================================================================
# S.F.C.P.C — Backup automático do PostgreSQL
#
# O que faz:
#   1. Gera um dump comprimido do banco dentro do container Docker
#   2. Salva em /var/backups/sfcpc/ com data/hora no nome
#   3. Apaga backups mais antigos que RETENTION_DAYS dias
#   4. (Opcional) Envia para pasta remota via rsync se REMOTE_BACKUP_PATH estiver
#      configurado no .env
#
# Como usar manualmente:
#   chmod +x infra/backup/backup.sh
#   sudo ./infra/backup/backup.sh
#
# Para agendar automaticamente, rode:
#   sudo ./infra/backup/setup_cron.sh
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuração — edite ou exporte as variáveis antes de rodar
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Carrega variáveis do .env se existir
if [ -f "$PROJECT_ROOT/.env" ]; then
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
fi

POSTGRES_USER="${POSTGRES_USER:-sfcpc}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-sfcpc}"
POSTGRES_DB="${POSTGRES_DB:-sfcpc}"
CONTAINER_NAME="${POSTGRES_CONTAINER:-sfcpc_db}"
BACKUP_DIR="${BACKUP_DIR:-/var/backups/sfcpc}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"
REMOTE_BACKUP_PATH="${REMOTE_BACKUP_PATH:-}"  # ex: user@servidor:/backups/sfcpc

# ---------------------------------------------------------------------------
# Funções auxiliares
# ---------------------------------------------------------------------------
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
err() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERRO: $*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Verificações
# ---------------------------------------------------------------------------
command -v docker >/dev/null 2>&1 || err "Docker não encontrado."
docker inspect "$CONTAINER_NAME" >/dev/null 2>&1 || err "Container '$CONTAINER_NAME' não está rodando. Rode: docker compose up -d db"

# ---------------------------------------------------------------------------
# Criar diretório de backup
# ---------------------------------------------------------------------------
mkdir -p "$BACKUP_DIR"

# ---------------------------------------------------------------------------
# Gerar nome do arquivo com timestamp
# ---------------------------------------------------------------------------
TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"
FILENAME="sfcpc_backup_${TIMESTAMP}.sql.gz"
FILEPATH="${BACKUP_DIR}/${FILENAME}"

# ---------------------------------------------------------------------------
# Executar pg_dump dentro do container e comprimir
# ---------------------------------------------------------------------------
log "Iniciando backup do banco '$POSTGRES_DB' no container '$CONTAINER_NAME'..."

docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" "$CONTAINER_NAME" \
    pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
    --format=plain \
    --no-owner \
    --no-acl \
    --verbose \
    2>/tmp/sfcpc_pg_dump.log \
    | gzip > "$FILEPATH"

# Verifica se o arquivo foi criado e tem tamanho > 0
[ -s "$FILEPATH" ] || err "Backup gerado está vazio. Verifique /tmp/sfcpc_pg_dump.log"

FILESIZE=$(du -sh "$FILEPATH" | cut -f1)
log "✅ Backup criado: $FILEPATH ($FILESIZE)"

# ---------------------------------------------------------------------------
# Remover backups antigos
# ---------------------------------------------------------------------------
log "Removendo backups mais antigos que $RETENTION_DAYS dias..."
OLD_COUNT=$(find "$BACKUP_DIR" -name "sfcpc_backup_*.sql.gz" -mtime +"$RETENTION_DAYS" | wc -l)
find "$BACKUP_DIR" -name "sfcpc_backup_*.sql.gz" -mtime +"$RETENTION_DAYS" -delete
log "$OLD_COUNT arquivo(s) antigo(s) removido(s)."

# ---------------------------------------------------------------------------
# Listar backups existentes
# ---------------------------------------------------------------------------
TOTAL=$(find "$BACKUP_DIR" -name "sfcpc_backup_*.sql.gz" | wc -l)
log "Total de backups disponíveis: $TOTAL"

# ---------------------------------------------------------------------------
# Envio remoto via rsync (opcional)
# ---------------------------------------------------------------------------
if [ -n "$REMOTE_BACKUP_PATH" ]; then
    log "Enviando para destino remoto: $REMOTE_BACKUP_PATH"
    if command -v rsync >/dev/null 2>&1; then
        rsync -az --progress "$FILEPATH" "$REMOTE_BACKUP_PATH/" \
            && log "✅ Backup enviado para $REMOTE_BACKUP_PATH" \
            || log "⚠️  Falha no envio remoto. Backup local mantido."
    else
        log "⚠️  rsync não encontrado. Pulando envio remoto."
    fi
fi

log "Backup concluído com sucesso."
