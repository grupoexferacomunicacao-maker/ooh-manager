require("dotenv").config();
const express = require("express");
const cors    = require("cors");
const path    = require("path");

const authRoutes      = require("./routes/auth");
const clientesRoutes  = require("./routes/clientes");
const propostasRoutes = require("./routes/propostas");
const piRoutes        = require("./routes/pi");
const producaoRoutes  = require("./routes/producao");
const financeiroRoutes= require("./routes/financeiro");
const faturamentoRoutes=require("./routes/faturamento");
const nfRoutes        = require("./routes/notas_fiscais");
const checkingRoutes  = require("./routes/checking");
const dashboardRoutes = require("./routes/dashboard");
const midiasRoutes    = require("./routes/midias");
const alertasRoutes   = require("./routes/alertas");
const relatoriosRoutes= require("./routes/relatorios");
const precosRoutes = require("./routes/precos");
const app  = express();
const PORT = process.env.PORT || 3001;

// ── Middlewares globais ─────────────────────────────────────
app.use(cors({ origin: process.env.FRONTEND_URL || "*", credentials: true }));
app.use(express.json({ limit: "20mb" }));
app.use(express.urlencoded({ extended: true }));
app.use("/uploads", express.static(path.join(__dirname, "..", "uploads")));

// ── Rotas ───────────────────────────────────────────────────
app.use("/api/auth",          authRoutes);
app.use("/api/clientes",      clientesRoutes);
app.use("/api/propostas",     propostasRoutes);
app.use("/api/pi",            piRoutes);
app.use("/api/producao",      producaoRoutes);
app.use("/api/financeiro",    financeiroRoutes);
app.use("/api/faturamento",   faturamentoRoutes);
app.use("/api/notas-fiscais", nfRoutes);
app.use("/api/checking",      checkingRoutes);
app.use("/api/dashboard",     dashboardRoutes);
app.use("/api/midias",        midiasRoutes);
app.use("/api/alertas",       alertasRoutes);
app.use("/api/relatorios",    relatoriosRoutes);
app.use("/api/precos", precosRoutes);
// ── Servir frontend ─────────────────────────────────────────
const frontendPath = path.join(__dirname, "../../frontend");
app.use(express.static(frontendPath));
app.get("/", (req, res) => {
  res.sendFile(path.join(frontendPath, "OOH_Manager.html"));
});

// ── Health check ────────────────────────────────────────────
app.get("/api/health", (req, res) => res.json({ status: "ok", version: "1.0.0" }));

// ── 404 handler ─────────────────────────────────────────────
app.use((req, res) => res.status(404).json({ erro: "Rota não encontrada" }));

// ── Error handler ───────────────────────────────────────────
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(err.status || 500).json({ erro: err.message || "Erro interno do servidor" });
});

app.listen(PORT, () => console.log(`🚀 OOH Manager API rodando na porta ${PORT}`));
module.exports = app;

// Evitar que o processo caia por erros nao tratados
process.on('uncaughtException', (err) => {
  console.error('[ERRO NAO TRATADO]', err.message);
});
process.on('unhandledRejection', (reason) => {
  console.error('[PROMISE REJEITADA]', reason);
});
const precosRoutes = require("./routes/precos");
// ...
app.use("/api/precos", precosRoutes);const precosRoutes = require("./routes/precos");
// ...
app.use("/api/precos", precosRoutes);
