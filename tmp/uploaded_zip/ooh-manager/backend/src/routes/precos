const router = require("express").Router();
const { query } = require("../config/db");
const { authMiddleware } = require("../middleware/auth");
router.use(authMiddleware);

router.get("/", async (req, res) => {
  try {
    const { rows } = await query("SELECT * FROM tabela_precos WHERE ativo = TRUE ORDER BY tipo, midia_nome");
    res.json(rows);
  } catch(e) {
    res.status(500).json({ erro: e.message });
  }
});

router.put("/:id", async (req, res) => {
  const { preco_1, preco_2_6, preco_7mais, desconto_multi, desconto_6h, unidade } = req.body;
  try {
    const pid = String(req.params["id"]);
    const { rows } = await query(
      "UPDATE tabela_precos SET preco_1=$1, preco_2_6=$2, preco_7mais=$3, desconto_multi=$4, desconto_6h=$5, unidade=$6, atualizado_em=NOW() WHERE id=$7 RETURNING *",
      [preco_1, preco_2_6, preco_7mais, desconto_multi, desconto_6h, unidade, pid]
    );
    if (!rows[0]) return res.status(404).json({ erro: "Preco nao encontrado" });
    res.json(rows[0]);
  } catch(e) {
    res.status(500).json({ erro: e.message });
  }
});

module.exports = router;
