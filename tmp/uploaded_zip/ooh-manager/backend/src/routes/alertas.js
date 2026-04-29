const router = require("express").Router();
const { query } = require("../config/db");
const { authMiddleware } = require("../middleware/auth");
router.use(authMiddleware);

// GET /api/alertas — todos os alertas do sistema
router.get("/", async (req, res) => {
  try {
    const alertas = [];

    // 1. Propostas sem resposta ha mais de 3 dias
    const { rows: propsPendentes } = await query(`
      SELECT p.id, p.numero, p.titulo, p.valor, p.criado_em,
             c.empresa AS cliente_nome, c.telefone, c.whatsapp, c.email,
             NOW() - p.criado_em AS tempo_sem_resposta
      FROM propostas p
      JOIN clientes c ON p.cliente_id = c.id
      WHERE p.status = 'Enviada'
        AND p.criado_em < NOW() - INTERVAL '3 days'
      ORDER BY p.criado_em ASC
    `);
    propsPendentes.forEach(p => {
      const dias = Math.floor(p.tempo_sem_resposta.days || 0);
      alertas.push({
        tipo: 'proposta_sem_resposta',
        nivel: dias > 7 ? 'critico' : 'aviso',
        titulo: `Proposta sem resposta ha ${dias} dias`,
        descricao: `${p.numero} - ${p.titulo} | Cliente: ${p.cliente_nome}`,
        valor: p.valor,
        referencia_id: p.id,
        referencia_num: p.numero,
        cliente: p.cliente_nome,
        contato: { telefone: p.telefone, whatsapp: p.whatsapp, email: p.email },
        criado_em: p.criado_em,
        dias: dias
      });
    });

    // 2. Cobranças vencidas
    await query("UPDATE cobrancas SET status='Atrasado' WHERE status='Pendente' AND vencimento < CURRENT_DATE");
    const { rows: cobsAtrasadas } = await query(`
      SELECT cb.id, cb.valor, cb.vencimento, cb.descricao,
             c.empresa AS cliente_nome, c.telefone, c.whatsapp, c.email,
             CURRENT_DATE - cb.vencimento AS dias_atraso
      FROM cobrancas cb
      JOIN clientes c ON cb.cliente_id = c.id
      WHERE cb.status = 'Atrasado'
      ORDER BY cb.vencimento ASC
    `);
    cobsAtrasadas.forEach(cb => {
      alertas.push({
        tipo: 'cobranca_atrasada',
        nivel: cb.dias_atraso > 15 ? 'critico' : 'aviso',
        titulo: `Cobranca atrasada ${cb.dias_atraso} dias`,
        descricao: `${cb.descricao} | Cliente: ${cb.cliente_nome}`,
        valor: cb.valor,
        referencia_id: cb.id,
        cliente: cb.cliente_nome,
        contato: { telefone: cb.telefone, whatsapp: cb.whatsapp, email: cb.email },
        vencimento: cb.vencimento,
        dias: cb.dias_atraso
      });
    });

    // 3. Cobranças vencendo em 3 dias
    const { rows: cobsProximas } = await query(`
      SELECT cb.id, cb.valor, cb.vencimento, cb.descricao,
             c.empresa AS cliente_nome,
             cb.vencimento - CURRENT_DATE AS dias_para_vencer
      FROM cobrancas cb
      JOIN clientes c ON cb.cliente_id = c.id
      WHERE cb.status = 'Pendente'
        AND cb.vencimento BETWEEN CURRENT_DATE AND CURRENT_DATE + 3
      ORDER BY cb.vencimento ASC
    `);
    cobsProximas.forEach(cb => {
      alertas.push({
        tipo: 'cobranca_proxima',
        nivel: 'info',
        titulo: `Vencimento em ${cb.dias_para_vencer} dia(s)`,
        descricao: `${cb.descricao} | Cliente: ${cb.cliente_nome}`,
        valor: cb.valor,
        referencia_id: cb.id,
        cliente: cb.cliente_nome,
        vencimento: cb.vencimento,
        dias: cb.dias_para_vencer
      });
    });

    // 4. Campanhas terminando em 7 dias
    const { rows: campaignsEnd } = await query(`
      SELECT pi.id, pi.numero, pi.campanha, pi.periodo_fim,
             c.empresa AS cliente_nome,
             pi.periodo_fim - CURRENT_DATE AS dias_restantes
      FROM pedidos_insercao pi
      JOIN clientes c ON pi.cliente_id = c.id
      WHERE pi.status = 'Ativo'
        AND pi.periodo_fim BETWEEN CURRENT_DATE AND CURRENT_DATE + 7
      ORDER BY pi.periodo_fim ASC
    `);
    campaignsEnd.forEach(pi => {
      alertas.push({
        tipo: 'campanha_terminando',
        nivel: 'info',
        titulo: `Campanha termina em ${pi.dias_restantes} dia(s)`,
        descricao: `${pi.numero} - ${pi.campanha} | ${pi.cliente_nome}`,
        referencia_id: pi.id,
        referencia_num: pi.numero,
        cliente: pi.cliente_nome,
        dias: pi.dias_restantes
      });
    });

    // 5. Producao parada (sem atualizacao ha 5+ dias)
    const { rows: prodParada } = await query(`
      SELECT op.id, op.status, op.atualizado_em, pi.campanha,
             c.empresa AS cliente_nome,
             NOW() - op.atualizado_em AS tempo_parado
      FROM ordens_producao op
      JOIN pedidos_insercao pi ON op.pi_id = pi.id
      JOIN clientes c ON pi.cliente_id = c.id
      WHERE op.status IN ('Pendente','Em producao')
        AND op.atualizado_em < NOW() - INTERVAL '5 days'
    `);
    prodParada.forEach(op => {
      const dias = Math.floor(op.tempo_parado.days || 0);
      alertas.push({
        tipo: 'producao_parada',
        nivel: 'aviso',
        titulo: `Producao parada ha ${dias} dias`,
        descricao: `Campanha: ${op.campanha} | ${op.cliente_nome}`,
        referencia_id: op.id,
        cliente: op.cliente_nome,
        dias: dias
      });
    });

    res.json(alertas);
  } catch(e) {
    console.error("Erro alertas:", e.message);
    res.status(500).json({ erro: e.message });
  }
});

module.exports = router;
