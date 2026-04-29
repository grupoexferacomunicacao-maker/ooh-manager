const jwt = require("jsonwebtoken");
const { query } = require("../config/db");

// Verifica token JWT
async function authMiddleware(req, res, next) {
  const header = req.headers.authorization;
  if (!header || !header.startsWith("Bearer ")) {
    return res.status(401).json({ erro: "Token não fornecido" });
  }
  const token = header.split(" ")[1];
  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const { rows } = await query(
      "SELECT id, nome, email, perfil, ativo FROM usuarios WHERE id = $1",
      [decoded.id]
    );
    if (!rows[0] || !rows[0].ativo) {
      return res.status(401).json({ erro: "Usuário inativo ou não encontrado" });
    }
    req.user = rows[0];
    next();
  } catch (e) {
    return res.status(401).json({ erro: "Token inválido ou expirado" });
  }
}

// Restringe por perfil
function authorize(...perfis) {
  return (req, res, next) => {
    if (!perfis.includes(req.user.perfil)) {
      return res.status(403).json({ erro: "Acesso não autorizado para este perfil" });
    }
    next();
  };
}

// Registra ação no log
async function registrarLog(usuarioId, acao, tabela, registroId, detalhe, ip) {
  try {
    await query(
      `INSERT INTO logs (usuario_id, acao, tabela, registro_id, detalhe, ip)
       VALUES ($1, $2, $3, $4, $5, $6)`,
      [usuarioId, acao, tabela, registroId, JSON.stringify(detalhe), ip]
    );
  } catch (e) {
    console.error("Erro ao registrar log:", e.message);
  }
}

module.exports = { authMiddleware, authorize, registrarLog };
