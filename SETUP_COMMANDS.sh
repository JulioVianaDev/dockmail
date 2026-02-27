#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════
#  POTIRA MAIL SERVER — Setup completo copy-paste
#  IP público: 179.184.50.129 | Domínio: potira.io
# ══════════════════════════════════════════════════════════════════

set -e

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║   PASSO 1 — Instalar dependências no Raspberry Pi   ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
echo "# Cole estes comandos no seu Raspberry Pi:"
echo ""
cat <<'CMDS'
sudo apt update && sudo apt install -y docker.io docker-compose git curl
sudo usermod -aG docker $USER
newgrp docker
CMDS

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║   PASSO 2 — Clonar / criar o projeto                ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
cat <<'CMDS'
mkdir -p ~/potira-mail && cd ~/potira-mail
CMDS

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║   PASSO 3 — Gerar certificado SSL (Let's Encrypt)   ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
cat <<'CMDS'
# Certifica que a porta 80 está livre (para o desafio HTTP-01)
sudo systemctl stop apache2 nginx 2>/dev/null || true

cd ~/potira-mail
mkdir -p mailserver/certs

# Gera certificado para mail.potira.io
docker run --rm \
  -p 80:80 \
  -v $(pwd)/mailserver/certs:/etc/letsencrypt \
  certbot/certbot certonly \
    --standalone \
    --non-interactive \
    --agree-tos \
    --email postmaster@potira.io \
    -d mail.potira.io

# Ajusta permissões para o mailserver ler
sudo chmod -R 755 mailserver/certs/live/
CMDS

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║   PASSO 4 — Criar conta de e-mail no mailserver     ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
cat <<'CMDS'
cd ~/potira-mail

# Baixar o helper script do docker-mailserver
curl -fsSL https://raw.githubusercontent.com/docker-mailserver/docker-mailserver/master/setup.sh -o setup.sh
chmod +x setup.sh

# Subir só o mailserver pela primeira vez (sem TLS para poder criar a conta)
docker compose up -d mailserver

# Aguardar inicializar
sleep 15

# Criar o usuário contact@potira.io  (troque SUA_SENHA por uma senha forte!)
./setup.sh email add contact@potira.io SUA_SENHA_FORTE

# Criar também o postmaster (boa prática)
./setup.sh email add postmaster@potira.io SUA_SENHA_FORTE

# Ver contas criadas
./setup.sh email list
CMDS

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║   PASSO 5 — Gerar chave DKIM                        ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
cat <<'CMDS'
cd ~/potira-mail

# Gerar DKIM para potira.io (seletor padrão: mail)
./setup.sh config dkim

# Ver a chave pública gerada (cole no DNS depois se mudar)
cat mailserver/config/opendkim/keys/potira.io/mail.txt
CMDS

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║   PASSO 6 — Criar o .env e subir tudo               ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
cat <<'CMDS'
cd ~/potira-mail

# Edite o .env com a senha que você usou no passo 4
cat > .env <<EOF
MAIL_PASSWORD=SUA_SENHA_FORTE
EOF

# Subir todos os serviços
docker compose up -d --build

# Ver logs
docker compose logs -f mailserver
CMDS

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║   PASSO 7 — Testar envio via API Node.js            ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
cat <<'CMDS'
# Aguardar mailer subir
sleep 10

# Testar health
curl http://localhost:3000/health

# Enviar e-mail de teste para o Gmail
curl -X POST http://localhost:3000/send \
  -H "Content-Type: application/json" \
  -d '{
    "to": "SEU_EMAIL@gmail.com",
    "subject": "Teste Potira Mail Server 🚀",
    "text": "Se você recebeu isso, o servidor de e-mail está funcionando!",
    "html": "<h1>✅ Potira Mail Server</h1><p>Servidor funcionando perfeitamente!</p>"
  }'
CMDS

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║   PASSO 8 — Testar envio direto com Nodemailer      ║"
echo "╚══════════════════════════════════════════════════════╝"
echo ""
cat <<'CMDS'
# Pode também testar direto com node:
node -e "
const nodemailer = require('nodemailer');
const t = nodemailer.createTransport({
  host: 'localhost', port: 587, secure: false,
  auth: { user: 'contact@potira.io', pass: 'SUA_SENHA_FORTE' },
  tls: { rejectUnauthorized: false }
});
t.sendMail({
  from: 'contact@potira.io',
  to: 'SEU_EMAIL@gmail.com',
  subject: 'Teste direto Nodemailer',
  text: 'Funcionou!'
}).then(i => console.log('Enviado:', i.messageId)).catch(console.error);
"
CMDS

echo ""
echo "══════════════════════════════════════════════════════"
echo "  REFERÊNCIA — Comandos úteis do dia a dia"
echo "══════════════════════════════════════════════════════"
echo ""
cat <<'CMDS'
# Ver todos os containers
docker compose ps

# Logs do mailserver
docker compose logs -f mailserver

# Logs do mailer (Node.js)
docker compose logs -f mailer

# Adicionar novo usuário
./setup.sh email add USUARIO@potira.io SENHA

# Listar usuários
./setup.sh email list

# Renovar certificado SSL (rodar a cada 3 meses ou no cron)
docker compose run --rm certbot

# Reiniciar tudo
docker compose restart

# Parar tudo
docker compose down

# Verificar filas de e-mail no postfix
docker exec mailserver postqueue -p

# Flush da fila (forçar reenvio)
docker exec mailserver postqueue -f
CMDS

echo ""
echo "══════════════════════════════════════════════════════"
echo "  DNS — Confirmação do que você já tem configurado"
echo "══════════════════════════════════════════════════════"
echo ""
echo "  ✅ A  potira.io         → 179.184.50.129"
echo "  ✅ A  mail.potira.io    → 179.184.50.129"
echo "  ✅ MX potira.io         → mail.potira.io (prioridade 10)"
echo "  ✅ TXT SPF              → v=spf1 mx a ip4:179.184.50.129 ~all"
echo "  ✅ TXT DKIM             → mail._domainkey (já configurado)"
echo "  ✅ TXT DMARC            → v=DMARC1; p=none; rua=mailto:postmaster@potira.io"
echo ""
echo "  ⚠️  Verifique se o seu ISP permite porta 25 saindo!"
echo "     Muitos ISPs bloqueiam SMTP saindo (porta 25)."
echo "     Se bloqueado, use porta 587 como relay."
echo ""
CMDS
