const router = require("express").Router();
const { query } = require("../config/db");
const { authMiddleware, authorize } = require("../middleware/auth");
router.use(authMiddleware);

// GET /api/financeiro — cobranças
router.get("/", async (req, res) => {
  const { status } = req.query;
  let sql = `SELECT cb.*, c.empresa AS cliente_nome, pi.campanha,
                    pi.periodo_inicio, pi.periodo_fim, pi.valor_total
             FROM cobrancas cb
             JOIN clientes c ON cb.cliente_id = c.id
             JOIN pedidos_insercao pi ON cb.pi_id = pi.id
             WHERE 1=1`;
  const params = [];
  if (status) { params.push(status); sql += ` AND cb.status = $${params.length}`; }
  await query("UPDATE cobrancas SET status='Atrasado' WHERE status='Pendente' AND vencimento < CURRENT_DATE");
  sql += " ORDER BY cb.vencimento ASC";
  const { rows } = await query(sql, params);
  res.json(rows);
});

// GET /api/financeiro/resumo
router.get("/resumo", async (req, res) => {
  const { rows } = await query(
    `SELECT
       COALESCE(SUM(valor) FILTER (WHERE status='Pendente'),0)  AS pendente,
       COALESCE(SUM(valor) FILTER (WHERE status='Pago'),0)      AS pago,
       COALESCE(SUM(valor) FILTER (WHERE status='Atrasado'),0)  AS atrasado,
       COUNT(*) FILTER (WHERE status='Pendente')  AS qtd_pendente,
       COUNT(*) FILTER (WHERE status='Atrasado')  AS qtd_atrasado
     FROM cobrancas`
  );
  res.json(rows[0]);
});

// GET /api/financeiro/tarefas — fila de faturamento/NF para o financeiro
router.get("/tarefas", async (req, res) => {
  const { rows } = await query(
    `SELECT tf.*,
            c.empresa AS cliente_nome,
            c.email   AS cliente_email,
            c.telefone AS cliente_telefone,
            pi.numero AS pi_numero,
            pi.status AS pi_status
     FROM tarefas_financeiro tf
     JOIN clientes c  ON tf.cliente_id = c.id
     JOIN pedidos_insercao pi ON tf.pi_id = pi.id
     ORDER BY tf.criado_em DESC`
  );
  res.json(rows);
});

// PUT /api/financeiro/:id/pagar
router.put("/:id/pagar", authorize("financeiro","administrador"), async (req, res) => {
  const { forma_pagamento } = req.body;
  const { rows } = await query(
    `UPDATE cobrancas SET status='Pago', data_pagamento=CURRENT_DATE, forma_pagamento=$1
     WHERE id=$2 RETURNING *`,
    [forma_pagamento||"Transferencia", req.params.id]
  );
  if (!rows[0]) return res.status(404).json({ erro: "Cobranca nao encontrada" });
  res.json(rows[0]);
});

// POST /api/financeiro/tarefas/:id/faturar — fatura e emite NF em uma acao
router.post("/tarefas/:id/faturar", authorize("financeiro","administrador"), async (req, res) => {
  const { observacoes } = req.body;
  try {
    const { rows: tarRows } = await query(
      "SELECT * FROM tarefas_financeiro WHERE id=$1", [req.params.id]
    );
    if (!tarRows[0]) return res.status(404).json({ erro: "Tarefa nao encontrada" });
    const tarefa = tarRows[0];

    // Gerar faturamento
    const ano = new Date().getFullYear();
    const seq = await query("SELECT nextval('seq_faturamento') AS n");
    const numFat = `FAT-${ano}-${String(seq.rows[0].n).padStart(3,"0")}`;
    const { rows: fatRows } = await query(
      `INSERT INTO faturamentos (pi_id, numero, valor, status)
       VALUES ($1,$2,$3,'Faturado') RETURNING *`,
      [tarefa.pi_id, numFat, tarefa.valor_total]
    );
    const fat = fatRows[0];

    // Emitir NF (simulada)
    const numeroNF  = `NFS-e ${Math.floor(Math.random()*90000+10000)}`;
    const chave     = `${Date.now()}${Math.floor(Math.random()*1e10)}`.substring(0,44);
    const { rows: nfRows } = await query(
      `INSERT INTO notas_fiscais (faturamento_id, numero_nf, serie, chave_acesso, status, emitida_em, resposta_api)
       VALUES ($1,$2,'1',$3,'Emitida',NOW(),$4) RETURNING *`,
      [fat.id, numeroNF, chave, JSON.stringify({ simulado:true, mensagem:"NF emitida com sucesso" })]
    );
    const nf = nfRows[0];

    // Atualizar tarefa
    await query(
      `UPDATE tarefas_financeiro
       SET status_faturamento='Faturado', status_nf='Emitida',
           faturamento_id=$1, nf_id=$2, observacoes=$3, atualizado_em=NOW()
       WHERE id=$4`,
      [fat.id, nf.id, observacoes||null, req.params.id]
    );

    res.json({ faturamento: fat, nota_fiscal: nf, mensagem: "Faturamento e NF gerados com sucesso!" });
  } catch(e) {
    console.error("Erro ao faturar:", e.message);
    res.status(500).json({ erro: e.message });
  }
});

module.exports = router;
