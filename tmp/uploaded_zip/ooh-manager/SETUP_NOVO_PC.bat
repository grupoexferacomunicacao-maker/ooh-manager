@echo off
title OOH Manager - Setup
color 0A
setlocal EnableDelayedExpansion

echo.
echo OOH Manager - Configurando PC
echo ================================
echo.

:: Auto elevar sem fechar
>nul 2>&1 net session
if %errorLevel% NEQ 0 (
    echo Abrindo como administrador...
    powershell -Command "Start-Process cmd -ArgumentList '/k cd /d \"%~dp0\" && \"%~f0\"' -Verb RunAs"
    exit /b
)

set "DIR=%~dp0"
set "BACKEND=%DIR%backend"

echo Pasta do sistema: %DIR%
echo.

:: PASSO 1 - Node.js
echo [1] Verificando Node.js...
set "NODE=node"
if exist "C:\Program Files\nodejs\node.exe" set "NODE=C:\Program Files\nodejs\node.exe"
if exist "C:\Program Files (x86)\nodejs\node.exe" set "NODE=C:\Program Files (x86)\nodejs\node.exe"

"%NODE%" --version >nul 2>&1
if %errorLevel% NEQ 0 (
    echo ERRO: Node.js nao encontrado!
    echo Baixe em: https://nodejs.org e instale a versao LTS
    echo Depois execute este arquivo novamente.
    pause
    exit /b 1
)
for /f "tokens=*" %%v in ('"%NODE%" --version 2^>nul') do echo OK: Node.js %%v

:: PASSO 2 - Encontrar PostgreSQL
echo.
echo [2] Localizando PostgreSQL...
set "PG_BIN="
set "PG_DATA="

for %%V in (17 16 15 14 13) do (
    if exist "C:\Program Files\PostgreSQL\%%V\bin\psql.exe" (
        if not defined PG_BIN (
            set "PG_BIN=C:\Program Files\PostgreSQL\%%V\bin"
            set "PG_DATA=C:\Program Files\PostgreSQL\%%V\data"
            set "PG_VER=%%V"
        )
    )
)

if not defined PG_BIN (
    for %%V in (17 16 15 14 13) do (
        if exist "C:\Program Files (x86)\PostgreSQL\%%V\bin\psql.exe" (
            if not defined PG_BIN (
                set "PG_BIN=C:\Program Files (x86)\PostgreSQL\%%V\bin"
                set "PG_DATA=C:\Program Files (x86)\PostgreSQL\%%V\data"
                set "PG_VER=%%V"
            )
        )
    )
)

if not defined PG_BIN (
    where psql >nul 2>&1
    if !errorLevel!==0 (
        for /f "tokens=*" %%p in ('where psql 2^>nul') do (
            if not defined PG_BIN set "PG_BIN=%%~dpp%%~np%%~xp"
        )
        set "PG_BIN=!PG_BIN:psql.exe=!"
    )
)

if not defined PG_BIN (
    echo ERRO: PostgreSQL nao encontrado!
    echo Instale em: https://www.postgresql.org/download/windows/
    pause
    exit /b 1
)

echo OK: PostgreSQL %PG_VER% em %PG_BIN%
set "PATH=%PATH%;%PG_BIN%"

:: PASSO 3 - Iniciar servico
echo.
echo [3] Iniciando servico PostgreSQL...
net start postgresql-x64-%PG_VER% >nul 2>&1
net start postgresql >nul 2>&1
timeout /t 3 /nobreak >nul

:: PASSO 4 - Descobrir senha
echo.
echo [4] Testando conexao...
set "PGPASSWORD=OohManager2025!"
"%PG_BIN%\psql.exe" -U postgres -h 127.0.0.1 -p 5432 -c "SELECT 1;" >nul 2>&1
if %errorLevel%==0 goto :senha_ok

set "PGPASSWORD=postgres"
"%PG_BIN%\psql.exe" -U postgres -h 127.0.0.1 -p 5432 -c "SELECT 1;" >nul 2>&1
if %errorLevel%==0 goto :senha_ok

set "PGPASSWORD=admin"
"%PG_BIN%\psql.exe" -U postgres -h 127.0.0.1 -p 5432 -c "SELECT 1;" >nul 2>&1
if %errorLevel%==0 goto :senha_ok

set "PGPASSWORD=123456"
"%PG_BIN%\psql.exe" -U postgres -h 127.0.0.1 -p 5432 -c "SELECT 1;" >nul 2>&1
if %errorLevel%==0 goto :senha_ok

set "PGPASSWORD="
"%PG_BIN%\psql.exe" -U postgres -h 127.0.0.1 -p 5432 -c "SELECT 1;" >nul 2>&1
if %errorLevel%==0 goto :senha_ok

echo Nenhuma senha padrao funcionou.
echo.
set /p "PGPASSWORD=Digite a senha do PostgreSQL: "
"%PG_BIN%\psql.exe" -U postgres -h 127.0.0.1 -p 5432 -c "SELECT 1;" >nul 2>&1
if %errorLevel%==0 goto :senha_ok

:: Resetar senha via pg_hba.conf
echo Tentando resetar senha automaticamente...
if not defined PG_DATA (
    echo ERRO: Nao foi possivel resetar. Abra o pgAdmin e defina a senha: OohManager2025!
    pause
    exit /b 1
)

