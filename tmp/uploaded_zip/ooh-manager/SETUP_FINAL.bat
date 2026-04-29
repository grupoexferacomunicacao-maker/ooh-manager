@echo off
title Setup Final OOH Manager
color 0A

>nul 2>&1 net session
if %errorLevel% NEQ 0 (
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs -Wait"
    exit /b
)

set "DIR=%~dp0"
set "BACKEND=%DIR%backend"
set "PG=C:\Program Files\PostgreSQL\16\bin"
set "NODE=C:\Program Files\nodejs\node.exe"
set "NPM=C:\Program Files\nodejs\npm.cmd"

echo.
echo PASSO 1: Criando .env...
(
echo PORT=3001
echo NODE_ENV=production
echo DB_HOST=localhost
echo DB_PORT=5432
echo DB_NAME=ooh_manager
echo DB_USER=postgres
echo DB_PASSWORD=OohManager2025!
echo JWT_SECRET=ooh_jwt_secret_key_2025
echo JWT_EXPIRES_IN=7d
echo UPLOAD_DIR=./uploads
echo FRONTEND_URL=*
) > "%BACKEND%\.env"
echo .env criado: %BACKEND%\.env
type "%BACKEND%\.env"
echo.

echo PASSO 2: Criando pasta uploads...
if not exist "%BACKEND%\uploads" mkdir "%BACKEND%\uploads"
echo OK
echo.

echo PASSO 3: npm install...
cd /d "%BACKEND%"
call "%NPM%" install
echo npm install encerrado com codigo: %errorLevel%
echo.

echo PASSO 4: Testando senha PostgreSQL...
set "PGPASSWORD=OohManager2025!"
"%PG%\psql.exe" -U postgres -c "SELECT 'conexao ok';"
echo Resultado acima. Se falhou, qual foi a senha que voce usou?
echo.

echo PASSO 5: Criando banco de dados...
"%PG%\psql.exe" -U postgres -c "CREATE DATABASE ooh_manager;"
"%PG%\psql.exe" -U postgres -d ooh_manager -f "%DIR%database\schema.sql"
echo.

echo PASSO 6: Criando admin...
"%NODE%" -e "const{Pool}=require('pg'),b=require('bcryptjs'),p=new Pool({host:'localhost',port:5432,database:'ooh_manager',user:'postgres',password:'OohManager2025!'});b.hash('admin123',12).then(h=>p.query(\"INSERT INTO usuarios(nome,email,senha_hash,perfil)VALUES('Admin','admin@oohmanager.com','\"+h+\"','administrador')ON CONFLICT(email)DO NOTHING\").then(()=>{console.log('Admin criado OK');p.end()}).catch(e=>{console.log('Erro admin:',e.message);p.end()})).catch(e=>{console.log('Erro bcrypt:',e.message);p.end()});"
echo.

echo === CONCLUIDO ===
echo Agora rode o INICIAR.bat
echo.
pause
