@echo off
title OOH Manager - Corrigir Senha PostgreSQL
color 0E
setlocal EnableDelayedExpansion

>nul 2>&1 net session
if %errorLevel% NEQ 0 (
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs -Wait"
    exit /b
)

set "DIR=%~dp0"

echo.
echo  +==============================================+
echo  |  OOH Manager - Corrigir senha PostgreSQL    |
echo  +==============================================+
echo.

:: Encontrar psql.exe
set "PG_BIN="
for %%P in (
    "C:\Program Files\PostgreSQL\17\bin"
    "C:\Program Files\PostgreSQL\16\bin"
    "C:\Program Files\PostgreSQL\15\bin"
    "C:\Program Files\PostgreSQL\14\bin"
) do (
    if exist "%%~P\psql.exe" set "PG_BIN=%%~P"
)

if not defined PG_BIN (
    color 0C
    echo  ERRO: PostgreSQL nao encontrado!
    echo  Instale em: https://www.postgresql.org/download/windows/
    pause & exit /b 1
)
echo  PostgreSQL encontrado: %PG_BIN%
set "PATH=%PATH%;%PG_BIN%"

echo.
echo  Digite a senha que voce usou ao instalar o PostgreSQL:
echo  (deixe em branco e pressione Enter se nao definiu senha)
echo.
set /p "PGPASSWORD=  Senha: "

echo.
echo  Testando conexao...
"%PG_BIN%\psql.exe" -U postgres -c "SELECT 1;" >nul 2>&1
if %errorLevel% NEQ 0 (
    color 0C
    echo  ERRO: Senha incorreta ou PostgreSQL nao esta rodando!
    echo.
    echo  Opcoes:
    echo  1. Verifique se o servico PostgreSQL esta ativo
    echo     Painel de Controle > Servicos > postgresql-x64-16
    echo  2. Tente a senha que digitou na instalacao do PostgreSQL
    echo  3. Se esqueceu a senha, veja como resetar em:
    echo     https://www.postgresql.org/docs/current/auth-pg-hba-conf.html
    echo.
    pause & exit /b 1
)
echo  OK: Conexao com PostgreSQL estabelecida!

:: Atualizar .env com a senha correta
echo.
echo  Atualizando configuracoes com a senha correta...
(
    echo PORT=3001
    echo NODE_ENV=production
    echo DB_HOST=localhost
    echo DB_PORT=5432
    echo DB_NAME=ooh_manager
    echo DB_USER=postgres
    echo DB_PASSWORD=%PGPASSWORD%
    echo JWT_SECRET=ooh_secret_%RANDOM%%RANDOM%
    echo JWT_EXPIRES_IN=7d
    echo UPLOAD_DIR=./uploads
    echo FRONTEND_URL=*
) > "%DIR%backend\.env"
echo  OK: .env atualizado com a senha correta!

:: Criar banco se nao existir
echo.
echo  Criando banco de dados...
"%PG_BIN%\psql.exe" -U postgres -c "CREATE DATABASE ooh_manager;" >nul 2>&1
"%PG_BIN%\psql.exe" -U postgres -d ooh_manager -f "%DIR%database\schema.sql" >nul 2>&1
echo  OK: Banco configurado!

:: Instalar node_modules se necessario
if not exist "%DIR%backend\node_modules" (
    echo.
    echo  Instalando dependencias Node.js...
    set "PATH=%PATH%;C:\Program Files\nodejs"
    cd /d "%DIR%backend"
    call npm install --loglevel=warn
    echo  OK: Dependencias instaladas!
)

:: Criar usuario admin
echo.
echo  Criando usuario admin...
set "NODE=node"
if exist "C:\Program Files\nodejs\node.exe" set "NODE=C:\Program Files\nodejs\node.exe"
cd /d "%DIR%backend"
"%NODE%" -e "const{Pool}=require('pg'),b=require('bcryptjs'),p=new Pool({host:'localhost',port:5432,database:'ooh_manager',user:'postgres',password:process.env.DB_PASSWORD||'%PGPASSWORD%'});b.hash('admin123',12).then(h=>p.query(\"INSERT INTO usuarios(nome,email,senha_hash,perfil)VALUES('Admin','admin@oohmanager.com','\"+h+\"','administrador')ON CONFLICT(email)DO NOTHING\").then(()=>{console.log('  OK: admin criado!');p.end()}).catch(()=>{console.log('  OK: admin ja existe.');p.end()})).catch(e=>{console.log('  Erro:',e.message);p.end()});"

echo.
echo  +==============================================+
echo  |   Tudo corrigido! Sistema pronto.           |
echo  |                                             |
echo  |   Login: admin@oohmanager.com              |
echo  |   Senha: admin123                          |
echo  +==============================================+
echo.
echo  Iniciando sistema...
timeout /t 2 /nobreak >nul
start "" "%DIR%INICIAR.bat"
pause
