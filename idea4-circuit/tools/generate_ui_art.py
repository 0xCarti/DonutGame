"""Rebuild the original Golden Hour illustrated UI assets. Python standard library only."""
from pathlib import Path
import math
import random
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "ui"
INK, CREAM, GOLD, RUST, TEAL = "#173c3f", "#fff5dc", "#e9b65d", "#c65f43", "#477b72"


def tag(name, **a):
    return "<" + name + " " + " ".join(f'{k.replace("_", "-")}="{v}"' for k, v in a.items()) + "/>"


def rect(x, y, w, h, fill, rx=0, **kw):
    return tag("rect", x=x, y=y, width=w, height=h, fill=fill, rx=rx, **kw)


def circ(x, y, r, fill, **kw):
    return tag("circle", cx=x, cy=y, r=r, fill=fill, **kw)


def ellipse(x, y, rx, ry, fill, **kw):
    return tag("ellipse", cx=x, cy=y, rx=rx, ry=ry, fill=fill, **kw)


def path(d, fill="none", stroke=None, sw=2, **kw):
    if stroke:
        kw.update(stroke=stroke, stroke_width=sw, stroke_linecap="round", stroke_linejoin="round")
    return tag("path", d=d, fill=fill, **kw)


def group(body, x=0, y=0, s=1, rot=0):
    return f'<g transform="translate({x} {y}) scale({s}) rotate({rot})">{body}</g>'


def svg(w, h, body, defs="", intrinsic_scale=1):
    # Keep layout coordinates stable while Godot imports a higher-resolution
    # raster texture for sharp icons and illustrations on high-density phones.
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w * intrinsic_scale}" height="{h * intrinsic_scale}" viewBox="0 0 {w} {h}"><defs>{defs}</defs>{body}</svg>\n'


def save(folder, name, w, h, body, defs=""):
    dest = OUT / folder / (name + ".svg")
    dest.parent.mkdir(parents=True, exist_ok=True)
    data = svg(w, h, body, defs, intrinsic_scale=3 if folder == "icons" else 2)
    ET.fromstring(data)
    dest.write_text(data, encoding="utf-8")


def cloud(x, y, s=1, color=CREAM):
    return group(path("M0 18 Q-6 3 10 3 Q17-17 32-3 Q50-10 53 8 Q68 8 65 20 H0Z", color), x, y, s)


def tree(x, y, s=1, fruit=False):
    b = path("M0 12V72M0 42L-14 27M0 34L14 17", stroke="#69725a", sw=7)
    b += circ(-15, 6, 25, "#89a481") + circ(16, 0, 28, "#708e72") + circ(0, -21, 24, "#96ac83")
    if fruit:
        for a, z in [(-19, 5), (16, -9), (5, 18), (0, -28), (30, 5)]:
            b += circ(a, z, 4, RUST) + path(f"M{a} {z-4}l2-3", stroke="#6c7256", sw=1.5)
    return group(b, x, y, s)


def bunting(w=640, y=20, night=False):
    b = path(f"M0 {y}Q{w/2} {y+65} {w} {y}", stroke=INK, sw=1.5)
    for i in range(18):
        x = 12 + i * (w - 24) / 17
        yy = y + 65 * 2 * (x / w) * (1-x/w)
        if night:
            b += circ(x, yy+4, 8, GOLD, opacity=".12") + circ(x, yy+4, 3, CREAM)
        else:
            b += path(f"M{x-7} {yy}l7 16 7-15Z", [RUST, GOLD, CREAM, TEAL][i % 4])
    return b


def wheel(x, y, s=1, night=False):
    metal = "#7b9a8d" if night else "#658477"
    b = path("M0 0L-40 108H40Z", stroke=metal, sw=5)
    b += circ(0, 0, 72, "none", stroke=metal, stroke_width=4)
    b += circ(0, 0, 57, "none", stroke=metal, stroke_width=2)
    for i in range(12):
        a = i * math.pi / 6
        xx, yy = round(math.sin(a)*72, 2), round(math.cos(a)*72, 2)
        b += path(f"M0 0L{xx} {yy}", stroke=metal, sw=2)
        b += rect(xx-8, yy-3, 16, 14, [RUST, GOLD, "#789f9c"][i%3], 4)
        b += rect(xx-5, yy-1, 10, 5, CREAM, 2)
        if night:
            b += circ(xx, yy-6, 3, CREAM)
    b += circ(0, 0, 8, GOLD)
    return group(b, x, y, s)


def tent(x, y, s=1, color=RUST, large=False):
    b = rect(-54, 0, 108, 65, CREAM) + path("M-70 0L0-70 70 0Z", color)
    b += path("M0-70L-19 0H19Z", GOLD) + path("M-45 0L0-70-29 0ZM45 0L0-70 29 0Z", CREAM)
    b += path("M-13 65V22Q0 3 13 22V65Z", INK) + path("M0-70v-22l24 8-24 8", stroke=INK, sw=2)
    b += path("M2-91l22 7-22 7Z", GOLD) + path("M-54 0V65M54 0V65", stroke=color, sw=3)
    for xx in range(-50, 51, 20):
        b += path(f"M{xx} 0q10 13 20 0", color)
    if large:
        b += path("M-67-3L-90 65M67-3L90 65", stroke="#9f997b", sw=1.5)
    return group(b, x, y, s)


