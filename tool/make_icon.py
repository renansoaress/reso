"""Desenha o icone do ReSo e gera todas as variantes que o projeto usa.

    python tool/make_icon.py        (precisa do Pillow: pip install pillow)

O desenho e o logo do app em grade 2x2 -- "Re" em cima, "So" embaixo --,
cada letra na mesma fonte e cor do wordmark da tela (lib/brand.dart), sobre
uma placa grafite de cantos arredondados. Mudou aqui, muda la.

Gera:
  web/favicon.png, web/icons/*            PWA (any, maskable e Apple)
  assets/icon/app_icon.png                o icone em alta, para quem precisar
  windows/runner/resources/app_icon.ico   executavel, atalho e instalador
  installer/linux/reso-<tamanho>.png      .deb e install.sh
  android/.../mipmap-*/ic_launcher.png    launcher legado
  ios/.../AppIcon.appiconset/*.png        opacos, como a App Store exige

Tudo e desenhado 4x maior e reduzido depois: em 16 px, desenhar direto
serrilha a curva das letras.
"""

import io
import struct
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
FONTS = ROOT / "assets" / "fonts"

# As cores do logo sobre fundo escuro (as mesmas de lib/brand.dart).
LETTERS = [
    ("R", "Logo-R.ttf", (0x4D, 0x94, 0xFF)),  # azul
    ("e", "Logo-e.ttf", (0x34, 0xD3, 0x7F)),  # verde
    ("S", "Logo-S.ttf", (0xFF, 0x5C, 0x67)),  # vermelho
    ("o", "Logo-o.ttf", (0xB4, 0x74, 0xFF)),  # roxo
]
TOP = (0x23, 0x28, 0x36)
BOTTOM = (0x0D, 0x0F, 0x15)
EDGE = (255, 255, 255, 30)

SS = 4  # supersampling


def gradient(n):
    """Fundo vertical do topo (mais claro) para a base."""
    col = Image.new("RGB", (1, n))
    for y in range(n):
        t = y / max(n - 1, 1)
        col.putpixel((0, y), tuple(round(a + (b - a) * t) for a, b in zip(TOP, BOTTOM)))
    return col.resize((n, n))


def glyphs(n, scale):
    """As quatro letras, centradas como bloco; `scale` e a fracao do lado
    que o bloco ocupa na altura."""
    size = round(n * scale * 0.62)
    fonts = [ImageFont.truetype(str(FONTS / f), size) for _, f, _ in LETTERS]
    # Caixas com ancora na linha de base, para "R" e "e" (e "S" e "o")
    # dividirem a mesma linha como no texto.
    boxes = [ft.getbbox(ch, anchor="ls") for (ch, _, _), ft in zip(LETTERS, fonts)]
    gap = size * 0.06
    row_w = [boxes[0][2] - boxes[0][0] + gap + boxes[1][2] - boxes[1][0],
             boxes[2][2] - boxes[2][0] + gap + boxes[3][2] - boxes[3][0]]
    cap = max(-boxes[0][1], -boxes[2][1])  # altura das maiusculas
    line = cap * 1.18
    block_h = cap + line
    block_w = max(row_w)
    x0 = (n - block_w) / 2
    base1 = (n - block_h) / 2 + cap
    base2 = base1 + line
    # "So" alinhado pela direita com "Re": o bloco fica um quadrado justo.
    placed = []
    for i, ((ch, _, color), ft, box) in enumerate(zip(LETTERS, fonts, boxes)):
        row = i // 2
        base = base1 if row == 0 else base2
        left = x0 + (block_w - row_w[row]) / 2
        if i % 2 == 1:
            prev = boxes[i - 1]
            left += prev[2] - prev[0] + gap
        placed.append((ch, ft, color, (left - box[0], base)))
    return placed


