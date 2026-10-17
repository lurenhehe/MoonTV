#!/usr/bin/env bash
set -euo pipefail
cd /opt/moontv
umask 077
mkdir -p backups
stamp=$(date -u +%Y%m%dT%H%M%SZ)
target="backups/$stamp"
mkdir "$target"
docker compose exec -T redis redis-cli --rdb /data/moontv-backup.rdb >/dev/null
cp data/redis/moontv-backup.rdb "$target/dump.rdb"
rm data/redis/moontv-backup.rdb
cp .env compose.yaml "$target/"
tar -czf "$target.tar.gz" -C backups "$stamp"
sha256sum "$target.tar.gz" > "$target.tar.gz.sha256"
rm -r -- "$target"
# Keep the newest fourteen validated, project-specific backup archives.
mapfile -t old < <(find backups -maxdepth 1 -type f -name '20*T*Z.tar.gz' -printf '%f\n' | sort -r | tail -n +15)
for archive in "${old[@]}"; do
  rm -f -- "backups/$archive" "backups/$archive.sha256"
done
echo "backup=$target.tar.gz"