def small_stall(x, y, s=1, color=RUST):
    b = rect(0, 0, 82, 47, "#ddab70", 3) + rect(6, 5, 70, 34, INK, 1)
    b += rect(9, 8, 64, 25, "#396057") + rect(-6, 39, 94, 9, "#f6d490", 2)
    b += rect(3, 48, 76, 24, color, 2) + path("M-9 0L0-27H82L91 0Z", CREAM)
    for xx in range(0, 80, 24):
        b += path(f"M{xx} -27h13l5 27h-19Z", color)
    b += path("M1-26V74M81-26V74", stroke="#6b6955", sw=3)
    b += circ(31, 24, 7, GOLD) + circ(31, 24, 1.4, INK) + rect(46, 13, 20, 19, CREAM, 1)
    return group(b, x, y, s)


def van(x, y, s=1, level=0, color=None):
    color = color or ["#c87450", TEAL, "#d5a348", INK][level]
    b = ellipse(90, 90, 105, 11, INK, opacity=".1")
    b += rect(0, 4, 127, 76, color, 10) + path("M125 24H160L187 54V79H123Z", color)
    b += path("M135 31H155L172 52H135Z", "#a6c4b3") + path("M144 32L158 50H153L139 32Z", "#d6e3cb")
    b += path("M3 62H182V78H3Z", "#e9d4ad") + rect(24, 15, 78, 36, CREAM, 3)
    b += circ(62, 33, 12, GOLD) + circ(62, 33, 2.4, "#a16a37") + path("M41 32H27M84 32H98", stroke=color, sw=2)
    b += rect(5, 77, 180, 7, INK, 2) + rect(177, 59, 9, 8, GOLD, 2)
    b += path("M127 26V70M138 60h8", stroke=INK, sw=2)
    for xx in [35, 155]:
        b += circ(xx, 82, 18, INK) + circ(xx, 82, 10, "#9caca0") + circ(xx, 82, 4, CREAM)
    if level == 0:
        b += path("M10 54l11-2M90 70l17-3M110 13l6 3", stroke="#9b523b", sw=2)
    if level > 0:
        b += path("M10 4V-3H112V4M22-3V-9M101-3V-9", stroke=INK, sw=3)
    return group(b, x, y, s)


def crowd(x, y, n=6, scale=1):
    b = ""
    for i in range(n):
        xx, yy = i * 15, (i%3)*3
        b += circ(xx, yy, 4.5, ["#a76e51", "#dcab7e", "#c88a67"][i%3])
        b += path(f"M{xx-5} {yy+18}v-8q5-7 10 0v8Z", [TEAL, RUST, GOLD, "#817e9a"][i%4])
    return group(b, x, y, scale)


def stage(x, y, s=1, night=False):
    b = rect(-82, -61, 164, 99, INK, 4) + rect(-68, -48, 136, 75, "#486c64")
    b += path("M-92-61L0-94 92-61Z", RUST) + path("M-76-59V38M76-59V38", stroke=GOLD, sw=4)
    for xx in [-47, -15, 17, 49]:
        b += circ(xx, -55, 4, CREAM)
        b += path(f"M{xx} -50l-17 65h34Z", GOLD, opacity=".13")
    b += rect(-94, 31, 188, 12, "#5c6759", 2)
    b += crowd(-36, -1, 5, 1)
    b += rect(-70, -5, 18, 32, "#263f3d", 2) + rect(52, -5, 18, 32, "#263f3d", 2)
    for xx in [-61, 61]:
        b += circ(xx, 11, 5, "#7b8b7a")
    return group(b, x, y, s)


