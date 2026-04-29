@echo off
chcp 65001 >nul
title OOH Manager - Instalador Windows
color 0A

echo.
echo  +==================================================+
echo  |       OOH Manager - Instalador Windows           |
echo  |       Sistema de Gestao de Midia OOH             |
echo  +==================================================+
echo.

:: Verificar se esta rodando como administrador
net session >nul 2>&1
if %errorLevel% NEQ 0 (
    echo  [ERRO] Execute este arquivo como ADMINISTRADOR!
    echo.
    echo  Clique com o botao direito em INSTALAR.bat
    echo  e selecione "Executar como administrador"
    echo.
    pause
    exit /b 1
)

echo  [1/6] Verificando Node.js...
node --version >nul 2>&1
if %errorLevel% NEQ 0 (
    echo  Node.js nao encontrado. Baixando instalador...
    echo.
    powershell -Command "Invoke-WebRequest -Uri 'https://nodejs.org/dist/v20.11.1/node-v20.11.1-x64.msi' -OutFile '%TEMP%\node_installer.msi' -UseBasicParsing"
    echo  Instalando Node.js...
    msiexec /i "%TEMP%\node_installer.msi" /quiet /norestart
    :: Recarregar PATH
    call RefreshEnv.cmd >nul 2>&1
    set "PATH=%PATH%;C:\Program Files\nodejs"
    echo  [OK] Node.js instalado!
) else (
    for /f "tokens=*" %%i in ('node --version') do echo  [OK] Node.js %%i encontrado
)

echo.
echo  [2/6] Verificando PostgreSQL...
sc query postgresql >nul 2>&1
if %errorLevel% NEQ 0 (
    echo  PostgreSQL nao encontrado.
    echo.
    echo  +==============================================+
    echo  |  ACAO NECESSARIA: Instale o PostgreSQL       |
    echo  |                                              |
    echo  |  1. Abra o navegador na URL abaixo:          |
    echo  |  https://www.postgresql.org/download/windows |
    echo  |                                              |
    echo  |  2. Baixe PostgreSQL 16 para Windows         |
    echo  |  3. Instale com a senha: ooh_manager_2025    |
    echo  |  4. Porta padrao: 5432                       |
    echo  |  5. Apos instalar, execute INSTALAR.bat      |
    echo  |     novamente                                |
    echo  +==============================================+
    echo.
    start https://www.postgresql.org/download/windows/
    pause
    exit /b 1
) else (
    echo  [OK] PostgreSQL encontrado
)

echo.
echo  [3/6] Criando banco de dados...
set PGPASSWORD=ooh_manager_2025
"C:\Program Files\PostgreSQL\16\bin\psql.exe" -U postgres -c "CREATE DATABASE ooh_manager;" >nul 2>&1
if %errorLevel% NEQ 0 (
    "C:\Program Files\PostgreSQL\15\bin\psql.exe" -U postgres -c "CREATE DATABASE ooh_manager;" >nul 2>&1
)

:: Executar schema SQL
for %%P in ("C:\Program Files\PostgreSQL\16\bin\psql.exe" "C:\Program Files\PostgreSQL\15\bin\psql.exe") do (
    if exist %%P (
        %%P -U postgres -d ooh_manager -f "%~dp0database\schema.sql" >nul 2>&1
        echo  [OK] Banco de dados criado com sucesso!
        goto :db_done
    )
)
echo  [AVISO] Verifique a instalacao do PostgreSQL manualmente.
:db_done

echo.
echo  [4/6] Instalando dependencias do backend...
cd /d "%~dp0backend"
call npm install --silent
if %errorLevel% NEQ 0 (
    echo  [ERRO] Falha ao instalar dependencias. Verifique sua conexao.
    pause
    exit /b 1
)
echo  [OK] Dependencias instaladas!

echo.
echo  [5/6] Configurando variaveis de ambiente...
if not exist "%~dp0backend\.env" (
    copy "%~dp0backend\.env.example" "%~dp0backend\.env" >nul
    powershell -Command "(Get-Content '%~dp0backend\.env') -replace 'sua_senha_aqui','ooh_manager_2025' | Set-Content '%~dp0backend\.env'"
    powershell -Command "(Get-Content '%~dp0backend\.env') -replace 'troque_por_uma_chave_secreta_longa_e_aleatoria','ooh_jwt_$(Get-Random)_secret_windows' | Set-Content '%~dp0backend\.env'"
    echo  [OK] Arquivo .env criado automaticamente!
) else (
    echo  [OK] Arquivo .env ja existe, mantendo configuracoes.
)

echo.
echo  [6/6] Criando pasta de uploads...
if not exist "%~dp0backend\uploads" mkdir "%~dp0backend\uploads"
echo  [OK] Pasta uploads criada!

echo.
echo  +==================================================+
echo  |        Instalacao Concluida com Sucesso!         |
echo  +==================================================+
echo.
echo  Para iniciar o sistema, execute: INICIAR.bat
echo.

:: Criar usuario admin inicial
echo  Criando usuario administrador padrao...
timeout /t 3 /nobreak >nul
cd /d "%~dp0backend"
node -e "
const { Pool } = require('pg');
const bcrypt = require('bcryptjs');
const pool = new Pool({ host:'localhost', port:5432, database:'ooh_manager', user:'postgres', password:'ooh_manager_2025' });
bcrypt.hash('admin123', 12).then(hash => {
  pool.query(\"INSERT INTO usuarios (nome,email,senha_hash,perfil) VALUES ('Administrador','admin@oohmanager.com','\"+hash+\"','administrador') ON CONFLICT DO NOTHING\")
  .then(() => { console.log('[OK] Admin criado: admin@oohmanager.com / admin123'); pool.end(); })
  .catch(e => { console.log('[AVISO] Admin ja existe ou erro:', e.message); pool.end(); });
});
"

echo.
echo  ====================================================
echo   Login inicial:
echo   Email: admin@oohmanager.com
echo   Senha: admin123
echo  ====================================================
echo.
pause
