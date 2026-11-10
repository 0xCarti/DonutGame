"""Generate the original Golden Hour Circuit polish artwork, without dependencies.

All pieces are authored SVG geometry. Decorative pictures have a 2x intrinsic
resolution; tintable interface emblems have a 3x intrinsic resolution. The
existing illustration collection is deliberately not touched.
"""
from pathlib import Path
import math
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "ui"
NAVY, TEAL, GOLD, CREAM, RUST = "#102e3c", "#1e5d60", "#f2bc5b", "#fff6d8", "#d7774b"


def path(d, fill="none", stroke=None, width=2, **attrs):
    if stroke:
        attrs.update(stroke=stroke, stroke_width=width,
                     stroke_linecap="round", stroke_linejoin="round")
    a = " ".join(f'{key.replace("_", "-")}="{value}"' for key, value in attrs.items())
    return f'<path d="{d}" fill="{fill}" {a}/>'


def circle(x, y, r, fill, **attrs):
    a = " ".join(f'{key.replace("_", "-")}="{value}"' for key, value in attrs.items())
    return f'<circle cx="{x}" cy="{y}" r="{r}" fill="{fill}" {a}/>'


def ellipse(x, y, rx, ry, fill, **attrs):
    a = " ".join(f'{key.replace("_", "-")}="{value}"' for key, value in attrs.items())
    return f'<ellipse cx="{x}" cy="{y}" rx="{rx}" ry="{ry}" fill="{fill}" {a}/>'


def rect(x, y, w, h, fill, rx=0, **attrs):
    a = " ".join(f'{key.replace("_", "-")}="{value}"' for key, value in attrs.items())
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}" {a}/>'


def group(body, x=0, y=0, scale=1, angle=0):
    return f'<g transform="translate({x} {y}) scale({scale}) rotate({angle})">{body}</g>'


def save(folder, name, w, h, body, defs=""):
    target = OUT / folder / f"{name}.svg"
    target.parent.mkdir(parents=True, exist_ok=True)
    scale = 3 if folder == "icons" else 2
    data = f'<svg xmlns="http://www.w3.org/2000/svg" width="{w*scale}" height="{h*scale}" viewBox="0 0 {w} {h}"><defs>{defs}</defs>{body}</svg>\n'
    ET.fromstring(data)
    target.write_text(data, encoding="utf-8")


def linear(name, colors, diagonal=False):
    coords = 'x1="0" y1="0" x2="1" y2="1"' if diagonal else 'x1="0" y1="0" x2="0" y2="1"'
    stops = "".join(f'<stop offset="{i/(len(colors)-1):.3f}" stop-color="{color}"/>' for i, color in enumerate(colors))
    return f'<linearGradient id="{name}" {coords}>{stops}</linearGradient>'


def star(x, y, radius, color, points=4, angle=0, opacity=1):
    xy = []
    for i in range(points*2):
        a = math.radians(angle-90 + i*180/points)
        r = radius if i % 2 == 0 else radius*.34
        xy.append(f'{x+math.cos(a)*r:.2f},{y+math.sin(a)*r:.2f}')
    return path("M"+"L".join(xy)+"Z", color, opacity=opacity)


def glow(x, y, r=4):
    return circle(x, y, r*4.3, GOLD, opacity=".035") + circle(x, y, r*2.6, GOLD, opacity=".07") + circle(x, y, r*1.6, GOLD, opacity=".14") + circle(x, y, r, "#ffe2a2") + circle(x-.6, y-.8, r*.45, "#fff9e7")


