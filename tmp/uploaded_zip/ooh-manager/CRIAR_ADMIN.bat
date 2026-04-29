@echo off
title Criar Admin
color 0A

>nul 2>&1 net session
if %errorLevel% NEQ 0 (
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs -Wait"
    exit /b
)

echo.
echo Criando usuario administrador...
echo.

set PGPASSWORD=OohManager2025!

curl -s -X POST "http://localhost:3001/api/auth/register" -H "Content-Type: application/json" -d "{\"nome\":\"Administrador\",\"email\":\"admin@oohmanager.com\",\"senha\":\"admin123\",\"perfil\":\"administrador\"}"

echo.
echo.
echo Se apareceu um ID acima, o admin foi criado!
echo Login: admin@oohmanager.com
echo Senha: admin123
echo.
pause
