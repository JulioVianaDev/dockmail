#!/bin/bash
# ─────────────────────────────────────────────────────────────────
#  setup.sh — Run ONCE after first docker-compose up
#  Sets up email accounts and copies DKIM key
# ─────────────────────────────────────────────────────────────────

set -e

CONTAINER="mailserver"
DOMAIN="potira.io"

echo "⏳ Waiting for mailserver to be ready..."
sleep 10

echo ""
echo "📬 Creating email account: contact@potira.io"
docker exec "$CONTAINER" setup email add contact@potira.io your_password_here

echo ""
echo "📬 Creating email account: postmaster@potira.io"
docker exec "$CONTAINER" setup email add postmaster@potira.io your_password_here

echo ""
echo "🔑 Generating DKIM key (if not yet generated)..."
docker exec "$CONTAINER" setup config dkim

echo ""
echo "📋 Your DKIM public key (put this in DNS as TXT for mail._domainkey.$DOMAIN):"
cat ./config/opendkim/keys/$DOMAIN/mail.txt 2>/dev/null || \
  docker exec "$CONTAINER" cat /tmp/docker-mailserver/opendkim/keys/$DOMAIN/mail.txt 2>/dev/null || \
  echo "  → Key not found yet, check ./config/opendkim/keys/$DOMAIN/mail.txt after startup"

echo ""
echo "✅ Setup complete!"
echo ""
echo "Test sending email:"
echo "  curl -X POST http://localhost:3025/send \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"to\":\"test@gmail.com\",\"subject\":\"Hello from Potira!\",\"text\":\"It works!\"}'"
