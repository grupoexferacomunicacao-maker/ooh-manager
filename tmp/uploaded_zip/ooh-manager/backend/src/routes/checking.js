const router  = require("express").Router();
const multer  = require("multer");
const path    = require("path");
const { query } = require("../config/db");
const { authMiddleware } = require("../middleware/auth");

router.use(authMiddleware);

// Configuração de upload
const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, path.join(__dirname, "../../uploads")),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    cb(null, `checking_${Date.now()}${ext}`);
  },
});
const upload = multer({
  storage,
  limits: { fileSize: (parseInt(process.env.MAX_FILE_SIZE_MB) || 10) * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const ok = /jpeg|jpg|png|webp/.test(path.extname(file.originalname).toLowerCase());
    cb(ok ? null : new Error("Apenas imagens são permitidas"), ok);
  },
});

// GET /api/checking
router.get("/", async (req, res) => {
  const { pi_id } = req.query;
  let sql = `SELECT ck.*, pi.campanha, c.empresa AS cliente_nome
             FROM checkings ck
             JOIN pedidos_insercao pi ON ck.pi_id = pi.id
             JOIN clientes c ON pi.cliente_id = c.id WHERE 1=1`;
  const params = [];
  if (pi_id) { params.push(pi_id); sql += ` AND ck.pi_id = $${params.length}`; }
  sql += " ORDER BY ck.data DESC";
  const { rows } = await query(sql, params);
  res.json(rows);
});

// GET /api/checking/:id (com fotos)
router.get("/:id", async (req, res) => {
  const { rows } = await query("SELECT * FROM checkings WHERE id=$1", [req.params.id]);
  if (!rows[0]) return res.status(404).json({ erro: "Checking não encontrado" });
  const { rows: fotos } = await query(
    "SELECT * FROM checking_fotos WHERE checking_id=$1 ORDER BY criado_em", [req.params.id]
  );
  res.json({ ...rows[0], fotos });
});

// POST /api/checking
router.post("/", async (req, res) => {
  const { pi_id, localizacao, observacao } = req.body;
  if (!pi_id) return res.status(400).json({ erro: "pi_id obrigatório" });
  const { rows } = await query(
    `INSERT INTO checkings (pi_id, localizacao, observacao, responsavel_id)
     VALUES ($1,$2,$3,$4) RETURNING *`,
    [pi_id, localizacao, observacao, req.user.id]
  );
  res.status(201).json(rows[0]);
});

// POST /api/checking/:id/fotos
router.post("/:id/fotos", upload.array("fotos", 20), async (req, res) => {
  const fotos = req.files;
  if (!fotos || !fotos.length) return res.status(400).json({ erro: "Nenhuma foto enviada" });

  const inseridas = [];
  for (const f of fotos) {
    const url = `/uploads/${f.filename}`;
    const { rows } = await query(
      "INSERT INTO checking_fotos (checking_id, url, legenda) VALUES ($1,$2,$3) RETURNING *",
      [req.params.id, url, req.body.legenda||null]
    );
    inseridas.push(rows[0]);
  }
  res.status(201).json(inseridas);
});

module.exports = router;