def donut(x, y, scale=1, angle=0):
    # Tiny aperture and softly irregular edge give a mini-donut silhouette.
    d = ellipse(0, 9, 39, 32, "#4e2619", opacity=".24")
    d += path("M-39 1C-42-20-24-38-3-39C20-42 40-25 40-3C43 21 24 39 2 39C-21 41-40 25-39 1Z", "url(#dough)")
    d += path("M-35-5C-33-27-14-36 2-36C21-36 34-23 36-8C24-23 12-27-4-26C-18-26-28-18-35-5Z", "#ffe6a7", opacity=".65")
    d += path("M-36 14C-24 35 1 39 21 27C30 22 35 14 38 6C37 29 17 41-2 38C-18 40-32 30-36 14Z", "#a85329", opacity=".45")
    d += ellipse(1, 1, 5, 6, "#9b4f2c") + ellipse(1, 2, 3.1, 3.7, "#472c23")
    d += path("M-5-1Q-4-8 3-6", stroke="#ffdfa0", width=2.8)
    for xx, yy, rr in [(-25,-7,1.3),(-13,-22,1),(13,-25,1.5),(26,-7,1),(-25,15,1.4),(-9,26,1),(21,20,1.2),(7,17,1),(-14,8,1.2),(18,3,1.1),(-8,-11,.8),(5,-21,.8)]:
        d += circle(xx, yy, rr, "#fff2c1", opacity=".85")
    return group(d, x, y, scale, angle)


DOUGH_DEF = linear("dough", ["#fbc978", "#e9a04c", "#c57537", "#de9a50"], True)


def marquee():
    defs = linear("night", ["#234e58", NAVY, "#09242f"]) + linear("rail", ["#ffe7a0", "#b97b39", "#f5cb77"])
    b = rect(0, 0, 640, 160, "url(#night)", 24)
    b += path("M0 128Q320 68 640 128V160H0Z", TEAL, opacity=".18")
    b += path("M-20 38Q160 103 320 25Q480 103 660 38", stroke="#071c27", width=3)
    b += path("M-20 36Q160 101 320 23Q480 101 660 36", stroke="#557779", width=1)
    # Lights frame a quiet middle area intended for interface text.
    for i in range(15):
        x = i*640/14
        half_t = x/320 if x <= 320 else (x-320)/320
        y = (36*(1-half_t)**2 + 2*101*(1-half_t)*half_t + 23*half_t**2) if x <=320 else (23*(1-half_t)**2 + 2*101*(1-half_t)*half_t +36*half_t**2)
        b += path(f"M{x:.1f} {y:.1f}v5", stroke="#a69367", width=2) + glow(x, y+8, 3.8)
    for x, y, r in [(31,107,3),(65,132,2),(570,128,2),(611,104,3),(141,22,2),(496,19,2)]:
        b += star(x,y,r,CREAM,opacity=.55)
    b += path("M22 148H618", stroke="url(#rail)", width=2)
    b += circle(16,148,2,GOLD) + circle(624,148,2,GOLD)
    save("decor", "marquee", 640, 160, b, defs)


def ticket():
    defs = linear("paper", ["#fffaf0", "#f9edcf", "#e8d3aa"]) + linear("tab", ["#f3bc66", "#e99e48"])
    # The concave ticket notches are real alpha, not painted circles.
    outline = "M20 4H620Q636 4 636 20V86C608 86 608 126 636 126V196Q636 212 620 212H20Q4 212 4 196V126C32 126 32 86 4 86V20Q4 4 20 4Z"
    b = group(path(outline, "#1f2732", opacity=".16"), 0, 7)
    b += path(outline, "url(#paper)")
    b += path("M28 14H612M26 201H614", stroke="#fff9e9", width=2)
    b += path("M45 23H595M45 193H595", stroke="#bda476", width=1, stroke_dasharray="3 6", opacity=".65")
    b += path("M545 35V181", stroke="#ba9a65", width=1.4, stroke_dasharray="4 6", opacity=".55")
    b += path("M18 49V78M18 139V168M622 49V78M622 139V168", stroke="#d1b47c", width=2)
    for x in [48, 592]:
        b += star(x,42,6,"#c39d5e",points=4,opacity=.6) + star(x,174,6,"#c39d5e",points=4,opacity=.6)
    b += circle(574,108,21,"none", stroke="#d0b681",stroke_width="1.4") + circle(574,108,17,"none",stroke="#d0b681",stroke_width=".8")
    b += star(574,108,11,"#c59b57",points=5,opacity=.75)
    save("decor", "ticket", 640, 220, b, defs)


