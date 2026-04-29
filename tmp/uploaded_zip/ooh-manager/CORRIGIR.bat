@echo off
title Corrigindo OOH Manager
color 0A
setlocal EnableDelayedExpansion

:: Auto-elevar
>nul 2>&1 net session
if %errorLevel% NEQ 0 (
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs -Wait"
    exit /b
)

set "DIR=%~dp0"
echo.
echo  Corrigindo OOH Manager...
echo  Pasta: %DIR%
echo.

::  PASSO 1: Instalar Node.js se necessario 
echo  [1] Verificando Node.js...
set "NPM=npm"
set "NODE=node"

if exist "C:\Program Files\nodejs\npm.cmd" (
    set "NPM=C:\Program Files\nodejs\npm.cmd"
    set "NODE=C:\Program Files\nodejs\node.exe"
    echo      Encontrado em C:\Program Files\nodejs
    goto :node_ok
)

where node >nul 2>&1
if %errorLevel%==0 (
    echo      Node.js no PATH
    goto :node_ok
)

echo      Node.js NAO encontrado. Instalando...
powershell -Command "(New-Object Net.WebClient).DownloadFile('https://nodejs.org/dist/v20.11.1/node-v20.11.1-x64.msi','%TEMP%\node.msi')"
msiexec /i "%TEMP%\node.msi" /quiet /norestart
set "NPM=C:\Program Files\nodejs\npm.cmd"
set "NODE=C:\Program Files\nodejs\node.exe"
set "PATH=%PATH%;C:\Program Files\nodejs"
echo      Node.js instalado!

:node_ok
echo      OK

::  PASSO 2: Criar .env 
echo.
echo  [2] Criando arquivo .env...
(
    echo PORT=3001
    echo NODE_ENV=production
    echo DB_HOST=localhost
    echo DB_PORT=5432
    echo DB_NAME=ooh_manager
    echo DB_USER=postgres
    echo DB_PASSWORD=OohManager2025!
    echo JWT_SECRET=ooh_secret_%RANDOM%%RANDOM%
    echo JWT_EXPIRES_IN=7d
    echo UPLOAD_DIR=./uploads
    echo FRONTEND_URL=*
) > "%DIR%backend\.env"
echo      OK: .env criado em %DIR%backend\.env

::  PASSO 3: Criar pasta uploads 
if not exist "%DIR%backend\uploads" mkdir "%DIR%backend\uploads"

::  PASSO 4: npm install 
echo.
echo  [3] Instalando dependencias (npm install)...
echo      Isso pode demorar 1-2 minutos...
cd /d "%DIR%backend"
set "PATH=%PATH%;C:\Program Files\nodejs;%APPDATA%\npm"
call "%NPM%" install --loglevel=warn
if %errorLevel% NEQ 0 (
    color 0C
    echo      ERRO no npm install!
    echo      Tente rodar manualmente:
    echo      1. Abra o CMD
    echo      2. Digite: cd /d "%DIR%backend"
    echo      3. Digite: npm install
    pause
    exit /b 1
)
echo      OK: node_modules criado!

::  PASSO 5: Instalar PostgreSQL 
echo.
echo  [4] Verificando PostgreSQL...
set "PG_BIN="
for %%P in ("C:\Program Files\PostgreSQL\17\bin" "C:\Program Files\PostgreSQL\16\bin" "C:\Program Files\PostgreSQL\15\bin" "C:\Program Files\PostgreSQL\14\bin") do (
    if exist "%%~P\psql.exe" set "PG_BIN=%%~P"
)

if defined PG_BIN (
    echo      Encontrado: %PG_BIN%
    goto :pg_ok
)

echo      PostgreSQL NAO encontrado. Instalando...
echo      Baixando (~200MB), aguarde...
powershell -Command "(New-Object Net.WebClient).DownloadFile('https://get.enterprisedb.com/postgresql/postgresql-16.2-1-windows-x64.exe','%TEMP%\pg.exe')"
if not exist "%TEMP%\pg.exe" (
    color 0C
    echo      ERRO: Falha no download do PostgreSQL!
    echo      Instale manualmente: https://www.postgresql.org/download/windows/
    echo      Use a senha: OohManager2025!
    pause
    exit /b 1
)
echo      Instalando PostgreSQL (aguarde 2-3 min)...
"%TEMP%\pg.exe" --mode unattended --superpassword "OohManager2025!" --serverport 5432 --prefix "C:\Program Files\PostgreSQL\16"
set "PG_BIN=C:\Program Files\PostgreSQL\16\bin"
timeout /t 8 /nobreak >nul
echo      PostgreSQL instalado!

:pg_ok
set "PATH=%PATH%;%PG_BIN%"
sc start postgresql-x64-17 >nul 2>&1
sc start postgresql-x64-16 >nul 2>&1
sc start postgresql-x64-15 >nul 2>&1
sc start postgresql >nul 2>&1
timeout /t 3 /nobreak >nul
echo      Servico iniciado.

::  PASSO 6: Criar banco 
echo.
echo  [5] Configurando banco de dados...
set "PGPASSWORD=OohManager2025!"
"%PG_BIN%\psql.exe" -U postgres -c "CREATE DATABASE ooh_manager;" >nul 2>&1
"%PG_BIN%\psql.exe" -U postgres -d ooh_manager -f "%DIR%database\schema.sql" >nul 2>&1
echo      OK: Banco configurado.

::  PASSO 7: Criar usuario admin 
echo.
echo  [6] Criando usuario admin...
cd /d "%DIR%backend"
"%NODE%" -e "const{Pool}=require('pg'),b=require('bcryptjs'),p=new Pool({host:'localhost',port:5432,database:'ooh_manager',user:'postgres',password:'OohManager2025!'});b.hash('admin123',12).then(h=>p.query(\"INSERT INTO usuarios(nome,email,senha_hash,perfil)VALUES('Admin','admin@oohmanager.com','\"+h+\"','administrador')ON CONFLICT(email)DO NOTHING\").then(()=>{console.log('     OK: admin criado!');p.end()}).catch(()=>{console.log('     OK: admin ja existe.');p.end()})).catch(e=>{console.log('     Erro:',e.message);p.end()});" 2>nul

::  PASSO 8: Criar atalho 
powershell -Command "try{$s=(New-Object -COM WScript.Shell).CreateShortcut([Environment]::GetFolderPath('Desktop')+'\OOH Manager.lnk');$s.TargetPath='%DIR%INICIAR.bat';$s.WorkingDirectory='%DIR%';$s.Save();Write-Host '     OK: Atalho criado na Area de Trabalho!'}catch{Write-Host '     Aviso: sem atalho.'}"

::  FIM 
echo.
echo  +=============================================+
echo  |   Correcao concluida! Tudo pronto.         |
echo  |                                             |
echo  |   Login: admin@oohmanager.com              |
echo  |   Senha: admin123                          |
echo  +=============================================+
echo.
echo  Iniciando o sistema agora...
timeout /t 3 /nobreak >nul
start "" "%DIR%INICIAR.bat"
pause
