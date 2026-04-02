# 💾 Backup Automático — S.F.C.P.C

Sistema simples de backup do PostgreSQL para o VPS (Hostinger).

---

## Arquivos

| Arquivo | O que faz |
|---|---|
| `backup.sh` | Gera o backup comprimido do banco |
| `restore.sh` | Restaura um backup (use só em emergência) |
| `setup_cron.sh` | Agenda o backup automático todo dia às 02:00 |

---

## Instalação no VPS (uma vez)

```bash
# 1. Entre no servidor
ssh root@seu-vps

# 2. Vá para a pasta do projeto
cd /opt/sfcpc   # ou onde você clonou o projeto

# 3. Dê permissão aos scripts
chmod +x infra/backup/backup.sh
chmod +x infra/backup/restore.sh
chmod +x infra/backup/setup_cron.sh

# 4. Agende o backup automático (02:00 todo dia)
sudo ./infra/backup/setup_cron.sh

# 5. Teste rodar uma vez na mão
sudo ./infra/backup/backup.sh
```

---

## Onde ficam os backups?

```
/var/backups/sfcpc/
  sfcpc_backup_20260402_020000.sql.gz
  sfcpc_backup_20260403_020000.sql.gz
  ...
```

Cada arquivo tem o nome com **data e hora**. Backups mais antigos que **30 dias** são apagados automaticamente.

---

## Configuração via `.env`

Variáveis opcionais que você pode adicionar ao seu `.env`:

```env
# Pasta onde os backups são salvos (padrão: /var/backups/sfcpc)
BACKUP_DIR=/var/backups/sfcpc

# Quantos dias de backup manter (padrão: 30)
BACKUP_RETENTION_DAYS=30

# Horário do cron (padrão: 02:00)
BACKUP_CRON_HOUR=2
BACKUP_CRON_MINUTE=0

# Envio para servidor remoto via rsync (opcional)
# REMOTE_BACKUP_PATH=user@outroservidor.com:/backups/sfcpc

# Nome do container do banco (padrão: sfcpc_db)
# POSTGRES_CONTAINER=sfcpc_db
```

---

## Como restaurar em emergência

```bash
# ⚠️ APAGA O BANCO ATUAL e restaura o backup escolhido
sudo ./infra/backup/restore.sh /var/backups/sfcpc/sfcpc_backup_20260402_020000.sql.gz
```

O script vai pedir que você digite `CONFIRMO` antes de apagar qualquer coisa.

---

## Ver os logs do backup

```bash
# Últimos 20 logs
tail -20 /var/log/sfcpc_backup.log

# Monitorar em tempo real
tail -f /var/log/sfcpc_backup.log
```

---

## Envio para servidor remoto (recomendado)

Para máxima segurança, configure o envio para um **servidor diferente** (outro VPS, NAS, ou storage S3-compatible da Hostinger):

```env
REMOTE_BACKUP_PATH=user@backup-server.com:/backups/sfcpc
```

Configure a chave SSH sem senha entre os servidores:

```bash
ssh-keygen -t ed25519 -C "sfcpc-backup"
ssh-copy-id user@backup-server.com
```