def venue_art():
    ids = ["willowbank", "brass_bell", "juniper", "lantern_quay", "copperfield", "orchard_days", "cedar_sound", "moonwheel", "saltwind", "meadow_crown", "solstice", "grand_circuit"]
    for idx, name in enumerate(ids):
        night = name in ["lantern_quay", "cedar_sound", "moonwheel"]
        sky = "#284d59" if night else ["#f1d29b", "#eaceaa", "#dde2bb", "#b7d4ca"][idx%4]
        hills = "#55776a" if night else "#a8b69a"
        b = rect(0, 0, 640, 240, sky, 18)
        b += circ(540, 55, 29, "#fff0bb")
        if night:
            b += circ(549, 47, 28, sky)
            for x, y in [(30, 49), (123, 18), (204, 57), (344, 24), (439, 46), (590, 87), (398, 72)]:
                b += circ(x, y, 1.6, CREAM)
        else:
            b += cloud(70, 34, .75) + cloud(324, 53, .55) + cloud(453, 27, .7)
        b += path("M0 136Q95 69 211 128T410 123T640 119V240H0Z", hills)
        b += path("M0 167Q169 125 301 163T640 159V240H0Z", "#446f60" if night else "#7e9c7c")
        b += path("M0 216Q220 164 640 219V240H0Z", "#9b9b7b" if night else "#e7c797")
        if name == "willowbank":
            b += path("M0 156Q140 143 205 176T430 182L465 205Q260 193 207 192T0 191Z", "#8eb5aa")
            b += tree(65, 108, .8) + tent(403, 125, .66) + small_stall(485, 145, .68, TEAL)
            b += path("M194 160q38-35 78 0M191 159v16M272 159v16", stroke="#977b54", sw=5)
            b += crowd(384, 183, 8, .8)
        elif name == "brass_bell":
            b += wheel(457, 93, .9) + tent(315, 151, .6) + small_stall(65, 153, .5)
            b += crowd(330, 196, 13, .7) + bunting()
        elif name == "juniper":
            b += rect(360, 112, 129, 64, "#b27255") + path("M347 112L424 66 503 112Z", RUST)
            b += rect(403, 127, 42, 49, INK) + path("M425 128v48M403 127l42 49M445 127l-42 49", stroke=CREAM, sw=2)
            for xx in range(261, 590, 23):
                b += path(f"M{xx} 181v-24", stroke=CREAM, sw=3)
            b += path("M250 165H598M250 175H598", stroke=CREAM, sw=3)
            b += ellipse(548, 156, 18, 10, CREAM) + circ(562, 151, 8, "#746d59") + path("M538 161v11M551 161v11", stroke="#746d59", sw=3)
            b += tree(93, 114, .8) + tent(200, 143, .5, GOLD)
        elif name == "lantern_quay":
            b += path("M0 146H640V210H0Z", "#345b67")
            for xx in range(19, 630, 43):
                b += path(f"M{xx} 169h20m-8 15h29", stroke="#7baca5", sw=1.4)
            b += path("M393 155l35-20h99l23 20Z", "#c7aa7b") + path("M467 63v85M467 72l-47 65h47Z", stroke=CREAM, sw=2, fill=RUST)
            b += path("M0 190H640V224H0Z", "#b99572")
            b += small_stall(275, 155, .6, GOLD) + small_stall(550, 149, .55)
            b += bunting(night=True)
            for xx, yy in [(88, 66), (209, 77), (370, 78), (500, 68)]:
                b += path(f"M{xx} {yy-25}v25", stroke=INK, sw=1.2) + ellipse(xx, yy, 10, 13, RUST) + rect(xx-5, yy-14, 10, 3, GOLD)
                b += path(f"M{xx} {yy-9}v18", stroke=GOLD, sw=1.5)
        elif name == "copperfield":
            b += path("M277 190H610M277 196H610", stroke="#758174", sw=3)
            b += rect(370, 115, 158, 56, "#4d6d5f", 13) + rect(494, 76, 61, 84, "#517665", 3)
            b += rect(502, 87, 42, 34, "#acc2a0", 3) + rect(391, 79, 16, 44, INK, 2) + rect(383, 77, 32, 7, INK, 2)
            for xx in [397, 444, 512]:
                b += circ(xx, 174, 22, INK) + circ(xx, 174, 15, GOLD) + path(f"M{xx-15} 174h30M{xx} 159v30", stroke=INK, sw=2)
            b += path("M400 174H511", stroke=CREAM, sw=4) + cloud(387, 52, .6) + cloud(335, 37, .8)
            b += tree(63, 105, .7) + tent(266, 139, .52, GOLD)
        elif name == "orchard_days":
            for xx, yy, ss in [(70, 116, .8), (317, 104, .6), (417, 112, .75), (530, 102, .9), (608, 113, .7)]:
                b += tree(xx, yy, ss, True)
            b += small_stall(354, 155, .7, TEAL)
            for xx in [495, 535, 575]:
                b += rect(xx, 170, 32, 23, "#a97d51", 2) + path(f"M{xx} 179h32m-32 8h32", stroke="#d3b078", sw=2)
                for ax, ay in [(8, 168), (19, 166), (26, 170)]:
                    b += circ(xx+ax, ay, 6, RUST)
            b += bunting()
        elif name in ["cedar_sound", "solstice"]:
            if name == "solstice":
                b += circ(436, 104, 55, "#eaa164") + path("M0 159Q200 145 640 158V190H0Z", "#83956c")
            b += stage(424, 145, .93, night) + crowd(310, 194, 19, .8)
            for xx in [62, 566, 600]:
                b += path(f"M{xx} 71l-22 62h12l-20 29h60l-20-29h12Z", "#386456")
            b += bunting(night=True)
        elif name == "moonwheel":
            b += wheel(420, 95, 1.12, True) + tent(582, 157, .57, "#b9879d")
            b += small_stall(263, 157, .5, GOLD) + crowd(310, 204, 17, .6) + bunting(night=True)
        elif name == "saltwind":
            b += path("M0 148H640V193H0Z", "#7ca9ab") + path("M0 184Q190 170 350 189T640 185V240H0Z", "#e7d4ac")
            b += rect(505, 77, 28, 82, CREAM) + rect(505, 109, 28, 19, RUST) + rect(500, 68, 38, 12, INK, 2) + path("M500 68l19-14 19 14Z", RUST)
            for xx, yy, co in [(345, 52, RUST), (420, 82, GOLD), (117, 65, TEAL)]:
                b += path(f"M{xx} {yy-19}l14 19-14 23-14-23Z", co) + path(f"M{xx} {yy+23}q15 23-4 37t6 21", stroke=INK, sw=1)
            b += tent(354, 167, .6, TEAL) + crowd(400, 195, 10, .65)
        elif name == "meadow_crown":
            b += rect(311, 95, 233, 80, CREAM) + path("M295 95L427 41 559 95Z", "#a35e68")
            for xx in [332, 386, 440, 494]:
                b += path(f"M{xx} 173v-49q14-21 28 0v49Z", "#607f70")
            b += circ(427, 86, 15, GOLD) + path("M415 84l3-10 9 8 9-8 3 10v9h-24Z", CREAM)
            b += tent(238, 153, .43, TEAL) + tent(586, 153, .43, TEAL) + crowd(318, 194, 17, .7) + bunting()
        else:
            b += wheel(490, 87, .86) + tent(329, 141, .7) + stage(605, 159, .47)
            b += path("M247 197V131Q247 110 269 110H341Q361 110 361 131V197", stroke=GOLD, sw=14)
            b += path("M247 197V131Q247 110 269 110H341Q361 110 361 131V197", stroke=RUST, sw=4)
            b += circ(305, 109, 14, CREAM) + circ(305, 109, 8, GOLD) + circ(305, 109, 1.5, RUST)
            b += crowd(380, 194, 17, .72) + bunting()
        b += van(54, 159, .63, 1 if idx>5 else 0)
        b += path("M12 226h31M561 227h51", stroke="#f5e5c7", sw=2)
        save("venues", name, 640, 240, b)


