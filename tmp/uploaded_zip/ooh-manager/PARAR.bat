@echo off
chcp 65001 >nul
title OOH Manager - Encerrando
color 0C

echo.
echo  Encerrando OOH Manager...
echo.

taskkill /f /fi "WINDOWTITLE eq OOH Manager - Backend API" >nul 2>&1
taskkill /f /im node.exe >nul 2>&1

echo  [OK] Sistema encerrado com sucesso.
echo.
timeout /t 2 /nobreak >nul
