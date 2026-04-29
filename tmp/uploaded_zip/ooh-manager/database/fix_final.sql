-- Criar tabela tarefas_financeiro se nao existir
CREATE TABLE IF NOT EXISTS tarefas_financeiro (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  pi_id           UUID NOT NULL REFERENCES pedidos_insercao(id),
  cliente_id      UUID NOT NULL REFERENCES clientes(id),
  campanha        VARCHAR(200),
  valor_total     NUMERIC(14,2),
  periodo_inicio  DATE,
  periodo_fim     DATE,
  status_faturamento  VARCHAR(30) DEFAULT 'Pendente',
  status_nf           VARCHAR(30) DEFAULT 'Pendente',
  faturamento_id  UUID REFERENCES faturamentos(id),
  nf_id           UUID REFERENCES notas_fiscais(id),
  observacoes     TEXT,
  criado_em       TIMESTAMPTZ DEFAULT NOW(),
  atualizado_em   TIMESTAMPTZ DEFAULT NOW()
);

-- Adicionar colunas novas ao checklist se nao existirem
ALTER TABLE ordens_producao ADD COLUMN IF NOT EXISTS check_promotoras BOOLEAN DEFAULT FALSE;
ALTER TABLE ordens_producao ADD COLUMN IF NOT EXISTS check_material_cliente BOOLEAN DEFAULT FALSE;

-- Atualizar valores null para false
UPDATE ordens_producao SET
  check_arte = COALESCE(check_arte, FALSE),
  check_aprovacao = COALESCE(check_aprovacao, FALSE),
  check_grafica = COALESCE(check_grafica, FALSE),
  check_promotoras = COALESCE(check_promotoras, FALSE),
  check_material_cliente = COALESCE(check_material_cliente, FALSE);

-- Campos cnpj e agencia nas propostas
ALTER TABLE propostas ADD COLUMN IF NOT EXISTS cnpj VARCHAR(20);
ALTER TABLE propostas ADD COLUMN IF NOT EXISTS agencia VARCHAR(150);

-- Campo cargo nos clientes
ALTER TABLE clientes ADD COLUMN IF NOT EXISTS cargo VARCHAR(120);

-- Midias novas
INSERT INTO midias (nome) VALUES ('Bikedoor') ON CONFLICT DO NOTHING;
INSERT INTO midias (nome) VALUES ('Mochila Pirulito') ON CONFLICT DO NOTHING;
INSERT INTO midias (nome) VALUES ('Led Truck') ON CONFLICT DO NOTHING;
INSERT INTO midias (nome) VALUES ('Vitrine Truck') ON CONFLICT DO NOTHING;
INSERT INTO midias (nome) VALUES ('Empena') ON CONFLICT DO NOTHING;

SELECT 'Banco atualizado com sucesso!' AS resultado;

-- Campo observacoes na producao
ALTER TABLE ordens_producao ADD COLUMN IF NOT EXISTS observacoes TEXT;

-- Campo observacoes na producao (se ainda nao existe)
ALTER TABLE ordens_producao ADD COLUMN IF NOT EXISTS observacoes TEXT;
