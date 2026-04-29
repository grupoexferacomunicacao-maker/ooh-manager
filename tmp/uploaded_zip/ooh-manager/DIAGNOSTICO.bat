@echo off
chcp 65001 >nul 2>&1
title OOH Manager - Diagnostico
color 0E
setlocal EnableDelayedExpansion

echo.
echo  ============================================
echo   OOH Manager - Diagnostico do Sistema
echo  ============================================
echo.

set "ERROS=0"
set "DIR=%~dp0"

:: -- Node.js -------------------------------------------------
echo  [NODE.JS]
where node >nul 2>&1
if %errorLevel%==0 (
    for /f "tokens=*" %%v in ('node --version 2^>nul') do echo  OK  - Versao: %%v
) else (
    echo  ERRO - Node.js NAO encontrado
    echo         Solucao: Execute INSTALAR_TUDO.bat
    set /a ERROS+=1
)
echo.

:: -- node_modules --------------------------------------------
echo  [DEPENDENCIAS]
if exist "%DIR%backend\node_modules" (
    echo  OK  - node_modules encontrado
) else (
    echo  ERRO - Pasta node_modules ausente
    echo         Solucao: Abra o CMD na pasta backend e rode: npm install
    set /a ERROS+=1
)
echo.

:: -- .env ----------------------------------------------------
echo  [CONFIGURACAO]
if exist "%DIR%backend\.env" (
    echo  OK  - Arquivo .env encontrado
) else (
    echo  ERRO - Arquivo .env nao encontrado
    echo         Solucao: Execute INSTALAR_TUDO.bat
    set /a ERROS+=1
)
echo.

:: -- PostgreSQL ----------------------------------------------
echo  [POSTGRESQL]
set "PG_OK=0"
for %%S in (postgresql-x64-17 postgresql-x64-16 postgresql-x64-15 postgresql-x64-14 postgresql) do (
    sc query %%S 2>nul | find "RUNNING" >nul 2>&1
    if !errorLevel!==0 (
        echo  OK  - Servico %%S esta RODANDO
        set "PG_OK=1"
    )
)
if "%PG_OK%"=="0" (
    echo  ERRO - Nenhum servico PostgreSQL ativo
    echo         Solucao: Verifique se o PostgreSQL foi instalado
    echo         e se o servico esta iniciado nos Servicos do Windows
    set /a ERROS+=1
)
echo.

:: -- Porta 3001 ----------------------------------------------
echo  [PORTA 3001 - Backend]
netstat -aon 2>nul | find ":3001 " >nul 2>&1
if %errorLevel%==0 (
    echo  OK  - Porta 3001 esta em uso ^(backend provavelmente rodando^)
) else (
    echo  INFO - Porta 3001 livre ^(backend nao iniciado ainda^)
)
echo.

:: -- Arquivo HTML --------------------------------------------
echo  [FRONTEND]
if exist "%DIR%frontend\OOH_Manager.html" (
    echo  OK  - OOH_Manager.html encontrado
) else (
    echo  ERRO - OOH_Manager.html nao encontrado
    echo         Caminho esperado: %DIR%frontend\OOH_Manager.html
    set /a ERROS+=1
)
echo.

:: -- Banco de dados ------------------------------------------
echo  [BANCO DE DADOS]
set "PG_BIN="
for %%P in (
    "C:\Program Files\PostgreSQL\17\bin"
    "C:\Program Files\PostgreSQL\16\bin"
    "C:\Program Files\PostgreSQL\15\bin"
    "C:\Program Files\PostgreSQL\14\bin"
) do (
    if exist "%%~P\psql.exe" set "PG_BIN=%%~P"
)
if defined PG_BIN (
    set "PGPASSWORD=OohManager2025!"
    "%PG_BIN%\psql.exe" -U postgres -d ooh_manager -c "SELECT COUNT(*) FROM usuarios;" >nul 2>&1
    if !errorLevel!==0 (
        echo  OK  - Banco ooh_manager acessivel e tabelas criadas
    ) else (
        echo  ERRO - Banco ooh_manager inacessivel ou tabelas ausentes
        echo         Solucao: Execute INSTALAR_TUDO.bat novamente
        set /a ERROS+=1
    )
) else (
    echo  AVISO - psql.exe nao encontrado para testar banco
)
echo.

:: -- Resumo --------------------------------------------------
echo  ============================================
if "%ERROS%"=="0" (
    color 0A
    echo   TUDO OK! Execute INICIAR.bat para abrir.
) else (
    color 0C
    echo   !ERROS! problema^(s^) encontrado^(s^).
    echo   Leia as solucoes acima e tente novamente.
    echo   Se persistir, execute INSTALAR_TUDO.bat
)
echo  ============================================
echo.
pause
