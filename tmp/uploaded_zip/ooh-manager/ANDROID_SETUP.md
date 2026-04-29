# OOH Manager no Android

## Opcao 1 — PWA (mais facil, recomendado)

### O que e PWA?
Progressive Web App — o app roda no navegador do celular mas funciona
como um aplicativo nativo: icone na tela inicial, tela cheia, sem barra do browser.

### Como instalar no Android:

1. **Configure o IP do servidor**
   - No computador Windows, abra o CMD e digite: `ipconfig`
   - Anote o IP local (ex: 192.168.1.100)

2. **Edite o arquivo .env do backend**
   - Abra `backend/.env`
   - Mude: `FRONTEND_URL=*`
   - Isso ja deve estar configurado

3. **No celular Android:**
   - Conecte o celular na mesma rede Wi-Fi do computador
   - Abra o Chrome no celular
   - Acesse: `http://192.168.1.100:3001` (use o IP do seu computador)
   - Ou acesse o arquivo: baixe o OOH_Manager.html no celular

4. **Instalar como app:**
   - No Chrome, toque nos 3 pontinhos (menu)
   - Selecione "Adicionar a tela inicial"
   - Confirme — o icone aparece na tela do celular
   - Abrir pelo icone da tela inicial = experiencia de app nativo

---

## Opcao 2 — Servidor na nuvem (acesso de qualquer lugar)

Para acessar de qualquer celular, em qualquer lugar:

### Railway.app (gratis para comecar):
1. Crie conta em railway.app
2. New Project > Deploy from GitHub
3. Adicione PostgreSQL como servico
4. Configure as variaveis do .env
5. Seu app fica em: https://seu-app.railway.app

### Render.com (alternativa gratuita):
1. Crie conta em render.com
2. New Web Service > conecte o repositorio
3. Configure as env vars
4. Deploy automatico

---

## Opcao 3 — APK nativo com Capacitor

Para gerar um APK real instalavel:

### Pre-requisitos:
- Node.js instalado
- Android Studio instalado
- Java JDK 17+

### Passos:
```
npm install -g @capacitor/cli
npx cap init "OOH Manager" "com.exfera.oohmanager"
npx cap add android
npx cap copy android
npx cap open android
```
No Android Studio: Build > Generate Signed Bundle/APK

---

## Recomendacao

Para uso interno da equipe Exfera:
**PWA via Wi-Fi** e a opcao mais rapida e sem custo adicional.

Para acesso remoto (vendedores em campo):
**Railway.app** com o backend hospedado na nuvem.