def portrait(name, bg, skin, hair, shirt, style, extras=""):
    b = rect(0, 0, 160, 160, bg, 22) + circ(120, 28, 44, CREAM, opacity=".12")
    b += path("M10 160v-11q8-37 48-38h44q39 3 48 38v11Z", shirt)
    b += path("M51 121q29 21 58 0l7 39H44Z", CREAM, opacity=".88")
    b += path("M53 120l-4 40M106 120l5 40", stroke=shirt, sw=4)
    b += rect(66, 91, 28, 33, skin, 10) + path("M67 104q14 13 26 0v9q-14 12-26 0Z", "#8e4d38", opacity=".14")
    if style in ["long", "bun", "waves"]:
        b += path("M38 62Q28 12 77 13Q127 10 126 64L133 118Q108 130 101 102H56Q48 128 29 113Z", hair)
    else:
        b += path("M38 67Q28 15 79 15Q126 14 123 67Z", hair)
    b += ellipse(39, 74, 7, 11, skin) + ellipse(120, 74, 7, 11, skin)
    b += path("M41 55Q41 26 80 26Q118 26 118 55V80Q116 111 81 113Q43 109 41 80Z", skin)
    b += path("M49 55q11-7 20-2M91 53q12-5 21 3", stroke=hair, sw=3)
    b += ellipse(62, 70, 2.8, 3.6, INK) + ellipse(99, 70, 2.8, 3.6, INK)
    b += path("M80 71l-3 13h7", stroke="#93543f", sw=1.7, opacity=".6")
    b += path("M67 93q13 12 27-1", stroke="#7c4638", sw=2.5)
    b += ellipse(53, 84, 7, 3.8, "#d97c69", opacity=".28") + ellipse(107, 84, 7, 3.8, "#d97c69", opacity=".28")
    if style == "short":
        b += path("M38 58Q29 20 61 16Q78 3 96 18Q123 15 124 57L109 43Q91 50 78 31Q64 48 42 46Z", hair)
    elif style == "waves":
        b += path("M38 70Q27 40 44 25Q65 7 86 17Q115 10 125 35L118 65Q109 27 92 38Q72 51 48 43Z", hair)
        b += path("M43 33q11-13 24-11M101 25q15 2 17 15", stroke=CREAM, sw=2, opacity=".18")
    elif style == "curly":
        for x, y, r in [(40, 45, 14), (45, 29, 13), (62, 21, 14), (82, 18, 15), (101, 23, 15), (117, 39, 15), (120, 55, 10)]:
            b += circ(x, y, r, hair)
            b += path(f"M{x-4} {y-6}q6-3 9 1", stroke=CREAM, sw=1.3, opacity=".16")
    elif style == "bun":
        b += circ(81, 13, 17, hair) + path("M38 61Q28 26 59 19Q104 4 124 37L118 62Q109 34 82 31Q57 45 42 43Z", hair)
        b += path("M67 18q14 7 29 0", stroke=GOLD, sw=3)
    elif style == "long":
        b += path("M39 75Q25 24 64 17Q107 5 122 34L122 76Q110 55 110 36Q82 60 47 49L45 88Z", hair)
    elif style == "bald":
        b += path("M40 62V49Q42 30 48 27L45 66ZM119 62V47Q117 31 112 27L115 66Z", hair)
    elif style == "cap":
        b += path("M35 49Q31 12 78 12Q119 13 123 44Z", shirt) + path("M33 44Q95 32 138 48L135 54H36Z", INK)
        b += circ(80, 30, 8, GOLD) + circ(80, 30, 1.4, INK)
    if "glasses" in extras:
        b += rect(48, 61, 26, 20, "none", 7, stroke=INK, stroke_width=2.5) + rect(88, 61, 26, 20, "none", 7, stroke=INK, stroke_width=2.5)
        b += path("M74 67q7-5 14 0M42 65h6M114 65h5", stroke=INK, sw=2)
    if "beard" in extras:
        b += path("M43 78Q45 110 80 115Q115 111 118 78Q111 96 99 90Q80 85 61 92Q49 89 43 78Z", hair)
        b += path("M69 99q12 7 24-1", stroke=CREAM, sw=2)
    if "moustache" in extras:
        b += path("M60 94Q69 80 80 88Q91 80 102 94Q87 98 80 92Q72 98 60 94Z", hair)
    if "earring" in extras:
        b += circ(38, 84, 3, GOLD) + circ(121, 84, 3, GOLD)
    if "bandana" in extras:
        b += path("M37 44Q82 23 122 42L121 52Q79 34 38 54Z", RUST)
        for xx, yy in [(47, 44), (62, 39), (80, 37), (98, 41), (115, 46)]:
            b += circ(xx, yy, 2, CREAM)
    b += rect(69, 136, 23, 13, shirt, 2) + circ(80.5, 142.5, 4.5, GOLD) + circ(80.5, 142.5, .8, shirt)
    save("crew", name, 160, 160, b)


