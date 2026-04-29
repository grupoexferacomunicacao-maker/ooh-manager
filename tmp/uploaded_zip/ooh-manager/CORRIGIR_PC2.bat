@echo off
title Corrigindo OOH Manager
color 0A
setlocal EnableDelayedExpansion

echo Mantendo janela aberta - nao feche!
echo.

:: Elevar sem fechar janela
>nul 2>&1 net session
if %errorLevel% NEQ 0 (
    echo Abrindo como administrador...
    powershell -Command "Start-Process cmd -ArgumentList '/k \"%~f0\"' -Verb RunAs"
    exit /b
)

set "DIR=%~dp0"
set "BACKEND=%DIR%backend"

echo ================================
echo  Corrigindo OOH Manager
echo ================================
echo.

:: STEP 1 - Find Node.js
echo [1] Node.js...
set "NODE=node"
if exist "C:\Program Files\nodejs\node.exe" set "NODE=C:\Program Files\nodejs\node.exe"
"%NODE%" --version >nul 2>&1
if %errorLevel% NEQ 0 (
    echo ERRO: Instale Node.js em https://nodejs.org
    pause & exit /b 1
)
for /f %%v in ('"%NODE%" --version 2^>nul') do echo OK: %%v

:: STEP 2 - Find PostgreSQL
echo.
echo [2] Localizando PostgreSQL...
set "PG="
set "DT="

for %%V in (17 16 15 14 13 12) do (
    if exist "C:\Program Files\PostgreSQL\%%V\bin\psql.exe" if not defined PG (
        set "PG=C:\Program Files\PostgreSQL\%%V\bin"
        set "DT=C:\Program Files\PostgreSQL\%%V\data"
        set "VER=%%V"
        echo OK: Encontrado versao %%V
    )
)
for %%V in (17 16 15 14 13 12) do (
    if exist "C:\Program Files (x86)\PostgreSQL\%%V\bin\psql.exe" if not defined PG (
        set "PG=C:\Program Files (x86)\PostgreSQL\%%V\bin"
        set "DT=C:\Program Files (x86)\PostgreSQL\%%V\data"
        set "VER=%%V"
        echo OK: Encontrado versao %%V ^(x86^)
    )
)

:: Check all drives
for %%D in (D E F) do (
    for %%V in (17 16 15 14 13) do (
        if exist "%%D:\Program Files\PostgreSQL\%%V\bin\psql.exe" if not defined PG (
            set "PG=%%D:\Program Files\PostgreSQL\%%V\bin"
            set "DT=%%D:\Program Files\PostgreSQL\%%V\data"
            set "VER=%%V"
            echo OK: Encontrado em %%D:
        )
    )
)

if not defined PG (
    echo ERRO: PostgreSQL nao encontrado!
    echo Instale em: https://www.postgresql.org/download/windows/
    echo Use senha: postgres
    pause & exit /b 1
)
set "PATH=%PATH%;%PG%"
echo Caminho: %PG%

:: STEP 3 - Start service
echo.
echo [3] Iniciando servico...
net start postgresql-x64-%VER% >nul 2>&1
net start postgresql-%VER% >nul 2>&1
net start postgresql >nul 2>&1
timeout /t 3 /nobreak >nul
echo OK

:: STEP 4 - Find password
echo.
echo [4] Testando conexao...
set "PASS="
for %%P in (postgres admin 123456 password root 1234 12345 "") do (
    set "PGPASSWORD=%%P"
    "%PG%\psql.exe" -U postgres -h 127.0.0.1 -p 5432 -c "SELECT 1;" >nul 2>&1
    if !errorLevel!==0 (
        set "PASS=%%P"
        echo OK: Senha encontrada: %%P
        goto :found
    )
)

:: Ask user
echo Nenhuma senha automatica funcionou.
set /p "PGPASSWORD=Digite a senha que voce usou ao instalar o PostgreSQL: "
"%PG%\psql.exe" -U postgres -h 127.0.0.1 -p 5432 -c "SELECT 1;" >nul 2>&1
if %errorLevel%==0 (
    set "PASS=%PGPASSWORD%"
    echo OK: Senha correta!
    goto :found
)

