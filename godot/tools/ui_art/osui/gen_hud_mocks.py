"""Flight HUD mock renders for lane osui: the target layout for B (no overlaps at 16:9 and phone widths).

Logical canvas follows the game: 720 dp tall, width = 720 * aspect (1280 at 16:9, 1600 at 20:9). The video frame is
16:9; on wider screens the button rails move into the pillarbox bars so the picture stays clear.
Backgrounds are clean frames captured from the game with the HUD hidden (docs/realism/osui/bg_*.png).
"""
import os, io, base64
import numpy as np
from PIL import Image, ImageEnhance, ImageFilter
import osui_lib as L
import gen_hud as Hd

HUD = os.path.join(L.OUT, "hud")
BG = os.path.join(L.REAL, "src")


def uri(im):
    b = io.BytesIO()
    im.convert("RGB").save(b, "JPEG", quality=90)
    return "data:image/jpeg;base64," + base64.b64encode(b.getvalue()).decode()


def colourmap(im, stops):
    g = np.asarray(im.convert("L").filter(ImageFilter.GaussianBlur(1.2)), np.float32) / 255.0
    g = np.clip((g - g.mean()) * 1.8 + 0.5, 0, 1)
    cs = np.array([[int(c[i:i + 2], 16) for i in (1, 3, 5)] for c in stops], np.float32)
    x = g * (len(stops) - 1)
    i = np.clip(x.astype(int), 0, len(stops) - 2)
    f = (x - i)[..., None]
    out = cs[i] * (1 - f) + cs[i + 1] * f
    return Image.fromarray(out.astype(np.uint8), "RGB")


def bgimg(name, mode=None):
    p = os.path.join(BG, name)
    im = Image.open(p).convert("RGB")
    if mode == "thermal":
        im = colourmap(im, Hd.PALETTES["ironbow"])
    elif mode == "night":
        im = colourmap(ImageEnhance.Brightness(im).enhance(0.6), Hd.PALETTES["green_phosphor"])
        n = np.random.default_rng(3).normal(0, 9, (im.height, im.width, 1))
        im = Image.fromarray(np.clip(np.asarray(im, np.float32) + n, 0, 255).astype(np.uint8))
    return im


def btn(s, name, cx, cy, d, state="default", label=None, key=None):
    f = os.path.join(HUD, "button", state, "128", f"{name}{'_key' if key else ''}.png")
    s.image(cx - d / 2, cy - d / 2, d, d, f, "xMidYMid meet")
    if label:
        s.text(cx, cy + d / 2 + 14, label, 12, "#FFFFFF", 500, "middle", halo=("#00000080", 2.6))


def glyph(s, name, x, y, size, colour="#FFFFFF"):
    s.add(f'<g transform="translate({x} {y}) scale({size/24})">{Hd.G[name].replace("#FFF", colour)}</g>')


def top_bar(s, x0, w, compact=False, thermal=False, unread=True):
    """40 dp top bar. Left: back (to the tablet desktop) + mode. Centre: link/GPS/battery. Right: camera params, bell, more.
    Rule: items are laid out left to right with min 16 dp gaps; when the row is too narrow, drop in this order:
    cell V and amps, dBm, WB, shutter. Never shrink the 40 dp touch targets of back / bell / more."""
    s.rect(x0, 0, w, 40, s.lin([(0, "#000", 0.55), (1, "#000", 0.25)]))
    W = lambda t: len(t) * 7.6
    s.add(f'<g opacity="1">')
    glyph(s, "back", x0 + 10, 8, 24)
    if unread:
        s.circle(x0 + 30, 11, 4, "#E5484D", stroke="#000", sw=1)
    s.image(x0 + 50, 9, 22, 22, os.path.join(HUD, "glyph", "48", "mode_N.png"), "xMidYMid meet")
    s.text(x0 + 80, 25, "NORMAL", 13, "#FFFFFF", 700, family="mono")
    cx = x0 + (w * (0.30 if not compact else 0.27))
    glyph(s, "gps", cx, 9, 22); s.text(cx + 26, 25, "17", 13, "#FFFFFF", 500, family="mono")
    cx += 62
    glyph(s, "rc", cx, 9, 22)
    glyph(s, "signal", cx + 24, 11, 16, "#7EE06A")
    glyph(s, "hd", cx + 44, 9, 22)
    glyph(s, "signal", cx + 68, 11, 16, "#7EE06A")
    if not compact:
        s.text(cx + 90, 25, "-69 dBm", 13, "#FFFFFF", 500, family="mono")
        cx += 160
    else:
        cx += 100
    glyph(s, "battery", cx, 8, 24)
    s.text(cx + 30, 25, "100%" + ("" if compact else "  4.13V"), 13, "#FFFFFF", 500, family="mono")
    # right cluster, right-aligned: [ISO 100] [1/299] [EV +0.0] [WB 5600K] | bell | more
    rx = x0 + w - 12
    glyph(s, "more", rx - 28, 8, 24); rx -= 48
    glyph(s, "bell", rx - 26, 8, 24)
    if unread:
        s.rect(rx - 12, 5, 16, 14, "#E5484D", r=7); s.text(rx - 4, 15.5, "3", 10, "#FFFFFF", 700, "middle")
    rx -= 44
    s.rect(rx - 1, 10, 1, 20, "#FFFFFF", opacity=0.3)
    rx -= 12
    params = ["WB 5600K", "EV +0.0", "1/299", "ISO 100"] if not compact else ["EV +0.0", "1/299", "ISO 100"]
    for p in params:
        s.text(rx, 25, p, 13, "#FFFFFF", 500, "end", family="mono")
        rx -= W(p) + 14
    s.add("</g>")


