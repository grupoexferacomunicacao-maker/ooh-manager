const router = require("express").Router();
const { query } = require("../config/db");
const { authMiddleware, authorize } = require("../middleware/auth");
router.use(authMiddleware);

// ── FATURAMENTO ──────────────────────────────────────────────
router.get("/", async (req, res) => {
  const { rows } = await query(
    `SELECT f.*, pi.campanha, c.empresa AS cliente_nome
     FROM faturamentos f
     JOIN pedidos_insercao pi ON f.pi_id = pi.id
     JOIN clientes c ON pi.cliente_id = c.id
     ORDER BY f.criado_em DESC`
  );
  res.json(rows);
});

router.post("/", authorize("financeiro","administrador"), async (req, res) => {
  const { pi_id } = req.body;
  if (!pi_id) return res.status(400).json({ erro: "pi_id obrigatório" });

  const { rows: piRows } = await query("SELECT * FROM pedidos_insercao WHERE id=$1", [pi_id]);
  if (!piRows[0]) return res.status(404).json({ erro: "PI não encontrado" });

  const ano = new Date().getFullYear();
  const seq = await query("SELECT nextval('seq_faturamento') AS n");
  const numero = `FAT-${ano}-${String(seq.rows[0].n).padStart(3, "0")}`;

  const { rows } = await query(
    `INSERT INTO faturamentos (pi_id, numero, valor, status)
     VALUES ($1,$2,$3,'Faturado') RETURNING *`,
    [pi_id, numero, piRows[0].valor_total]
  );
  res.status(201).json(rows[0]);
});

module.exports = router;
