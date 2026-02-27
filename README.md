# 📧 Potira Mail Server — docker-compose

Mail server for `potira.io` using **docker-mailserver** + **Roundcube** + **NodeMailer API**.

## 📁 Project Structure

```
potira-mail/
├── docker-compose.yml
├── setup.sh              ← Run after first start
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

### 3. Edit passwords

Open setup.sh and docker-compose.yml and replace `your_password_here` with a real password.

### 4. Start containers

```bash
docker-compose up -d
```

### 5. Create email accounts and DKIM

```bash
chmod +x setup.sh
./setup.sh
```

### 6. Send a test email

```bash
curl -X POST http://localhost:3025/send \
  -H "Content-Type: application/json" \
  -d '{
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

POST /send — body: { to, subject, text, html }
GET  /health — returns { status: ok }

## Troubleshooting

Check logs: docker logs mailserver -f
List accounts: docker exec mailserver setup email list
Test blacklist: https://mxtoolbox.com/blacklists.aspx
Test mail score: https://mail-tester.com