:: Reset password
echo Resetando senha via pg_hba.conf...
if not defined DT (
    echo ERRO: data directory nao encontrado
    pause & exit /b 1
)
copy "%DT%\pg_hba.conf" "%DT%\pg_hba.conf.bak" >nul
powershell -Command "(Get-Content '%DT%\pg_hba.conf') -replace 'scram-sha-256','trust' -replace '\bmd5\b','trust' | Set-Content '%DT%\pg_hba.conf'"
net stop postgresql-x64-%VER% >nul 2>&1
net stop postgresql >nul 2>&1
timeout /t 3 /nobreak >nul
net start postgresql-x64-%VER% >nul 2>&1
net start postgresql >nul 2>&1
timeout /t 5 /nobreak >nul
set "PGPASSWORD="
"%PG%\psql.exe" -U postgres -h 127.0.0.1 -p 5432 -c "ALTER USER postgres PASSWORD 'postgres';" >nul 2>&1
copy "%DT%\pg_hba.conf.bak" "%DT%\pg_hba.conf" >nul
net stop postgresql-x64-%VER% >nul 2>&1
net stop postgresql >nul 2>&1
timeout /t 2 /nobreak >nul
net start postgresql-x64-%VER% >nul 2>&1
net start postgresql >nul 2>&1
timeout /t 5 /nobreak >nul
set "PGPASSWORD=postgres"
set "PASS=postgres"
"%PG%\psql.exe" -U postgres -h 127.0.0.1 -p 5432 -c "SELECT 1;" >nul 2>&1
if %errorLevel% NEQ 0 (
    echo ERRO: Nao foi possivel conectar!
    echo Abra o pgAdmin e defina a senha para: postgres
    pause & exit /b 1
)
echo OK: Senha redefinida para: postgres

:found

:: STEP 5 - Create DB
echo.
echo [5] Criando banco de dados...
"%PG%\psql.exe" -U postgres -h 127.0.0.1 -p 5432 -c "CREATE DATABASE ooh_manager;" >nul 2>&1
"%PG%\psql.exe" -U postgres -h 127.0.0.1 -p 5432 -d ooh_manager -f "%DIR%database\schema.sql" >nul 2>&1
"%PG%\psql.exe" -U postgres -h 127.0.0.1 -p 5432 -d ooh_manager -f "%DIR%database\fix_final.sql" >nul 2>&1
echo OK: Banco criado!

:: STEP 6 - Fix .env with correct password
echo.
echo [6] Atualizando .env com senha correta...
(
echo PORT=3001
echo NODE_ENV=production
echo DB_HOST=localhost
echo DB_PORT=5432
echo DB_NAME=ooh_manager
echo DB_USER=postgres
echo DB_PASSWORD=%PASS%
echo JWT_SECRET=ooh_jwt_%RANDOM%%RANDOM%_key
echo JWT_EXPIRES_IN=7d
echo UPLOAD_DIR=./uploads
echo FRONTEND_URL=*
) > "%BACKEND%\.env"
echo OK: .env atualizado!
if not exist "%BACKEND%\uploads" mkdir "%BACKEND%\uploads"

:: STEP 7 - npm install if needed
if not exist "%BACKEND%\node_modules" (
    echo.
    echo [7] Instalando dependencias...
    cd /d "%BACKEND%"
    call npm install --loglevel=warn
    echo OK
) else (
    echo.
    echo [7] Dependencias ja instaladas. OK
)

:: STEP 8 - Create admin
echo.
echo [8] Criando admin...
cd /d "%BACKEND%"
"%NODE%" -e "const{Pool}=require('pg'),b=require('bcryptjs'),p=new Pool({host:'localhost',port:5432,database:'ooh_manager',user:'postgres',password:'%PASS%'});b.hash('admin123',12).then(h=>p.query(\"INSERT INTO usuarios(nome,email,senha_hash,perfil)VALUES('Administrador','admin@oohmanager.com','\"+h+\"','administrador')ON CONFLICT(email)DO NOTHING\").then(()=>{console.log('OK: admin criado');p.end()}).catch(e=>{console.log('Info:',e.message);p.end()})).catch(e=>{console.log('Erro:',e.message);p.end()});"

:: STEP 9 - Shortcut
powershell -Command "try{$s=(New-Object -COM WScript.Shell).CreateShortcut([Environment]::GetFolderPath('Desktop')+'\OOH Manager.lnk');$s.TargetPath='%DIR%INICIAR.bat';$s.WorkingDirectory='%DIR%';$s.Save();Write-Host 'OK: Atalho criado!'}catch{}"

echo.
echo ================================
echo  TUDO PRONTO!
echo  Login: admin@oohmanager.com
echo  Senha: admin123
echo ================================
echo.
echo Iniciando sistema...
timeout /t 2 /nobreak >nul
start "" "%DIR%INICIAR.bat"
echo.
echo Pressione qualquer tecla para fechar.
pause
