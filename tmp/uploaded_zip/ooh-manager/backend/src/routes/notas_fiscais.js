const router = require("express").Router();
const { query } = require("../config/db");
const { authMiddleware, authorize } = require("../middleware/auth");
router.use(authMiddleware);

router.get("/", async (req, res) => {
  const { rows } = await query(
    `SELECT nf.*, f.numero AS faturamento_numero, pi.campanha, c.empresa AS cliente_nome
     FROM notas_fiscais nf
     JOIN faturamentos f ON nf.faturamento_id = f.id
     JOIN pedidos_insercao pi ON f.pi_id = pi.id
     JOIN clientes c ON pi.cliente_id = c.id
     ORDER BY nf.criado_em DESC`
  );
  res.json(rows);
});

// POST /api/notas-fiscais — emite NF (simulada)
router.post("/", authorize("financeiro","administrador"), async (req, res) => {
  const { faturamento_id } = req.body;
  if (!faturamento_id) return res.status(400).json({ erro: "faturamento_id obrigatório" });

  // Em produção: chamar API real de NFSe aqui
  // const resp = await fetch(process.env.NFSE_API_URL + "/nfse", { method: "POST", ... });

  // Simulação
  const numeroNF = `NFS-e ${Math.floor(Math.random() * 90000 + 10000)}`;
  const chave    = `${Date.now()}${Math.floor(Math.random() * 1e10)}`.substring(0,44);

  const { rows } = await query(
    `INSERT INTO notas_fiscais (faturamento_id, numero_nf, serie, chave_acesso, status, emitida_em, resposta_api)
     VALUES ($1,$2,'1',$3,'Emitida',NOW(),$4) RETURNING *`,
    [faturamento_id, numeroNF, chave, JSON.stringify({ simulado: true, mensagem: "NF emitida com sucesso (simulação)" })]
  );

  // Marcar faturamento como faturado
  await query("UPDATE faturamentos SET status='Faturado' WHERE id=$1", [faturamento_id]);

  res.status(201).json(rows[0]);
});

module.exports = router;
