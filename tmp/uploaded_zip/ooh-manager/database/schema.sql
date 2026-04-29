-- ============================================================
--  OOH Manager — Schema PostgreSQL
--  Versão 1.0
-- ============================================================

-- Extensões
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- USUÁRIOS E AUTENTICAÇÃO
-- ============================================================
CREATE TABLE usuarios (
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
CREATE TABLE clientes (
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

CREATE TABLE interacoes (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  cliente_id  UUID NOT NULL REFERENCES clientes(id) ON DELETE CASCADE,
  usuario_id  UUID REFERENCES usuarios(id),
  descricao   TEXT NOT NULL,
  criado_em   TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- MÍDIAS
-- ============================================================
CREATE TABLE midias (
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
CREATE TABLE propostas (
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

CREATE TABLE proposta_midias (
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
CREATE TABLE pedidos_insercao (
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

CREATE TABLE pi_midias (
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
CREATE TABLE ordens_producao (
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
CREATE TABLE cobrancas (
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
CREATE TABLE faturamentos (
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
CREATE TABLE notas_fiscais (
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
CREATE TABLE checkings (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  pi_id       UUID NOT NULL REFERENCES pedidos_insercao(id),
  data        DATE NOT NULL DEFAULT CURRENT_DATE,
  localizacao TEXT,
  observacao  TEXT,
  responsavel_id UUID REFERENCES usuarios(id),
  criado_em   TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE checking_fotos (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  checking_id UUID NOT NULL REFERENCES checkings(id) ON DELETE CASCADE,
  url         TEXT NOT NULL,
  legenda     TEXT,
  criado_em   TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- LOG DE AÇÕES
-- ============================================================
CREATE TABLE logs (
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
CREATE SEQUENCE seq_proposta START 1;
CREATE SEQUENCE seq_pi START 1;
CREATE SEQUENCE seq_faturamento START 1;

-- ============================================================
-- ÍNDICES
-- ============================================================
CREATE INDEX idx_clientes_status       ON clientes(status);
CREATE INDEX idx_propostas_cliente     ON propostas(cliente_id);
CREATE INDEX idx_propostas_status      ON propostas(status);
CREATE INDEX idx_pi_cliente            ON pedidos_insercao(cliente_id);
CREATE INDEX idx_cobrancas_vencimento  ON cobrancas(vencimento);
CREATE INDEX idx_cobrancas_status      ON cobrancas(status);
CREATE INDEX idx_checkings_pi          ON checkings(pi_id);
CREATE INDEX idx_logs_usuario          ON logs(usuario_id);
CREATE INDEX idx_logs_criado_em        ON logs(criado_em);

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