copy "%PG_DATA%\pg_hba.conf" "%PG_DATA%\pg_hba.conf.bak" >nul 2>&1
powershell -Command "(Get-Content '%PG_DATA%\pg_hba.conf') -replace 'scram-sha-256','trust' -replace '\bmd5\b','trust' | Set-Content '%PG_DATA%\pg_hba.conf'"
net stop postgresql-x64-%PG_VER% >nul 2>&1
net stop postgresql >nul 2>&1
timeout /t 3 /nobreak >nul
net start postgresql-x64-%PG_VER% >nul 2>&1
net start postgresql >nul 2>&1
timeout /t 4 /nobreak >nul

set "PGPASSWORD="
"%PG_BIN%\psql.exe" -U postgres -h 127.0.0.1 -p 5432 -c "ALTER USER postgres PASSWORD 'OohManager2025!';" >nul 2>&1
copy "%PG_DATA%\pg_hba.conf.bak" "%PG_DATA%\pg_hba.conf" >nul 2>&1
net stop postgresql-x64-%PG_VER% >nul 2>&1
net stop postgresql >nul 2>&1
timeout /t 2 /nobreak >nul
net start postgresql-x64-%PG_VER% >nul 2>&1
net start postgresql >nul 2>&1
timeout /t 4 /nobreak >nul

set "PGPASSWORD=OohManager2025!"
"%PG_BIN%\psql.exe" -U postgres -h 127.0.0.1 -p 5432 -c "SELECT 1;" >nul 2>&1
if %errorLevel% NEQ 0 (
    echo ERRO: Nao foi possivel conectar ao PostgreSQL.
    echo Abra o pgAdmin e defina a senha para: OohManager2025!
    pause
    exit /b 1
)
echo Senha redefinida para: OohManager2025!

:senha_ok
echo OK: Conectado ao PostgreSQL. Senha: %PGPASSWORD%

:: PASSO 5 - Banco de dados
echo.
echo [5] Criando banco de dados...
"%PG_BIN%\psql.exe" -U postgres -h 127.0.0.1 -p 5432 -c "CREATE DATABASE ooh_manager;" >nul 2>&1
"%PG_BIN%\psql.exe" -U postgres -h 127.0.0.1 -p 5432 -d ooh_manager -f "%DIR%database\schema.sql" >nul 2>&1
"%PG_BIN%\psql.exe" -U postgres -h 127.0.0.1 -p 5432 -d ooh_manager -f "%DIR%database\fix_final.sql" >nul 2>&1
echo OK: Banco configurado!

:: PASSO 6 - .env
echo.
echo [6] Criando .env...
(
echo PORT=3001
echo NODE_ENV=production
echo DB_HOST=localhost
echo DB_PORT=5432
echo DB_NAME=ooh_manager
echo DB_USER=postgres
echo DB_PASSWORD=%PGPASSWORD%
echo JWT_SECRET=ooh_jwt_%RANDOM%%RANDOM%_secret
echo JWT_EXPIRES_IN=7d
echo UPLOAD_DIR=./uploads
echo FRONTEND_URL=*
) > "%BACKEND%\.env"
echo OK: .env criado!
if not exist "%BACKEND%\uploads" mkdir "%BACKEND%\uploads"

:: PASSO 7 - npm install
echo.
echo [7] Instalando dependencias...
cd /d "%BACKEND%"
set "PATH=%PATH%;C:\Program Files\nodejs"
call npm install --loglevel=warn
if %errorLevel% NEQ 0 (
    echo ERRO no npm install. Tentando novamente...
    call npm install
)
echo OK: Dependencias instaladas!

:: PASSO 8 - Admin
echo.
echo [8] Criando usuario admin...
cd /d "%BACKEND%"
"%NODE%" -e "const{Pool}=require('pg'),b=require('bcryptjs'),p=new Pool({host:'localhost',port:5432,database:'ooh_manager',user:'postgres',password:'%PGPASSWORD%'});b.hash('admin123',12).then(h=>p.query(\"INSERT INTO usuarios(nome,email,senha_hash,perfil)VALUES('Administrador','admin@oohmanager.com','\"+h+\"','administrador')ON CONFLICT(email)DO NOTHING\").then(()=>{console.log('OK: Admin criado!');p.end()}).catch(e=>{console.log('Erro:',e.message);p.end()})).catch(e=>{console.log('Erro:',e.message);p.end()});"

:: PASSO 9 - Atalho
powershell -Command "try{$s=(New-Object -COM WScript.Shell).CreateShortcut([Environment]::GetFolderPath('Desktop')+'\OOH Manager.lnk');$s.TargetPath='%DIR%INICIAR.bat';$s.WorkingDirectory='%DIR%';$s.Save();Write-Host 'OK: Atalho criado!'}catch{}"

echo.
echo +==============================================+
echo    INSTALACAO CONCLUIDA!
echo.
echo    Login: admin@oohmanager.com
echo    Senha: admin123
echo.
echo    Atalho criado na Area de Trabalho!
echo +==============================================+
echo.
echo Iniciando sistema...
timeout /t 3 /nobreak >nul
start "" "%DIR%INICIAR.bat"
echo.
echo Esta janela pode ser fechada.
pause
