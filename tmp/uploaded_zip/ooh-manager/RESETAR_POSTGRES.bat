@echo off
title Resetar PostgreSQL
color 0E
setlocal EnableDelayedExpansion

>nul 2>&1 net session
if %errorLevel% NEQ 0 (
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs -Wait"
    exit /b
)

set "DIR=%~dp0"

echo.
echo  Localizando PostgreSQL...

set "PG_BIN="
set "PG_DATA="

for %%V in (17 16 15 14) do (
    if exist "C:\Program Files\PostgreSQL\%%V\bin\psql.exe" (
        set "PG_BIN=C:\Program Files\PostgreSQL\%%V\bin"
        set "PG_DATA=C:\Program Files\PostgreSQL\%%V\data"
        set "PG_VER=%%V"
    )
)

if not defined PG_BIN (
    color 0C
    echo  ERRO: PostgreSQL nao encontrado!
    pause & exit /b 1
)

echo  Encontrado: PostgreSQL %PG_VER% em %PG_BIN%
echo  Data dir:   %PG_DATA%
set "PATH=%PATH%;%PG_BIN%"

:: Parar servico
echo.
echo  [1] Parando servico PostgreSQL...
sc stop postgresql-x64-%PG_VER% >nul 2>&1
sc stop postgresql >nul 2>&1
timeout /t 3 /nobreak >nul
echo      OK

:: Fazer backup do pg_hba.conf e colocar trust temporario
echo  [2] Configurando acesso temporario sem senha...
set "HBA=%PG_DATA%\pg_hba.conf"

if not exist "%HBA%" (
    color 0C
    echo  ERRO: Arquivo pg_hba.conf nao encontrado em %HBA%
    echo  Verifique o caminho do PostgreSQL.
    pause & exit /b 1
)

copy "%HBA%" "%HBA%.backup" >nul
powershell -Command "
    (Get-Content '%HBA%') | ForEach-Object {
        if (\$_ -match '^host' -or \$_ -match '^local') {
            \$_ -replace 'scram-sha-256|md5|peer|ident','trust'
        } else { \$_ }
    } | Set-Content '%HBA%'
"
echo      OK: pg_hba.conf configurado para trust temporario

:: Reiniciar PostgreSQL
echo  [3] Reiniciando PostgreSQL...
sc start postgresql-x64-%PG_VER% >nul 2>&1
sc start postgresql >nul 2>&1
timeout /t 5 /nobreak >nul
echo      OK

:: Redefinir senha do postgres
echo  [4] Redefinindo senha do usuario postgres...
set "NOVA_SENHA=OohManager2025!"
set "PGPASSWORD="
"%PG_BIN%\psql.exe" -U postgres -c "ALTER USER postgres PASSWORD 'OohManager2025!';" >nul 2>&1
if %errorLevel%==0 (
    echo      OK: Senha redefinida para: OohManager2025!
) else (
    echo      AVISO: Tente manualmente se necessario.
)

:: Restaurar pg_hba.conf original
echo  [5] Restaurando configuracao original...
copy "%HBA%.backup" "%HBA%" >nul
echo      OK

:: Reiniciar PostgreSQL com config original
echo  [6] Reiniciando PostgreSQL com config final...
sc stop postgresql-x64-%PG_VER% >nul 2>&1
sc stop postgresql >nul 2>&1
timeout /t 3 /nobreak >nul
sc start postgresql-x64-%PG_VER% >nul 2>&1
sc start postgresql >nul 2>&1
timeout /t 5 /nobreak >nul
echo      OK

:: Testar conexao com nova senha
echo  [7] Testando conexao...
set "PGPASSWORD=OohManager2025!"
"%PG_BIN%\psql.exe" -U postgres -c "SELECT version();" >nul 2>&1
if %errorLevel%==0 (
    echo      OK: Conexao funcionando com a nova senha!
    goto :continuar
)

color 0C
echo      ERRO: Ainda nao conecta. Tente manualmente:
echo      1. Abra pgAdmin (instalado junto com PostgreSQL)
echo      2. Conecte como postgres
echo      3. Mude a senha para: OohManager2025!
pause & exit /b 1

:continuar
:: Criar banco e tabelas
echo.
echo  [8] Criando banco de dados ooh_manager...
"%PG_BIN%\psql.exe" -U postgres -c "CREATE DATABASE ooh_manager;" >nul 2>&1
"%PG_BIN%\psql.exe" -U postgres -d ooh_manager -f "%DIR%database\schema.sql" >nul 2>&1
echo      OK

:: Atualizar .env
echo  [9] Atualizando .env...
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
echo      OK

:: npm install se necessario
if not exist "%DIR%backend\node_modules" (
    echo  [10] Instalando dependencias...
    set "PATH=%PATH%;C:\Program Files\nodejs"
    cd /d "%DIR%backend"
    call npm install --loglevel=warn
    echo      OK
)

:: Criar admin
echo  [11] Criando usuario admin...
set "NODE=node"
if exist "C:\Program Files\nodejs\node.exe" set "NODE=C:\Program Files\nodejs\node.exe"
cd /d "%DIR%backend"
"%NODE%" -e "const{Pool}=require('pg'),b=require('bcryptjs'),p=new Pool({host:'localhost',port:5432,database:'ooh_manager',user:'postgres',password:'OohManager2025!'});b.hash('admin123',12).then(h=>p.query(\"INSERT INTO usuarios(nome,email,senha_hash,perfil)VALUES('Admin','admin@oohmanager.com','\"+h+\"','administrador')ON CONFLICT(email)DO NOTHING\").then(()=>{console.log('      OK');p.end()}).catch(()=>{console.log('      ja existe');p.end()})).catch(e=>{console.log('Erro:',e.message);p.end()});"

echo.
echo  +=============================================+
echo  |   Tudo pronto!                             |
echo  |                                            |
echo  |   Login: admin@oohmanager.com             |
echo  |   Senha: admin123                         |
echo  +=============================================+
echo.
echo  Iniciando sistema...
timeout /t 2 /nobreak >nul
start "" "%DIR%INICIAR.bat"
pause
