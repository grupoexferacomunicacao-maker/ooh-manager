@echo off
title Instalando dependencias
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
echo  Instalando dependencias do OOH Manager...
echo  Pasta: %BACKEND%
echo.

:: Garantir Node no PATH
set "PATH=C:\Program Files\nodejs;%APPDATA%\npm;%PATH%"

:: Verificar Node
echo  [1] Verificando Node.js...
where node >nul 2>&1
if %errorLevel% NEQ 0 (
    if exist "C:\Program Files\nodejs\node.exe" (
        set "PATH=C:\Program Files\nodejs;%PATH%"
    ) else (
        color 0C
        echo  ERRO: Node.js nao encontrado!
        echo  Baixe e instale: https://nodejs.org
        echo  Escolha a versao LTS e instale normalmente.
        pause & exit /b 1
    )
)
for /f "tokens=*" %%v in ('node --version 2^>nul') do echo  OK: Node.js %%v

:: Verificar npm
echo.
echo  [2] Verificando npm...
where npm >nul 2>&1
if %errorLevel% NEQ 0 (
    color 0C
    echo  ERRO: npm nao encontrado!
    echo  Reinstale o Node.js em: https://nodejs.org
    pause & exit /b 1
)
for /f "tokens=*" %%v in ('npm --version 2^>nul') do echo  OK: npm %%v

:: Entrar na pasta backend
echo.
echo  [3] Entrando na pasta backend...
if not exist "%BACKEND%" (
    color 0C
    echo  ERRO: Pasta backend nao encontrada em %BACKEND%
    pause & exit /b 1
)
cd /d "%BACKEND%"
echo  OK: %BACKEND%

:: Apagar node_modules corrompido se existir
if exist "%BACKEND%\node_modules" (
    echo.
    echo  [4] Removendo node_modules anterior...
    rd /s /q "%BACKEND%\node_modules"
    echo  OK
)

:: Rodar npm install
echo.
echo  [4] Rodando npm install...
echo      Aguarde, pode demorar 2-3 minutos...
echo.
call npm install
set "NPM_ERR=%errorLevel%"

echo.
if exist "%BACKEND%\node_modules" (
    color 0A
    echo  OK: node_modules criado com sucesso!
) else (
    color 0C
    echo  ERRO: npm install falhou! (codigo %NPM_ERR%)
    echo.
    echo  Tente manualmente:
    echo  1. Abra o Prompt de Comando (CMD)
    echo  2. Digite: cd /d "%BACKEND%"
    echo  3. Digite: npm install
    echo  4. Se der erro, copie a mensagem e me envie.
    pause & exit /b 1
)

:: Criar .env se nao existir
echo.
echo  [5] Verificando .env...
if not exist "%BACKEND%\.env" (
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
    ) > "%BACKEND%\.env"
    echo  OK: .env criado!
) else (
    echo  OK: .env ja existe.
)

if not exist "%BACKEND%\uploads" mkdir "%BACKEND%\uploads"

echo.
echo  +=============================================+
echo  |   Dependencias instaladas! Tudo pronto.    |
echo  +=============================================+
echo.
echo  Agora execute: INICIAR.bat
echo.
pause