def bottom_strip(s, x0, w, H, drawer=False):
    s.rect(x0, H - 48, w, 48, s.lin([(0, "#000", 0.2), (1, "#000", 0.55)]))
    items = [("H", "212 m"), ("AGL", "162.4 m"), ("MSL", "294 m"), ("H.S", "8.4 m/s  30 km/h"), ("V.S", "+0.3 m/s"), ("WIND", "4.2 m/s  WSW")]
    x = x0 + 16
    for k, v in items:
        s.text(x, H - 30, k, 10, "#BBCCDD", 500, family="mono")
        s.text(x, H - 12, v, 15, "#FFFFFF", 700, family="mono")
        x += len(v) * 9.2 + 30
    # pull-up handle for the camera drawer, centred on the strip's top edge
    s.image(x0 + w / 2 - 48, H - 48 - 30, 96, 32, os.path.join(HUD, "pill", "handle_down_2x.png" if drawer else "handle_up_2x.png"), "xMidYMid meet")


def left_rail(s, cx, top, landing=False):
    names = [("mode_N", "Mode"), ("takeoff" if landing else "land", "Takeoff" if landing else "Land"), ("rth", "Return"), ("view_chase", "View")]
    for i, (n, lab) in enumerate(names):
        btn(s, n, cx, top + 26 + i * 80, 52, "default", lab)


def right_rail(s, cx, top, H, thermal="default", night="default", video=False):
    btn(s, "thermal", cx, top + 24, 48, thermal, None, "T")
    btn(s, "night", cx, top + 84, 48, night, None, "K")
    btn(s, "photo_video" if not video else "video", cx, top + 160, 44)
    # shutter (existing ShutterButton art drawn in code): white ring, red/white core
    sy = top + 240
    s.circle(cx, sy, 36, "#000", opacity=0.22)
    s.circle(cx, sy, 33, "none", stroke="#FFFFFF", sw=4)
    s.circle(cx, sy, 26, "#FFFFFF" if not video else "#E5484D")
    btn(s, "playback", cx, top + 320, 44)


def gimbal_scale(s, x, y0, y1, deg=-20):
    s.rect(x, y0, 1.2, y1 - y0, "#FFFFFF", opacity=0.9)
    for a in range(20, -91, -10):
        yy = y0 + (20 - a) / 110 * (y1 - y0)
        s.rect(x - (8 if a % 30 == 0 else 4), yy, 8 if a % 30 == 0 else 4, 1.2, "#FFFFFF")
        if a % 30 == 0 or a == 20:
            s.text(x - 12, yy + 4, str(a), 10, "#FFFFFF", 500, "end", family="mono")
    gy = y0 + (20 - deg) / 110 * (y1 - y0)
    s.add(f'<path d="M{x+2} {gy} L{x+11} {gy-5} L{x+11} {gy+5} Z" fill="#FFE14D"/>')
    s.text(x + 6, y1 + 18, f"{deg}°", 12, "#FFE14D", 700, "middle", family="mono")


