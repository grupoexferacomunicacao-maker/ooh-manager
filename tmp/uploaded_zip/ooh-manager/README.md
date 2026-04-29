# OOH Manager — Sistema de Gestão para Mídia Out of Home

Plataforma SaaS completa para empresas de mídia OOH. Gerencia todo o fluxo:
**Lead → Proposta → PI → Produção → Financeiro → Faturamento → Nota Fiscal → Checking.**

---

## 🗂 Estrutura do Projeto

```
ooh-manager/
├── database/
│   └── schema.sql          # Schema completo PostgreSQL
├── backend/
│   ├── src/
│   │   ├── server.js       # Entry point Express
│   │   ├── config/
│   │   │   └── db.js       # Pool PostgreSQL
│   │   ├── middleware/
│   │   │   └── auth.js     # JWT + controle de perfil
│   │   └── routes/
│   │       ├── auth.js
│   │       ├── clientes.js
│   │       ├── propostas.js
│   │       ├── pi.js
│   │       ├── producao.js
│   │       ├── financeiro.js
│   │       ├── faturamento.js
│   │       ├── notas_fiscais.js
│   │       ├── checking.js
│   │       └── dashboard.js
│   ├── .env.example
│   ├── Dockerfile
│   └── package.json
├── frontend/
│   └── src/
│       └── ooh_saas.jsx    # App React completo
└── docker-compose.yml
```

---

## 🚀 Rodar com Docker (recomendado)

### Pré-requisitos
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) instalado

### Passos

```bash
# 1. Clone ou copie o projeto
cd ooh-manager

# 2. Suba tudo (banco + backend + frontend)
docker compose up --build

# 3. Acesse
# Frontend: http://localhost:3000
# API:      http://localhost:3001/api
```

O banco de dados é criado automaticamente com o `schema.sql`.

---

## 💻 Rodar Manualmente (sem Docker)

### 1. PostgreSQL

Instale o PostgreSQL e crie o banco:

```bash
psql -U postgres
CREATE DATABASE ooh_manager;
\q

psql -U postgres -d ooh_manager -f database/schema.sql
```

### 2. Backend

```bash
cd backend
cp .env.example .env
# Edite .env com suas configurações

npm install
npm run dev
# API disponível em http://localhost:3001
```

### 3. Frontend

```bash
# Opção A: React com Vite
cd frontend
npm create vite@latest . -- --template react
npm install
# Substitua src/App.jsx pelo conteúdo de ooh_saas.jsx
npm run dev

# Opção B: Abrir direto como artifact no Claude.ai
# Cole o conteúdo de ooh_saas.jsx no chat do Claude
```

---

## 🔑 Criar Primeiro Usuário Administrador

```bash
curl -X POST http://localhost:3001/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "nome": "Administrador",
    "email": "admin@suaempresa.com",
    "senha": "senha123",
    "perfil": "administrador"
  }'
```

---

## 📡 API — Referência Rápida

### Autenticação

| Método | Rota | Descrição |
|--------|------|-----------|
| POST | `/api/auth/login` | Login, retorna JWT |
| POST | `/api/auth/register` | Cadastrar usuário |
| GET | `/api/auth/me` | Dados do usuário logado |

> Todas as rotas protegidas exigem header: `Authorization: Bearer <token>`

### CRM / Clientes

| Método | Rota | Descrição |
|--------|------|-----------|
| GET | `/api/clientes` | Listar (filtros: status, busca) |
| GET | `/api/clientes/:id` | Detalhe + histórico |
| POST | `/api/clientes` | Criar |
| PUT | `/api/clientes/:id` | Atualizar |
| DELETE | `/api/clientes/:id` | Remover |
| POST | `/api/clientes/:id/interacoes` | Adicionar interação |

### Propostas

| Método | Rota | Descrição |
|--------|------|-----------|
| GET | `/api/propostas` | Listar |
| GET | `/api/propostas/:id` | Detalhe + mídias |
| POST | `/api/propostas` | Criar |
| PUT | `/api/propostas/:id/status` | Alterar status (Aprovada → gera PI automaticamente) |

### Pedidos de Inserção

| Método | Rota | Descrição |
|--------|------|-----------|
| GET | `/api/pi` | Listar todos os PIs |
| GET | `/api/pi/:id` | Detalhe + mídias |

### Produção

| Método | Rota | Descrição |
|--------|------|-----------|
| GET | `/api/producao` | Listar ordens |
| PUT | `/api/producao/:id/checklist` | Atualizar checklist |
| PUT | `/api/producao/:id/status` | Atualizar status |

### Financeiro

| Método | Rota | Descrição |
|--------|------|-----------|
| GET | `/api/financeiro` | Listar cobranças |
| GET | `/api/financeiro/resumo` | Totais por status |
| PUT | `/api/financeiro/:id/pagar` | Marcar como pago |

### Faturamento

| Método | Rota | Descrição |
|--------|------|-----------|
| GET | `/api/faturamento` | Listar |
| POST | `/api/faturamento` | Gerar faturamento de um PI |

### Notas Fiscais

| Método | Rota | Descrição |
|--------|------|-----------|
| GET | `/api/notas-fiscais` | Listar |
| POST | `/api/notas-fiscais` | Emitir NF (simulada) |

### Checking Fotográfico

| Método | Rota | Descrição |
|--------|------|-----------|
| GET | `/api/checking` | Listar |
| GET | `/api/checking/:id` | Detalhe + fotos |
| POST | `/api/checking` | Criar registro |
| POST | `/api/checking/:id/fotos` | Upload de fotos (multipart) |

### Dashboard

| Método | Rota | Descrição |
|--------|------|-----------|
| GET | `/api/dashboard` | KPIs consolidados |

---

## 👥 Perfis de Acesso

| Perfil | Permissões |
|--------|-----------|
| `administrador` | Acesso total |
| `comercial` | CRM, Propostas, PIs |
| `operacional` | Produção, Checking |
| `financeiro` | Financeiro, Faturamento, NF |

---

## ☁️ Deploy em Produção

### Opção 1 — Railway (mais fácil, gratuito para início)
1. Crie conta em [railway.app](https://railway.app)
2. New Project → Deploy from GitHub
3. Adicione serviço PostgreSQL
4. Configure as variáveis de ambiente do `.env.example`
5. Deploy automático a cada push

### Opção 2 — VPS (DigitalOcean, Contabo, etc.)
```bash
# No servidor Ubuntu 22.04
apt update && apt install -y docker.io docker-compose
git clone seu-repo
cd ooh-manager
cp backend/.env.example backend/.env
# Edite o .env
docker compose -f docker-compose.yml up -d
```

### Opção 3 — Render.com
- Backend: Web Service (Node.js)
- Banco: PostgreSQL (plano free disponível)
- Frontend: Static Site (após build do React)

---

## 🔧 Integrações Futuras

- **NFSe real**: Substitua a simulação em `notas_fiscais.js` pela API do seu município (eNotas, NFSe.io, Prefeitura)
- **WhatsApp**: Integre a API oficial do WhatsApp Business ou Evolution API
- **Email**: Configure SMTP no `.env` e use Nodemailer (já como dependência)
- **Google Drive**: Use googleapis para salvar PDFs de propostas e checkings
- **Geração de PDF**: Adicione `puppeteer` ou `pdfkit` para exportar propostas e relatórios

---

## 📞 Suporte

Sistema desenvolvido para empresas de mídia OOH.
Personalize os templates de proposta, regras de faturamento e integrações conforme necessidade.
