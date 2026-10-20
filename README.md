# 📧 Potira Mail Server — docker-compose

Multi-domain mail server (`potira.io`, `juliovianadev.com`, …) using **docker-mailserver** + **Roundcube** + **NodeMailer API**.

A single mailserver instance hosts as many domains and mailboxes as you want: list them in `accounts.conf` and run `./setup.sh`.

## 📁 Project Structure

```
potira-mail/
├── docker-compose.yml
├── .env.example          ← copy to .env (passwords, server IP)
├── accounts.conf.example ← copy to accounts.conf (mailboxes of every domain)
├── aliases.conf.example  ← copy to aliases.conf (optional forwarding)
├── setup.sh              ← Syncs mailboxes, aliases, DKIM; prints DNS records
├── get-certs.sh          ← Get Let's Encrypt TLS certs
├── certs/                ← fullchain.pem + privkey.pem
├── config/               ← docker-mailserver config
├── data/                 ← mail data (auto-generated)
└── node-mailer-test/
    ├── Dockerfile
    ├── package.json
    └── index.js          ← REST API to send emails
```

## 🚀 Step-by-step Setup

### 1. Add missing DNS A record for mail subdomain

| Type | Name | Content        |
|------|------|----------------|
| A    | mail | 179.184.50.129 |

You already have MX pointing to mail.potira.io — this A record makes it resolve.

### 2. Get TLS certificate (run on the VPS host)

```bash
apt install certbot -y
chmod +x get-certs.sh
./get-certs.sh
```

This puts fullchain.pem and privkey.pem into ./certs/

### 3. Configure domains, mailboxes and passwords

```bash
cp .env.example .env                       # SMTP_PASS, SERVER_IP, ALLOWED_FROM_DOMAINS
cp accounts.conf.example accounts.conf     # one "<email> <password>" per line
cp aliases.conf.example aliases.conf       # optional: "<alias> <destination>"
```

Every domain that appears in `accounts.conf` / `aliases.conf` is served automatically.
These three files are git-ignored.

### 4. Start containers

```bash
docker-compose up -d
```

### 5. Create mailboxes, DKIM keys and get the DNS records

```bash
chmod +x setup.sh
./setup.sh
```

The script creates (or updates the password of) every mailbox, creates aliases,
generates a DKIM key per domain and prints the DNS records to create for each domain:

| Type | Name                      | Value                                   |
|------|---------------------------|-----------------------------------------|
| A    | mail.potira.io (once)     | server IP                               |
| MX   | `<domain>`                | mail.potira.io (priority 10)            |
| TXT  | `<domain>`                | `v=spf1 mx ip4:<server IP> ~all`        |
| TXT  | `mail._domainkey.<domain>`| DKIM key printed by setup.sh            |
| TXT  | `_dmarc.<domain>`         | `v=DMARC1; p=none; rua=mailto:postmaster@<domain>` |

All domains use `mail.potira.io` as MX, so the existing TLS certificate covers them.

### Adding another domain or mailbox later

1. Add the line(s) to `accounts.conf` (e.g. `contato@novodominio.com senha`)
2. Add the domain to `ALLOWED_FROM_DOMAINS` in `.env` if the API should send from it, then `docker-compose up -d mailer-test`
3. Run `./setup.sh` again and create the DNS records it prints for the new domain

### 6. Send a test email

```bash
curl -X POST http://localhost:3025/send \
  -H "Content-Type: application/json" \
  -d '{
    "from": "contato@juliovianadev.com",
    "fromName": "Julio Viana",
    "to": "youremail@gmail.com",
    "subject": "Hello from Potira!",
    "text": "Sent from my own mail server!"
  }'
```

## 🌐 Ports

| Port | Service              |
|------|----------------------|
| 25   | SMTP incoming        |
| 587  | SMTP Submission      |
| 465  | SMTPS                |
| 143  | IMAP                 |
| 993  | IMAPS                |
| 8025 | Roundcube webmail    |
| 3025 | NodeMailer REST API  |

## NodeMailer API

POST /send — body: { from?, fromName?, to, subject, text, html }

`from` defaults to `FROM_EMAIL` and must belong to a domain in `ALLOWED_FROM_DOMAINS`.
The API logs in with a single account (`SMTP_USER`) and can send as any served domain;
DKIM signs each message with the key of the sender's domain.
GET  /health — returns { status: ok }

## Troubleshooting

Check logs: docker logs mailserver -f
List accounts: docker exec mailserver setup email list
List aliases: docker exec mailserver setup alias list
Test blacklist: https://mxtoolbox.com/blacklists.aspx
Test mail score: https://mail-tester.com