def reticle(s, cx, cy):
    for a, b in (((-14, 0), (-4, 0)), ((4, 0), (14, 0)), ((0, -14), (0, -4)), ((0, 4), (0, 14))):
        s.add(f'<path d="M{cx+a[0]} {cy+a[1]} L{cx+b[0]} {cy+b[1]}" stroke="#FFFFFF" stroke-width="1.5" opacity="0.9"/>')
    for k in (-20, -10, 10, 20):
        yy = cy + k * 5.2
        s.add(f'<path d="M{cx-34} {yy} H{cx-10} M{cx+10} {yy} H{cx+34}" stroke="#FFFFFF" stroke-width="1.4" opacity="0.5"/>')
    s.add(f'<path d="M{cx-120} {cy} H{cx-10} M{cx+10} {cy} H{cx+120}" stroke="#FFFFFF" stroke-width="1.5" opacity="0.9"/>')


def minimap(s, x, y, size=150):
    s.rect(x, y, size, size, "#1B231B", r=12, opacity=0.85)
    s.rect(x + 0.5, y + 0.5, size - 1, size - 1, "none", r=12, stroke="#FFFFFF", sw=1, opacity=0.35)
    s.circle(x + size / 2, y + size / 2, size * 0.36, "none", stroke="#FFFFFF", sw=1, opacity=0.35)
    s.add(f'<path d="M{x+size*0.1} {y+size*0.7} C{x+size*0.4} {y+size*0.6} {x+size*0.5} {y+size*0.3} {x+size*0.9} {y+size*0.2}" stroke="#E2DBCC" stroke-width="2" fill="none" opacity="0.8"/>')
    s.image(x + size / 2 - 12, y + size / 2 - 12, 24, 24, os.path.join(L.OUT, "map", "pin", "drone_arrow.png"), "xMidYMid meet")
    s.text(x + size / 2, y + 14, "N", 11, "#FF8888", 700, "middle")
    s.circle(x + size * 0.28, y + size * 0.72, 5, "#FFCC44")
    s.text(x + size * 0.28, y + size * 0.72 + 3.5, "H", 8, "#000", 700, "middle")


def histogram(s, x, y, w=160, h=56):
    s.rect(x, y, w, h, "#000", r=6, opacity=0.38)
    rng = np.random.default_rng(1)
    v = np.convolve(rng.random(48), np.ones(5) / 5, "same")
    for i, a in enumerate(v):
        bh = a * (h - 12)
        s.rect(x + 4 + i * (w - 8) / 48, y + h - 4 - bh, (w - 8) / 48 - 0.6, bh, "#FFFFFF", opacity=0.85)
    s.text(x + 6, y + 12, "LUMA", 9, "#99FFBB", 700, family="mono")


def tag(s, x, y, name):
    p = os.path.join(HUD, "tag", f"tag_{name}.png")
    im = Image.open(p)
    w = im.width / 2
    s.image(x - w / 2, y, w, 24, p, "xMidYMid meet")


