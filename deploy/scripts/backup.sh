#!/bin/sh
# Sauvegarde manuelle de la base (dump compressé pg_dump -Fc).
# Usage : ./backup.sh [dossier_sortie]   (défaut : ../backups)
set -e
OUT="${1:-$(dirname "$0")/../backups}"
mkdir -p "$OUT"
FILE="$OUT/padel-$(date +%Y%m%d-%H%M%S).dump"
docker compose -f "$(dirname "$0")/../docker-compose.prod.yml" exec -T db \
  pg_dump -U "${POSTGRES_USER:-padel}" -Fc "${POSTGRES_DB:-padel}" > "$FILE"
echo "Backup créé : $FILE ($(du -h "$FILE" | cut -f1))"
