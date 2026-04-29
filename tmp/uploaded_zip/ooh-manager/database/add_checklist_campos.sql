ALTER TABLE ordens_producao ADD COLUMN IF NOT EXISTS check_promotoras BOOLEAN DEFAULT FALSE;
ALTER TABLE ordens_producao ADD COLUMN IF NOT EXISTS check_material_cliente BOOLEAN DEFAULT FALSE;

-- Tabela de tarefas financeiras geradas automaticamente pelo PI
CREATE TABLE IF NOT EXISTS tarefas_financeiro (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  pi_id           UUID NOT NULL REFERENCES pedidos_insercao(id),
  cliente_id      UUID NOT NULL REFERENCES clientes(id),
  campanha        VARCHAR(200),
  valor_total     NUMERIC(14,2),
  periodo_inicio  DATE,
  periodo_fim     DATE,
  status_faturamento  VARCHAR(30) DEFAULT 'Pendente' CHECK (status_faturamento IN ('Pendente','Faturado','Cancelado')),
  status_nf           VARCHAR(30) DEFAULT 'Pendente' CHECK (status_nf IN ('Pendente','Emitida','Cancelada')),
  faturamento_id  UUID REFERENCES faturamentos(id),
  nf_id           UUID REFERENCES notas_fiscais(id),
  observacoes     TEXT,
  criado_em       TIMESTAMPTZ DEFAULT NOW(),
  atualizado_em   TIMESTAMPTZ DEFAULT NOW()
);

-- Campo cargo na tabela clientes
ALTER TABLE clientes ADD COLUMN IF NOT EXISTS cargo VARCHAR(120);

-- Midias novas
INSERT INTO midias (nome) VALUES
  ('Bikedoor'),
  ('Mochila Pirulito'),
  ('Led Truck'),
  ('Vitrine Truck'),
  ('Empena')
ON CONFLICT DO NOTHING;

-- Campos cnpj e agencia na tabela propostas
ALTER TABLE propostas ADD COLUMN IF NOT EXISTS cnpj VARCHAR(20);
ALTER TABLE propostas ADD COLUMN IF NOT EXISTS agencia VARCHAR(150);