def camera_drawer(s, x0, w, H, thermal=False):
    """Pull-up camera drawer: 176 dp tall over the bottom of the video, above the telemetry strip (which stays)."""
    top = H - 48 - 184
    s.rect(x0 + 12, top, w - 24, 176, "#0B0D0C", r=20, opacity=0.78)
    s.rect(x0 + 12.5, top + 0.5, w - 25, 175, "none", r=19.5, stroke="#FFFFFF", sw=1, opacity=0.18)
    cols = [("lens_standard", "LENS", ["84° Std", "150° Wide"], 0), ("ev", "EV", None, None), ("wb", "WB", ["Auto", "Sun", "Cloud", "Shade"], 0),
            ("af", "FOCUS", ["AF", "MF"], 0), ("light", "LIGHT", ["Off", "On"], 0)]
    cx = x0 + 32
    colw = (w - 64) / 5
    for i, (g, lab, opts, sel) in enumerate(cols):
        x = cx + i * colw
        glyph(s, g, x, top + 16, 22)
        s.text(x + 30, top + 32, lab, 11, "#BBCCDD", 700, family="mono")
        if opts:
            ox = x
            for j, o in enumerate(opts):
                ow = len(o) * 7.4 + 20
                if ox + ow > x + colw - 8:
                    break
                s.rect(ox, top + 50, ow, 32, "#E0AB59" if j == sel else "#FFFFFF", r=16, opacity=1 if j == sel else 0.12)
                s.text(ox + ow / 2, top + 71, o, 13, "#241C0C" if j == sel else "#FFFFFF", 500, "middle")
                ox += ow + 6
        else:
            s.rect(x, top + 62, colw - 24, 6, "#FFFFFF", r=3, opacity=0.25)
            s.rect(x + (colw - 24) / 2 - 2, top + 54, 4, 22, "#E0AB59", r=2)
            s.text(x + (colw - 24) / 2, top + 96, "+0.0", 13, "#FFFFFF", 700, "middle", family="mono")
    # second row: thermal palette chips (only while thermal is on) + overlays
    y2 = top + 116
    s.text(cx, y2 + 6, "THERMAL PALETTE" if thermal else "LOOK", 11, "#BBCCDD", 700, family="mono")
    if thermal:
        for j, n in enumerate(["whitehot", "blackhot", "ironbow", "rainbow"]):
            s.image(cx + j * 60, y2 + 16, 48, 28, os.path.join(HUD, "chip", f"palette_{n}{'_selected' if n == 'ironbow' else ''}.png"), "xMidYMid meet")
    else:
        for j, o in enumerate(["Natural", "Flat", "Vivid"]):
            s.rect(cx + j * 84, y2 + 16, 76, 30, "#E0AB59" if j == 0 else "#FFFFFF", r=15, opacity=1 if j == 0 else 0.12)
            s.text(cx + j * 84 + 38, y2 + 36, o, 13, "#241C0C" if j == 0 else "#FFFFFF", 500, "middle")
    ox = x0 + w - 32 - 3 * 52
    s.text(ox, y2 + 6, "OVERLAYS", 11, "#BBCCDD", 700, family="mono")
    for j, (g, on) in enumerate((("grid", False), ("histogram", True), ("view_map", True))):
        btn(s, g, ox + 22 + j * 52, y2 + 32, 40, "active" if on else "default")


def hud_screen(path, bgname, aspect="16x9", mode=None, drawer=False, shade=None, landing=False):
    if aspect == "16x9":
        W, H, PW, PH = 1280, 720, 1920, 1080
    else:
        W, H, PW, PH = 1600, 720, 2400, 1080
    s = L.Svg(W, H, PW, PH)
    s.rect(0, 0, W, H, "#000")
    fx = (W - 1280) / 2
    im = bgimg(bgname, mode)
    s.image(fx, 0, 1280, 720, uri(im.resize((1920, 1080))), "none")
    wide = W > 1280
    # rails: inside the frame at 16:9, inside the pillarbox bars when wider
    lcx = (fx / 2) if wide else 40
    rcx = (W - fx / 2) if wide else W - 88
    reticle(s, W / 2, H / 2)
    gimbal_scale(s, fx + 1280 - 26, H * 0.28, (H - 48 - 184 - 34) if drawer else H * 0.72)   # shortened above the open drawer
    top_bar(s, 0, W, compact=False, thermal=mode == "thermal")
    left_rail(s, lcx, 56, landing)
    right_rail(s, rcx, 52, H, "active" if mode == "thermal" else "default", "active" if mode == "night" else "default")
    if mode:
        tag(s, W / 2, 48, {"thermal": "thermal_ironbow", "night": "night_green"}[mode])
    # info lines under the left rail are moved into the frame's top-left, below the top bar
    if not drawer:
        minimap(s, fx + 16 if not wide else fx + 16, H - 48 - 16 - 150)
        histogram(s, fx + 1280 - 26 - 40 - 160 - (0 if wide else 100), H - 48 - 16 - 56)
    else:
        camera_drawer(s, fx, 1280, H, thermal=mode == "thermal")
    bottom_strip(s, 0, W, H, drawer)
    # REC chip example in the info strip
    if mode is None and not drawer:
        s.rect(W / 2 - 46, 48, 92, 24, "#0B0D0C", r=12, opacity=0.62)
        s.circle(W / 2 - 30, 60, 5, "#E5484D")
        s.text(W / 2 + 10, 65, "REC 00:42", 12, "#FFFFFF", 700, "middle", family="mono")
    if shade == "hint":
        s.image(W / 2 - 80, 0, 160, 40, os.path.join(HUD, "pill", "shade_hint_2x.png"), "xMidYMid meet")
    s.save(path)


