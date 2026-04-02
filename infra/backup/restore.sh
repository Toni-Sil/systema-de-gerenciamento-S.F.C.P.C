#!/usr/bin/env bash
# =============================================================================
# S.F.C.P.C — Restore do PostgreSQL a partir de um backup
#
# USO:
#   sudo ./infra/backup/restore.sh /var/backups/sfcpc/sfcpc_backup_20260402_020000.sql.gz
#
# ⚠️  ATENÇÃO: Este script APAGA o banco atual e restaura o backup.
#     Use apenas em caso de recuperação de desastre ou migração.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

if [ -f "$PROJECT_ROOT/.env" ]; then
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
fi

POSTGRES_USER="${POSTGRES_USER:-sfcpc}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-sfcpc}"
POSTGRES_DB="${POSTGRES_DB:-sfcpc}"
CONTAINER_NAME="${POSTGRES_CONTAINER:-sfcpc_db}"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
err() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERRO: $*" >&2; exit 1; }

# ---------------------------------------------------------------------------
# Validações
# ---------------------------------------------------------------------------
[ $# -eq 1 ] || err "Uso: $0 <caminho_do_backup.sql.gz>"
BACKUP_FILE="$1"
[ -f "$BACKUP_FILE" ] || err "Arquivo não encontrado: $BACKUP_FILE"
[[ "$BACKUP_FILE" == *.sql.gz ]] || err "O arquivo deve ser um .sql.gz gerado pelo backup.sh"

command -v docker >/dev/null 2>&1 || err "Docker não encontrado."
docker inspect "$CONTAINER_NAME" >/dev/null 2>&1 || err "Container '$CONTAINER_NAME' não está rodando."

# ---------------------------------------------------------------------------
# Confirmação de segurança
# ---------------------------------------------------------------------------
echo ""
echo "⚠️  ATENÇÃO: Isso VAI APAGAR todos os dados atuais do banco '$POSTGRES_DB'."
echo "   Arquivo de restore: $BACKUP_FILE"
echo ""
read -rp "Digite 'CONFIRMO' para continuar: " CONFIRM
[ "$CONFIRM" = "CONFIRMO" ] || err "Restore cancelado pelo usuário."

# ---------------------------------------------------------------------------
# Drop e recriação do banco
# ---------------------------------------------------------------------------
log "Encerrando conexões ativas no banco..."
docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" "$CONTAINER_NAME" \
    psql -U "$POSTGRES_USER" -d postgres -c \
    "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='$POSTGRES_DB' AND pid <> pg_backend_pid();"

log "Dropando banco '$POSTGRES_DB'..."
docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" "$CONTAINER_NAME" \
    psql -U "$POSTGRES_USER" -d postgres -c "DROP DATABASE IF EXISTS \"$POSTGRES_DB\";"

log "Recriando banco '$POSTGRES_DB'..."
docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" "$CONTAINER_NAME" \
    psql -U "$POSTGRES_USER" -d postgres -c "CREATE DATABASE \"$POSTGRES_DB\" OWNER \"$POSTGRES_USER\";"

# ---------------------------------------------------------------------------
# Restore
# ---------------------------------------------------------------------------
log "Restaurando backup: $BACKUP_FILE"
gunzip -c "$BACKUP_FILE" | docker exec -i \
    -e PGPASSWORD="$POSTGRES_PASSWORD" "$CONTAINER_NAME" \
    psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
    && log "✅ Restore concluído com sucesso!" \
    || err "Falha durante o restore. Verifique os logs acima."
