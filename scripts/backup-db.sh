#!/usr/bin/env bash
set -euo pipefail

# ILG Database Backup Script
# Usage: bash scripts/backup-db.sh [db_path]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DB_PATH="${1:-$PROJECT_ROOT/db/ilg.db}"
BACKUP_DIR="$PROJECT_ROOT/db/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

if [ ! -f "$DB_PATH" ]; then
    echo "ERROR: Database not found at $DB_PATH"
    exit 1
fi

mkdir -p "$BACKUP_DIR"
cp "$DB_PATH" "$BACKUP_DIR/ilg_backup_${TIMESTAMP}.db"
echo "Backup created: $BACKUP_DIR/ilg_backup_${TIMESTAMP}.db"

# Keep only last 10 backups
BACKUP_COUNT=$(ls -1 "$BACKUP_DIR"/ilg_backup_*.db 2>/dev/null | wc -l)
if [ "$BACKUP_COUNT" -gt 10 ]; then
    ls -t "$BACKUP_DIR"/ilg_backup_*.db | tail -n +11 | xargs rm -f
    echo "Cleanup: keeping last 10 backups (removed $((BACKUP_COUNT - 10)) old backups)"
else
    echo "Backups: $BACKUP_COUNT total (keeping all)"
fi
