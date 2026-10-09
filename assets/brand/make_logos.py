"""Benitoite のロゴを SVG（文字は輪郭に変換）と PNG に書き出す。"""
import os
import sys

import resvg_py
from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

OUT = sys.argv[1]
os.makedirs(os.path.join(OUT, "svg"), exist_ok=True)
os.makedirs(os.path.join(OUT, "png"), exist_ok=True)

font = instantiateVariableFont(TTFont("Sora.ttf"), {"wght": 600})
gs = font.getGlyphSet()
cmap = font.getBestCmap()
UPM = font["head"].unitsPerEm
hmtx = font["hmtx"]


def glyph_bounds(ch):
    bp = BoundsPen(gs)
    gs[cmap[ord(ch)]].draw(bp)
    return bp.bounds  # xMin, yMin, xMax, yMax（フォントの単位、y は上向き）


def text_paths(text, size, x, baseline, tracking=-0.01):
    """文字列を輪郭のパスにする。各文字の (x, 送り幅) も返す。"""
    s = size / UPM
    ds, spans = [], []
    for ch in text:
        name = cmap[ord(ch)]
        pen = SVGPathPen(gs)
        gs[name].draw(TransformPen(pen, (s, 0, 0, -s, x, baseline)))
        ds.append(pen.getCommands())
        adv = hmtx[name][0] * s
        spans.append((x, adv))
        x += adv + tracking * size
    return " ".join(ds), spans, x - tracking * size


GEM = """<g transform="translate({x} {y}) scale({s})">
<polygon points="0,-1 -0.867,0.5 -0.347,0.2 0,-0.4" fill="{c1}"/>
<polygon points="0,-1 0,-0.4 0.347,0.2 0.867,0.5" fill="{c2}"/>
<polygon points="-0.867,0.5 0.867,0.5 0.347,0.2 -0.347,0.2" fill="{c3}"/>
<polygon points="0,-0.4 -0.347,0.2 0.347,0.2" fill="{c4}"/>{extra}
</g>"""
LIGHT = dict(c1="#2F6BFF", c2="#163FB8", c3="#0B2A85", c4="#8DB5FF",
             extra='\n<polygon points="0,-0.4 -0.16,-0.12 0.05,-0.18" fill="#FFFFFF" opacity="0.7"/>')
DARK = dict(c1="#5FA0FF", c2="#2F6BFF", c3="#1F4FD1", c4="#CFE6FF", extra="")


def gem_a(x, y, s):
    return GEM.format(x=x, y=y, s=s, **LIGHT)


def gem_d(cx, cy, k):
    """D の結晶と光の輪。k は元の 200 の枠に対する倍率。"""
    return f"""<defs><radialGradient id="glow" cx="{cx}" cy="{cy}" r="{92*k}" gradientUnits="userSpaceOnUse">
<stop offset="0" stop-color="#4FC3FF" stop-opacity="0.6"/>
<stop offset="1" stop-color="#4FC3FF" stop-opacity="0"/></radialGradient></defs>
<circle cx="{cx}" cy="{cy}" r="{92*k}" fill="url(#glow)"/>
<circle cx="{cx}" cy="{cy}" r="{72*k}" fill="none" stroke="#4FC3FF" stroke-opacity="0.35" stroke-width="{1.5*k}"/>
<circle cx="{cx}" cy="{cy}" r="{88*k}" fill="none" stroke="#4FC3FF" stroke-opacity="0.18" stroke-width="{1.5*k}"/>
""" + GEM.format(x=cx, y=cy + 4 * k, s=58 * k, **DARK)


def svg(w, h, body, title):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w:.1f} {h:.1f}" '
            f'width="{w:.1f}" height="{h:.1f}">\n<title>{title}</title>\n{body}\n</svg>\n')


files = {}

