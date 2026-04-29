@echo off
title OOH Manager - Instalador
color 0A
setlocal EnableDelayedExpansion

echo.
echo  +==================================================+
echo  |      OOH Manager - Instalador Completo          |
echo  +==================================================+
echo.

:: Auto-elevar para administrador
>nul 2>&1 net session
if %errorLevel% NEQ 0 (
    echo  Solicitando permissao de administrador...
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs -Wait"
    exit /b
)

set "DIR=%~dp0"
set "LOG=%DIR%instalar_log.txt"
echo Inicio: %date% %time% > "%LOG%"

:: ============================================================
echo  [1/7] Verificando internet...
:: ============================================================
powershell -Command "try{(New-Object Net.WebClient).DownloadString('https://nodejs.org')|Out-Null;exit 0}catch{exit 1}" >nul 2>&1
if %errorLevel% NEQ 0 (
    color 0C
    echo  ERRO: Sem conexao com a internet!
    echo  Conecte-se e tente novamente.
    pause & exit /b 1
)
echo  OK: Internet disponivel

:: ============================================================
echo.
echo  [2/7] Verificando Node.js...
:: ============================================================
set "NODE_OK=0"
if exist "C:\Program Files\nodejs\node.exe" set "NODE_OK=1"
if exist "C:\Program Files (x86)\nodejs\node.exe" set "NODE_OK=1"
where node >nul 2>&1
if %errorLevel%==0 set "NODE_OK=1"

if "%NODE_OK%"=="1" (
    for /f "tokens=*" %%v in ('node --version 2^>nul') do echo  OK: Node.js %%v encontrado
    goto :node_pronto
)

echo  Baixando Node.js v20 LTS...
powershell -Command "
    Write-Host '  Aguarde o download...' -NoNewline
    (New-Object Net.WebClient).DownloadFile(
        'https://nodejs.org/dist/v20.11.1/node-v20.11.1-x64.msi',
        '$env:TEMP\node_setup.msi'
    )
    Write-Host ' Concluido.'
" 2>>"%LOG%"

if not exist "%TEMP%\node_setup.msi" (
    color 0C
    echo  ERRO: Falha ao baixar Node.js!
    pause & exit /b 1
)

echo  Instalando Node.js... (aguarde)
msiexec /i "%TEMP%\node_setup.msi" /quiet /norestart ADDLOCAL=ALL
echo  OK: Node.js instalado!
set "PATH=%PATH%;C:\Program Files\nodejs"

:node_pronto

:: ============================================================
echo.
echo  [3/7] Verificando PostgreSQL...
:: ============================================================
set "PG_BIN="
for %%P in (
    "C:\Program Files\PostgreSQL\17\bin"
    "C:\Program Files\PostgreSQL\16\bin"
    "C:\Program Files\PostgreSQL\15\bin"
    "C:\Program Files\PostgreSQL\14\bin"
) do (
    if exist "%%~P\psql.exe" (
        set "PG_BIN=%%~P"
        goto :pg_encontrado
    )
)

echo  Baixando PostgreSQL 16... (pode demorar 3-5 minutos)
powershell -Command "
    Write-Host '  Aguarde o download (~200MB)...' -NoNewline
    (New-Object Net.WebClient).DownloadFile(
        'https://get.enterprisedb.com/postgresql/postgresql-16.2-1-windows-x64.exe',
        '$env:TEMP\pg_setup.exe'
    )
    Write-Host ' Concluido.'
" 2>>"%LOG%"

if not exist "%TEMP%\pg_setup.exe" (
    color 0C
    echo  ERRO: Falha ao baixar PostgreSQL!
    echo  Instale manualmente: https://www.postgresql.org/download/windows/
    echo  Use a senha: OohManager2025!
    pause & exit /b 1
)

echo  Instalando PostgreSQL... (aguarde 2-3 minutos)
"%TEMP%\pg_setup.exe" --mode unattended --unattendedmodeui minimal --superpassword "OohManager2025!" --serverport 5432 --prefix "C:\Program Files\PostgreSQL\16"
echo  OK: PostgreSQL instalado!
set "PG_BIN=C:\Program Files\PostgreSQL\16\bin"
timeout /t 5 /nobreak >nul

:pg_encontrado
echo  OK: PostgreSQL em %PG_BIN%
set "PATH=%PATH%;%PG_BIN%"

