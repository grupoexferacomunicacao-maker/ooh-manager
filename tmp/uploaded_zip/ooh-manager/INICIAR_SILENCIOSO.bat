@echo off
set "DIR=%~dp0"
set "NODE=C:\Program Files\nodejs\node.exe"
set "PATH=%PATH%;C:\Program Files\nodejs;C:\Program Files\PostgreSQL\16\bin"

:: Iniciar PostgreSQL
sc start postgresql-x64-16 >nul 2>&1
sc start postgresql-x64-15 >nul 2>&1
timeout /t 3 /nobreak >nul

:: Matar instancia anterior se existir
for /f "tokens=5" %%a in ('netstat -aon 2^>nul ^| find ":3001 "') do taskkill /f /pid %%a >nul 2>&1
timeout /t 1 /nobreak >nul

:: Iniciar backend em loop (reinicia se cair)
:loop
cd /d "%DIR%backend"
"%NODE%" src/server.js
echo Backend caiu. Reiniciando em 3 segundos...
timeout /t 3 /nobreak >nul
goto :loop
