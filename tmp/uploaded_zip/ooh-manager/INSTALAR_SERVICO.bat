@echo off
title Instalar Servico OOH Manager
color 0A

>nul 2>&1 net session
if %errorLevel% NEQ 0 (
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs -Wait"
    exit /b
)

set "DIR=%~dp0"
set "NODE=C:\Program Files\nodejs\node.exe"
set "NPM=C:\Program Files\nodejs\npm.cmd"

echo.
echo Instalando OOH Manager como servico Windows...
echo.

:: Instalar node-windows para gerenciar o servico
echo [1] Instalando gerenciador de servico...
cd /d "%DIR%backend"
call "%NPM%" install node-windows --save 2>nul
echo OK

:: Criar script de instalacao do servico
echo [2] Criando servico Windows...
(
echo var Service = require^('node-windows'^).Service;
echo var svc = new Service^({
echo   name: 'OOH Manager Backend',
echo   description: 'OOH Manager - Sistema de Gestao de Midia OOH',
echo   script: '%DIR%backend\\src\\server.js'.replace^(/\\\\/g,'/'^),
echo   nodeOptions: [],
echo   env: {
echo     name: 'NODE_ENV',
echo     value: 'production'
echo   }
echo }^);
echo svc.on^('install', function^(^){
echo   svc.start^(^);
echo   console.log^('Servico instalado e iniciado!'^);
echo }^);
echo svc.install^(^);
) > "%DIR%backend\instalar_servico.js"

"%NODE%" "%DIR%backend\instalar_servico.js"

echo.
echo [3] Aguardando servico iniciar...
timeout /t 8 /nobreak >nul

sc query "OOH Manager Backend" >nul 2>&1
if %errorLevel%==0 (
    echo OK: Servico instalado com sucesso!
    echo O backend agora inicia automaticamente com o Windows.
) else (
    echo Usando metodo alternativo...
    goto :metodo_alternativo
)
goto :fim

:metodo_alternativo
:: Usar NSSM se node-windows falhar
echo Baixando NSSM (gerenciador de servicos)...
powershell -Command "(New-Object Net.WebClient).DownloadFile('https://nssm.cc/release/nssm-2.24.zip','%TEMP%\nssm.zip')"
powershell -Command "Expand-Archive '%TEMP%\nssm.zip' '%TEMP%\nssm' -Force"
copy "%TEMP%\nssm\nssm-2.24\win64\nssm.exe" "%DIR%nssm.exe" >nul 2>&1

if exist "%DIR%nssm.exe" (
    "%DIR%nssm.exe" install "OOHManagerBackend" "%NODE%" "%DIR%backend\src\server.js"
    "%DIR%nssm.exe" set "OOHManagerBackend" AppDirectory "%DIR%backend"
    "%DIR%nssm.exe" set "OOHManagerBackend" AppEnvironmentExtra "NODE_ENV=production"
    "%DIR%nssm.exe" set "OOHManagerBackend" Start SERVICE_AUTO_START
    "%DIR%nssm.exe" set "OOHManagerBackend" AppRestartDelay 3000
    net start OOHManagerBackend
    echo OK: Servico NSSM instalado!
) else (
    echo Configurando inicializacao automatica via Task Scheduler...
    schtasks /create /tn "OOH Manager Backend" /tr "\"%DIR%INICIAR_SILENCIOSO.bat\"" /sc onlogon /ru "%USERNAME%" /f >nul 2>&1
    echo OK: Tarefa agendada criada!
)

:fim
echo.
echo +=============================================+
echo   OOH Manager configurado como servico!
echo   O backend reinicia automaticamente.
echo +=============================================+
echo.
pause