def portraits():
    specs = [
        ("bea", "#dfc1ae", "#dba681", "#ddd3b6", "#a15a55", "bun", "glasses"),
        ("ozzy", "#d2c39a", "#ce956f", "#3b3b35", "#5c7778", "waves", "beard"),
        ("nell", "#b9d1bd", "#edbb91", "#88583e", "#518078", "long", "glasses"),
        ("ravi", "#bed0cd", "#a96d4b", "#302f2d", "#526e82", "short", "beard"),
        ("mabel", "#d7c0d0", "#b47856", "#625044", "#846087", "curly", "earring"),
        ("kit", "#c7d0a6", "#ddad84", "#846143", "#6b7d55", "cap", ""),
        ("dottie", "#e8c5ac", "#efbd93", "#a4553c", "#b96549", "bun", "bandana earring"),
        ("sol", "#e3ce96", "#c08c67", "#49413a", "#4a615a", "bald", "moustache"),
        ("june", "#bbd1bf", "#89553e", "#343330", "#3f756d", "bun", "earring"),
        ("pip", "#d6d0a5", "#e3b38b", "#af7643", "#8c935a", "curly", ""),
        ("ida", "#e2bfc4", "#c99473", "#534439", "#a35d72", "waves", "earring"),
        ("gus", "#b8cbb4", "#c99876", "#b8b2a1", "#638063", "cap", "beard"),
        ("tansy", "#dfcad4", "#8c604b", "#37312f", "#8d718c", "long", "glasses earring"),
        ("mo", "#bfc9db", "#e0af8b", "#514e58", "#65708f", "short", "glasses"),
    ]
    for spec in specs:
        portrait(*spec)


def donut(x, y, size, flavor, seed=0):
    rng = random.Random(seed)
    r = 24
    b = ellipse(0, 3, r, r*.86, "#a96732") + ellipse(0, -1, r, r*.86, "#d99848")
    b += ellipse(-2, -5, 20.5, 15.5, "#e9b768") + path("M-19-3Q-15-20 3-20", stroke="#f6ce85", sw=2)
    glazing = {"maple":"#b77735", "rainbow":"#fff0d8", "coffee":"#a57a54", "caramel":"#cc8b3e", "berry":"#b56e94", "cocoa":"#674335", "lemon":"#e7d673"}
    if flavor in glazing:
        co = glazing[flavor]
        b += path("M-21-6Q-20-17-8-18Q8-24 20-11Q23-4 19 1L15 0Q10 6 6 2Q1 8-5 3Q-10 7-14 2Q-23 2-21-6Z", co)
        b += path("M-15-10Q-8-17 2-16", stroke=CREAM, sw=2, opacity=".5")
    if flavor in ["classic", "cinnamon", "apple", "coffee", "cocoa", "lemon"]:
        for j in range(52):
            a = rng.random()*math.tau
            rr = math.sqrt(rng.random())*19
            xx, yy = math.cos(a)*rr, math.sin(a)*rr*.7-3
            col = {"classic":CREAM, "cinnamon":"#9a5c30", "apple":"#f5d5a2", "coffee":"#594232", "cocoa":"#b97754", "lemon":CREAM}[flavor]
            b += circ(round(xx,2), round(yy,2), .45+rng.random()*.65, col, opacity=".85")
    if flavor in ["maple", "caramel"]:
        b += path("M-17-11L15 3M-9-18L21-4M-21-2L4 9", stroke="#f0bd6a", sw=2.6)
    if flavor == "apple":
        for xx, yy in [(-12,-9), (9,-10), (16,-1), (-7,6), (-15,0), (4,-15)]:
            b += rect(xx, yy, 3.5, 3, "#e9c58b", 1, transform=f"rotate(20 {xx} {yy})")
    if flavor == "rainbow":
        for j in range(20):
            a, rr = rng.random()*math.tau, 6+rng.random()*12
            xx, yy = round(math.cos(a)*rr,2), round(math.sin(a)*rr*.7-5,2)
            b += path(f"M{xx} {yy}l{rng.choice([-2,2])} 2", stroke=[RUST, GOLD, "#7f9d79", "#a47a99", "#6e9baa"][j%5], sw=1.7)
    if flavor in ["caramel", "berry"]:
        for xx, yy in [(-12,-9), (9,-10), (16,-1), (-7,5), (-15,0)]:
            b += path(f"M{xx} {yy}l2 1m-1-2v3", stroke=CREAM, sw=1)
    b += ellipse(0, -1.5, 2.1, 2.8, "#8d542e") + path("M-2-2q1-3 3-1", stroke="#f1c67a", sw=1)
    return group(b, x, y, size)