def draw_art(n, *, rounded, scale):
    """Desenha em n x n. `rounded`: placa com cantos e margem transparente;
    sem ela, fundo cheio (maskable, Apple, iOS)."""
    img = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    bg = gradient(n).convert("RGBA")
    mask = Image.new("L", (n, n), 0)
    md = ImageDraw.Draw(mask)
    if rounded:
        inset = n * 0.06
        radius = n * 0.235
        md.rounded_rectangle((inset, inset, n - inset, n - inset), radius, fill=255)
    else:
        md.rectangle((0, 0, n, n), fill=255)
    img.paste(bg, (0, 0), mask)

    if rounded:
        # Filete claro na borda: separa a placa de fundos escuros.
        edge = Image.new("RGBA", (n, n), (0, 0, 0, 0))
        ImageDraw.Draw(edge).rounded_rectangle(
            (inset, inset, n - inset, n - inset), radius,
            outline=EDGE, width=max(1, round(n * 0.008)))
        img = Image.alpha_composite(img, edge)

    placed = glyphs(n, scale)

    # Brilho difuso de cada letra, bem leve: da profundidade sem neon.
    glow = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for ch, ft, color, (x, y) in placed:
        gd.text((x, y), ch, font=ft, fill=color + (90,), anchor="ls")
    glow = glow.filter(ImageFilter.GaussianBlur(n * 0.035))
    glow_mask = Image.new("L", (n, n), 0)
    glow_mask.paste(mask, (0, 0))
    clipped = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    clipped.paste(glow, (0, 0), glow_mask)
    img = Image.alpha_composite(img, clipped)

    d = ImageDraw.Draw(img)
    for ch, ft, color, (x, y) in placed:
        d.text((x, y), ch, font=ft, fill=color + (255,), anchor="ls")
    return img


def render(size, *, rounded=True, scale=None, opaque=False):
    if scale is None:
        scale = 0.58 if rounded else 0.50
    big = draw_art(size * SS, rounded=rounded, scale=scale)
    out = big.resize((size, size), Image.LANCZOS)
    if opaque:
        out = out.convert("RGB")
    return out


def save(img, path):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, optimize=True)


def save_ico(path, sizes):
    blobs = []
    for s in sizes:
        buf = io.BytesIO()
        render(s).save(buf, "PNG", optimize=True)
        blobs.append(buf.getvalue())
    header = struct.pack("<HHH", 0, 1, len(sizes))
    offset = 6 + 16 * len(sizes)
    entries = b""
    for s, blob in zip(sizes, blobs):
        side = 0 if s >= 256 else s
        entries += struct.pack("<BBBBHHII", side, side, 0, 0, 1, 32, len(blob), offset)
        offset += len(blob)
    Path(path).write_bytes(header + entries + b"".join(blobs))


def main():
    web = ROOT / "web"
    save(render(32), web / "favicon.png")
    save(render(192), web / "icons" / "Icon-192.png")
    save(render(512), web / "icons" / "Icon-512.png")
    # Maskable: o Android recorta em circulo/gota; o desenho fica na zona
    # segura (os 80% centrais).
    save(render(192, rounded=False, scale=0.46), web / "icons" / "Icon-maskable-192.png")
    save(render(512, rounded=False, scale=0.46), web / "icons" / "Icon-maskable-512.png")
    # O iOS arredonda sozinho e poe fundo preto onde houver transparencia.
    save(render(180, rounded=False, scale=0.56, opaque=True), web / "icons" / "apple-touch-icon.png")

    save(render(1024), ROOT / "assets" / "icon" / "app_icon.png")
    save_ico(ROOT / "windows" / "runner" / "resources" / "app_icon.ico",
             [16, 20, 24, 32, 40, 48, 64, 128, 256])

    for s in (256, 128, 64, 48, 32):
        save(render(s), ROOT / "installer" / "linux" / f"reso-{s}.png")

    android = ROOT / "android" / "app" / "src" / "main" / "res"
    for folder, s in (("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)):
        target = android / f"mipmap-{folder}" / "ic_launcher.png"
        if target.parent.exists():
            save(render(s), target)

    # iOS: regrava cada PNG do AppIcon no tamanho que ele ja tem.
    ios = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    for png in sorted(ios.glob("*.png")):
        with Image.open(png) as old:
            s = old.size[0]
        save(render(s, rounded=False, scale=0.56, opaque=True), png)

    print("pronto: icones da web, Windows, Linux, Android e iOS")


if __name__ == "__main__":
    main()
