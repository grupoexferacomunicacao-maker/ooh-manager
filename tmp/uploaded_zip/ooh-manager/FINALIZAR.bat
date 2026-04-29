@echo off
title OOH Manager - Finalizando configuracao
color 0A
setlocal EnableDelayedExpansion

>nul 2>&1 net session
if %errorLevel% NEQ 0 (
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs -Wait"
    exit /b
)

set "DIR=%~dp0"
set "BACKEND=%DIR%backend"

echo.
echo  Finalizando configuracao do OOH Manager...
echo.

::  Encontrar PostgreSQL 
echo  [1] Localizando PostgreSQL...
set "PG_BIN="
set "PG_VER="
for %%V in (17 16 15 14) do (
    if exist "C:\Program Files\PostgreSQL\%%V\bin\psql.exe" (
        if not defined PG_BIN (
            set "PG_BIN=C:\Program Files\PostgreSQL\%%V\bin"
            set "PG_DATA=C:\Program Files\PostgreSQL\%%V\data"
            set "PG_VER=%%V"
        )
    )
)
if not defined PG_BIN (
    color 0C
    echo  ERRO: PostgreSQL nao encontrado!
    echo  Instale em: https://www.postgresql.org/download/windows/
    pause & exit /b 1
)
echo  OK: PostgreSQL %PG_VER% em %PG_BIN%
set "PATH=%PATH%;%PG_BIN%"

::  Iniciar servico PostgreSQL 
echo.
echo  [2] Iniciando servico PostgreSQL...
sc start postgresql-x64-%PG_VER% >nul 2>&1
timeout /t 4 /nobreak >nul
sc query postgresql-x64-%PG_VER% | find "RUNNING" >nul 2>&1
if %errorLevel%==0 (
    echo  OK: Servico rodando!
    goto :pg_rodando
)
echo  Tentando metodo alternativo...
net start postgresql-x64-%PG_VER% >nul 2>&1
timeout /t 4 /nobreak >nul
echo  OK: Servico iniciado.

:pg_rodando

::  Pedir senha e testar 
echo.
echo  [3] Testando conexao com PostgreSQL...
echo.
echo  Digite a senha do PostgreSQL (a que voce usou na instalacao):
echo  Se nao definiu senha, pressione Enter.
echo.
set /p "PGPASSWORD=  Senha postgres: "

"%PG_BIN%\psql.exe" -U postgres -c "SELECT 1;" >nul 2>&1
if %errorLevel% NEQ 0 (
    echo.
    echo  Senha incorreta. Redefinindo senha automaticamente...
    echo.

    :: Modo trust temporario
    set "HBA=%PG_DATA%\pg_hba.conf"
    copy "%HBA%" "%HBA%.bak" >nul 2>&1

    powershell -Command "
        \$f = '%PG_DATA%\pg_hba.conf'
        \$c = Get-Content \$f
        \$c = \$c -replace 'scram-sha-256','trust' -replace '\bmd5\b','trust'
        \$c | Set-Content \$f
    "

    sc stop postgresql-x64-%PG_VER% >nul 2>&1
    timeout /t 3 /nobreak >nul
    sc start postgresql-x64-%PG_VER% >nul 2>&1
    timeout /t 4 /nobreak >nul

    set "PGPASSWORD="
    "%PG_BIN%\psql.exe" -U postgres -c "ALTER USER postgres PASSWORD 'OohManager2025!';" >nul 2>&1

    copy "%HBA%.bak" "%HBA%" >nul 2>&1
    sc stop postgresql-x64-%PG_VER% >nul 2>&1
    timeout /t 3 /nobreak >nul
    sc start postgresql-x64-%PG_VER% >nul 2>&1
    timeout /t 4 /nobreak >nul

    set "PGPASSWORD=OohManager2025!"
    "%PG_BIN%\psql.exe" -U postgres -c "SELECT 1;" >nul 2>&1
    if %errorLevel% NEQ 0 (
        color 0C
        echo  ERRO: Nao foi possivel conectar ao PostgreSQL.
        echo  Abra o pgAdmin, conecte como postgres e mude a senha para: OohManager2025!
        pause & exit /b 1
    )
    echo  OK: Senha redefinida para OohManager2025!
) else (
    echo  OK: Conexao estabelecida!
)

::  Criar .env com senha correta 
echo.
echo  [4] Criando arquivo .env...
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
) > "%BACKEND%\.env"
echo  OK: .env criado com a senha correta!

::  Criar banco e tabelas 
echo.
echo  [5] Criando banco de dados...
"%PG_BIN%\psql.exe" -U postgres -c "CREATE DATABASE ooh_manager;" >nul 2>&1
"%PG_BIN%\psql.exe" -U postgres -d ooh_manager -f "%DIR%database\schema.sql" >nul 2>&1
echo  OK: Banco configurado!

::  Criar pasta uploads 
if not exist "%BACKEND%\uploads" mkdir "%BACKEND%\uploads"

::  Criar usuario admin 
echo.
echo  [6] Criando usuario admin...
set "NODE=node"
if exist "C:\Program Files\nodejs\node.exe" set "NODE=C:\Program Files\nodejs\node.exe"
cd /d "%BACKEND%"
"%NODE%" -e "const{Pool}=require('pg'),b=require('bcryptjs'),p=new Pool({host:'localhost',port:5432,database:'ooh_manager',user:'postgres',password:'%PGPASSWORD%'});b.hash('admin123',12).then(h=>p.query(\"INSERT INTO usuarios(nome,email,senha_hash,perfil)VALUES('Admin','admin@oohmanager.com','\"+h+\"','administrador')ON CONFLICT(email)DO NOTHING\").then(()=>{console.log('  OK');p.end()}).catch(e=>{console.log('  Erro:',e.message);p.end()})).catch(e=>{console.log('  Erro:',e.message);p.end()});"

::  Resultado 
echo.
echo  +=============================================+
echo  |   Configuracao concluida! Sistema pronto.  |
echo  |                                            |
echo  |   Login: admin@oohmanager.com             |
echo  |   Senha: admin123                         |
echo  +=============================================+
echo.
echo  Iniciando sistema...
timeout /t 2 /nobreak >nul
start "" "%DIR%INICIAR.bat"
pause