def recipes():
    flavors = ["classic", "cinnamon", "lemon", "apple", "maple", "rainbow", "coffee", "caramel", "berry", "cocoa"]
    for i, flavor in enumerate(flavors):
        b = circ(80, 80, 74, ["#f3e6c8", "#eee1ca", "#f0ebcc", "#e8e9d1", "#efddc0", "#f0dfe4", "#e6ddcf", "#f3e0c7", "#ecdeeb", "#eaded5"][i])
        b += ellipse(79, 120, 61, 19, INK, opacity=".08")
        b += path("M24 46L139 55 123 136 14 114Z", "#fcf3dc")
        b += path("M24 46L34 61 139 55M17 103L123 136M126 78l-3 58", stroke="#e0cca5", sw=1.5)
        b += donut(67, 62, 1.13, flavor, i+10) + donut(106, 91, 1.05, flavor, i+50) + donut(51, 105, 1.15, flavor, i+80)
        if flavor == "cinnamon":
            b += group(rect(0, 0, 5, 37, "#986036", 2)+path("M3 3v30", stroke="#cf9563", sw=1), 122, 27, 1, 25)
            b += group(rect(0, 0, 5, 36, "#a97343", 2)+path("M3 3v30", stroke="#e3ac75", sw=1), 134, 32, 1, 37)
        elif flavor == "lemon":
            b += path("M113 36a20 20 0 0 1 27 23Z", GOLD) + path("M117 38a16 16 0 0 1 21 17Z", "#f5df83") + path("M118 39l17 14m-17-14l10 17m-10-17l19 7", stroke=CREAM, sw=1.4)
        elif flavor == "apple":
            b += path("M126 38Q111 27 108 43Q105 58 122 62Q142 59 139 44Q137 29 126 38Z", RUST) + path("M125 38l3-12", stroke="#755d3b", sw=2) + path("M128 32q15-13 13-1-6 6-13 1Z", "#789061")
        elif flavor == "coffee":
            for xx, yy, rot in [(127,33,15),(141,44,-28),(113,31,40)]:
                b += group(ellipse(0,0,4,6,"#79563b")+path("M0-4q-3 3 0 8",stroke="#bd9163",sw=1),xx,yy,1,rot)
        elif flavor == "berry":
            for xx, yy in [(124,34),(135,37),(127,45)]:
                b += circ(xx,yy,6,"#795674")+circ(xx-1,yy-2,2,"#b487a5")
            b += path("M126 29q8-16 15-10-3 13-15 10Z", "#789369")
        elif flavor == "cocoa":
            b += path("M124 28Q147 36 128 55Q117 62 114 59Q134 44 124 28Z", RUST) + path("M124 28q-1-9 8-8",stroke="#69815c",sw=3)
        save("recipes", flavor, 160, 160, b)


def fryer(level):
    width = [142, 165, 190, 211][level]
    x = (256-width)/2
    b = ellipse(128, 141, width*.51, 8, INK, opacity=".1")
    b += rect(x+5, 67, width-10, 63, "#7f9a96", 7) + rect(x+9, 73, width-18, 50, "#c5d4c8", 5)
    b += rect(x+17, 85, width-34, 31, "#9bb0a5", 3) + rect(x+19, 87, width-38, 9, "#dce2cf", 2)
    b += path(f"M{x+14} 130v13M{x+width-14} 130v13", stroke=INK, sw=5)
    b += rect(x, 48, width, 35, "#e0e4d3", 5) + rect(x+8, 53, width-16, 22, "#55736b", 3)
    b += rect(x+12, 57, width-24, 14, "#af7a39", 3)
    b += path(f"M{x+14} 58h{width-29}", stroke=GOLD, sw=2)
    for i in range(3+level):
        b += donut(x+24+i*(width-48)/(2+level), 63, .32, "classic", i)
    # Hopper and the shiny dispenser are deliberately readable machine details.
    b += path(f"M{x+14} 16h42l-7 24h-28Z", "#dce3d6") + ellipse(x+35,16,21,5,"#77948c")
    b += path(f"M{x+27} 40v14h15V40", stroke="#67867e", sw=3)
    b += rect(x+25, 5, 20, 11, "#7d9990", 3) + circ(x+35,10.5,3,GOLD)
    for i in range(1+min(level,2)):
        xx = x+width-24-i*27
        b += circ(xx,104,8,INK)+circ(xx,104,5,"#c9d6c6")+path(f"M{xx} 104l3-4",stroke=RUST,sw=2)
    if level>0:
        b += rect(x+width-51,29,42,23,INK,3)+rect(x+width-47,33,34,10,"#c1d5a4",2)
        b += path(f"M{x+width-38} 38h5m5 0h6",stroke=TEAL,sw=2)
    if level>1:
        b += rect(x+54,86,37,25,"#be8c54",3)+circ(x+72,98,7,GOLD)+circ(x+72,98,1.5,RUST)
    if level>2:
        b += path(f"M{x+width-10} 73l20 16v10h-21",stroke="#9ab0a4",sw=6)+rect(x+width-13,101,29,15,"#bbcdbf",3)
    return b


def equipment():
    for i in range(4):
        b = circ(128,80,73,["#efdfc5","#dce7d6","#e9dfc4","#e0e6ce"][i])
        if i==0: b += van(30,37,1,0)
        elif i==1: b += van(30,36,1,1)
        elif i==2:
            b += van(18,45,.8,2)
            b += rect(174,76,64,43,CREAM,4)+rect(178,80,56,24,TEAL,2)+path("M166 116h9",stroke=INK,sw=3)+circ(207,122,11,INK)+circ(207,122,5,GOLD)
            b += rect(42,33,66,19,"#d6b87f",3)+path("M47 39h55m-55 7h55",stroke="#aa8959",sw=1.5)
        else:
            b += van(103,29,.65,1)+van(17,60,.89,3)
        save("equipment",f"truck_{i}",256,160,b)
        save("equipment",f"fryer_{i}",256,160,circ(128,80,73,["#e3e8d8","#dde5d4","#eee1c7","#eee3c5"][i])+fryer(i))
        b = circ(128,80,73,["#f0e1c9","#e2e6d1","#eedbc6","#e6dec6"][i])
        if i==0:
            b += small_stall(65,57,1.2,TEAL)
        elif i==1:
            b += small_stall(60,55,1.28,RUST)
            b += path("M43 56V139M180 56V139M35 56L67 15H165L195 56Z",fill=CREAM,stroke=INK,sw=2)
            for xx in [67,101,135]: b += path(f"M{xx} 16h16l13 40h-42Z",RUST)
        elif i==2:
            b += tent(129,76,.8,TEAL,True)+small_stall(90,82,.85,RUST)
            b += rect(59,95,30,42,INK,2)+path("M64 103h19m-19 8h17m-17 8h13",stroke=GOLD,sw=2)
        else:
            b += rect(28,47,201,90,CREAM,7)+rect(36,55,185,75,TEAL,3)
            b += path("M19 48L42 19H213L237 48Z",RUST)+path("M20 49H237",stroke=INK,sw=4)
            for xx in [54,96,138,180]: b += path(f"M{xx} 20h20l5 27h-27Z",CREAM)
            b += rect(50,70,157,35,INK,3)+rect(43,106,169,8,GOLD,2)+rect(86,118,74,19,CREAM,2)
            b += circ(124,83,14,GOLD)+circ(124,83,2.8,RUST)
            b += path("M30 54v87M226 54v87",stroke=INK,sw=4)
            for xx in [52,76,100,148,172,196]: b += circ(xx,57,2.5,GOLD)
        save("equipment",f"stand_{i}",256,160,b)


