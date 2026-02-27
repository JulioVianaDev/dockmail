#!/bin/bash
# ─────────────────────────────────────────────────────────────────
#  get-certs.sh — Obtain Let's Encrypt TLS cert for mail.potira.io
#  Run this BEFORE docker-compose up
#  Requires: certbot installed on host  (apt install certbot)
# ─────────────────────────────────────────────────────────────────

DOMAIN="mail.potira.io"
CERT_DIR="./certs"

echo "🔐 Requesting TLS certificate for $DOMAIN ..."

# Standalone mode — temporarily binds port 80
# Make sure port 80 is open on your modem/VPS firewall
certbot certonly \
  --standalone \
  --non-interactive \
  --agree-tos \
  --email postmaster@potira.io \
  -d "$DOMAIN"

echo "📂 Copying certs to $CERT_DIR ..."
mkdir -p "$CERT_DIR"
cp /etc/letsencrypt/live/$DOMAIN/fullchain.pem "$CERT_DIR/fullchain.pem"
cp /etc/letsencrypt/live/$DOMAIN/privkey.pem   "$CERT_DIR/privkey.pem"
chmod 644 "$CERT_DIR/"*.pem

echo "✅ Certificates ready in $CERT_DIR"