# --- 結晶のアイコン ---
# A: 透明の地。結晶の外接の枠（幅 1.734、高さ 1.5）を 512 の正方形の中央に置く。
s = 512 * 0.86 / 1.734
cy = 256 + (1 - 0.5) / 2 * s  # 上下の中央に置くための重心のずらし
files["benitoite-icon-light"] = svg(512, 512, gem_a(256, round(cy, 1), round(s, 1)), "Benitoite")
# D: 暗い地の角丸の正方形と、透明の地の二通り。
k = 512 / 200
files["benitoite-icon-dark"] = svg(512, 512,
    f'<rect width="512" height="512" rx="{36*k:.1f}" fill="#0A1033"/>\n' + gem_d(256, 256, k), "Benitoite")
files["benitoite-icon-dark-transparent"] = svg(512, 512, gem_d(256, 256, k), "Benitoite")

# --- ロゴ（結晶と文字の組） ---
SIZE = 96


def lockup(name, gem_svg, gem_w, text_color, h=200):
    cap = glyph_bounds("B")[3] / UPM * SIZE
    baseline = h / 2 + cap / 2
    d, _, end = text_paths("Benitoite", SIZE, gem_w + 36, baseline)
    files[name] = svg(end + 8, h, gem_svg + f'\n<path d="{d}" fill="{text_color}"/>', "Benitoite")


lockup("benitoite-logo-light", gem_a(100, 122, 88), 182, "#0E1631")
lockup("benitoite-logo-dark", gem_d(100, 100, 1.0), 196, "#DDEBFF")

# --- ワードマーク E ---
def wordmark(name, text_color, tri, tri_in):
    size, pad = 160, 16
    stem_top = glyph_bounds("ı")[3] / UPM * size
    asc = max(glyph_bounds(c)[3] for c in "bt") / UPM * size
    tw, gap = 0.27 * size, 0.07 * size
    th = tw * 0.866
    baseline = pad + max(asc, stem_top + gap + th)
    d, spans, end = text_paths("benıtoıte", size, pad, baseline, tracking=-0.02)
    tris = []
    gb = glyph_bounds("ı")
    for idx in (3, 6):
        x0, _ = spans[idx]
        cx = x0 + (gb[0] + gb[2]) / 2 / UPM * size
        bot = baseline - stem_top - gap
        top = bot - th
        tris.append(f'<polygon points="{cx:.1f},{top:.1f} {cx-tw/2:.1f},{bot:.1f} {cx+tw/2:.1f},{bot:.1f}" fill="{tri}"/>')
        tris.append(f'<polygon points="{cx:.1f},{top+th*0.4:.1f} {cx-tw*0.2:.1f},{bot-th*0.2:.1f} {cx+tw*0.2:.1f},{bot-th*0.2:.1f}" fill="{tri_in}"/>')
    desc = -min(glyph_bounds(c)[1] for c in "benıtoıte") / UPM * size
    h = baseline + desc + pad
    files[name] = svg(end + pad, h, f'<path d="{d}" fill="{text_color}"/>\n' + "\n".join(tris), "benitoite")


wordmark("benitoite-wordmark-light", "#0E1631", "#1F4FD1", "#8DB5FF")
wordmark("benitoite-wordmark-dark", "#DDEBFF", "#4F86FF", "#CFE6FF")

# --- 書き出し ---
def png(name, src, width):
    data = resvg_py.svg_to_bytes(svg_string=src, width=width)
    with open(os.path.join(OUT, "png", name), "wb") as f:
        f.write(bytes(data))


for name, src in files.items():
    with open(os.path.join(OUT, "svg", name + ".svg"), "w") as f:
        f.write(src)
    if "icon" in name:
        for px in (16, 32, 64, 128, 256, 512, 1024):
            png(f"{name}-{px}.png", src, px)
    else:
        for px in (800, 1600):
            png(f"{name}-{px}w.png", src, px)
print("\n".join(sorted(os.listdir(os.path.join(OUT, "svg")))))
