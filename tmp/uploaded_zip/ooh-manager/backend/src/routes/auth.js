const router  = require("express").Router();
const bcrypt  = require("bcryptjs");
const jwt     = require("jsonwebtoken");
const { body, validationResult } = require("express-validator");
const { query } = require("../config/db");
const { authMiddleware } = require("../middleware/auth");

// POST /api/auth/login
router.post("/login", [
  body("email").isEmail(),
  body("senha").notEmpty(),
], async (req, res) => {
  const erros = validationResult(req);
  if (!erros.isEmpty()) return res.status(400).json({ erros: erros.array() });

  const { email, senha } = req.body;
  try {
    const { rows } = await query(
      "SELECT * FROM usuarios WHERE email = $1 AND ativo = TRUE", [email]
    );
    if (!rows[0]) return res.status(401).json({ erro: "Credenciais inválidas" });

    const valido = await bcrypt.compare(senha, rows[0].senha_hash);
    if (!valido) return res.status(401).json({ erro: "Credenciais inválidas" });

    const token = jwt.sign(
      { id: rows[0].id, perfil: rows[0].perfil },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRES_IN || "7d" }
    );

    res.json({
      token,
      usuario: { id: rows[0].id, nome: rows[0].nome, email: rows[0].email, perfil: rows[0].perfil }
    });
  } catch (e) {
    res.status(500).json({ erro: e.message });
  }
});

// POST /api/auth/register (admin only em produção)
router.post("/register", [
  body("nome").notEmpty(),
  body("email").isEmail(),
  body("senha").isLength({ min: 6 }),
  body("perfil").isIn(["administrador","comercial","operacional","financeiro"]),
], async (req, res) => {
  const erros = validationResult(req);
  if (!erros.isEmpty()) return res.status(400).json({ erros: erros.array() });

  const { nome, email, senha, perfil } = req.body;
  try {
    const hash = await bcrypt.hash(senha, 12);
    const { rows } = await query(
      `INSERT INTO usuarios (nome, email, senha_hash, perfil)
       VALUES ($1, $2, $3, $4) RETURNING id, nome, email, perfil`,
      [nome, email, hash, perfil]
    );
    res.status(201).json(rows[0]);
  } catch (e) {
    if (e.code === "23505") return res.status(400).json({ erro: "Email já cadastrado" });
    res.status(500).json({ erro: e.message });
  }
});

// GET /api/auth/me
router.get("/me", authMiddleware, (req, res) => res.json(req.user));

module.exports = router;
