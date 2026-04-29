const router = require("express").Router();
const { query } = require("../config/db");
const { authMiddleware } = require("../middleware/auth");
router.use(authMiddleware);

// GET /api/relatorios/mensal?ano=2025&mes=4
router.get("/mensal", async (req, res) => {
  const ano = parseInt(req.query.ano) || new Date().getFullYear();
  const mes = parseInt(req.query.mes) || new Date().getMonth() + 1;

  try {
    const [fatRes, cobRes, pisRes, clientesRes, propRes] = await Promise.all([
      // Faturamento do mes
      query(`SELECT COALESCE(SUM(valor),0) AS total, COUNT(*) AS qtd
             FROM faturamentos
             WHERE EXTRACT(YEAR FROM data)=$1 AND EXTRACT(MONTH FROM data)=$2`, [ano, mes]),
      // Recebimentos do mes
      query(`SELECT COALESCE(SUM(valor),0) AS total, COUNT(*) AS qtd
             FROM cobrancas
             WHERE status='Pago'
               AND EXTRACT(YEAR FROM data_pagamento)=$1
               AND EXTRACT(MONTH FROM data_pagamento)=$2`, [ano, mes]),
      // PIs abertos no mes
      query(`SELECT COUNT(*) AS qtd, COALESCE(SUM(valor_total),0) AS volume
             FROM pedidos_insercao
             WHERE EXTRACT(YEAR FROM criado_em)=$1 AND EXTRACT(MONTH FROM criado_em)=$2`, [ano, mes]),
      // Novos clientes no mes
      query(`SELECT COUNT(*) AS qtd FROM clientes
             WHERE EXTRACT(YEAR FROM criado_em)=$1 AND EXTRACT(MONTH FROM criado_em)=$2`, [ano, mes]),
      // Propostas enviadas vs aprovadas
      query(`SELECT
               COUNT(*) FILTER (WHERE status='Enviada') AS enviadas,
               COUNT(*) FILTER (WHERE status='Aprovada') AS aprovadas,
               COUNT(*) FILTER (WHERE status='Reprovada') AS reprovadas,
               COALESCE(SUM(valor) FILTER (WHERE status='Aprovada'),0) AS valor_aprovado
             FROM propostas
             WHERE EXTRACT(YEAR FROM criado_em)=$1 AND EXTRACT(MONTH FROM criado_em)=$2`, [ano, mes]),
    ]);

    // Top clientes do mes
    const { rows: topClientes } = await query(`
      SELECT c.empresa, SUM(cb.valor) AS total_pago, COUNT(cb.id) AS qtd_pagamentos
      FROM cobrancas cb
      JOIN clientes c ON cb.cliente_id = c.id
      WHERE cb.status = 'Pago'
        AND EXTRACT(YEAR FROM cb.data_pagamento)=$1
        AND EXTRACT(MONTH FROM cb.data_pagamento)=$2
      GROUP BY c.empresa
      ORDER BY total_pago DESC LIMIT 5`, [ano, mes]);

    // Evolucao mensal (ultimos 6 meses)
    const { rows: evolucao } = await query(`
      SELECT
        EXTRACT(YEAR FROM data_pagamento) AS ano,
        EXTRACT(MONTH FROM data_pagamento) AS mes,
        COALESCE(SUM(valor),0) AS total
      FROM cobrancas
      WHERE status = 'Pago'
        AND data_pagamento >= CURRENT_DATE - INTERVAL '6 months'
      GROUP BY 1, 2 ORDER BY 1, 2`);

    // Midias mais vendidas
    const { rows: topMidias } = await query(`
      SELECT m.nome, COUNT(*) AS qtd, COALESCE(SUM(pm.valor),0) AS receita
      FROM proposta_midias pm
      JOIN midias m ON pm.midia_id = m.id
      JOIN propostas p ON pm.proposta_id = p.id
      WHERE p.status = 'Aprovada'
        AND EXTRACT(YEAR FROM p.criado_em)=$1
        AND EXTRACT(MONTH FROM p.criado_em)=$2
      GROUP BY m.nome ORDER BY qtd DESC LIMIT 5`, [ano, mes]);

    res.json({
      periodo: { ano, mes },
      faturamento: fatRes.rows[0],
      recebimentos: cobRes.rows[0],
      pis: pisRes.rows[0],
      novos_clientes: clientesRes.rows[0],
      propostas: propRes.rows[0],
      top_clientes: topClientes,
      evolucao_mensal: evolucao,
      top_midias: topMidias,
    });
  } catch(e) {
    res.status(500).json({ erro: e.message });
  }
});

// GET /api/relatorios/logs
router.get("/logs", async (req, res) => {
  const { limit = 50, usuario_id } = req.query;
  let sql = `SELECT l.*, u.nome AS usuario_nome, u.perfil
             FROM logs l LEFT JOIN usuarios u ON l.usuario_id = u.id WHERE 1=1`;
  const params = [];
  if (usuario_id) { params.push(usuario_id); sql += ` AND l.usuario_id = $${params.length}`; }
  sql += ` ORDER BY l.criado_em DESC LIMIT $${params.length + 1}`;
  params.push(parseInt(limit));
  const { rows } = await query(sql, params);
  res.json(rows);
});

// GET /api/relatorios/calendario
router.get("/calendario", async (req, res) => {
  try {
    const { rows } = await query(`
      SELECT pi.id, pi.numero, pi.campanha, pi.periodo_inicio, pi.periodo_fim,
             pi.valor_total, pi.status,
             c.empresa AS cliente_nome,
             op.status AS status_producao
      FROM pedidos_insercao pi
      JOIN clientes c ON pi.cliente_id = c.id
      LEFT JOIN ordens_producao op ON op.pi_id = pi.id AND op.status != 'Cancelado'
      WHERE pi.status = 'Ativo'
        AND pi.periodo_fim >= CURRENT_DATE - INTERVAL '30 days'
      ORDER BY pi.periodo_inicio ASC
    `);
    res.json(rows);
  } catch(e) {
    res.status(500).json({ erro: e.message });
  }
});

// GET /api/relatorios/funil
router.get("/funil", async (req, res) => {
  try {
    const { rows } = await query(`
      SELECT
        status,
        COUNT(*) AS qtd,
        COALESCE(SUM(valor),0) AS valor_total,
        COALESCE(AVG(valor),0) AS ticket_medio
      FROM propostas
      GROUP BY status ORDER BY
        CASE status WHEN 'Rascunho' THEN 1 WHEN 'Enviada' THEN 2 WHEN 'Aprovada' THEN 3 WHEN 'Reprovada' THEN 4 END
    `);
    const total_valor = rows.reduce((a,b) => a + parseFloat(b.valor_total||0), 0);
    res.json({ etapas: rows, total_valor });
  } catch(e) {
    res.status(500).json({ erro: e.message });
  }
});

module.exports = router;
