"""Phone app icons at the exact paths UniverseUI.app_icon() loads: assets/ui/icon_<key>.png.

The tablet kit art is reused where an app matches (chat = DroneBudz, studio = VidTube, market = Facade, and the
same-named apps); Map and Search are new tiles in the same family. Rendered natively at every size with the tablet
generator's make_icon(), so the pixels match the tablet kit exactly at 128 and 64.
"""
import math
from lib import *
from glyphs import *
import gen_icons as GI
from appui_lib import save_ui


def fg_map(c):
    # a three-panel folded survey map with a brass route and a rust pin
    panels = [(-40, -28, -14, 34, -2), (-14, -34, 14, 28, 2), (14, -28, 40, 34, -2)]
    for i, (x0, y0, x1, y1, sk) in enumerate(panels):
        poly = c.poly([(x0, y0), (x1, y0), (x1, y1), (x0, y1)], 1.2)
        shade = (CREAM_HI, CREAM_LO) if i != 1 else (hx("#EDE3C6"), hx("#D3C6A2"))
        c.fill(poly, vgrad(shade[0], shade[1], y0, y1))
    # contour lines and a lake
    for k in range(3):
        pts = [(x, -10 + k * 9 + 4 * math.sin(x * 0.12 + k)) for x in np.linspace(-38, 38, 40)]
        c.fill(c.line(pts, 1.2), hx("#9DAF8F"), 0.75)
    c.fill(c.ellipse(-25, 18, 9, 6), hx("#7FB2B8"))
    route = [(-30, 26), (-18, 12), (-4, 14), (8, 0), (22, -10)]
    for a, b in zip(route, route[1:]):
        n = 4
        for j in range(n):
            t0, t1 = j / n, (j + 0.55) / n
            c.fill(c.line([(a[0] + (b[0] - a[0]) * t0, a[1] + (b[1] - a[1]) * t0), (a[0] + (b[0] - a[0]) * t1, a[1] + (b[1] - a[1]) * t1)], 3.0), BRASS_LO)
    pin = c.circle(22, -20, 9) | c.poly([(14.5, -16), (29.5, -16), (22, -2)], 1.0)
    c.fill(pin, vgrad(hx("#D97A5C"), hx("#8A432C"), -29, -2))
    c.fill(c.circle(22, -20, 3.6), CREAM_HI)


def fg_search(c):
    c.fill(c.ring(-8, -8, 24, 9.5), vgrad(CREAM_HI, CREAM_LO, -32, 16))
    c.fill(c.circle(-8, -8, 19.2), vgrad(hx("#8FC0C5"), hx("#3F7A84"), -27, 11), 0.9)
    c.fill(c.arc(-8, -8, 13, 200, 260, 3.2), CREAM_HI, 0.7)
    h = c.line([(10, 10), (34, 34)], 13)
    c.fill(h, Gradient([(0, BRASS_HI), (1, BRASS_LO)], p0=(10, 10), p1=(34, 34)))
    c.fill(c.line([(9, 9), (13, 13)], 9), CREAM_LO)


# key -> (tablet icon name or None, tile top, tile bottom, art)
BY_NAME = {n: (t, b, a) for n, t, b, a in GI.ICONS}
PHONE = {
    "chat": "icon_dronebudz", "studio": "icon_vidtube", "photos": "icon_photos", "jobs": "icon_jobs",
    "casebook": "icon_casebook", "market": "icon_facade", "settings": "icon_settings", "recents": "icon_recents",
    "home": "icon_home", "weather": "icon_weather", "camera": "icon_camera", "phone": "icon_phone",
}
NEW = {"map": ("#6E8F6A", "#2C4733", fg_map), "search": ("#55706A", "#1D2B27", fg_search)}


def build():
    keys = []
    for key in list(PHONE) + list(NEW):
        if key in PHONE:
            top, bot, art = BY_NAME[PHONE[key]]
        else:
            top, bot, art = NEW[key]
        for S in (256, 128, 96, 48):
            c, bgc, fgc = GI.make_icon(f"icon_{key}", top, bot, art, S)
            rel = f"icon_{key}.png" if S == 256 else f"icons/{S}/icon_{key}.png"
            save_ui(c.render(), rel, note=("reuses tablet " + PHONE[key]) if key in PHONE else "new tile")
        m = GI.mono_icon(art, 96)
        save_ui(m.render(), f"icons/mono/icon_{key}_mono.png", note="notification-shade mono")
        keys.append(key)
    return keys


if __name__ == "__main__":
    print(build())
