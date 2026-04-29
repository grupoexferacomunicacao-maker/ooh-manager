const router = require("express").Router();
const { query } = require("../config/db");
const { authMiddleware } = require("../middleware/auth");
router.use(authMiddleware);

router.get("/", async (req, res) => {
  // Atualiza cobranças vencidas antes de calcular
  await query("UPDATE cobrancas SET status='Atrasado' WHERE status='Pendente' AND vencimento < CURRENT_DATE");

  const [
    clientesRes,
    pisRes,
    finRes,
    funiRes,
    prodRes,
    checkRes,
    top5Res,
  ] = await Promise.all([
    query(`SELECT
             COUNT(*) AS total,
             COUNT(*) FILTER (WHERE status='Fechado') AS ativos,
             COUNT(*) FILTER (WHERE status='Lead') AS leads,
             COUNT(*) FILTER (WHERE status='Em negociação') AS negociacao
           FROM clientes`),
    query(`SELECT COUNT(*) AS total, SUM(valor_total) AS volume FROM pedidos_insercao WHERE status='Ativo'`),
    query(`SELECT
             COALESCE(SUM(valor) FILTER (WHERE status='Pago'),0)    AS pago,
             COALESCE(SUM(valor) FILTER (WHERE status='Pendente'),0) AS pendente,
             COALESCE(SUM(valor) FILTER (WHERE status='Atrasado'),0) AS atrasado
           FROM cobrancas`),
    query(`SELECT status, COUNT(*) AS qtd FROM clientes GROUP BY status`),
    query(`SELECT status, COUNT(*) AS qtd FROM ordens_producao GROUP BY status`),
    query(`SELECT COUNT(*) AS total FROM checkings`),
    query(`SELECT c.empresa, SUM(pi.valor_total) AS volume
           FROM pedidos_insercao pi
           JOIN clientes c ON pi.cliente_id = c.id
           GROUP BY c.empresa ORDER BY volume DESC LIMIT 5`),
  ]);

  res.json({
    clientes: clientesRes.rows[0],
    pis: pisRes.rows[0],
    financeiro: finRes.rows[0],
    funil: funiRes.rows,
    producao: prodRes.rows,
    checkings: checkRes.rows[0],
    top5Clientes: top5Res.rows,
  });
});

module.exports = router;
