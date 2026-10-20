#!/bin/bash
# ─────────────────────────────────────────────────────────────────
#  setup.sh — Sync mailboxes, aliases and DKIM for every domain
#  Reads accounts.conf (and aliases.conf, if present).
#  Safe to run again whenever you add a domain or an account.
# ─────────────────────────────────────────────────────────────────

set -euo pipefail
cd "$(dirname "$0")"

CONTAINER="mailserver"
MAIL_HOST="mail.potira.io"
ACCOUNTS_FILE="accounts.conf"
ALIASES_FILE="aliases.conf"

if [ -f .env ]; then
  set -a; . ./.env; set +a
fi
SERVER_IP="${SERVER_IP:-179.184.50.129}"

if [ ! -f "$ACCOUNTS_FILE" ]; then
  echo "❌ $ACCOUNTS_FILE not found. Create it from the example:"
  echo "   cp accounts.conf.example accounts.conf && nano accounts.conf"
  exit 1
fi

dms() { docker exec "$CONTAINER" "$@" </dev/null; }

# Print non-comment, non-empty lines of a config file
entries() { [ -f "$1" ] && grep -vE '^[[:space:]]*(#|$)' "$1" || true; }

echo "⏳ Waiting for mailserver to be ready..."
for _ in $(seq 1 30); do
  dms setup email list >/dev/null 2>&1 && break
  sleep 2
done

# ─── Mailboxes ────────────────────────────────────────────────────
existing_accounts=$(dms setup email list 2>/dev/null | awk '$1=="*"{print $2}')

while read -r email password _; do
  if [ -z "${password:-}" ]; then
    echo "⚠️  Skipping '$email': missing password"
    continue
  fi
  if grep -qixF -- "$email" <<<"$existing_accounts"; then
    echo "🔁 Updating password: $email"
    dms setup email update "$email" "$password"
  else
    echo "📬 Creating mailbox: $email"
    dms setup email add "$email" "$password"
  fi
done < <(entries "$ACCOUNTS_FILE")

# ─── Aliases ──────────────────────────────────────────────────────
existing_aliases=$(dms setup alias list 2>/dev/null || true)

while read -r alias destination _; do
  if [ -z "${destination:-}" ]; then
    echo "⚠️  Skipping alias '$alias': missing destination"
    continue
  fi
  current=$(awk -v a="$alias" '$1=="*" && tolower($2)==tolower(a){print $3}' <<<"$existing_aliases")
  if tr ',' '\n' <<<"$current" | grep -qixF -- "$destination"; then
    echo "✔️  Alias exists: $alias → $destination"
  else
    echo "↪️  Creating alias: $alias → $destination"
    dms setup alias add "$alias" "$destination"
  fi
done < <(entries "$ALIASES_FILE")

# ─── DKIM ─────────────────────────────────────────────────────────
domains=$( { entries "$ACCOUNTS_FILE"; entries "$ALIASES_FILE"; } \
  | awk '{print $1}' | sed 's/.*@//' | tr 'A-Z' 'a-z' | sort -u)

new_keys=0
for domain in $domains; do
  if ! dms test -f "/tmp/docker-mailserver/opendkim/keys/$domain/mail.txt"; then
    new_keys=1
  fi
done

echo ""
echo "🔑 Generating DKIM keys (existing keys are kept)..."
dms setup config dkim domain "$(paste -sd, <<<"$domains")"

if [ "$new_keys" = 1 ]; then
  echo "🔄 New DKIM keys created — restarting mailserver to load them..."
  docker restart "$CONTAINER" >/dev/null
fi

# ─── DNS records ──────────────────────────────────────────────────
echo ""
echo "══════════════════════════════════════════════════════════════"
echo "  DNS records — create these at each domain's DNS provider"
echo "══════════════════════════════════════════════════════════════"
echo ""
echo "  (once, in potira.io)  A  $MAIL_HOST  →  $SERVER_IP"

for domain in $domains; do
  dkim=$(dms cat "/tmp/docker-mailserver/opendkim/keys/$domain/mail.txt" 2>/dev/null \
    | grep -o '"[^"]*"' | tr -d '"\n' || true)
  echo ""
  echo "  ── $domain ──"
  echo "  MX   $domain                    →  $MAIL_HOST (priority 10)"
  echo "  TXT  $domain                    →  v=spf1 mx ip4:$SERVER_IP ~all"
  echo "  TXT  mail._domainkey.$domain    →  ${dkim:-<key not found, run ./setup.sh again>}"
  echo "  TXT  _dmarc.$domain             →  v=DMARC1; p=none; rua=mailto:postmaster@$domain"
done

echo ""
echo "✅ Setup complete! Domains served: $(paste -sd' ' <<<"$domains")"
echo ""
echo "Test sending email:"
echo "  curl -X POST http://localhost:3025/send \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"from\":\"contato@juliovianadev.com\",\"to\":\"test@gmail.com\",\"subject\":\"Hello!\",\"text\":\"It works!\"}'"
