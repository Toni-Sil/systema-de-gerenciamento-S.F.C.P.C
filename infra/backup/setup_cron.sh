#!/usr/bin/env bash
# =============================================================================
# S.F.C.P.C — Configura o cron de backup automático no servidor
#
# Agendamento padrão: todo dia às 02:00 da manhã
#
# USO (como root ou com sudo):
#   chmod +x infra/backup/setup_cron.sh
#   sudo ./infra/backup/setup_cron.sh
#
# Para verificar se foi agendado:
#   sudo crontab -l
#
# Para remover:
#   sudo crontab -e   # delete a linha sfcpc_backup
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_SCRIPT="$SCRIPT_DIR/backup.sh"
LOG_FILE="/var/log/sfcpc_backup.log"

# Horário do backup (padrão: 02:00 todo dia)
CRON_HOUR="${BACKUP_CRON_HOUR:-2}"
CRON_MINUTE="${BACKUP_CRON_MINUTE:-0}"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

[ -f "$BACKUP_SCRIPT" ] || { echo "ERRO: backup.sh não encontrado em $BACKUP_SCRIPT"; exit 1; }

# Garante que o script tem permissão de execução
chmod +x "$BACKUP_SCRIPT"

# Cria arquivo de log se não existir
touch "$LOG_FILE"

# Linha do cron a ser adicionada
CRON_LINE="$CRON_MINUTE $CRON_HOUR * * * $BACKUP_SCRIPT >> $LOG_FILE 2>&1  # sfcpc_backup"

# Verifica se já existe uma entrada sfcpc_backup no crontab
if sudo crontab -l 2>/dev/null | grep -q 'sfcpc_backup'; then
    log "⚠️  Cron de backup já existe. Atualizando..."
    # Remove entrada antiga e adiciona nova
    sudo crontab -l 2>/dev/null | grep -v 'sfcpc_backup' | sudo crontab -
fi

# Adiciona nova entrada
(sudo crontab -l 2>/dev/null; echo "$CRON_LINE") | sudo crontab -

log "✅ Backup automático configurado:"
log "   Horário : todo dia às $CRON_HOUR:$(printf '%02d' $CRON_MINUTE)"
log "   Script  : $BACKUP_SCRIPT"
log "   Log     : $LOG_FILE"
log "   Backups : /var/backups/sfcpc/"
echo ""
echo "Para verificar: sudo crontab -l"
echo "Para ver os logs em tempo real: tail -f $LOG_FILE"
