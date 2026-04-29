@echo off
title OOH Manager
color 0B
setlocal EnableDelayedExpansion

set "DIR=%~dp0"
set "NODE=C:\Program Files\nodejs\node.exe"
set "PATH=%PATH%;C:\Program Files\nodejs;C:\Program Files\PostgreSQL\16\bin;C:\Program Files\PostgreSQL\15\bin"

echo.
echo ============================================
echo  OOH Manager - Iniciando sistema...
echo ============================================
echo.

if not exist "%DIR%backend\node_modules" (
    color 0C
    echo ERRO: node_modules nao encontrado!
    echo Execute INSTALAR_TUDO.bat como administrador.
    pause & exit /b 1
)
if not exist "%DIR%backend\.env" (
    color 0C
    echo ERRO: Arquivo .env nao encontrado!
    echo Execute INSTALAR_TUDO.bat como administrador.
    pause & exit /b 1
)
if not exist "%DIR%frontend\OOH_Manager.html" (
    color 0C
    echo ERRO: OOH_Manager.html nao encontrado!
    pause & exit /b 1
)

echo [1] Verificando arquivos... OK

echo [2] Iniciando PostgreSQL...
sc start postgresql-x64-17 >nul 2>&1
sc start postgresql-x64-16 >nul 2>&1
sc start postgresql-x64-15 >nul 2>&1
timeout /t 2 /nobreak >nul
echo     OK

echo [3] Liberando porta 3001...
for /f "tokens=5" %%a in ('netstat -aon 2^>nul ^| find ":3001 "') do taskkill /f /pid %%a >nul 2>&1
timeout /t 1 /nobreak >nul
echo     OK

echo [4] Iniciando backend com auto-reinicio...
set "BACKEND_DIR=%DIR%backend"

:: Iniciar backend num loop que reinicia automaticamente
start "OOH Manager - Servidor" cmd /k "title OOH Manager - Servidor && cd /d "%BACKEND_DIR%" && :loop && "%NODE%" src/server.js || (echo Reiniciando em 3s... && timeout /t 3 /nobreak >nul && goto loop)"

echo     Aguardando servidor...
set "T=0"
:aguardar
timeout /t 2 /nobreak >nul
set /a T+=1
powershell -Command "try{Invoke-WebRequest 'http://localhost:3001/api/health' -UseBasicParsing -TimeoutSec 2|Out-Null;exit 0}catch{exit 1}" >nul 2>&1
if %errorLevel%==0 (
    echo     Servidor OK!
    goto :servidor_ok
)
if %T% LSS 15 goto :aguardar
echo     AVISO: Servidor demorou. Verifique a janela do servidor.

:servidor_ok
echo [5] Abrindo navegador...
set "HTML=%DIR%frontend\OOH_Manager.html"

if exist "C:\Program Files\Google\Chrome\Application\chrome.exe" (
    start "" "C:\Program Files\Google\Chrome\Application\chrome.exe" "%HTML%"
    goto :fim
)
if exist "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe" (
    start "" "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe" "%HTML%"
    goto :fim
)
if exist "C:\Program Files\Microsoft\Edge\Application\msedge.exe" (
    start "" "C:\Program Files\Microsoft\Edge\Application\msedge.exe" "%HTML%"
    goto :fim
)
start "" "%HTML%"

:fim
echo.
echo ============================================
echo  Sistema iniciado!
echo  Login: admin@oohmanager.com / admin123
echo  O servidor reinicia automaticamente se cair.
echo ============================================
echo.
echo  Pressione qualquer tecla para fechar esta janela.
echo  A janela "OOH Manager - Servidor" deve ficar aberta.
echo.
pause
