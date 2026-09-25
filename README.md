# Site — Instituto Dr. Bach

Site estático (HTML + CSS + JS puro), mobile-first, pronto para Vercel ou Netlify.
A pasta publicada é `public/`.

## Rodar localmente
```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\servidor-local.ps1
# abra http://localhost:8080
```
(Com Node instalado também funciona: `npx serve public`.)

## Deploy
- **Vercel:** importe o repositório; o `vercel.json` já aponta para `public/`.
- **Netlify:** arraste a pasta `public/` ou conecte o repositório (`netlify.toml` incluso).

## Estrutura
```
public/
  index.html            página única (todas as seções)
  css/styles.css        estilos — cores e fontes em :root
  js/main.js            menu, carrossel, lightbox, animações
  images/               fotos otimizadas (WebP + JPG, 480/960/original)
  logo.png, favicon.png, apple-touch-icon.png
  robots.txt, sitemap.xml
source-images/          originais (não vão para o deploy)
scripts/
  otimizar-imagens.ps1  regenera todas as imagens a partir de source-images/
  servidor-local.ps1    servidor local
```

## Adicionar/trocar fotos
1. Coloque o JPG original em `source-images/` com o nome desejado.
2. Se for uma foto nova, adicione-a em `$fotos` no `scripts/otimizar-imagens.ps1` (com recorte opcional).
3. Rode:
   ```powershell
   .\scripts\otimizar-imagens.ps1 -Cwebp "C:\caminho\cwebp.exe"
   ```
   O `cwebp` vem no pacote libwebp: https://developers.google.com/speed/webp/download

## O que falta substituir (busque por `[` no index.html)
| Placeholder | Onde |
|---|---|
| `SEU-DOMINIO.com.br` | `<head>` (canonical, Open Graph, JSON-LD), `robots.txt`, `sitemap.xml` |
| `[CARGA HORÁRIA]`, `[DURAÇÃO]`, `[VALOR]` | Cards de cursos, FAQ |
| `[ENDEREÇO]`, `[DATAS]` | FAQ e rodapé |
| `[CONFIRMAR]` | Preços encontrados no Instagram (ASB 3x R$184 / 6x R$160, TSB a partir de R$600) — apague a etiqueta após confirmar |
| `[REVISAR]` | Depoimentos de Lara, Kevym e Camili (texto de exemplo) |
| Fotos "foto em breve" | Evandro Nolasco, Ronald de Oliveira — salve em `source-images/prof-*.jpg` |
