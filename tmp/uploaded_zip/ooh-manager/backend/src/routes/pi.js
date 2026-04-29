// ── pi.js ────────────────────────────────────────────────────
const router = require("express").Router();
const { query } = require("../config/db");
const { authMiddleware } = require("../middleware/auth");
router.use(authMiddleware);

router.get("/", async (req, res) => {
  const { rows } = await query(
    `SELECT pi.*, c.empresa AS cliente_nome,
            p.titulo AS proposta_titulo
     FROM pedidos_insercao pi
     JOIN clientes c ON pi.cliente_id = c.id
     JOIN propostas p ON pi.proposta_id = p.id
     ORDER BY pi.criado_em DESC`
  );
  res.json(rows);
});

router.get("/:id", async (req, res) => {
  const { rows } = await query(
    `SELECT pi.*, c.empresa AS cliente_nome, c.email AS cliente_email
     FROM pedidos_insercao pi
     JOIN clientes c ON pi.cliente_id = c.id
     WHERE pi.id = $1`, [req.params.id]
  );
  if (!rows[0]) return res.status(404).json({ erro: "PI não encontrado" });
  const { rows: midias } = await query(
    `SELECT pm.*, m.nome AS midia_nome FROM pi_midias pm
     JOIN midias m ON pm.midia_id = m.id WHERE pm.pi_id = $1`,
    [req.params.id]
  );
  res.json({ ...rows[0], midias });
});

module.exports = router;