def events():
    # Pictures are deliberately scenic, with one clear focal subject per category.
    for kind in ["travel","machine","customer","crew","weather","opportunity","story"]:
        b = rect(0,0,320,160,"#eee0bf",14)+circ(266,36,24,"#fff3ce")
        b += path("M0 107Q71 67 144 104T320 94V160H0Z","#afbea1")
        if kind=="travel":
            b += path("M0 146Q129 98 320 146",stroke="#d0ba94",sw=38)+path("M0 147Q129 99 320 147",stroke=CREAM,sw=2,stroke_dasharray="13 12")
            b += tree(286,81,.45)+van(52,56,.85,0)
            b += path("M29 130V70",stroke=INK,sw=3)+path("M14 71H58L67 80 58 89H14Z",RUST)+path("M48 99H7L0 107 7 115H48Z",CREAM)
        elif kind=="machine":
            b += group(fryer(2),27,14,.87)
            b += group(path("M0 0q12-9 21-2L11 8l8 8 12-10q3 13-8 19h-9l-29 30q-10 2-12-8L2 17Z",INK)+circ(-20,47,3,GOLD),250,25,.8,15)
        elif kind=="customer":
            b += small_stall(37,66,1.05,TEAL)+crowd(201,88,4,1.4)
            b += path("M183 24h77q10 0 10 10v25q0 9-10 9h-39l-15 12V68h-23q-10 0-10-9V34q0-10 10-10Z",CREAM)
            for xx in [193,220,247]: b += circ(xx,46,5,GOLD)
        elif kind=="crew":
            for x,y,co,skin in [(89,77,TEAL,"#cc9571"),(160,65,RUST,"#996747"),(231,79,"#8d7391","#e3b38b")]:
                b += path(f"M{x-30} 150v-27q6-23 30-23t30 23v27Z",co)+rect(x-6,y+16,12,19,skin,4)+ellipse(x,y,20,25,skin)
                b += path(f"M{x-20} {y-4}q-7-25 20-25t20 24q-14-8-22-18-6 14-18 19Z",INK)
                b += circ(x-7,y+1,1.6,INK)+circ(x+7,y+1,1.6,INK)+path(f"M{x-6} {y+12}q6 6 12 0",stroke=INK,sw=1.5)
                b += path(f"M{x-14} 119l14 10 14-10v31h-28Z",CREAM)
            b += path("M119 35l8-11m60 12-1-15m43 25 8-7",stroke=GOLD,sw=3)
        elif kind=="weather":
            b = rect(0,0,320,160,"#a9c2bd",14)+path("M0 123Q150 92 320 122V160H0Z","#719889")
            b += cloud(39,35,1.5,"#dce4d7")+cloud(190,20,1.8,"#e8ebdd")
            for x,y in [(42,90),(67,111),(95,83),(124,108),(217,87),(263,112),(288,79)]: b += path(f"M{x} {y}l-6 13",stroke="#648e94",sw=2)
            b += path("M124 92q35-62 76 0Z",RUST)+path("M143 92q13-58 35 0Z",CREAM)+path("M160 91v44q-1 13-13 4",stroke=INK,sw=3)
            b += ellipse(165,151,55,4,"#92b4b1")
        elif kind=="opportunity":
            b += stage(252,119,.45)+path("M56 136l20-86 72 17-17 88Z",CREAM)+path("M77 56l64 15-9 32-64-16Z",RUST)
            b += circ(105,80,11,GOLD)+circ(105,80,2,CREAM)+path("M72 108l46 11m-49 2l31 8",stroke=TEAL,sw=4)
            b += path("M185 30l6 14 16 1-12 10 4 16-14-9-14 9 4-16-12-10 16-1Z",GOLD)
            b += path("M177 18l-2-8m30 17 7-6m-53 8-8-4",stroke=RUST,sw=2)
        else:
            b += path("M70 142V53Q108 37 158 57Q207 35 250 53V142Q209 124 158 142Q108 125 70 142Z",CREAM,INK,2)
            b += path("M158 58V141M81 67q30-8 63 4M83 80q27-8 60 3M83 94q27-8 60 3M173 112q27-8 60 3M173 125q27-8 60 3",stroke="#c8b895",sw=2)
            # Duchess, the recurring seagull, on a miniature book plate.
            b += ellipse(206,91,22,13,"#cad8cc")+circ(223,78,10,CREAM)+path("M231 77l13 4-13 4Z",GOLD)+circ(227,76,1.8,INK)
            b += path("M197 102l-4 10m20-10 3 10M188 89l-12-6 9 13",stroke=INK,sw=2)
            b += path("M206 57l-8-7 5-9 7 6 7-6 4 11Z",GOLD)
        save("events",kind,320,160,b)


