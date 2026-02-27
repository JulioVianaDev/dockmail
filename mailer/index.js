const express = require("express");
const nodemailer = require("nodemailer");

const app = express();
app.use(express.json());

// ── Transporter usando o mailserver interno ──────────────────────────────────
const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST || "mailserver",
  port: parseInt(process.env.SMTP_PORT || "587"),
  secure: false,                // porta 587 usa STARTTLS
  auth: {
    user: process.env.SMTP_USER || "contact@potira.io",
    pass: process.env.SMTP_PASS || "sua_senha_aqui",
  },
  tls: {
    rejectUnauthorized: false,  // aceita cert self-signed em dev
  },
});

// ── Verifica conexão ao iniciar ───────────────────────────────────────────────
transporter.verify((err, ok) => {
  if (err) {
    console.error("❌ SMTP connection error:", err.message);
  } else {
    console.log("✅ SMTP server pronto para enviar e-mails");
  }
});

// ── POST /send  { to, subject, text, html } ───────────────────────────────────
app.post("/send", async (req, res) => {
  const { to, subject, text, html } = req.body;

  if (!to || !subject) {
    return res.status(400).json({ error: "Campos 'to' e 'subject' são obrigatórios" });
  }

  try {
    const info = await transporter.sendMail({
      from: `"Potira" <${process.env.MAIL_FROM || "contact@potira.io"}>`,
      to,
      subject,
      text: text || "",
      html: html || text || "",
    });

    console.log("✉️  E-mail enviado:", info.messageId, "→", to);
    res.json({ success: true, messageId: info.messageId });
  } catch (err) {
    console.error("❌ Erro ao enviar:", err.message);
    res.status(500).json({ error: err.message });
  }
});

// ── GET /health ───────────────────────────────────────────────────────────────
app.get("/health", (_req, res) => res.json({ status: "ok" }));

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`🚀 Mailer API rodando na porta ${PORT}`));
