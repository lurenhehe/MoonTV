#!/usr/bin/env bash
set -euo pipefail
cd /opt/moontv
exec 9>/run/lock/moontv-update.lock
flock -n 9 || exit 0
umask 077
available_kb=$(df -Pk . | awk 'NR==2 {print $4}')
if (( available_kb < 614400 )); then
  echo 'Insufficient disk space: need at least 600 MiB before downloading an update.' >&2
  exit 1
fi
old_image=$(sed -n 's/^MOONTV_IMAGE=//p' .env)
docker pull ghcr.io/moontechlab/lunatv:latest
new_image=$(docker image inspect ghcr.io/moontechlab/lunatv:latest --format '{{index .RepoDigests 0}}')
source=$(docker image inspect "$new_image" --format '{{index .Config.Labels "org.opencontainers.image.source"}}')
revision=$(docker image inspect "$new_image" --format '{{index .Config.Labels "org.opencontainers.image.revision"}}')
[[ "$source" == 'https://github.com/MoonTechLab/LunaTV' && "$revision" =~ ^[0-9a-f]{40}$ ]]
if [[ "$new_image" == "$old_image" ]]; then
  python3 probe.py
  echo "Already current: $revision"
  exit 0
fi
./backup.sh
cp .env .env.rollback
rollback() {
  echo 'Update verification failed; restoring the previous image.' >&2
  cp .env.rollback .env
  docker compose up -d --no-deps --wait --wait-timeout 180 app
}
trap rollback ERR
sed -i "s|^MOONTV_IMAGE=.*|MOONTV_IMAGE=$new_image|" .env
docker compose up -d --no-deps --wait --wait-timeout 180 app
python3 probe.py
trap - ERR
printf '%s image=%s revision=%s\n' "$(date -u +%FT%TZ)" "$new_image" "$revision" >> updates.log
echo "Updated successfully: $revision"