def light_strand():
    # Transparent strip fits a shallow header without hiding title text.
    b = path("M-15 3Q80 39 160 9Q240 39 320 7Q400 39 480 9Q560 39 655 3", stroke="#0a2430", width=2.8)
    b += path("M-15 2Q80 38 160 8Q240 38 320 6Q400 38 480 8Q560 38 655 2", stroke="#73938d", width=.8)
    for i in range(25):
        x = i*640/24
        segment = min(3,int(x/160))
        t = (x-segment*160)/160
        endpoints = [(6,8),(8,6),(6,8),(8,6)][segment]
        y = endpoints[0]*(1-t)**2 + 2*38*(1-t)*t + endpoints[1]*t*t
        b += path(f"M{x:.2f} {y:.2f}v4",stroke="#b0a16f",width=1.5)
        b += glow(x,y+7,3.0)
    save("decor","light_strand",640,48,b)


def medal(name, tier, colors):
    defs = linear("metal", colors) + linear("edge", ["#fff2bf", colors[1], colors[-1]]) + DOUGH_DEF
    b = ellipse(96,169,59,10,"#132b35", opacity=".13")
    b += path("M58 107L39 174L68 161L84 181L97 123Z", "#b34c3e")
    b += path("M134 107L153 174L124 161L108 181L95 123Z", "#d76d49")
    b += path("M62 117L49 160L66 150L77 165L88 125Z", "#ed9a67", opacity=".5")
    b += path("M130 117L143 160L126 150L115 165L104 125Z", "#ffbc7e", opacity=".5")
    b += circle(96,91,67,"#132b35",opacity=".15")
    xy=[]
    for i in range(40):
        a=math.radians(i*9)
        r=66 if i%2==0 else 61
        xy.append(f"{96+math.cos(a)*r:.2f},{85+math.sin(a)*r:.2f}")
    b += path("M"+"L".join(xy)+"Z", "url(#edge)")
    b += circle(96,85,56,"url(#metal)",stroke="#fff4c7",stroke_width="1.5")
    b += circle(96,85,47,"none",stroke=colors[-1],stroke_width="1.5")
    b += circle(96,85,43,"#fff4ca",opacity=".2")
    b += donut(96,88,.78,-9)
    if tier==3:
        b += path("M77 41L72 24L88 32L96 17L104 32L120 24L115 41Z", "#ffe7a3", stroke="#b57c33",width=1.3)
        b += circle(96,18,2.7,CREAM) + circle(72,24,2,CREAM) + circle(120,24,2,CREAM)
        sparks=[(24,42,10),(160,63,12),(153,21,6),(28,119,6)]
    elif tier==2:
        b += star(96,36,10,CREAM,5)
        sparks=[(29,54,8),(161,87,7),(148,26,4)]
    else:
        sparks=[(35,52,5),(156,104,5)]
    for x,y,r in sparks:
        b += star(x,y,r,GOLD) + star(x,y,r*.5,CREAM)
    for x,y in [(67,37),(128,43),(145,94),(49,97)]:
        b += circle(x,y,1.8,CREAM,opacity=".85")
    save("decor",name,192,192,b,defs)


def burst():
    defs = linear("night", ["#1e4855", "#102a36"]) + DOUGH_DEF
    b = rect(0,0,640,240,"url(#night)",22)
    for i in range(16):
        a=2*math.pi*i/16
        points=[]
        for r,offset in [(37,-.12),(400,-.04),(400,.04),(37,.12)]:
            points.append(f"{320+math.cos(a+offset)*r:.2f},{115+math.sin(a+offset)*r:.2f}")
        b += path("M"+"L".join(points)+"Z", GOLD,opacity=".055")
    b += ellipse(320,187,120,23,"#051e29",opacity=".35")
    b += circle(320,112,96,GOLD,opacity=".025") + circle(320,112,79,GOLD,opacity=".04")
    b += donut(257,132,1.08,-23) + donut(388,135,.96,22) + donut(323,101,1.43,-8)
    for i, (x,y,a) in enumerate([(70,62,25),(126,182,-17),(196,48,50),(228,205,17),(427,41,-34),(473,184,36),(542,74,13),(570,181,-26),(133,113,56),(497,109,-17)]):
        b += group(rect(-3,-7,6,14,[RUST,GOLD,"#77b5a4",CREAM][i%4],1.7),x,y,1,a)
    for x,y,r in [(97,140,11),(171,70,6),(466,64,10),(543,151,8),(355,27,6),(300,209,5)]:
        b += star(x,y,r,GOLD) + star(x,y,r*.48,CREAM)
    # Clip rays at the rounded frame; the SVG root still bounds the picture.
    b += path("M18 225H622", stroke=GOLD,width=1,opacity=".3")
    save("decor","donut_burst",640,240,b,defs)


