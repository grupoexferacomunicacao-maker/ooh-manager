const router = require("express").Router();
const { query } = require("../config/db");
const { authMiddleware } = require("../middleware/auth");

router.use(authMiddleware);

// GET /api/midias
router.get("/", async (req, res) => {
  const { rows } = await query("SELECT * FROM midias WHERE ativo = TRUE ORDER BY nome");
  res.json(rows);
});

module.exports = router;
