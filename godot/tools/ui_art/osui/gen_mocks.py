"""Mock renders of the tablet/phone OS for lane osui. These are the visual target for DSH session B.

Tablet: 1280 x 720 dp rendered at 1920 x 1080 (1.5x). Phone: 412 x 915 dp rendered at 1080 x 2400 (2.625x).
Everything is drawn from the shipped assets (icons, components, system glyphs, map renderer), so a screen that looks
right here can be rebuilt in Godot with the same files and numbers. Outputs: docs/realism/osui/*.jpg
"""
import os, io, base64, math
from PIL import Image, ImageFilter, ImageEnhance
import osui_lib as L
import gen_map as M

T = L.DARK
NOTIFY = os.path.normpath(os.path.join(L.GODOT, "..", "..", "AeroSim-notify", "godot"))
WALL = os.path.join(NOTIFY, "assets", "ui", "tablet_red_barn.jpg")
ICON = lambda k: os.path.join(L.OUT, "icons", "circle", "192", f"{k}.png")
MONO = lambda k: os.path.join(L.OUT, "icons", "mono", "48", f"{k}.png")
AV = lambda k: os.path.join(L.UI, "sizes", "96", f"avatar_{k}.png")
TAB = (1280, 720, 1920, 1080)
PHO = (412, 915, 1080, 2400)
APPS = {"dronebudz": "DroneBudz", "vidtube": "VidTube Studio", "photos": "Photos", "jobs": "Jobs", "casebook": "Casebook",
        "facade": "Facade", "map": "Map", "settings": "Settings", "weather": "Weather", "camera": "Camera", "clock": "Clock",
        "files": "Files", "phone": "Phone", "notes": "Field Notes", "store": "Facade Apps"}


def uri(im, fmt="JPEG"):
    b = io.BytesIO()
    (im.convert("RGB") if fmt == "JPEG" else im).save(b, fmt, quality=88)
    return f"data:image/{'jpeg' if fmt == 'JPEG' else 'png'};base64," + base64.b64encode(b.getvalue()).decode()


_wall = {}


def wall(w_px, h_px, blur=0, dim=1.0):
    key = (w_px, h_px, blur, dim)
    if key not in _wall:
        im = Image.open(WALL).convert("RGB")
        sw, sh = im.size
        s = max(w_px / sw, h_px / sh)
        im = im.resize((int(sw * s) + 1, int(sh * s) + 1), Image.LANCZOS)
        l, t = (im.width - w_px) // 2, (im.height - h_px) // 2
        im = im.crop((l, t, l + w_px, t + h_px))
        if blur:
            im = im.filter(ImageFilter.GaussianBlur(blur))
        if dim != 1.0:
            im = ImageEnhance.Brightness(im).enhance(dim)
        _wall[key] = uri(im)
    return _wall[key]


def sglyph(s, name, x, y, size, colour, filled=False):
    s.icon(name, x, y, size, colour, filled=filled)


# ------------------------------------------------------------------ shared chrome
def status_bar(s, w, y=0, h=28, colour="#FFFFFF", notif=("dronebudz", "jobs"), dnd=False, clock="20:30", pad=16, scale=1.0):
    fs = 14 * scale
    s.text(pad, y + h / 2 + fs * 0.36, clock, fs, colour, 500)
    x = pad + 46 * scale
    for k in notif:
        s.image(x, y + h / 2 - 8 * scale, 16 * scale, 16 * scale, MONO(k), "xMidYMid meet", 0.95)
        x += 22 * scale
    rx = w - pad
    s.text(rx, y + h / 2 + fs * 0.36, "86%", fs, colour, 500, "end")
    rx -= 30 * scale + 18 * scale
    s.icon("battery_5_bar", rx + 4 * scale, y + h / 2 - 9 * scale, 18 * scale, colour)
    rx -= 22 * scale
    s.icon("signal_cellular_alt", rx, y + h / 2 - 9 * scale, 18 * scale, colour)
    rx -= 22 * scale
    s.icon("wifi", rx, y + h / 2 - 9 * scale, 18 * scale, colour, filled=True)
    if dnd:
        rx -= 22 * scale
        s.icon("do_not_disturb_on", rx, y + h / 2 - 9 * scale, 18 * scale, colour, filled=True)


def pill(s, w, h, colour="#FFFFFF", width=108):
    s.rect(w / 2 - width / 2, h - 12, width, 4, colour, r=2, opacity=0.85)


def app_icon(s, k, x, y, size, label=None, label_colour="#FFFFFF", fs=12, badge=None, shadow=True, maxw=None):
    if shadow:
        s.circle(x + size / 2, y + size / 2 + 1.2, size / 2, "#000", opacity=0.22)
    s.image(x, y, size, size, ICON(k), "xMidYMid meet")
    if badge is not None:
        if badge == "dot":
            s.circle(x + size * 0.86, y + size * 0.14, 4.5, T["badge"], stroke="#00000033", sw=0.5)
        else:
            bw = 16 if len(badge) == 1 else 22
            s.rect(x + size * 0.86 - bw / 2, y + size * 0.14 - 8, bw, 16, T["badge"], r=8)
            s.text(x + size * 0.86, y + size * 0.14 + 3.8, badge, 11, "#FFFFFF", 500, "middle")
    if label:
        s.text(x + size / 2, y + size + fs + 6, label, fs, label_colour, 400, "middle",
               halo=("#00000066", 2.2) if label_colour == "#FFFFFF" else None)