def icons():
    shapes = {
        "proficiency": '<path d="M7 25h18M10 25v-6h4v6m4 0V14h4v11M5 15l7-7 6 3 9-8m-7 0h7v7"/>',
        "punctuality": '<circle cx="15" cy="17" r="11"/><path d="M15 10v7l5 3M12 2h6m-3 0v4m8 0 3 3M5 6 2 9"/>',
        "hospitality": '<path d="M4 24h24M7 21a9 9 0 0 1 18 0M16 12V9m-2 0h4M5 28h22M9 5l1-2m12 2-1-2"/><path d="M13 17q3-3 6 0"/>',
        "mood": '<circle cx="16" cy="16" r="12"/><path d="M10 20q6 7 12 0M10 11v2m12-2v2"/>',
        "bond": '<path d="M16 27 5 17a7 7 0 0 1 11-9 7 7 0 0 1 11 9L16 27Z"/><path d="m10 16 4 4 8-9"/>',
        "buff": '<path d="M16 28V5M7 14l9-9 9 9M5 24h7m-3-4v8m14-9h5m-2.5-2.5v5"/>',
        "debuff": '<path d="M16 4v23M7 18l9 9 9-9M4 9h7m12-2h5"/>',
        "timer": '<path d="M8 3h16M8 29h16M10 3v6q0 4 6 7-6 3-6 7v6m12-26v6q0 4-6 7 6 3 6 7v6M12 8h8m-8 17h8"/>',
        "permanent": '<path d="M16 7c-5-9-14-3-12 5 2 9 11 5 12-1 1-6 10-10 12-1 2 8-7 14-12 5"/><path d="m12 25 3 3 6-7"/>',
        "dice": '<rect x="5" y="5" width="22" height="22" rx="5"/><circle cx="11" cy="11" r="1"/><circle cx="21" cy="11" r="1"/><circle cx="16" cy="16" r="1"/><circle cx="11" cy="21" r="1"/><circle cx="21" cy="21" r="1"/>',
        "counter": '<path d="M3 17h26v11H3V17Zm3 0V6h13v11M9 9h7m-7 4h7m5 6h9M8 21h8v4H8v-4Zm14-8h4l2 4"/>',
        "fryer_role": '<path d="M4 18h24v10H4V18Zm3 0 2-9h14l2 9M16 9V3m-4 0h8M8 22h16M7 4l-2 3m20-3 2 3"/>',
        "mechanic": '<path d="M27 4a8 8 0 0 1-10 10L7 27a3 3 0 0 1-4-4l13-10A8 8 0 0 1 25 3l-6 6 4 3 4-8Z"/>',
        "runner": '<circle cx="20" cy="5" r="3"/><path d="m10 11 6-2 6 6 5 1M17 10l-4 8 7 4-2 7m-6-11-5 8H3m8-12-4 1M2 8h5m-6 6h4"/>',
        "creative": '<path d="M14 20 25 3l4 4-16 13-5 2 1-5Zm-4 1c-7-2-8 2-7 7 7 1 10-2 7-7ZM21 9l3 3M3 5h6M6 2v6"/>',
        "driver": '<circle cx="16" cy="16" r="12"/><circle cx="16" cy="16" r="4"/><path d="m4 14 8 1m8 0 8-1M16 20v8M7 10q9-8 18 0"/>',
    }
    for name, shape in shapes.items():
        save("icons",name,32,32, f'<g fill="none" stroke="#ffffff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">{shape}</g>')


def main():
    marquee()
    light_strand()
    ticket()
    medal("reward_perfect",3,["#fff3b8","#efbd56","#b77a30"])
    medal("reward_great",2,["#e8ffff","#9fc5c8","#477b83"])
    medal("reward_good",1,["#ffd9ac","#dca273","#a46843"])
    burst()
    icons()
    print("Generated 7 decorative pictures and 16 tintable emblems.")


if __name__ == "__main__":
    main()
