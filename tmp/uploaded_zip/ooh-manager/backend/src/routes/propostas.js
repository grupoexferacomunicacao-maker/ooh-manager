const router = require("express").Router();
const { query } = require("../config/db");
const { authMiddleware, registrarLog } = require("../middleware/auth");

router.use(authMiddleware);

// Gera número sequencial PROP-YYYY-NNN
async function gerarNumero() {
  const ano = new Date().getFullYear();
  const seq = await query("SELECT nextval('seq_proposta') AS n");
  return `PROP-${ano}-${String(seq.rows[0].n).padStart(3, "0")}`;
}

// GET /api/propostas
router.get("/", async (req, res) => {
  const { cliente_id, status } = req.query;
  let sql = `SELECT p.*, c.empresa AS cliente_nome
             FROM propostas p JOIN clientes c ON p.cliente_id = c.id WHERE 1=1`;
  const params = [];
  if (cliente_id) { params.push(cliente_id); sql += ` AND p.cliente_id = $${params.length}`; }
  if (status)     { params.push(status);     sql += ` AND p.status = $${params.length}`; }
  sql += " ORDER BY p.criado_em DESC";
  const { rows } = await query(sql, params);
  res.json(rows);
});

// GET /api/propostas/:id
router.get("/:id", async (req, res) => {
  const { rows } = await query(
    `SELECT p.*, c.empresa AS cliente_nome, c.email AS cliente_email
     FROM propostas p JOIN clientes c ON p.cliente_id = c.id
     WHERE p.id = $1`, [req.params.id]
  );
  if (!rows[0]) return res.status(404).json({ erro: "Proposta não encontrada" });

  const { rows: midias } = await query(
    `SELECT pm.*, m.nome AS midia_nome FROM proposta_midias pm
     JOIN midias m ON pm.midia_id = m.id WHERE pm.proposta_id = $1`,
    [req.params.id]
  );
  res.json({ ...rows[0], midias });
});

// POST /api/propostas
router.post("/", async (req, res) => {
  const { cliente_id, titulo, cnpj, agencia, periodo_inicio, periodo_fim, valor, midias, observacoes, template_html } = req.body;
  if (!cliente_id || !titulo) return res.status(400).json({ erro: "Cliente e titulo obrigatorios" });

  const numero = await gerarNumero();
  const { rows } = await query(
    `INSERT INTO propostas (numero, cliente_id, titulo, cnpj, agencia, periodo_inicio, periodo_fim, valor, observacoes, template_html, criado_por)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11) RETURNING *`,
    [numero, cliente_id, titulo, cnpj||null, agencia||null, periodo_inicio, periodo_fim, valor||0, observacoes, template_html, req.user.id]
  );
  const proposta = rows[0];

  // Inserir mídias vinculadas
  if (midias && midias.length) {
    for (const m of midias) {
      await query(
        `INSERT INTO proposta_midias (proposta_id, midia_id, quantidade, valor, localizacao)
         VALUES ($1,$2,$3,$4,$5)`,
        [proposta.id, m.midia_id, m.quantidade||1, m.valor||0, m.localizacao||null]
      );
    }
  }

  await registrarLog(req.user.id, "criar_proposta", "propostas", proposta.id, { numero }, req.ip);
  res.status(201).json(proposta);
});

// PUT /api/propostas/:id/status
router.put("/:id/status", async (req, res) => {
  try {
    const { status } = req.body;
    const validos = ["Rascunho","Enviada","Aprovada","Reprovada"];
    if (!validos.includes(status)) return res.status(400).json({ erro: "Status invalido" });

    const { rows } = await query(
      "UPDATE propostas SET status=$1 WHERE id=$2 RETURNING *",
      [status, req.params.id]
    );
    if (!rows[0]) return res.status(404).json({ erro: "Proposta nao encontrada" });

    // Se aprovada → gerar PI automaticamente
    if (status === "Aprovada") {
      const proposta = rows[0];
      const ano = new Date().getFullYear();
      const seq = await query("SELECT nextval('seq_pi') AS n");
      const numeroPi = `PI-${ano}-${String(seq.rows[0].n).padStart(3, "0")}`;

      const hoje = new Date().toISOString().split("T")[0];
      const dataInicio = proposta.periodo_inicio ? proposta.periodo_inicio : hoje;
      const dataFim    = proposta.periodo_fim    ? proposta.periodo_fim    : hoje;
      const dataVenc   = dataInicio;

      const { rows: piRows } = await query(
        `INSERT INTO pedidos_insercao (numero, proposta_id, cliente_id, campanha, periodo_inicio, periodo_fim, valor_total, criado_por)
         VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING *`,
        [numeroPi, proposta.id, proposta.cliente_id, proposta.titulo,
         dataInicio, dataFim, proposta.valor || 0, req.user.id]
      );
      const pi = piRows[0];

      await query(
        "INSERT INTO ordens_producao (pi_id, responsavel_id) VALUES ($1,$2)",
        [pi.id, req.user.id]
      );

      await query(
        `INSERT INTO cobrancas (pi_id, cliente_id, descricao, valor, vencimento)
         VALUES ($1,$2,$3,$4,$5)`,
        [pi.id, proposta.cliente_id, proposta.titulo, proposta.valor || 0, dataVenc]
      );

      await query(
        `INSERT INTO tarefas_financeiro
           (pi_id, cliente_id, campanha, valor_total, periodo_inicio, periodo_fim)
         VALUES ($1,$2,$3,$4,$5,$6)`,
        [pi.id, proposta.cliente_id, proposta.titulo,
         proposta.valor || 0, dataInicio, dataFim]
      );

      return res.json({ proposta: rows[0], pi });
    }

    res.json(rows[0]);
  } catch (e) {
    console.error("Erro ao aprovar proposta:", e.message);
    res.status(500).json({ erro: e.message });
  }
});

module.exports = router;
