#!/bin/sh
# Restauration d'un dump dans la base (ÉCRASE les données actuelles).
# Usage : ./restore.sh backups/padel-YYYYMMDD-HHMMSS.dump
set -e
[ -f "$1" ] || { echo "Usage: $0 <fichier.dump>"; exit 1; }
echo "⚠ Restauration de $1 — les données actuelles seront remplacées. Ctrl+C pour annuler (5 s)…"
sleep 5
docker compose -f "$(dirname "$0")/../docker-compose.prod.yml" exec -T db \
  pg_restore -U "${POSTGRES_USER:-padel}" -d "${POSTGRES_DB:-padel}" --clean --if-exists < "$1"
echo "Restauration terminée."