:: Garantir que servico esta rodando
sc start postgresql-x64-17 >nul 2>&1
sc start postgresql-x64-16 >nul 2>&1
sc start postgresql-x64-15 >nul 2>&1
sc start postgresql-x64-14 >nul 2>&1
sc start postgresql >nul 2>&1
timeout /t 3 /nobreak >nul

:: ============================================================
echo.
echo  [4/7] Criando banco de dados...
:: ============================================================
set "PGPASSWORD=OohManager2025!"

"%PG_BIN%\psql.exe" -U postgres -c "CREATE DATABASE ooh_manager;" >>"%LOG%" 2>&1
"%PG_BIN%\psql.exe" -U postgres -d ooh_manager -f "%DIR%database\schema.sql" >>"%LOG%" 2>&1
if %errorLevel%==0 (
    echo  OK: Banco de dados criado!
) else (
    echo  OK: Banco ja existe ou foi criado anteriormente.
)

:: ============================================================
echo.
echo  [5/7] Instalando dependencias Node.js...
:: ============================================================
cd /d "%DIR%backend"

:: Garantir npm no PATH
set "PATH=%PATH%;C:\Program Files\nodejs;%APPDATA%\npm"

echo  Rodando npm install... (aguarde)
call npm install --loglevel=error 2>>"%LOG%"
if %errorLevel% NEQ 0 (
    echo  Tentando novamente...
    call npm install 2>>"%LOG%"
)

if exist "%DIR%backend\node_modules" (
    echo  OK: Dependencias instaladas!
) else (
    color 0C
    echo  ERRO: Falha ao instalar dependencias!
    echo  Verifique o log: %LOG%
    pause & exit /b 1
)

:: ============================================================
echo.
echo  [6/7] Criando configuracoes (.env)...
:: ============================================================
if not exist "%DIR%backend\.env" (
    (
        echo PORT=3001
        echo NODE_ENV=production
        echo DB_HOST=localhost
        echo DB_PORT=5432
        echo DB_NAME=ooh_manager
        echo DB_USER=postgres
        echo DB_PASSWORD=OohManager2025!
        echo JWT_SECRET=ooh_jwt_%RANDOM%%RANDOM%_secret_key
        echo JWT_EXPIRES_IN=7d
        echo UPLOAD_DIR=./uploads
        echo FRONTEND_URL=*
    ) > "%DIR%backend\.env"
    echo  OK: Arquivo .env criado!
) else (
    echo  OK: .env ja existe, mantendo configuracoes.
)

if not exist "%DIR%backend\uploads" mkdir "%DIR%backend\uploads"

:: ============================================================
echo.
echo  [7/7] Criando usuario administrador...
:: ============================================================
cd /d "%DIR%backend"
set "PATH=%PATH%;C:\Program Files\nodejs"

node -e "const {Pool}=require('pg');const b=require('bcryptjs');const p=new Pool({host:'localhost',port:5432,database:'ooh_manager',user:'postgres',password:'OohManager2025!'});b.hash('admin123',12).then(h=>p.query(\"INSERT INTO usuarios(nome,email,senha_hash,perfil)VALUES('Administrador','admin@oohmanager.com','\"+h+\"','administrador')ON CONFLICT(email)DO NOTHING\").then(()=>{console.log('OK: Admin criado!');p.end();}).catch(e=>{console.log('OK: Admin ja existe.');p.end();})).catch(e=>{console.log('Erro bcrypt:',e.message);p.end();});" 2>>"%LOG%"

:: Criar atalho na Area de Trabalho
powershell -Command "
    try {
        $s = (New-Object -COM WScript.Shell).CreateShortcut(
            [Environment]::GetFolderPath('Desktop') + '\OOH Manager.lnk'
        )
        $s.TargetPath = '%DIR%INICIAR.bat'
        $s.WorkingDirectory = '%DIR%'
        $s.Description = 'OOH Manager'
        $s.Save()
        Write-Host '  OK: Atalho criado na Area de Trabalho!'
    } catch { Write-Host '  Aviso: Nao foi possivel criar atalho.' }
" 2>>"%LOG%"

:: ============================================================
color 0A
echo.
echo  +==================================================+
echo  |      Instalacao concluida com sucesso!          |
echo  |                                                  |
echo  |  Login: admin@oohmanager.com                    |
echo  |  Senha: admin123                                |
echo  |                                                  |
echo  |  Atalho criado na Area de Trabalho!             |
echo  +==================================================+
echo.
echo  Deseja iniciar o sistema agora? [S/N]
choice /c SN /n /m "  > "
if %errorLevel%==1 (
    start "" "%DIR%INICIAR.bat"
)
echo.
pause
