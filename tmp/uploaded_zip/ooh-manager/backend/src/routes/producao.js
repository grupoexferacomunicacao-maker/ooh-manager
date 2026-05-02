const router = require("express").Router();
const { query } = require("../config/db");
const { authMiddleware } = require("../middleware/auth");
router.use(authMiddleware);
 
// POST /api/producao — criar ordem manualmente
router.post("/", async (req, res) => {
  const { pi_id } = req.body;
  if (!pi_id) return res.status(400).json({ erro: "pi_id obrigatorio" });
  try {
    // Verificar se ja existe ordem ativa para este PI
    const { rows: exists } = await query(
      "SELECT id FROM ordens_producao WHERE pi_id=$1 AND status != 'Cancelado'", [pi_id]
    );
    if (exists.length > 0) return res.status(400).json({ erro: "Ja existe uma ordem ativa para este PI" });
 
    const { rows } = await query(
      "INSERT INTO ordens_producao (pi_id, responsavel_id) VALUES ($1,$2) RETURNING *",
      [pi_id, req.user.id]
    );
    res.status(201).json(rows[0]);
  } catch(e) {
    res.status(500).json({ erro: e.message });
  }
});
 
// GET /api/producao
router.get("/", async (req, res) => {
  try {
    const { rows } = await query(
      `SELECT op.*,
              pi.campanha, pi.periodo_inicio, pi.periodo_fim, pi.valor_total,
              c.empresa AS cliente_nome,
              u.nome    AS responsavel_nome
       FROM ordens_producao op
       JOIN pedidos_insercao pi ON op.pi_id = pi.id
       JOIN clientes c          ON pi.cliente_id = c.id
       LEFT JOIN usuarios u     ON op.responsavel_id = u.id
       ORDER BY
         CASE op.status WHEN 'Em produção' THEN 1 WHEN 'Pendente' THEN 2 WHEN 'Finalizado' THEN 3 ELSE 4 END,
         op.criado_em DESC`
    );
    // Normalizar booleanos
    const normalized = rows.map(function(r) {
      return {
        ...r,
        check_arte:             r.check_arte             || false,
        check_aprovacao:        r.check_aprovacao        || false,
        check_grafica:          r.check_grafica          || false,
        check_promotoras:       r.check_promotoras       || false,
        check_material_cliente: r.check_material_cliente || false,
      };
    });
    res.json(normalized);
  } catch(e) {
    res.status(500).json({ erro: e.message });
  }
});
 
// PUT /api/producao/:id/checklist
router.put("/:id/checklist", async (req, res) => {
  const { check_arte, check_aprovacao, check_grafica, check_promotoras, check_material_cliente, status } = req.body;
 
  // Calcular status automaticamente se nao fornecido
  const allDone = check_arte && check_aprovacao && check_grafica && check_promotoras && check_material_cliente;
  const anyDone = check_arte || check_aprovacao || check_grafica || check_promotoras || check_material_cliente;
  const novoStatus = status || (allDone ? "Finalizado" : anyDone ? "Em produção" : "Pendente");
 
  try {
    const { rows } = await query(
      `UPDATE ordens_producao
       SET check_arte=$1, check_aprovacao=$2, check_grafica=$3,
           check_promotoras=$4, check_material_cliente=$5, status=$6,
           atualizado_em=NOW()
       WHERE id=$7 RETURNING *`,
      [!!check_arte, !!check_aprovacao, !!check_grafica, !!check_promotoras, !!check_material_cliente, novoStatus, req.params.id]
    );
    if (!rows[0]) return res.status(404).json({ erro: "Ordem nao encontrada" });
    res.json({
      ...rows[0],
      check_arte:             rows[0].check_arte             || false,
      check_aprovacao:        rows[0].check_aprovacao        || false,
      check_grafica:          rows[0].check_grafica          || false,
      check_promotoras:       rows[0].check_promotoras       || false,
      check_material_cliente: rows[0].check_material_cliente || false,
    });
  } catch(e) {
    res.status(500).json({ erro: e.message });
  }
});
 
// PUT /api/producao/:id/status
router.put("/:id/status", async (req, res) => {
  const { status, observacoes } = req.body;
  const validos = ["Pendente","Em produção","Finalizado","Cancelado"];
  if (status && !validos.includes(status)) return res.status(400).json({ erro: "Status invalido" });
  try {
    const sets = [];
    const vals = [];
    if (status)      { vals.push(status);      sets.push(`status=$${vals.length}`); }
    if (observacoes !== undefined) { vals.push(observacoes); sets.push(`observacoes=$${vals.length}`); }
    sets.push("atualizado_em=NOW()");
    vals.push(req.params.id);
    const { rows } = await query(
      `UPDATE ordens_producao SET ${sets.join(",")} WHERE id=$${vals.length} RETURNING *`,
      vals
    );
    if (!rows[0]) return res.status(404).json({ erro: "Ordem nao encontrada" });
    res.json(rows[0]);
  } catch(e) {
    res.status(500).json({ erro: e.message });
  }
});
 
module.exports = router;