def icons():
    shapes = {
        "cash": '<rect x="3" y="5" width="18" height="14" rx="3"/><circle cx="12" cy="12" r="3"/><path d="M6 9h1m10 6h1"/>',
        "rep": '<path d="m12 3 2.8 5.7 6.2.9-4.5 4.4 1.1 6.2-5.6-3-5.6 3 1.1-6.2L3 9.6l6.2-.9Z"/>',
        "stock": '<path d="M5 7h14l1 14H4L5 7Zm3 0V4h8v3M4 12h16"/><circle cx="12" cy="16" r="2"/>',
        "calendar": '<rect x="3" y="5" width="18" height="16" rx="3"/><path d="M7 3v4m10-4v4M3 10h18m-13 4h1m6 0h1m-8 3h1"/>',
        "location": '<path d="M19 10c0 5-7 11-7 11S5 15 5 10a7 7 0 1 1 14 0Z"/><circle cx="12" cy="10" r="2.5"/>',
        "truck": '<path d="M3 5h12v12H3V5Zm12 5h3l3 4v3h-6"/><circle cx="7" cy="18" r="2"/><circle cx="18" cy="18" r="2"/><path d="M15 14h6"/>',
        "fryer": '<path d="M3 9h18v11H3V9Zm2 0V4h6v5m3 0V5h5v4M3 14h18"/><circle cx="16" cy="17" r="1"/><path d="M7 17h2"/>',
        "stand": '<path d="M3 9 6 3h12l3 6H3Zm2 1v11m14-11v11M3 16h18m-15 5h12M9 3 8 9m7-6 1 6"/>',
        "crew": '<circle cx="9" cy="7" r="3"/><path d="M3 21v-4a6 6 0 0 1 12 0v4M16 4a3 3 0 0 1 0 6m2 4q4 0 4 7"/>',
        "recipe": '<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="2"/><path d="m7 8 1 1m7-2-1 1m3 6 1 1m-9 2-1 1"/>',
        "garage": '<path d="m2 10 10-7 10 7M5 8v13h14V8M8 21V11h8v10M8 15h8m-8 3h8"/>',
        "journal": '<path d="M4 3h14q2 0 2 2v16H6q-2 0-2-2V3Zm0 14h16M8 7h8m-8 4h5"/>',
        "map": '<path d="m3 5 6-2 6 3 6-2v15l-6 2-6-3-6 2V5Zm6-2v15m6-12v15"/>',
        "star": '<path d="m12 3 2.8 5.7 6.2.9-4.5 4.4 1.1 6.2-5.6-3-5.6 3 1.1-6.2L3 9.6l6.2-.9Z"/>',
        "heart": '<path d="M12 21 4 13a5.5 5.5 0 0 1 8-7 5.5 5.5 0 0 1 8 7Z"/>',
        "skill": '<path d="m12 2 3 6 6 1-4 5 1 7-6-3-6 3 1-7-4-5 6-1Z"/><path d="m9 12 2 2 4-4"/>',
        "shield": '<path d="M3 5 12 2l9 3v6q0 7-9 11-9-4-9-11V5Z"/><path d="m8 11 3 3 5-5"/>',
        "train": '<path d="m2 9 10-6 10 6-10 6L2 9Zm4 3v6q6 5 12 0v-6m4-3v8"/>',
        "rest": '<path d="M17 3A9 9 0 1 0 21 16 9 9 0 0 1 17 3Z"/><path d="M3 4h4L3 8h4m12 0h3l-3 3h3"/>',
        "wrench": '<path d="M21 3a6 6 0 0 1-7 8L6 20a2 2 0 0 1-3-3l9-8a6 6 0 0 1 8-7l-4 4 2 2Z"/>',
        "upgrade": '<path d="m5 11 7-8 7 8h-4v7H9v-7H5Zm2 10h10"/>',
        "info": '<circle cx="12" cy="12" r="9"/><path d="M12 11v6m0-10v.5"/>',
        "close": '<path d="m6 6 12 12M18 6 6 18"/>',
        "settings": '<path d="m9 3 1-1h4l1 3 3 1 3 1 1 4-2 2-1 3 1 3-3 3-3-1-3 1-2 2-4-1-1-3-2-2-3-1V9l3-1 2-2 1-3Z" transform="translate(3 1) scale(.8)"/><circle cx="12" cy="12" r="3"/>',
        "check": '<path d="m4 12 5 5L20 6"/>',
        "arrow": '<path d="M4 12h16m-6-6 6 6-6 6"/>',
        "clock": '<circle cx="12" cy="12" r="9"/><path d="M12 6v6l4 3"/>',
        "weather": '<path d="M5 17a4 4 0 1 1 2-7 5 5 0 0 1 9 1 3 3 0 1 1 2 6H5Z"/><path d="m8 20-1 2m6-2-1 2m6-2-1 2M17 2v2m5 2-2 1m-8-4 1 2"/>',
        "coin": '<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="6"/><path d="M12 8v8m-2-6h3q2 1-1 2t0 2h2"/>',
        "bag": '<path d="M5 7h14l1 14H4L5 7Zm3 0V5a4 4 0 0 1 8 0v2"/><circle cx="12" cy="14" r="3"/><circle cx="12" cy="14" r=".6"/>',
    }
    for key, shape in shapes.items():
        # White source strokes allow Godot TextureRect.modulate and button icon
        # colors to apply the appropriate contrast color in every UI state.
        save("icons", key, 24, 24, f'<g fill="none" stroke="#ffffff" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round">{shape}</g>')


def main():
    icons()
    venue_art()
    portraits()
    recipes()
    equipment()
    events()
    print(f"Wrote {len(list(OUT.rglob('*.svg')))} original SVG assets to {OUT}")


if __name__ == "__main__":
    main()
