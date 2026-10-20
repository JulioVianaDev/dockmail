const express = require("express");
const nodemailer = require("nodemailer");

const app = express();
app.use(express.json());

// Transporter using the local docker-mailserver
const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST || "mailserver",
  port: parseInt(process.env.SMTP_PORT) || 587,
  secure: false, // STARTTLS
  auth: {
    user: process.env.SMTP_USER || "contact@potira.io",
    pass: process.env.SMTP_PASS || "your_password_here",
  },
  tls: {
    rejectUnauthorized: false, // allow self-signed for internal
  },
});

// Sender domains this API may use (all must be served by the mailserver)
const allowedFromDomains = (process.env.ALLOWED_FROM_DOMAINS || "potira.io")
  .split(",")
  .map((d) => d.trim().toLowerCase())
  .filter(Boolean);

// POST /send  →  body: { from?, fromName?, to, subject, text, html }
app.post("/send", async (req, res) => {
  const { to, subject, text, html } = req.body;
  const from = req.body.from || process.env.FROM_EMAIL || "contact@potira.io";
  const fromName = req.body.fromName || "Potira";

  if (!to || !subject) {
    return res.status(400).json({ error: "Fields 'to' and 'subject' are required." });
  }

  const fromDomain = String(from).split("@").pop().toLowerCase();
  if (!allowedFromDomains.includes(fromDomain)) {
    return res.status(400).json({ error: `Domain '${fromDomain}' is not allowed as sender.` });
  }

  try {
    const info = await transporter.sendMail({
      from: { name: fromName, address: from },
      to,
      subject,
      text: text || "",
      html: html || text || "",
    });

    console.log(`✅ Mail sent: ${info.messageId}`);
    res.json({ success: true, messageId: info.messageId });
  } catch (err) {
    console.error("❌ Error sending mail:", err.message);
    res.status(500).json({ error: err.message });
  }
});

// GET /health
app.get("/health", (req, res) => res.json({ status: "ok" }));

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`🚀 Mailer API running on port ${PORT}`));