def shade_pull(path):
    """Four states of the pull-down over the flight HUD: hover hint, dragging 35 percent, settled open, dismissing."""
    import gen_mocks as GM
    W, H = 1280, 720
    tiles = []
    for i, st in enumerate(("hint", "drag", "open", "heads_up")):
        s = L.Svg(W, H, 960, 540)
        s.image(0, 0, W, H, uri(bgimg("bg_16x9.png").resize((1280, 720))), "none")
        top_bar(s, 0, W)
        left_rail(s, 40, 56)
        right_rail(s, W - 88, 52, H)
        bottom_strip(s, 0, W, H)
        if st == "hint":
            s.image(W / 2 - 80, 40, 160, 40, os.path.join(HUD, "pill", "shade_hint_2x.png"), "xMidYMid meet")
            s.text(W / 2, 112, "1. pointer in the top 6 dp for 250 ms: the hint fades in under the HUD top bar (150 ms)", 15, "#FFFFFF", 500, "middle", halo=("#000000AA", 3))
        elif st in ("drag", "open"):
            frac = 0.38 if st == "drag" else 1.0
            sh = 560 * frac
            s.rect(0, 0, W, H, "#000", opacity=0.32 * frac)
            s.add(f'<path d="M0 0 H{W} V{sh-28} A28 28 0 0 1 {W-28} {sh} H28 A28 28 0 0 1 0 {sh-28} Z" fill="{L.DARK["surface-container"]}" fill-opacity="0.98"/>')
            if st == "open":
                s.text(28, 64, "20:30", 40, L.DARK["on-surface"])
                s.text(140, 56, "Sat, Oct 24", 14, L.DARK["on-surface-variant"])
                for j, (lab, sub, ic, on) in enumerate(GM.QS[:6]):
                    GM.qs_tile(s, 28 + (j % 2) * 296, 96 + (j // 2) * 76, 284, lab, sub, ic, on)
                GM.notification_group(s, 640, 96, 612)
                s.rect(W / 2 - 16, sh - 14, 32, 4, L.DARK["on-surface-variant"], r=2, opacity=0.5)
                s.text(W / 2, sh + 40, "3. released past 40 percent: settles open (280 ms, emphasized decelerate). Scrim 32 percent.", 15, "#FFFFFF", 500, "middle", halo=("#000000AA", 3))
            else:
                s.rect(W / 2 - 16, sh - 14, 32, 4, L.DARK["on-surface-variant"], r=2, opacity=0.5)
                s.text(W / 2, sh + 40, "2. dragging: the sheet follows the pointer 1:1; scrim alpha = 0.32 x progress", 15, "#FFFFFF", 500, "middle", halo=("#000000AA", 3))
        else:
            # heads-up while flying: below the top bar, never over the rails
            x0, w0 = W / 2 - 220, 440
            GM.card(s, x0, 48, w0, 92, L.DARK["surface-container-high"], 24, 0.97, 3)
            s.image(x0 + 16, 64, 20, 20, GM.MONO("dronebudz"), "xMidYMid meet")
            s.text(x0 + 44, 79, "DroneBudz  ·  now", 12, L.DARK["on-surface-variant"], 500)
            s.text(x0 + 16, 106, "Rennick", 14, L.DARK["on-surface"], 500)
            s.text(x0 + 16, 126, "You are getting close. The cruiser should be outside.", 14, L.DARK["on-surface-variant"])
            s.text(W / 2, 176, "4. heads-up in flight: 440 dp wide, 8 dp under the top bar, swipe up to dismiss", 15, "#FFFFFF", 500, "middle", halo=("#000000AA", 3))
        tiles.append(s.save(None))
    sheet = Image.new("RGB", (1920, 1080))
    for i, t in enumerate(tiles):
        sheet.paste(t.convert("RGB"), ((i % 2) * 960, (i // 2) * 540))
    sheet.save(path, quality=90)


def build():
    os.makedirs(L.REAL, exist_ok=True)
    hud_screen(os.path.join(L.REAL, "60_hud_16x9.jpg"), "bg_16x9.png", "16x9")
    hud_screen(os.path.join(L.REAL, "61_hud_16x9_thermal_drawer.jpg"), "bg_16x9.png", "16x9", "thermal", drawer=True)
    hud_screen(os.path.join(L.REAL, "62_hud_phone_20x9_night.jpg"), "bg_16x9.png", "20x9", "night")
    hud_screen(os.path.join(L.REAL, "63_hud_phone_20x9.jpg"), "bg_16x9.png", "20x9", None, drawer=False)
    shade_pull(os.path.join(L.REAL, "64_hud_shade_pull_states.jpg"))
    print("hud mocks")


if __name__ == "__main__":
    build()
