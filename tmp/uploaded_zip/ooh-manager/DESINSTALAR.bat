@echo off
chcp 65001 >nul 2>&1
title OOH Manager - Desinstalar
color 0C

echo.
echo  Deseja remover o OOH Manager completamente? [S/N]
choice /c SN /n /m "  Resposta: "
if %errorLevel%==2 exit /b

echo.
echo  [..] Encerrando processos...
taskkill /f /fi "WINDOWTITLE eq OOH Backend" >nul 2>&1
taskkill /f /im node.exe >nul 2>&1

echo  [..] Removendo atalhos...
del /f /q "%USERPROFILE%\Desktop\OOH Manager.lnk" >nul 2>&1
rd /s /q "%APPDATA%\Microsoft\Windows\Start Menu\Programs\OOH Manager" >nul 2>&1

echo  [..] Removendo registro...
reg delete "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\OOHManager" /f >nul 2>&1

echo.
echo  [OK] OOH Manager removido.
echo  Os arquivos do sistema foram mantidos em: %~dp0
echo  Voce pode apagar a pasta manualmente se desejar.
echo.
pause
