const router = require("express").Router();
const { query } = require("../config/db");
const { authMiddleware, registrarLog } = require("../middleware/auth");

router.use(authMiddleware);

// GET /api/clientes
router.get("/", async (req, res) => {
  const { status, busca } = req.query;
  let sql = `SELECT c.*, u.nome AS criado_por_nome
             FROM clientes c
             LEFT JOIN usuarios u ON c.criado_por = u.id
             WHERE 1=1`;
  const params = [];
  if (status) { params.push(status); sql += ` AND c.status = $${params.length}`; }
  if (busca)  { params.push(`%${busca}%`); sql += ` AND (c.empresa ILIKE $${params.length} OR c.contato ILIKE $${params.length})`; }
  sql += " ORDER BY c.criado_em DESC";
  const { rows } = await query(sql, params);
  res.json(rows);
});

// GET /api/clientes/:id
router.get("/:id", async (req, res) => {
  const { rows } = await query("SELECT * FROM clientes WHERE id = $1", [req.params.id]);
  if (!rows[0]) return res.status(404).json({ erro: "Cliente não encontrado" });

  const { rows: interacoes } = await query(
    `SELECT i.*, u.nome AS usuario_nome FROM interacoes i
     LEFT JOIN usuarios u ON i.usuario_id = u.id
     WHERE i.cliente_id = $1 ORDER BY i.criado_em DESC`,
    [req.params.id]
  );
  res.json({ ...rows[0], interacoes });
});

// POST /api/clientes
router.post("/", async (req, res) => {
  const { empresa, contato, cargo, telefone, whatsapp, email, origem, status, observacoes } = req.body;
  if (!empresa) return res.status(400).json({ erro: "Nome da empresa obrigatorio" });
  const { rows } = await query(
    `INSERT INTO clientes (empresa, contato, cargo, telefone, whatsapp, email, origem, status, observacoes, criado_por)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) RETURNING *`,
    [empresa, contato, cargo, telefone, whatsapp, email, origem, status||"Lead", observacoes, req.user.id]
  );
  await registrarLog(req.user.id, "criar_cliente", "clientes", rows[0].id, { empresa }, req.ip);
  res.status(201).json(rows[0]);
});

// PUT /api/clientes/:id
router.put("/:id", async (req, res) => {
  const { empresa, contato, cargo, telefone, whatsapp, email, origem, status, observacoes } = req.body;
  const { rows } = await query(
    `UPDATE clientes SET empresa=$1, contato=$2, cargo=$3, telefone=$4, whatsapp=$5,
     email=$6, origem=$7, status=$8, observacoes=$9
     WHERE id = $10 RETURNING *`,
    [empresa, contato, cargo, telefone, whatsapp, email, origem, status, observacoes, req.params.id]
  );
  if (!rows[0]) return res.status(404).json({ erro: "Cliente não encontrado" });
  res.json(rows[0]);
});

// DELETE /api/clientes/:id
router.delete("/:id", async (req, res) => {
  await query("DELETE FROM clientes WHERE id = $1", [req.params.id]);
  res.json({ mensagem: "Cliente removido" });
});

// POST /api/clientes/:id/interacoes
router.post("/:id/interacoes", async (req, res) => {
  const { descricao } = req.body;
  if (!descricao) return res.status(400).json({ erro: "Descrição obrigatória" });
  const { rows } = await query(
    `INSERT INTO interacoes (cliente_id, usuario_id, descricao)
     VALUES ($1, $2, $3) RETURNING *`,
    [req.params.id, req.user.id, descricao]
  );
  res.status(201).json(rows[0]);
});

module.exports = router;
