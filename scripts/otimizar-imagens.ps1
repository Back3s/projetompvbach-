<#
  Otimiza as fotos do site: recorta (quando configurado), gera WebP (q80) + JPG de
  fallback em 480px, 960px e tamanho original, e processa a logo (remove o fundo
  branco, gera versão roxa/branca, favicon e extrai o roxo exato).

  Uso (PowerShell, na raiz do projeto):
    .\scripts\otimizar-imagens.ps1 -Cwebp "C:\caminho\para\cwebp.exe"

  cwebp: https://developers.google.com/speed/webp/download (libwebp para Windows)
  Originais ficam em /source-images (fora do deploy). Saída em /public/images.
#>
param(
  [Parameter(Mandatory = $true)][string]$Cwebp,
  [string]$Src = (Join-Path $PSScriptRoot '..\source-images'),
  [string]$Out = (Join-Path $PSScriptRoot '..\public\images'),
  [int]$MaxKB = 250
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;

public static class Img {
  static ImageCodecInfo Codec(string mime) {
    foreach (var c in ImageCodecInfo.GetImageEncoders()) if (c.MimeType == mime) return c;
    return null;
  }

  static Bitmap CropResize(Bitmap src, Rectangle crop, int targetW) {
    int w = Math.Min(targetW, crop.Width);
    int h = (int)Math.Round(crop.Height * (w / (double)crop.Width));
    var dst = new Bitmap(w, h, PixelFormat.Format24bppRgb);
    using (var g = Graphics.FromImage(dst)) {
      g.InterpolationMode = InterpolationMode.HighQualityBicubic;
      g.PixelOffsetMode = PixelOffsetMode.HighQuality;
      g.CompositingQuality = CompositingQuality.HighQuality;
      using (var ia = new ImageAttributes()) {
        ia.SetWrapMode(WrapMode.TileFlipXY);
        g.DrawImage(src, new Rectangle(0, 0, w, h), crop.X, crop.Y, crop.Width, crop.Height, GraphicsUnit.Pixel, ia);
      }
    }
    return dst;
  }

  // Salva JPG recortado/redimensionado; retorna a largura final.
  public static int Jpeg(string srcPath, string dstPath, int cx, int cy, int cw, int ch, int targetW, long quality) {
    using (var src = new Bitmap(srcPath)) {
      var crop = cw > 0 ? new Rectangle(cx, cy, cw, ch) : new Rectangle(0, 0, src.Width, src.Height);
      using (var dst = CropResize(src, crop, targetW)) {
        var ep = new EncoderParameters(1);
        ep.Param[0] = new EncoderParameter(System.Drawing.Imaging.Encoder.Quality, quality);
        dst.Save(dstPath, Codec("image/jpeg"), ep);
        return dst.Width;
      }
    }
  }

  // Logo: transforma o fundo branco em transparência, recolore com um tom sólido.
  // Retorna "#RRGGBB|x,y,w,h|iconW" (roxo médio, caixa do conteúdo, largura do ícone).
  public static string Logo(string srcPath, string outPurple, string outWhite, string outIcon, string outFavicon, string outApple) {
    using (var src = new Bitmap(srcPath)) {
      int W = src.Width, H = src.Height;
      var rect = new Rectangle(0, 0, W, H);
      var sd = src.LockBits(rect, ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
      var px = new byte[sd.Stride * H]; Marshal.Copy(sd.Scan0, px, 0, px.Length); src.UnlockBits(sd);
      int stride = sd.Stride;

      // 1) cor média dos pixels "cheios" (bem roxos)
      long sr = 0, sg = 0, sb = 0, n = 0;
      int minX = W, minY = H, maxX = 0, maxY = 0;
      var alpha = new byte[W * H];
      for (int y = 0; y < H; y++) for (int x = 0; x < W; x++) {
        int i = y * stride + x * 4;
        int b = px[i], g = px[i + 1], r = px[i + 2];
        int mn = Math.Min(r, Math.Min(g, b));
        // alfa proporcional à distância do branco (usa o canal mais escuro)
        int a = (int)Math.Round((255 - mn) * 255.0 / (255 - 60));
        if (a < 18) a = 0; if (a > 255) a = 255;
        alpha[y * W + x] = (byte)a;
        if (a >= 250 && mn < 90) { sr += r; sg += g; sb += b; n++; }
        if (a > 60) { if (x < minX) minX = x; if (x > maxX) maxX = x; if (y < minY) minY = y; if (y > maxY) maxY = y; }
      }
      int R = (int)(sr / n), G = (int)(sg / n), B = (int)(sb / n);

      // 2) largura do ícone: primeira coluna vazia depois do ícone (gap antes do texto)
      int iconEnd = maxX;
      int run = 0;
      for (int x = minX + 50; x <= maxX; x++) {
        bool empty = true;
        for (int y = minY; y <= maxY; y++) if (alpha[y * W + x] > 60) { empty = false; break; }
        if (empty) { run++; if (run >= 12) { iconEnd = x - run; break; } } else run = 0;
      }

      int pad = 6;
      var box = Rectangle.FromLTRB(Math.Max(0, minX - pad), Math.Max(0, minY - pad), Math.Min(W, maxX + pad + 1), Math.Min(H, maxY + pad + 1));
      var iconBox = Rectangle.FromLTRB(box.Left, box.Top, Math.Min(W, iconEnd + pad + 1), box.Bottom);

      SaveTinted(alpha, W, box, R, G, B, outPurple, 900);
      SaveTinted(alpha, W, box, 255, 255, 255, outWhite, 900);
      SaveTinted(alpha, W, iconBox, R, G, B, outIcon, 512);
      SaveFavicon(alpha, W, iconBox, R, G, B, outFavicon, 64);
      SaveFavicon(alpha, W, iconBox, R, G, B, outApple, 180);
      return String.Format("#{0:X2}{1:X2}{2:X2}|{3},{4},{5},{6}|{7}", R, G, B, box.X, box.Y, box.Width, box.Height, iconBox.Width);
    }
  }

  static Bitmap Tinted(byte[] alpha, int W, Rectangle box, int R, int G, int B) {
    var bmp = new Bitmap(box.Width, box.Height, PixelFormat.Format32bppArgb);
    var d = bmp.LockBits(new Rectangle(0, 0, box.Width, box.Height), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
    var o = new byte[d.Stride * box.Height];
    for (int y = 0; y < box.Height; y++) for (int x = 0; x < box.Width; x++) {
      int i = y * d.Stride + x * 4;
      o[i] = (byte)B; o[i + 1] = (byte)G; o[i + 2] = (byte)R; o[i + 3] = alpha[(y + box.Y) * W + (x + box.X)];
    }
    Marshal.Copy(o, 0, d.Scan0, o.Length); bmp.UnlockBits(d);
    return bmp;
  }

  static void SaveTinted(byte[] alpha, int W, Rectangle box, int R, int G, int B, string path, int maxW) {
    using (var full = Tinted(alpha, W, box, R, G, B)) {
      int w = Math.Min(maxW, full.Width), h = (int)Math.Round(full.Height * (w / (double)full.Width));
      using (var dst = new Bitmap(w, h, PixelFormat.Format32bppArgb))
      using (var g = Graphics.FromImage(dst)) {
        g.InterpolationMode = InterpolationMode.HighQualityBicubic;
        g.PixelOffsetMode = PixelOffsetMode.HighQuality;
        g.DrawImage(full, 0, 0, w, h);
        dst.Save(path, ImageFormat.Png);
      }
    }
  }

  // Ícone roxo centralizado num quadrado branco arredondado.
  static void SaveFavicon(byte[] alpha, int W, Rectangle box, int R, int G, int B, string path, int size) {
    using (var icon = Tinted(alpha, W, box, R, G, B))
    using (var dst = new Bitmap(size, size, PixelFormat.Format32bppArgb))
    using (var g = Graphics.FromImage(dst)) {
      g.SmoothingMode = SmoothingMode.AntiAlias;
      g.InterpolationMode = InterpolationMode.HighQualityBicubic;
      g.PixelOffsetMode = PixelOffsetMode.HighQuality;
      float rad = size * 0.22f;
      using (var p = new GraphicsPath()) {
        p.AddArc(0, 0, rad * 2, rad * 2, 180, 90);
        p.AddArc(size - rad * 2 - 1, 0, rad * 2, rad * 2, 270, 90);
        p.AddArc(size - rad * 2 - 1, size - rad * 2 - 1, rad * 2, rad * 2, 0, 90);
        p.AddArc(0, size - rad * 2 - 1, rad * 2, rad * 2, 90, 90);
        p.CloseFigure();
        g.FillPath(Brushes.White, p);
      }
      float inner = size * 0.84f;
      float scale = Math.Min(inner / icon.Width, inner / icon.Height);
      float w = icon.Width * scale, h = icon.Height * scale;
      g.DrawImage(icon, (size - w) / 2, (size - h) / 2, w, h);
      dst.Save(path, ImageFormat.Png);
    }
  }
}
'@

$Src = (Resolve-Path $Src).Path
New-Item -ItemType Directory -Force $Out | Out-Null
$Out = (Resolve-Path $Out).Path
$Root = Split-Path $Out -Parent   # /public

# nome -> recorte opcional (x, y, largura, altura) em pixels do original
$fotos = [ordered]@{
  'pratica-real-pacientes'            = @(0, 12, 1146, 1430)  # remove a legenda e o canto arredondado da arte
  'equipe-direcao'                    = @(84, 348, 912, 1226) # só a foto dentro da moldura
  'equipe-turma-jaleco'               = $null
  'prof-raquel-pereverzieff'          = @(0, 0, 1088, 880)    # rosto/busto, sem o texto
  'laboratorio-asb'                   = $null
  'aluna-atendimento-closeup'         = $null
  'aula-pratica-maos'                 = $null
  'aula-pratica-cadeira-odontologica' = $null
  'aluno-pratica-clinica'             = $null
  'alunos-formados-certificado'       = @(0, 0, 1080, 970)    # remove a faixa de texto
}

foreach ($nome in $fotos.Keys) {
  $in = Join-Path $Src "$nome.jpg"
  if (-not (Test-Path $in)) { Write-Warning "Faltando: $in"; continue }
  $c = $fotos[$nome]
  if ($c) { $cx, $cy, $cw, $ch = $c } else {
    $img = [System.Drawing.Image]::FromFile($in); $cx = 0; $cy = 0; $cw = $img.Width; $ch = $img.Height; $img.Dispose()
  }
  foreach ($w in @(480, 960, 99999)) {
    $suffix = if ($w -eq 99999) { '' } else { "-$w" }
    if ($w -ne 99999 -and $w -ge $cw) { continue }
    $jpg = Join-Path $Out "$nome$suffix.jpg"
    $webp = Join-Path $Out "$nome$suffix.webp"
    $target = [Math]::Min($w, $cw)
    # JPG: baixa a qualidade até caber no limite
    foreach ($q in 82, 76, 70, 64, 58) {
      [void][Img]::Jpeg($in, $jpg, $cx, $cy, $cw, $ch, $target, $q)
      if ((Get-Item $jpg).Length -le $MaxKB * 1024) { break }
    }
    foreach ($q in 80, 72, 64, 56) {
      & $Cwebp -quiet -q $q -m 6 -sharp_yuv -metadata none -crop $cx $cy $cw $ch -resize $target 0 $in -o $webp
      if ((Get-Item $webp).Length -le $MaxKB * 1024) { break }
    }
    '{0,-44} {1,6:N0} KB   {2,-44} {3,6:N0} KB' -f (Split-Path $jpg -Leaf), ((Get-Item $jpg).Length / 1KB), (Split-Path $webp -Leaf), ((Get-Item $webp).Length / 1KB)
  }
}

# Logo
$logoIn = Join-Path $Src 'logo-instituto-dr-bach.jpg'
if (Test-Path $logoIn) {
  $res = [Img]::Logo($logoIn,
    (Join-Path $Out 'logo-instituto-dr-bach.png'),
    (Join-Path $Out 'logo-instituto-dr-bach-branco.png'),
    (Join-Path $Out 'logo-icone.png'),
    (Join-Path $Root 'favicon.png'),
    (Join-Path $Root 'apple-touch-icon.png'))
  Copy-Item (Join-Path $Out 'logo-instituto-dr-bach.png') (Join-Path $Root 'logo.png') -Force
  foreach ($f in 'logo-instituto-dr-bach', 'logo-instituto-dr-bach-branco') {
    & $Cwebp -quiet -q 90 -alpha_q 100 -exact (Join-Path $Out "$f.png") -o (Join-Path $Out "$f.webp")
  }
  "Logo processada. Roxo | caixa | largura do icone: $res"
}
