-- OOH Manager - Setup Supabase
-- Execute este arquivo no SQL Editor do Supabase

-- ============================================================
--  OOH Manager — Schema PostgreSQL
--  Versão 1.0
-- ============================================================

-- Extensões
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- USUÁRIOS E AUTENTICAÇÃO
-- ============================================================
CREATE TABLE IF NOT EXISTS usuarios (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  nome        VARCHAR(120) NOT NULL,
  email       VARCHAR(180) UNIQUE NOT NULL,
  senha_hash  TEXT NOT NULL,
  perfil      VARCHAR(30) NOT NULL CHECK (perfil IN ('administrador','comercial','operacional','financeiro')),
  ativo       BOOLEAN DEFAULT TRUE,
  criado_em   TIMESTAMPTZ DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- CLIENTES / CRM
-- ============================================================
CREATE TABLE IF NOT EXISTS clientes (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  empresa     VARCHAR(200) NOT NULL,
  contato     VARCHAR(120),
  telefone    VARCHAR(30),
  whatsapp    VARCHAR(30),
  email       VARCHAR(180),
  origem      VARCHAR(60),   -- Indicação, Google Ads, etc.
  status      VARCHAR(30) NOT NULL DEFAULT 'Lead'
              CHECK (status IN ('Lead','Em negociação','Fechado','Perdido')),
  observacoes TEXT,
  criado_por  UUID REFERENCES usuarios(id),
  criado_em   TIMESTAMPTZ DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS interacoes (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  cliente_id  UUID NOT NULL REFERENCES clientes(id) ON DELETE CASCADE,
  usuario_id  UUID REFERENCES usuarios(id),
  descricao   TEXT NOT NULL,
  criado_em   TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- MÍDIAS
-- ============================================================
CREATE TABLE IF NOT EXISTS midias (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  nome        VARCHAR(100) NOT NULL,  -- Painel LED, Outdoor, Busdoor...
  descricao   TEXT,
  ativo       BOOLEAN DEFAULT TRUE
);

INSERT INTO midias (nome) VALUES
  ('Painel LED'),('Outdoor'),('Busdoor'),('Frontlight'),
  ('Backlight'),('Mobiliário Urbano'),('Aeroporto'),
  ('Shopping'),('Mídia Digital OOH');

-- ============================================================
-- PROPOSTAS
-- ============================================================
CREATE TABLE IF NOT EXISTS propostas (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  numero        VARCHAR(20) UNIQUE NOT NULL,  -- PROP-2025-001
  cliente_id    UUID NOT NULL REFERENCES clientes(id),
  titulo        VARCHAR(200) NOT NULL,
  periodo_inicio DATE,
  periodo_fim    DATE,
  valor          NUMERIC(14,2) NOT NULL DEFAULT 0,
  status        VARCHAR(30) NOT NULL DEFAULT 'Rascunho'
                CHECK (status IN ('Rascunho','Enviada','Aprovada','Reprovada')),
  template_html TEXT,
  observacoes   TEXT,
  criado_por    UUID REFERENCES usuarios(id),
  criado_em     TIMESTAMPTZ DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS proposta_midias (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  proposta_id UUID NOT NULL REFERENCES propostas(id) ON DELETE CASCADE,
  midia_id    UUID NOT NULL REFERENCES midias(id),
  quantidade  INT DEFAULT 1,
  valor       NUMERIC(14,2) DEFAULT 0,
  localizacao TEXT
);

-- ============================================================
-- PEDIDO DE INSERÇÃO (PI)
-- ============================================================
CREATE TABLE IF NOT EXISTS pedidos_insercao (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  numero        VARCHAR(20) UNIQUE NOT NULL,  -- PI-2025-001
  proposta_id   UUID NOT NULL REFERENCES propostas(id),
  cliente_id    UUID NOT NULL REFERENCES clientes(id),
  campanha      VARCHAR(200) NOT NULL,
  periodo_inicio DATE NOT NULL,
  periodo_fim    DATE NOT NULL,
  valor_total   NUMERIC(14,2) NOT NULL,
  status        VARCHAR(30) DEFAULT 'Ativo'
                CHECK (status IN ('Ativo','Encerrado','Cancelado')),
  arquivo_url   TEXT,
  criado_por    UUID REFERENCES usuarios(id),
  criado_em     TIMESTAMPTZ DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS pi_midias (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  pi_id       UUID NOT NULL REFERENCES pedidos_insercao(id) ON DELETE CASCADE,
  midia_id    UUID NOT NULL REFERENCES midias(id),
  quantidade  INT DEFAULT 1,
  valor       NUMERIC(14,2) DEFAULT 0,
  localizacao TEXT
);

-- ============================================================
-- PRODUÇÃO
-- ============================================================
CREATE TABLE IF NOT EXISTS ordens_producao (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  pi_id           UUID NOT NULL REFERENCES pedidos_insercao(id),
  status          VARCHAR(30) DEFAULT 'Pendente'
                  CHECK (status IN ('Pendente','Em produção','Finalizado','Cancelado')),
  check_arte      BOOLEAN DEFAULT FALSE,
  check_aprovacao BOOLEAN DEFAULT FALSE,
  check_grafica   BOOLEAN DEFAULT FALSE,
  prazo           DATE,
  observacoes     TEXT,
  responsavel_id  UUID REFERENCES usuarios(id),
  criado_em       TIMESTAMPTZ DEFAULT NOW(),
  atualizado_em   TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- FINANCEIRO
-- ============================================================
CREATE TABLE IF NOT EXISTS cobrancas (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  pi_id       UUID NOT NULL REFERENCES pedidos_insercao(id),
  cliente_id  UUID NOT NULL REFERENCES clientes(id),
  descricao   VARCHAR(200),
  valor       NUMERIC(14,2) NOT NULL,
  vencimento  DATE NOT NULL,
  status      VARCHAR(20) DEFAULT 'Pendente'
              CHECK (status IN ('Pendente','Pago','Atrasado','Cancelado')),
  data_pagamento DATE,
  forma_pagamento VARCHAR(50),
  criado_em   TIMESTAMPTZ DEFAULT NOW(),
  atualizado_em TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- FATURAMENTO
-- ============================================================
CREATE TABLE IF NOT EXISTS faturamentos (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  pi_id       UUID NOT NULL REFERENCES pedidos_insercao(id),
  numero      VARCHAR(20) UNIQUE NOT NULL,
  valor       NUMERIC(14,2) NOT NULL,
  data        DATE NOT NULL DEFAULT CURRENT_DATE,
  status      VARCHAR(30) DEFAULT 'Pendente'
              CHECK (status IN ('Pendente','Faturado','Cancelado')),
  criado_em   TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- NOTAS FISCAIS
-- ============================================================
CREATE TABLE IF NOT EXISTS notas_fiscais (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  faturamento_id  UUID NOT NULL REFERENCES faturamentos(id),
  numero_nf       VARCHAR(50),
  serie           VARCHAR(10),
  chave_acesso    VARCHAR(100),
  xml_url         TEXT,
  pdf_url         TEXT,
  status          VARCHAR(30) DEFAULT 'Pendente'
                  CHECK (status IN ('Pendente','Emitida','Cancelada','Erro')),
  resposta_api    JSONB,
  emitida_em      TIMESTAMPTZ,
  criado_em       TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- CHECKING FOTOGRÁFICO
-- ============================================================
CREATE TABLE IF NOT EXISTS checkings (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  pi_id       UUID NOT NULL REFERENCES pedidos_insercao(id),
  data        DATE NOT NULL DEFAULT CURRENT_DATE,
  localizacao TEXT,
  observacao  TEXT,
  responsavel_id UUID REFERENCES usuarios(id),
  criado_em   TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS checking_fotos (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  checking_id UUID NOT NULL REFERENCES checkings(id) ON DELETE CASCADE,
  url         TEXT NOT NULL,
  legenda     TEXT,
  criado_em   TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- LOG DE AÇÕES
-- ============================================================
CREATE TABLE IF NOT EXISTS logs (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  usuario_id  UUID REFERENCES usuarios(id),
  acao        VARCHAR(100) NOT NULL,
  tabela      VARCHAR(60),
  registro_id UUID,
  detalhe     JSONB,
  ip          VARCHAR(45),
  criado_em   TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- SEQUÊNCIAS PARA NUMERAÇÃO AUTOMÁTICA
-- ============================================================
CREATE SEQUENCE IF NOT EXISTS seq_proposta START 1;
CREATE SEQUENCE IF NOT EXISTS seq_pi START 1;
CREATE SEQUENCE IF NOT EXISTS seq_faturamento START 1;

-- ============================================================
-- ÍNDICES
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_clientes_status       ON clientes(status);
CREATE INDEX IF NOT EXISTS idx_propostas_cliente     ON propostas(cliente_id);
CREATE INDEX IF NOT EXISTS idx_propostas_status      ON propostas(status);
CREATE INDEX IF NOT EXISTS idx_pi_cliente            ON pedidos_insercao(cliente_id);
CREATE INDEX IF NOT EXISTS idx_cobrancas_vencimento  ON cobrancas(vencimento);
CREATE INDEX IF NOT EXISTS idx_cobrancas_status      ON cobrancas(status);
CREATE INDEX IF NOT EXISTS idx_checkings_pi          ON checkings(pi_id);
CREATE INDEX IF NOT EXISTS idx_logs_usuario          ON logs(usuario_id);
CREATE INDEX IF NOT EXISTS idx_logs_criado_em        ON logs(criado_em);

-- ============================================================
-- FUNÇÃO: atualiza campo atualizado_em automaticamente
-- ============================================================
CREATE OR REPLACE FUNCTION set_atualizado_em()
RETURNS TRIGGER AS $$
BEGIN NEW.atualizado_em = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_clientes_upd   BEFORE UPDATE ON clientes           FOR EACH ROW EXECUTE FUNCTION set_atualizado_em();
CREATE TRIGGER trg_propostas_upd  BEFORE UPDATE ON propostas           FOR EACH ROW EXECUTE FUNCTION set_atualizado_em();
CREATE TRIGGER trg_pi_upd         BEFORE UPDATE ON pedidos_insercao    FOR EACH ROW EXECUTE FUNCTION set_atualizado_em();
CREATE TRIGGER trg_prod_upd       BEFORE UPDATE ON ordens_producao     FOR EACH ROW EXECUTE FUNCTION set_atualizado_em();
CREATE TRIGGER trg_cob_upd        BEFORE UPDATE ON cobrancas           FOR EACH ROW EXECUTE FUNCTION set_atualizado_em();


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