def card(s, x, y, w, h, fill, r=16, op=1.0, elev=0):
    f = f' filter="url(#{s.shadow(elev)})"' if elev else ""
    s.add(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{fill}" fill-opacity="{op}"{f}/>')


def switch(s, x, y, on=True, th=T, dis=False):
    if on:
        s.rect(x, y, 52, 32, th["primary"], r=16, opacity=0.38 if dis else 1)
        s.circle(x + 36, y + 16, 12, th["on-primary"])
        s.icon("check", x + 28, y + 8, 16, th["on-primary-container"] if th is T else th["primary"])
    else:
        s.rect(x + 1, y + 1, 50, 30, th["surface-container-highest"], r=15, stroke=th["outline"], sw=2)
        s.circle(x + 16, y + 16, 8, th["outline"])


def button(s, x, y, text, kind="filled", w=None, th=T, h=40, icon=None):
    w = w or (len(text) * 7.6 + 48 + (26 if icon else 0))
    fill, col, ol = {"filled": (th["primary"], th["on-primary"], None), "tonal": (th["secondary-container"], th["on-secondary-container"], None),
                     "outlined": ("none", th["primary"], th["outline"]), "text": ("none", th["primary"], None),
                     "danger": (th["error"], th["on-error"], None)}[kind]
    if fill != "none":
        s.rect(x, y, w, h, fill, r=h / 2)
    if ol:
        s.rect(x + 0.5, y + 0.5, w - 1, h - 1, "none", r=h / 2 - 0.5, stroke=ol, sw=1)
    tx = x + w / 2 + (9 if icon else 0)
    if icon:
        s.icon(icon, tx - len(text) * 3.8 - 24, y + h / 2 - 9, 18, col)
    s.text(tx, y + h / 2 + 5, text, 14, col, 500, "middle")
    return w


# ------------------------------------------------------------------ tablet home
def home_widgets(s, x, y, w):
    """Field-note widget (game-specific, kept), drawn on the M3 widget surface with the kit dials."""
    card(s, x, y, w, 196, T["surface-container"], 24, 0.92)
    s.text(x + 20, y + 30, "FIELD NOTE", 11, T["primary"], 500, tracking=1.2)
    s.text(x + 20, y + 56, "Halloway Valley", 22, T["on-surface"], 400)
    s.text(x + 20, y + 78, "10°C · wind 8.5 m/s · holding its autumn colour", 13, T["on-surface-variant"])
    d = os.path.join(L.UI, "tablet", "dials")
    for i, (face, needle, lab) in enumerate((("dial_wind_face", "dial_needle_wind", "WIND"), ("dial_battery_face", "dial_needle_battery", "DRONE"))):
        cx = x + 20 + i * 92
        s.image(cx, y + 92, 80, 80, os.path.join(d, face + ".png"), "xMidYMid meet")
        if i == 1:
            s.image(cx, y + 92, 80, 80, os.path.join(d, "dial_battery_fill.png"), "xMidYMid meet")
        s.add(f'<g transform="rotate({250 - 90 if i == 0 else 60} {cx + 40} {y + 132})">')
        s.image(cx, y + 92, 80, 80, os.path.join(d, needle + ".png"), "xMidYMid meet")
        s.add("</g>")
    s.text(x + 212, y + 116, "CREW", 11, T["primary"], 500, tracking=1)
    s.text(x + 212, y + 136, "10 on the server · 9+ unread", 13, T["on-surface"])
    s.text(x + 212, y + 160, "CASEBOOK", 11, T["primary"], 500, tracking=1)
    s.text(x + 212, y + 180, "Rennick has the file.", 13, T["on-surface"])


def tablet_home(path):
    W, H, PW, PH = TAB
    s = L.Svg(W, H, PW, PH)
    s.image(0, 0, W, H, wall(PW, PH))
    s.rect(0, 0, W, 96, s.lin([(0, "#000", 0.42), (1, "#000", 0)]))
    status_bar(s, W)
    # At a Glance
    s.text(48, 84, "Saturday, Oct 24", 24, "#FFFFFF", 400, halo=("#00000040", 3))
    s.icon("partly_cloudy_day", 48, 98, 22, "#FFFFFF")
    s.text(76, 115, "10°C  ·  Light wind from the WSW", 15, "#FFFFFF", 400, halo=("#00000050", 2.5))
    home_widgets(s, 48, 150, 420)
    # app grid: 5 columns, cell 112 x 108, icon 60
    grid = [["dronebudz", "vidtube", "photos", "jobs", "casebook"], ["facade", "map", "settings", "store", None]]
    badges = {"dronebudz": "9+", "jobs": "dot", "casebook": "dot"}
    gx0, gy0 = 600, 150
    for r, row in enumerate(grid):
        for c, k in enumerate(row):
            x, y = gx0 + c * 128, gy0 + r * 118
            if k is None:
                # folder: 2x2 preview of the first four apps on a tonal disc
                s.circle(x + 30, y + 30, 30, T["surface-container-highest"], opacity=0.92)
                for i, kk in enumerate(["weather", "clock", "files", "camera"]):
                    s.image(x + 9 + (i % 2) * 22, y + 9 + (i // 2) * 22, 20, 20, ICON(kk), "xMidYMid meet")
                s.text(x + 30, y + 78, "Valley tools", 12, "#FFFFFF", 400, "middle", halo=("#00000066", 2.2))
                continue
            app_icon(s, k, x, y, 60, APPS[k], badge=badges.get(k))
    # page dots
    s.circle(W / 2 - 6, 590, 3.5, "#FFFFFF")
    s.circle(W / 2 + 6, 590, 3.5, "#FFFFFF", opacity=0.45)
    # dock: tonal container, 6 icons + a divider + 1 recent app
    dk = ["dronebudz", "photos", "map", "facade", "camera", "phone"]
    dw = len(dk) * 72 + 16 + 72 + 24
    dx = (W - dw) / 2
    card(s, dx, 610, dw, 84, T["surface-container-high"], 28, 0.72)
    for i, k in enumerate(dk):
        app_icon(s, k, dx + 16 + i * 72, 622, 60, shadow=False)
    s.rect(dx + 16 + len(dk) * 72 + 4, 632, 1.5, 40, "#FFFFFF", opacity=0.35)
    app_icon(s, "vidtube", dx + 16 + len(dk) * 72 + 18, 622, 60, shadow=False)
    pill(s, W, H)
    s.save(path)


def tablet_drawer(path):
    W, H, PW, PH = TAB
    s = L.Svg(W, H, PW, PH)
    s.image(0, 0, W, H, wall(PW, PH, blur=22, dim=0.55))
    status_bar(s, W)
    # Android 14 large-screen drawer: a floating panel, 28 radius, surface-container at 94 percent
    px, py, pw, ph = 140, 48, 1000, 660
    card(s, px, py, pw, ph, T["surface-container"], 28, 0.96, 3)
    # search bar
    s.rect(px + 24, py + 20, pw - 48, 56, T["surface-container-highest"], r=28)
    s.icon("search", px + 44, py + 36, 24, T["on-surface-variant"])
    s.text(px + 84, py + 54, "Search apps", 16, T["on-surface-variant"])
    s.icon("mic", px + pw - 72, py + 36, 24, T["on-surface-variant"])
    # suggestions row (predicted apps) then a divider
    s.text(px + 32, py + 104, "Suggested", 12, T["on-surface-variant"], 500, tracking=0.5)
    sug = ["dronebudz", "map", "photos", "jobs", "vidtube", "facade"]
    cw = (pw - 64) / 6
    for i, k in enumerate(sug):
        app_icon(s, k, px + 32 + i * cw + cw / 2 - 30, py + 118, 60, APPS[k], T["on-surface"], 13, shadow=False,
                 badge="9+" if k == "dronebudz" else None)
    s.rect(px + 32, py + 222, pw - 64, 1, T["outline-variant"])
    # all apps, alphabetical, 6 columns, 112 dp rows, with a letter fast-scroll rail
    allk = sorted(APPS, key=lambda k: APPS[k].lower())
    clip = s.clip_rect(px, py + 223, pw, ph - 223, 0)
    inner = []
    s2 = L.Svg(W, H)
    for i, k in enumerate(allk):
        c, r = i % 6, i // 6
        app_icon(s2, k, px + 32 + c * cw + cw / 2 - 30, py + 246 + r * 118, 60, APPS[k], T["on-surface"], 13, shadow=False)
    s.group("".join(s2.body), clip=clip)
    # scroll fade (bottom), 48 dp
    pclip = s.clip_rect(px, py, pw, ph, 28)
    s.group(f'<rect x="{px}" y="{py + ph - 64}" width="{pw}" height="64" fill="{s.lin([(0, T["surface-container"], 0), (1, T["surface-container"], 1)])}"/>', clip=pclip)
    # fast-scroll rail
    for i, ch in enumerate("CDFJMPSVW"):
        s.text(px + pw - 22, py + 260 + i * 34, ch, 12, T["primary"] if ch == "C" else T["on-surface-variant"], 500, "middle")
    s.rect(px + pw - 30, py + 248, 16, 18, T["primary-container"], r=8, opacity=0.6)
    pill(s, W, H)
    s.save(path)


# ------------------------------------------------------------------ phone home / drawer
def phone_home(path):
    W, H, PW, PH = PHO
    s = L.Svg(W, H, PW, PH)
    s.image(0, 0, W, H, wall(PW, PH))
    s.rect(0, 0, W, 120, s.lin([(0, "#000", 0.45), (1, "#000", 0)]))
    status_bar(s, W, h=32)
    s.text(24, 92, "Sat, Oct 24", 22, "#FFFFFF", 400, halo=("#00000040", 3))
    s.icon("partly_cloudy_day", 24, 106, 20, "#FFFFFF")
    s.text(50, 122, "10°C", 15, "#FFFFFF", 400, halo=("#00000050", 2.5))
    # field-note widget 4 x 2 cells
    card(s, 16, 156, W - 32, 168, T["surface-container"], 24, 0.92)
    s.text(36, 186, "FIELD NOTE", 11, T["primary"], 500, tracking=1.2)
    s.text(36, 212, "Halloway Valley", 20, T["on-surface"])
    d = os.path.join(L.UI, "tablet", "dials")
    s.image(36, 226, 80, 80, os.path.join(d, "dial_wind_face.png"), "xMidYMid meet")
    s.image(126, 226, 80, 80, os.path.join(d, "dial_battery_face.png"), "xMidYMid meet")
    s.image(126, 226, 80, 80, os.path.join(d, "dial_battery_fill.png"), "xMidYMid meet")
    s.text(222, 252, "CREW", 11, T["primary"], 500, tracking=1)
    s.text(222, 270, "9+ unread", 13, T["on-surface"])
    s.text(222, 292, "CASEBOOK", 11, T["primary"], 500, tracking=1)
    s.text(222, 310, "Rennick has the file.", 12, T["on-surface"])
    rows = [["dronebudz", "vidtube", "photos", "jobs"], ["casebook", "facade", "map", "settings"]]
    cw = (W - 16) / 4
    for r, row in enumerate(rows):
        for c, k in enumerate(row):
            app_icon(s, k, 8 + c * cw + cw / 2 - 28, 520 + r * 104, 56, APPS[k], fs=12,
                     badge={"dronebudz": "9+", "jobs": "dot"}.get(k))
    s.circle(W / 2 - 6, 744, 3.2, "#FFFFFF")
    s.circle(W / 2 + 6, 744, 3.2, "#FFFFFF", opacity=0.45)
    for c, k in enumerate(["phone", "dronebudz", "camera", "map"]):
        app_icon(s, k, 8 + c * cw + cw / 2 - 28, 764, 56)
    # search pill at the bottom of the dock
    s.rect(16, 840, W - 32, 52, T["surface-container-high"], r=26, opacity=0.9)
    s.icon("search", 34, 854, 24, T["on-surface-variant"])
    s.text(70, 872, "Search", 16, T["on-surface-variant"])
    s.icon("mic", W - 64, 854, 24, T["on-surface-variant"])
    pill(s, W, H)
    s.save(path)


def phone_drawer(path):
    W, H, PW, PH = PHO
    s = L.Svg(W, H, PW, PH)
    s.image(0, 0, W, H, wall(PW, PH, blur=30, dim=0.45))
    card(s, 0, 40, W, H - 40, T["surface-container"], 28, 0.97)
    status_bar(s, W, h=32)
    s.rect(W / 2 - 16, 50, 32, 4, T["on-surface-variant"], r=2, opacity=0.4)
    s.rect(16, 66, W - 32, 56, T["surface-container-highest"], r=28)
    s.icon("search", 32, 82, 24, T["on-surface-variant"])
    s.text(68, 100, "Search apps", 16, T["on-surface-variant"])
    s.icon("more_vert", W - 56, 82, 24, T["on-surface-variant"])
    cw = (W - 16) / 4
    for i, k in enumerate(["dronebudz", "map", "photos", "jobs"]):
        app_icon(s, k, 8 + i * cw + cw / 2 - 28, 142, 56, APPS[k], T["on-surface"], 12, shadow=False)
    s.rect(24, 236, W - 48, 1, T["outline-variant"])
    allk = sorted(APPS, key=lambda k: APPS[k].lower())
    for i, k in enumerate(allk):
        c, r = i % 4, i // 4
        app_icon(s, k, 8 + c * cw + cw / 2 - 28, 256 + r * 104, 56, APPS[k], T["on-surface"], 12, shadow=False)
    s.rect(0, H - 120, W, 120, s.lin([(0, T["surface-container"], 0), (1, T["surface-container"], 1)]))
    pill(s, W, H)
    s.save(path)


# ------------------------------------------------------------------ notification shade + quick settings
QS = [("Drone link", "Halloway relay", "wifi", True), ("Bluetooth", "Controller", "bluetooth", True),
      ("Do Not Disturb", "Off", "do_not_disturb_on", False), ("Flashlight", "", "flashlight_on", False),
      ("Battery Saver", "", "battery_saver", False), ("Night camera", "Fitted", "nightlight", False),
      ("Thermal", "Fitted", "thermostat", True), ("Screen record", "", "screen_record", False)]


def qs_tile(s, x, y, w, label, sub, icon, on, h=64):
    fill = T["primary"] if on else T["surface-container-highest"]
    col = T["on-primary"] if on else T["on-surface"]
    s.rect(x, y, w, h, fill, r=h / 2)
    if w > h + 8:
        s.circle(x + 32, y + h / 2, 22, "#00000022" if on else "#FFFFFF10")
        s.icon(icon, x + 20, y + h / 2 - 12, 24, col, filled=on)
        s.text(x + 64, y + (h / 2 - 2 if sub else h / 2 + 5), label, 14, col, 500)
        if sub:
            s.text(x + 64, y + h / 2 + 16, sub, 12, col, 400, opacity=0.8)
        s.icon("chevron_right", x + w - 32, y + h / 2 - 10, 20, col, opacity=0.7)
    else:
        s.icon(icon, x + w / 2 - 12, y + h / 2 - 12, 24, col, filled=on)


def notification_group(s, x, y, w):
    """DroneBudz conversation group (expanded), returns the bottom y."""
    h = 228
    card(s, x, y, w, h, T["surface-container-high"], 24)
    s.image(x + 16, y + 16, 20, 20, MONO("dronebudz"), "xMidYMid meet")
    s.text(x + 44, y + 31, "DroneBudz", 12, T["on-surface"], 500)
    s.text(x + 116, y + 31, "·  #general  ·  now", 12, T["on-surface-variant"])
    s.icon("expand_less", x + w - 40, y + 14, 24, T["on-surface-variant"])
    msgs = [("rennick", "Rennick", "You are getting close. The cruiser should be outside."), ("maya", "Maya", "Ridge clip is up. 1,248 views already!"),
            ("jo", "Jo", "Can you grab a photo of the boat launch before dark?")]
    for i, (k, n, t) in enumerate(msgs):
        yy = y + 52 + i * 44
        clip = s.clip_circle(x + 36, yy + 16, 16)
        s.image(x + 20, yy, 32, 32, AV(k), clip=clip)
        s.text(x + 64, yy + 13, n, 14, T["on-surface"], 500)
        s.text(x + 64, yy + 31, t, 14, T["on-surface-variant"])
    by = y + h - 52
    button(s, x + 56, by, "Reply", "tonal", icon="reply")
    button(s, x + 166, by, "Mark as read", "text")
    return y + h


def notif_card(s, x, y, w, app, title, body, time="2 min", h=88, actions=None, progress=None, thumb=None):
    card(s, x, y, w, h, T["surface-container-high"], 24)
    s.image(x + 16, y + 16, 20, 20, MONO(app), "xMidYMid meet")
    s.text(x + 44, y + 31, APPS[app], 12, T["on-surface"], 500)
    s.text(x + 44 + len(APPS[app]) * 7.0 + 6, y + 31, "·  " + time, 12, T["on-surface-variant"])
    s.icon("expand_more", x + w - 40, y + 14, 24, T["on-surface-variant"])
    tx = x + 16
    if thumb:
        s.image(x + w - 112, y + 44, 96, 54, thumb, clip=s.clip_rect(x + w - 112, y + 44, 96, 54, 8))
    s.text(tx, y + 58, title, 14, T["on-surface"], 500)
    s.text(tx, y + 78, body, 14, T["on-surface-variant"])
    if progress is not None:
        s.rect(tx, y + 92, w - (150 if thumb else 32), 4, T["secondary-container"], r=2)
        s.rect(tx, y + 92, (w - (150 if thumb else 32)) * progress, 4, T["primary"], r=2)
    if actions:
        ax = tx - 12
        for a in actions:
            ax += button(s, ax, y + h - 46, a, "text") + 4
    return y + h


def tablet_shade(path):
    W, H, PW, PH = TAB
    s = L.Svg(W, H, PW, PH)
    s.image(0, 0, W, H, wall(PW, PH, blur=16, dim=0.6))
    s.rect(0, 0, W, H, "#000000", opacity=0.45)          # scrim behind the shade
    card(s, 0, -28, W, H + 16, T["surface-container"], 28, 0.98, 3)   # shade sheet: full height on tablets, bottom radius 28
    # header: big clock + date, status icons on the right
    s.text(28, 64, "20:30", 40, T["on-surface"], 400)
    s.text(140, 52, "Sat, Oct 24", 14, T["on-surface-variant"])
    s.text(140, 70, "Halloway Personal", 12, T["on-surface-variant"])
    status_bar(s, W, y=36, h=24, colour=T["on-surface"], notif=(), clock="")
    # quick settings (left pane): brightness slider + 2-column large tiles
    s.rect(28, 96, 580, 48, T["surface-container-highest"], r=24)
    s.rect(28, 96, 360, 48, T["primary"], r=24)
    s.icon("brightness_high", 44, 108, 24, T["on-primary"])
    for i, (lab, sub, ic, on) in enumerate(QS):
        qs_tile(s, 28 + (i % 2) * 296, 160 + (i // 2) * 76, 284, lab, sub, ic, on)
    # footer row: page dots, edit, settings, power
    s.circle(318 - 6, 476, 3, T["on-surface"]); s.circle(318 + 6, 476, 3, T["on-surface-variant"], opacity=0.5)
    for i, ic in enumerate(["edit", "settings", "power_settings_new"]):
        s.circle(468 + i * 52, 476, 20, T["surface-container-highest"])
        s.icon(ic, 456 + i * 52, 464, 24, T["on-surface"])
    # notifications (right pane)
    x0, w0 = 640, 612
    y = notification_group(s, x0, 96, w0) + 8
    y = notif_card(s, x0, y, w0, "vidtube", "Uploading “Ridge at golden hour”", "62% · about 20 seconds left", "now", 112,
                   progress=0.62, thumb=os.path.join(L.UI, "studio_banner.jpg")) + 8
    y = notif_card(s, x0, y, w0, "jobs", "New job: Toby Farm roof survey", "$140 · 1.2 km · photo set", "6 min", 120,
                   actions=["View", "Accept"]) + 18
    s.text(x0 + 4, y + 8, "Silent", 13, T["on-surface-variant"], 500)
    s.text(x0 + w0 - 4, y + 8, "Clear all", 13, T["primary"], 500, "end")
    notif_card(s, x0 + 0, y + 20, w0, "facade", "Thermal camera shipped", "MugShot Motors · arrives at the east gate", "1 h", 76)
    # handle
    s.rect(W / 2 - 16, H - 14, 32, 4, T["on-surface-variant"], r=2, opacity=0.5)
    s.save(path)


def phone_shade(path):
    W, H, PW, PH = PHO
    s = L.Svg(W, H, PW, PH)
    s.image(0, 0, W, H, wall(PW, PH, blur=20, dim=0.5))
    s.rect(0, 0, W, H, "#000", opacity=0.55)
    s.text(20, 44, "20:30", 16, T["on-surface"], 500)
    s.text(76, 44, "Sat, Oct 24", 14, T["on-surface-variant"])
    status_bar(s, W, y=26, h=24, colour=T["on-surface"], notif=(), clock="")
    # collapsed QS: 6 round tiles + brightness
    for i, (lab, sub, ic, on) in enumerate(QS[:6]):
        qs_tile(s, 16 + i * 64, 70, 56, lab, sub, ic, on, h=56)
    s.rect(16, 140, W - 32, 44, T["surface-container-highest"], r=22)
    s.rect(16, 140, 230, 44, T["primary"], r=22)
    s.icon("brightness_high", 30, 150, 24, T["on-primary"])
    s.rect(W / 2 - 16, 198, 32, 4, T["on-surface-variant"], r=2, opacity=0.5)
    y = notification_group(s, 8, 214, W - 16) + 6
    y = notif_card(s, 8, y, W - 16, "vidtube", "Uploading “Ridge at golden hour”", "62% · 20 s left", "now", 104, progress=0.62) + 6
    y = notif_card(s, 8, y, W - 16, "jobs", "New job: Toby Farm roof survey", "$140 · 1.2 km", "6 min", 120, actions=["View", "Accept"]) + 6
    button(s, W / 2 - 140, y + 12, "Manage", "tonal", w=130)
    button(s, W / 2 + 10, y + 12, "Clear all", "tonal", w=130)
    s.save(path)


# ------------------------------------------------------------------ settings (two pane, M3 list + switches + slider + dialog)
def tablet_settings(path):
    W, H, PW, PH = TAB
    s = L.Svg(W, H, PW, PH)
    s.rect(0, 0, W, H, T["surface"])
    status_bar(s, W, colour=T["on-surface"])
    # left pane: list
    s.text(24, 84, "Settings", 32, T["on-surface"], 400)
    s.rect(24, 104, 384, 48, T["surface-container-high"], r=24)
    s.icon("search", 40, 116, 24, T["on-surface-variant"])
    s.text(76, 134, "Search settings", 16, T["on-surface-variant"])
    rows = [("wifi", "Network & drone link", "Halloway relay"), ("bluetooth", "Connected devices", "Controller"),
            ("apps", "Apps", "Facade Apps, defaults"), ("notifications", "Notifications", "History, conversations"),
            ("battery_full", "Battery", "86% · about 9 h left"), ("storage", "Storage", "41% used · 128 GB"),
            ("volume_up", "Sound & vibration", "Volume, haptics, Do Not Disturb"), ("display_settings", "Display", "Brightness, dark theme"),
            ("palette", "Wallpaper & style", "Colours, themed icons, app shape"), ("security", "Security & privacy", "Screen lock"),
            ("location_on", "Location", "On · 3 apps have access"), ("system_update", "System", "Halloway OS 14 · valley build")]
    for i, (ic, t1, t2) in enumerate(rows):
        y = 168 + i * 44
        if t1 == "Notifications":
            s.rect(16, y - 2, 400, 44, T["secondary-container"], r=22)
        s.icon(ic, 32, y + 8, 24, T["on-secondary-container"] if t1 == "Notifications" else T["on-surface-variant"])
        s.text(72, y + 18, t1, 15, T["on-surface"], 500 if t1 == "Notifications" else 400)
        s.text(72, y + 35, t2, 12, T["on-surface-variant"])
    # right pane: Notifications detail
    x0 = 448
    card(s, x0, 40, W - x0 - 16, H - 56, T["surface-container-low"], 28)
    s.icon("arrow_back", x0 + 16, 60, 24, T["on-surface"])
    s.text(x0 + 56, 80, "Notifications", 22, T["on-surface"])
    y = 116

    def section(title):
        nonlocal y
        s.text(x0 + 24, y + 14, title, 14, T["primary"], 500)
        y += 30

    def row(t1, t2=None, on=None, icon=None, chevron=False, h=58):
        nonlocal y
        tx = x0 + 24
        if icon:
            s.image(x0 + 24, y + h / 2 - 16, 32, 32, ICON(icon), "xMidYMid meet")
            tx = x0 + 72
        s.text(tx, y + (h / 2 - 3 if t2 else h / 2 + 5), t1, 16, T["on-surface"])
        if t2:
            s.text(tx, y + h / 2 + 16, t2, 14, T["on-surface-variant"])
        if on is not None:
            s.rect(W - 120, y + 12, 1, h - 24, T["outline-variant"]) if icon else None
            switch(s, W - 96, y + h / 2 - 16, on)
        if chevron:
            s.icon("chevron_right", W - 64, y + h / 2 - 12, 24, T["on-surface-variant"])
        y += h

    section("Manage")
    row("App notifications", "Control notifications from individual apps", chevron=True)
    row("Notification history", "Show recent and snoozed notifications", on=True)
    s.rect(x0 + 24, y + 4, W - x0 - 64, 1, T["outline-variant"]); y += 12
    section("DroneBudz channels")
    row("Messages", "Pop on screen · sound", on=True, icon="dronebudz")
    row("Mentions and DMs", "Pop on screen · sound · overrides Do Not Disturb", on=True, icon="dronebudz")
    row("Job alerts", "Pop on screen", on=True, icon="jobs")
    row("Server activity", "Silent · shown in the shade only", on=False, icon="dronebudz")
    s.rect(x0 + 24, y + 4, W - x0 - 64, 1, T["outline-variant"]); y += 12
    section("Do Not Disturb")
    row("Do Not Disturb", "Off · Will turn on automatically at 22:00", on=False)
    s.text(x0 + 24, y + 22, "Alert volume", 16, T["on-surface"])
    s.rect(x0 + 180, y + 8, 300, 16, T["primary"], r=8)
    s.rect(x0 + 486, y + 8, W - 40 - (x0 + 486), 16, T["secondary-container"], r=8)
    s.rect(x0 + 481, y - 6, 4, 44, T["primary"], r=2)
    s.save(path)


# ------------------------------------------------------------------ lock screen (notifications, DND, shortcuts)
def lock_screen(path, phone=False):
    W, H, PW, PH = PHO if phone else TAB
    s = L.Svg(W, H, PW, PH)
    s.image(0, 0, W, H, wall(PW, PH, blur=0, dim=0.62))
    status_bar(s, W, h=32 if phone else 28, notif=(), dnd=True, clock="")
    s.text(16 if phone else 16, 21 if phone else 19, "Halloway Personal", 13, "#FFFFFF", 400, opacity=0.9)
    if phone:
        s.text(W / 2, 250, "20", 150, T["on-primary-container"], 400, "middle")
        s.text(W / 2, 390, "30", 150, T["on-primary-container"], 400, "middle")
        s.text(W / 2, 96, "Sat, Oct 24  ·  10°C", 16, "#FFFFFF", 400, "middle")
        y, x, w = 440, 12, W - 24
    else:
        s.text(80, 320, "20:30", 150, T["on-primary-container"], 400)
        s.text(86, 360, "Saturday, Oct 24  ·  10°C  ·  Do Not Disturb until 07:00", 18, "#FFFFFF", 400)
        y, x, w = 120, 760, 460
    # stacked notification cards (lock screen shows content because the device has no lock; sensitive content hidden option)
    y = notif_card(s, x, y, w, "dronebudz", "Rennick", "You are getting close. The cruiser should be outside.", "now", 88) + 8
    y = notif_card(s, x, y, w, "jobs", "New job: Toby Farm roof survey", "$140 · 1.2 km", "6 min", 88) + 8
    card(s, x + 40, y, w - 80, 36, T["surface-container-high"], 18, 0.9)
    for i, k in enumerate(["vidtube", "facade", "casebook"]):
        s.image(x + w / 2 - 36 + i * 24, y + 8, 20, 20, MONO(k), "xMidYMid meet")
    # DND chip
    s.rect(W / 2 - 92, H - 140, 184, 32, T["surface-container-high"], r=16, opacity=0.9)
    s.icon("do_not_disturb_on", W / 2 - 80, H - 132, 16, T["on-surface"], filled=True)
    s.text(W / 2 + 8, H - 119, "Do Not Disturb is on", 12, T["on-surface"], 500, "middle")
    # bottom shortcuts + unlock hint
    for cx, ic in ((48 if not phone else 52, "flashlight_on"), (W - (48 if not phone else 52), "photo_camera")):
        s.circle(cx, H - 64, 28, T["surface-container-high"], opacity=0.85)
        s.icon(ic, cx - 12, H - 76, 24, T["on-surface"], filled=True)
    s.icon("lock_open", W / 2 - 12, H - 92, 24, "#FFFFFF")
    s.text(W / 2, H - 52, "Swipe up to open", 13, "#FFFFFF", 400, "middle", opacity=0.9)
    pill(s, W, H)
    s.save(path)


# ------------------------------------------------------------------ Facade Apps: store listing, install states, permissions, uninstall
def store_listing(path, phone=False, state="install", sheet=False):
    W, H, PW, PH = PHO if phone else TAB
    s = L.Svg(W, H, PW, PH)
    s.rect(0, 0, W, H, T["surface"])
    status_bar(s, W, h=32 if phone else 28, colour=T["on-surface"])
    top = 36 if phone else 32
    s.icon("arrow_back", 16, top + 16, 24, T["on-surface"])
    s.image(56, top + 12, 32, 32, ICON("store"), "xMidYMid meet")
    s.text(96, top + 34, "Facade Apps", 20, T["on-surface"])
    s.icon("search", W - 104, top + 16, 24, T["on-surface"])
    s.icon("more_vert", W - 56, top + 16, 24, T["on-surface"])
    x0 = 24
    y = top + 72
    # app header: icon 72 with a progress ring while downloading
    ic_size = 80
    s.image(x0, y, ic_size, ic_size, ICON("camera"), "xMidYMid meet")
    if state in ("pending", "downloading", "installing"):
        s.circle(x0 + 40, y + 40, 46, "none", stroke=T["secondary-container"], sw=4)
        if state == "downloading":
            a = 0.42 * math.tau
            ex, ey = x0 + 40 + 46 * math.sin(a), y + 40 - 46 * math.cos(a)
            s.add(f'<path d="M{x0+40} {y-6} A46 46 0 0 1 {ex:.1f} {ey:.1f}" fill="none" stroke="{T["primary"]}" stroke-width="4" stroke-linecap="round"/>')
        else:
            s.add(f'<path d="M{x0+40} {y-6} A46 46 0 0 1 {x0+86} {y+40}" fill="none" stroke="{T["primary"]}" stroke-width="4" stroke-linecap="round"/>')
    tx = x0 + 108
    s.text(tx, y + 26, "ThermalSight", 28 if not phone else 24, T["on-surface"])
    s.text(tx, y + 50, "MugShot Motors", 14, T["primary"], 500)
    s.text(tx, y + 70, {"install": "Contains ads · In-app purchases", "pending": "Pending…", "downloading": "42% of 18 MB",
                        "installing": "Installing…", "installed": "Installed"}[state], 13, T["on-surface-variant"])
    y += 112
    # stats row
    stats = [("4.3 ★", "212 reviews"), ("18 MB", "Download"), ("12K+", "Downloads"), ("E", "Everyone")]
    sw_ = (W - 48) / 4
    for i, (a, b) in enumerate(stats):
        cx = x0 + sw_ * i + sw_ / 2
        if a.endswith("★"):   # Roboto has no star glyph: use the Material Symbol
            s.icon("star", cx + 6, y + 3, 15, T["on-surface"], filled=True)
            s.text(cx + 3, y + 16, a[:-2], 15, T["on-surface"], 500, "end")
        else:
            s.text(cx, y + 16, a, 15, T["on-surface"], 500, "middle")
        s.text(cx, y + 36, b, 12, T["on-surface-variant"], 400, "middle")
        if i:
            s.rect(x0 + sw_ * i, y + 4, 1, 32, T["outline-variant"])
    y += 60
    bw = W - 48
    if state == "install":
        button(s, x0, y, "Install", "filled", w=bw, h=44)
    elif state in ("pending", "downloading", "installing"):
        button(s, x0, y, "Cancel", "outlined", w=bw / 2 - 6, h=44)
        s.rect(x0 + bw / 2 + 6, y, bw / 2 - 6, 44, T["on-surface"], r=22, opacity=0.12)
        s.text(x0 + bw * 0.75 + 3, y + 27, "Open", 14, T["on-surface"], 500, "middle", opacity=0.38)
        if state == "downloading":
            s.rect(x0, y + 56, bw, 4, T["secondary-container"], r=2)
            s.rect(x0, y + 56, bw * 0.42, 4, T["primary"], r=2)
    else:
        button(s, x0, y, "Uninstall", "outlined", w=bw / 2 - 6, h=44)
        button(s, x0 + bw / 2 + 6, y, "Open", "filled", w=bw / 2 - 6, h=44)
    y += 76
    # screenshots carousel (game captures, 16:9)
    shots = [os.path.join(L.GODOT, "docs", "realism", "camera", "look", n + ".jpg") for n in ("natural", "vivid", "flat")]
    shw = 300 if not phone else 260
    for i, p in enumerate(shots):
        if x0 + i * (shw + 12) > W:
            break
        clip = s.clip_rect(x0 + i * (shw + 12), y, shw, shw * 9 / 16, 16)
        s.image(x0 + i * (shw + 12), y, shw, shw * 9 / 16, p, clip=clip)
    y += shw * 9 / 16 + 28
    s.text(x0, y, "About this app", 20, T["on-surface"])
    s.icon("arrow_forward" if False else "chevron_right", W - 48, y - 18, 24, T["on-surface-variant"])
    s.text(x0, y + 26, "See heat through haze and trees. Pairs with the Halloway thermal camera add-on.", 14, T["on-surface-variant"])
    for i, c in enumerate(["Photography", "Drone tools", "Weather"]):
        s.rect(x0 + i * 128, y + 44, 116, 32, "none", r=8, stroke=T["outline-variant"])
        s.text(x0 + i * 128 + 58, y + 65, c, 13, T["on-surface-variant"], 500, "middle")
    if sheet:
        s.rect(0, 0, W, H, "#000", opacity=0.32)
        sh = 380 if not phone else 470
        sx, sw2 = (0, W) if phone else (W / 2 - 320, 640)
        s.add(f'<path d="M{sx} {H} V{H-sh+28} A28 28 0 0 1 {sx+28} {H-sh} H{sx+sw2-28} A28 28 0 0 1 {sx+sw2} {H-sh+28} V{H} Z" fill="{T["surface-container-low"]}"/>')
        s.rect(sx + sw2 / 2 - 16, H - sh + 22, 32, 4, T["on-surface-variant"], r=2, opacity=0.4)
        s.image(sx + sw2 / 2 - 24, H - sh + 44, 48, 48, ICON("camera"), "xMidYMid meet")
        s.text(sx + sw2 / 2, H - sh + 124, "Allow ThermalSight to use the thermal camera", 18 if not phone else 16, T["on-surface"], 400, "middle")
        s.text(sx + sw2 / 2, H - sh + 148, "and the drone link?", 18 if not phone else 16, T["on-surface"], 400, "middle")
        perms = [("photo_camera", "Camera", "Take photos and video with the drone camera"), ("wifi", "Drone link", "Read telemetry and the video feed"),
                 ("location_on", "Location", "Tag photos with where they were taken")]
        for i, (ic, a, b) in enumerate(perms):
            yy = H - sh + 172 + i * 48
            s.icon(ic, sx + 32, yy + 4, 24, T["primary"])
            s.text(sx + 72, yy + 14, a, 15, T["on-surface"], 500)
            s.text(sx + 72, yy + 32, b, 13, T["on-surface-variant"])
        by = H - 64 if not phone else H - 72
        button(s, sx + 24, by - 52 if phone else by, "Allow", "filled", w=(sw2 - 60) / 2 if not phone else sw2 - 48)
        button(s, sx + (sw2 / 2 + 6 if not phone else 24), by, "Don't allow", "tonal", w=(sw2 - 60) / 2 if not phone else sw2 - 48)
    if state == "installed" and not phone and not sheet:
        # snackbar after install
        s.rect(W / 2 - 172, H - 80, 344, 48, T["inverse-surface"], r=4)
        s.text(W / 2 - 156, H - 51, "ThermalSight installed", 14, T["inverse-on-surface"])
        s.text(W / 2 + 156, H - 51, "Open", 14, T["inverse-primary"], 500, "end")
    pill(s, W, H, T["on-surface"])
    s.save(path)


def store_states(path):
    """Install-button state strip + uninstall dialog, the reference for the installer flow."""
    W, H = 1280, 520
    s = L.Svg(W, H, 1920, 780)
    s.rect(0, 0, W, H, T["surface"])
    s.text(24, 40, "Facade Apps: install flow states (left to right). Button 44 dp tall; icon ring 4 dp; snackbar after install.", 15, T["on-surface"])
    states = [("Install", "install"), ("Pending", "pending"), ("Downloading 42%", "downloading"), ("Installing", "installing"),
              ("Installed", "installed"), ("Update", "update"), ("Uninstalling", "uninstalling")]
    for i, (lab, st) in enumerate(states):
        x = 24 + i * 178
        y = 70
        s.image(x + 44, y, 80, 80, ICON("camera"), "xMidYMid meet")
        if st in ("pending", "downloading", "installing", "uninstalling"):
            s.circle(x + 84, y + 40, 46, "none", stroke=T["secondary-container"], sw=4)
            frac = {"pending": 0.12, "downloading": 0.42, "installing": 0.75, "uninstalling": 0.5}[st]
            a = frac * math.tau
            ex, ey = x + 84 + 46 * math.sin(a), y + 40 - 46 * math.cos(a)
            s.add(f'<path d="M{x+84} {y-6} A46 46 0 {1 if frac > 0.5 else 0} 1 {ex:.1f} {ey:.1f}" fill="none" stroke="{T["primary"] if st != "uninstalling" else T["error"]}" stroke-width="4" stroke-linecap="round"/>')
        s.text(x + 84, y + 124, lab, 13, T["on-surface-variant"], 500, "middle")
        by = y + 140
        if st == "install":
            button(s, x + 4, by, "Install", "filled", w=160, h=44)
        elif st == "update":
            button(s, x + 4, by, "Update", "filled", w=160, h=44)
        elif st == "installed":
            button(s, x + 4, by, "Open", "filled", w=160, h=44)
            button(s, x + 4, by + 54, "Uninstall", "outlined", w=160, h=44)
        else:
            button(s, x + 4, by, "Cancel", "outlined", w=160, h=44)
        if st == "downloading":
            s.rect(x + 4, by + 56, 160, 4, T["secondary-container"], r=2)
            s.rect(x + 4, by + 56, 67, 4, T["primary"], r=2)
            s.text(x + 84, by + 80, "7.6 of 18 MB", 12, T["on-surface-variant"], 400, "middle")
    # uninstall dialog
    dx, dy = 340, 330
    s.rect(0, 300, W, 220, "#000", opacity=0.32)
    card(s, dx, dy, 312, 172, T["surface-container-high"], 28, 1, 3)
    s.image(dx + 140, dy + 20, 32, 32, ICON("camera"), "xMidYMid meet")
    s.text(dx + 156, dy + 84, "Uninstall ThermalSight?", 22, T["on-surface"], 400, "middle")
    s.text(dx + 156, dy + 108, "Its photos stay in Photos.", 14, T["on-surface-variant"], 400, "middle")
    s.text(dx + 200, dy + 150, "Cancel", 14, T["primary"], 500, "end")
    s.text(dx + 288, dy + 150, "Uninstall", 14, T["error"], 500, "end")
    # snackbar
    s.rect(760, 380, 344, 48, T["inverse-surface"], r=4)
    s.text(776, 409, "ThermalSight uninstalled", 14, T["inverse-on-surface"])
    s.text(1088, 409, "Undo", 14, T["inverse-primary"], 500, "end")
    s.save(path)


# ------------------------------------------------------------------ map app
def map_screen(path, phone=False, theme="light"):
    W, H, PW, PH = PHO if phone else TAB
    s = L.Svg(W, H, PW, PH)
    S = M.STYLE[theme]
    th = L.LIGHT if theme == "light" else L.DARK
    # view: centred between the cemetery and the village, 1 dp = 1 m (zoom 15)
    ppm = 1.15 if not phone else 0.9
    cx, cz = (60, 160) if not phone else (120, 250)
    x0, z0 = cx - W / 2 / ppm, cz - H / 2 / ppm
    base = M.base_raster(x0, z0, x0 + W / ppm, z0 + H / ppm, PW // 2, PH // 2, theme)
    s.image(0, 0, W, H, uri(base.resize((PW, PH), Image.BILINEAR)), "none")
    M.overlay(s, x0, z0, ppm, 0, 0, theme, 17)
    P = lambda x, z: ((x - x0) * ppm, (z - z0) * ppm)
    # route from the home pad to the farm gate (blue with casing), walking leg dotted
    rt = [(34, 246), (100, 252), (200, 255), (286, 260), (270, 360), (240, 440), (215, 505), (188, 512)]
    d = "M" + " L".join("%.1f %.1f" % P(*p) for p in rt)
    s.add(f'<path d="{d}" fill="none" stroke="{S["route_casing"]}" stroke-width="9" stroke-linecap="round" stroke-linejoin="round"/>'
          f'<path d="{d}" fill="none" stroke="{S["route"]}" stroke-width="6.5" stroke-linecap="round" stroke-linejoin="round"/>')
    # pins
    for sid, nm, x, z in M.SITES:
        kind = "current" if sid == "south_gate" else ("suggested" if sid == "farm" else "open")
        px, pz = P(x, z)
        if -20 < px < W + 20 and -20 < pz < H + 20:
            s.image(px - 14, pz - 37, 28, 38, os.path.join(L.OUT, "map", "pin", f"pin_site_{kind}.png"), "xMidYMid meet")
    # my location puck with heading + accuracy
    lx, lz = P(30, 262)
    s.image(lx - 34, lz - 34, 68, 68, os.path.join(L.OUT, "map", "puck", f"accuracy_{theme}.png"), "xMidYMid meet")
    s.add(f'<g transform="rotate(35 {lx} {lz})">')
    s.image(lx - 40, lz - 40, 80, 80, os.path.join(L.OUT, "map", "puck", f"location_heading_{theme}.png"), "xMidYMid meet")
    s.add("</g>")
    # status bar scrim
    s.rect(0, 0, W, 40, s.lin([(0, "#000", 0.35 if theme == "light" else 0.5), (1, "#000", 0)]))
    status_bar(s, W, h=32 if phone else 28, colour="#FFFFFF" if theme == "dark" else "#1D1C16", notif=())
    # search bar + chips
    sx, sw_ = (12, W - 24) if phone else (16, 380)
    card(s, sx, 44, sw_, 52, th["surface-container-high"] if theme == "dark" else "#FFFFFF", 26, 1, 2)
    s.icon("search", sx + 16, 58, 24, th["on-surface-variant"])
    s.text(sx + 52, 76, "Search the valley", 16, th["on-surface-variant"])
    s.image(sx + sw_ - 44, 54, 32, 32, AV("you"), clip=s.clip_circle(sx + sw_ - 28, 70, 16))
    chips = [("flight_takeoff", "Launch sites"), ("local_parking", "Parking"), ("sailing", "Boat launch"), ("restaurant" if False else "storefront", "Village")]
    cx_ = sx if phone else sx + sw_ + 12
    cy_ = 106 if phone else 54
    for ic, t in chips:
        w = len(t) * 7.4 + 48
        if cx_ + w > W - 8:
            break
        card(s, cx_, cy_, w, 32, th["surface-container-high"] if theme == "dark" else "#FFFFFF", 16, 1, 1)
        s.icon(ic, cx_ + 10, cy_ + 7, 18, th["on-surface-variant"])
        s.text(cx_ + 34, cy_ + 21, t, 13, th["on-surface"], 500)
        cx_ += w + 8
    # right controls: layers, compass, zoom, recentre FAB
    rx = W - 56
    s.image(rx, 120 if phone else 108, 44, 44, os.path.join(L.OUT, "map", "control", "layers" + ("_dark" if theme == "dark" else "") + ".png"), "xMidYMid meet")
    s.image(rx, (172 if phone else 160), 44, 44, os.path.join(L.OUT, "map", "control", "compass" + ("_dark" if theme == "dark" else "") + ".png"), "xMidYMid meet")
    if not phone:
        s.image(rx, H - 252, 44, 84, os.path.join(L.OUT, "map", "control", "zoom" + ("_dark" if theme == "dark" else "") + ".png"), "xMidYMid meet")
    fab_y = H - 140 if not phone else H - 330
    s.image(W - 76, fab_y, 60, 60, os.path.join(L.OUT, "map", "control", "recentre" + ("_dark" if theme == "dark" else "") + ".png"), "xMidYMid meet")
    # scale bar
    sbx, sby = (16, H - 40) if not phone else (16, H - 312)
    m100 = 100 * ppm
    s.add(f'<path d="M{sbx} {sby-6} V{sby} H{sbx+m100} V{sby-6}" fill="none" stroke="{"#FFFFFF" if theme == "light" else "#121512"}" stroke-width="4"/>'
          f'<path d="M{sbx} {sby-6} V{sby} H{sbx+m100} V{sby-6}" fill="none" stroke="{"#3A362D" if theme == "light" else "#E6E0CB"}" stroke-width="1.6"/>')
    s.text(sbx + m100 + 6, sby + 1, "100 m", 11, "#3A362D" if theme == "light" else "#E6E0CB", 500, halo=(S["label_halo"], 2.4))
    # place sheet: tablet = side sheet card, phone = bottom sheet peek
    if phone:
        sh_y = H - 292
        s.add(f'<path d="M0 {H} V{sh_y+28} A28 28 0 0 1 28 {sh_y} H{W-28} A28 28 0 0 1 {W} {sh_y+28} V{H} Z" fill="{th["surface-container-low"]}" filter="url(#{s.shadow(2)})"/>')
        s.rect(W / 2 - 16, sh_y + 10, 32, 4, th["on-surface-variant"], r=2, opacity=0.4)
        bx, by_, bw = 20, sh_y + 30, W - 40
    else:
        bx, by_, bw = 16, H - 236 - 56, 380
        card(s, bx - 0, by_ - 8, bw, 236, th["surface-container-low"], 24, 1, 2)
        bx += 20; bw -= 40; by_ += 4
    s.text(bx, by_ + 24, "Toby Farm gate", 22, th["on-surface"])
    s.text(bx, by_ + 46, "Launch site · Suggested for the case", 14, th["on-surface-variant"])
    s.icon("star", bx, by_ + 56, 16, "#E0AB59", filled=True)
    s.text(bx + 20, by_ + 69, "Field access · 1.4 km · about 4 min by road", 13, th["on-surface-variant"])
    bwid = button(s, bx, by_ + 86, "Drive here", "filled", th=th, icon="directions_car")
    button(s, bx + bwid + 8, by_ + 86, "Fly here", "tonal", th=th, icon="flight_takeoff")
    if phone:
        s.text(bx, by_ + 160, "Nearby", 14, th["primary"], 500)
        for i, (k, n, dd) in enumerate((("farm", "Toby Farm", "120 m"), ("barn", "Old hay barn", "300 m"))):
            s.image(bx, by_ + 172 + i * 44, 32, 32, os.path.join(L.OUT, "map", "marker", "farm_farm.png" if k == "farm" else "farm_barn.png"), "xMidYMid meet")
            s.text(bx + 44, by_ + 186 + i * 44, n, 15, th["on-surface"])
            s.text(bx + 44, by_ + 203 + i * 44, dd, 12, th["on-surface-variant"])
        pill(s, W, H, th["on-surface"])
    else:
        s.text(bx, by_ + 160, "Open now · Gate unlocked 06:00 to 20:00", 13, th["on-surface-variant"])
        pill(s, W, H, "#3A362D" if theme == "light" else "#FFFFFF")
    s.save(path)


def layer_sheet(path):
    W, H, PW, PH = PHO
    s = L.Svg(W, H, PW, PH)
    base = M.base_raster(-200, -100, 300, 1010, PW // 2, PH // 2, "light")
    s.image(0, 0, W, H, uri(base.resize((PW, PH))), "none")
    M.overlay(s, -200, -100, W / 500, 0, 0, "light", 16)
    s.rect(0, 0, W, H, "#000", opacity=0.32)
    th = L.LIGHT
    sh_y = H - 420
    s.add(f'<path d="M0 {H} V{sh_y+28} A28 28 0 0 1 28 {sh_y} H{W-28} A28 28 0 0 1 {W} {sh_y+28} V{H} Z" fill="{th["surface-container-low"]}"/>')
    s.rect(W / 2 - 16, sh_y + 10, 32, 4, th["on-surface-variant"], r=2, opacity=0.4)
    s.text(24, sh_y + 52, "Map type", 16, th["on-surface"], 500)
    s.icon("close", W - 48, sh_y + 32, 24, th["on-surface-variant"])
    for i, (lab, thm, terr) in enumerate((("Default", "light", False), ("Night", "dark", False), ("Terrain", "light", True))):
        x = 24 + i * 124
        img = M.base_raster(-150, 120, 250, 520, 200, 200, thm)
        clip = s.clip_rect(x, sh_y + 68, 100, 100, 16)
        s.image(x, sh_y + 68, 100, 100, uri(img), clip=clip)
        if i == 0:
            s.rect(x - 3, sh_y + 65, 106, 106, "none", r=18, stroke=th["primary"], sw=3)
        s.text(x + 50, sh_y + 190, lab, 13, th["primary"] if i == 0 else th["on-surface"], 500, "middle")
    s.text(24, sh_y + 236, "Map details", 16, th["on-surface"], 500)
    for i, (ic, lab) in enumerate((("flight_takeoff", "Launch sites"), ("route", "Roads"), ("landscape", "Contours"), ("shield", "No-fly zones"))):
        x = 24 + i * 92
        s.rect(x, sh_y + 254, 72, 72, th["secondary-container"] if i < 3 else th["surface-container-highest"], r=16)
        s.icon(ic, x + 24, sh_y + 278, 24, th["on-secondary-container"])
        s.text(x + 36, sh_y + 346, lab, 12, th["on-surface"], 400, "middle")
    s.save(path)


def build():
    os.makedirs(L.REAL, exist_ok=True)
    jobs = [
        ("10_tablet_home.jpg", tablet_home), ("11_tablet_drawer.jpg", tablet_drawer),
        ("12_phone_home.jpg", phone_home), ("13_phone_drawer.jpg", phone_drawer),
        ("20_tablet_shade_qs.jpg", tablet_shade), ("21_phone_shade.jpg", phone_shade),
        ("22_tablet_settings_notifications.jpg", tablet_settings),
        ("23_tablet_lock_screen.jpg", lambda p: lock_screen(p, False)), ("24_phone_lock_screen.jpg", lambda p: lock_screen(p, True)),
        ("30_tablet_store_listing.jpg", lambda p: store_listing(p, False, "install")),
        ("31_tablet_store_permissions.jpg", lambda p: store_listing(p, False, "downloading", True)),
        ("32_phone_store_downloading.jpg", lambda p: store_listing(p, True, "downloading")),
        ("33_phone_store_permissions.jpg", lambda p: store_listing(p, True, "pending", True)),
        ("34_tablet_store_installed.jpg", lambda p: store_listing(p, False, "installed")),
        ("35_store_install_states.jpg", store_states),
        ("50_tablet_map_light.jpg", lambda p: map_screen(p, False, "light")), ("51_tablet_map_dark.jpg", lambda p: map_screen(p, False, "dark")),
        ("52_phone_map_light.jpg", lambda p: map_screen(p, True, "light")), ("53_phone_map_layers.jpg", layer_sheet),
    ]
    import sys
    only = sys.argv[1:] if len(sys.argv) > 1 else None
    for name, fn in jobs:
        if only and not any(o in name for o in only):
            continue
        fn(os.path.join(L.REAL, name))
        print(name)


if __name__ == "__main__":
    build()
