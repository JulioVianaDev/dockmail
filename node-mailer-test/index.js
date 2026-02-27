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

// POST /send  →  body: { to, subject, text, html }
app.post("/send", async (req, res) => {
  const { to, subject, text, html } = req.body;

  if (!to || !subject) {
    return res.status(400).json({ error: "Fields 'to' and 'subject' are required." });
  }

  try {
    const info = await transporter.sendMail({
      from: `"Potira" <${process.env.FROM_EMAIL || "contact@potira.io"}>`,
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
