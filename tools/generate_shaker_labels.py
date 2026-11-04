"""Original printed shaker labels; text converted to SVG paths for Godot import."""
from pathlib import Path
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen

ROOT = Path(__file__).resolve().parents[1]
FONT = TTFont(ROOT / 'assets/fonts/Fredoka-Medium.ttf')
GLYPHS = FONT.getGlyphSet()
CMAP = FONT.getBestCmap()
UPM = FONT['head'].unitsPerEm

def lettering(text, y, size, color, spacing=0):
    scale = size / UPM
    widths = [GLYPHS[CMAP[ord(c)]].width * scale for c in text]
    x = (512 - sum(widths) - max(0, len(text)-1)*spacing) / 2
    parts = []
    for c, width in zip(text, widths):
        pen = SVGPathPen(GLYPHS)
        GLYPHS[CMAP[ord(c)]].draw(pen)
        parts.append(f'<path fill="{color}" transform="translate({x:.3f} {y}) scale({scale:.6f} {-scale:.6f})" d="{pen.getCommands()}"/>')
        x += width + spacing
    return ''.join(parts)

def label(flavor):
    cinnamon = flavor == 'cinnamon'
    ink = '#773b29' if cinnamon else '#164a4c'
    accent = '#b56d3e' if cinnamon else '#668e88'
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="512" height="576" viewBox="0 0 512 576">',
        '<rect width="512" height="576" rx="26" fill="#f3e5c5"/>',
        f'<rect x="14" y="14" width="484" height="548" rx="20" fill="none" stroke="{ink}" stroke-width="5"/>',
        f'<rect x="26" y="26" width="460" height="524" rx="14" fill="none" stroke="{accent}" stroke-width="1.5"/>',
        f'<path d="M48 133H180M332 133H464" stroke="{accent}" stroke-width="2"/>',
        f'<circle cx="256" cy="110" r="36" fill="{ink}"/><circle cx="256" cy="110" r="26" fill="none" stroke="#f3e5c5" stroke-width="3"/><circle cx="256" cy="110" r="4" fill="#f3e5c5"/>']
    parts += [lettering('GOLDEN HOUR', 190, 38, ink, 1.5),
              lettering('HOT MINI DONUTS', 222, 19, ink, 2.2),
              f'<path d="M54 247H458" stroke="{accent}" stroke-width="2"/>',
              lettering('CINNAMON' if cinnamon else 'POWDERED', 326, 60, ink),
              lettering('SUGAR', 397, 79, ink, 3),
              f'<path d="M90 429H422" stroke="{accent}" stroke-width="2"/>',
              lettering('WARM & SWEET' if cinnamon else 'LIGHT & SWEET', 466, 23, ink, 1.2),
              lettering('FINISH WITH A LITTLE JOY', 518, 17, ink, 1.1), '</svg>']
    return ''.join(parts)

out = ROOT / 'assets/art'
for flavor in ['cinnamon', 'powdered']:
    (out / f'shaker_{flavor}.svg').write_text(label(flavor), encoding='utf-8')
    print(out / f'shaker_{flavor}.svg')
