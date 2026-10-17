#!/usr/bin/env bash
set -euo pipefail
cd /opt/moontv
exec 8>/run/lock/moontv-certificate.lock
flock -n 8 || exit 0
domain=dy.liyao03.dpdns.org
cert_dir=/home/web/certbot/live/$domain
if [[ ! -f "$cert_dir/fullchain.pem" ]]; then
  docker run --rm --memory 192m --cpus 0.25 \
    -v /home/web/certbot:/etc/letsencrypt \
    -v /home/web/letsencrypt:/var/www/letsencrypt \
    certbot/certbot certonly --webroot -w /var/www/letsencrypt \
    --cert-name "$domain" -d "$domain" --non-interactive
else
  docker run --rm --memory 192m --cpus 0.25 \
    -v /home/web/certbot:/etc/letsencrypt \
    -v /home/web/letsencrypt:/var/www/letsencrypt \
    certbot/certbot renew --cert-name "$domain" --non-interactive
fi
openssl x509 -in "$cert_dir/fullchain.pem" -noout -checkhost "$domain"
install -m 644 "$cert_dir/fullchain.pem" "/home/web/certs/${domain}_cert.pem"
install -m 600 "$cert_dir/privkey.pem" "/home/web/certs/${domain}_key.pem"
target="/home/web/conf.d/$domain.conf"
cp "$target" "$target.rollback"
install -m 644 nginx-https.conf "$target"
if ! docker exec nginx nginx -t; then
  mv "$target.rollback" "$target"
  exit 1
fi
docker exec nginx nginx -s reload
