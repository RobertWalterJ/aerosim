"""Priority 0 widget faces, needles, weather glyphs, status glyphs, badges."""
import math
from lib import *
from glyphs import *

BRASS_RING = [(0, hx("#F6D590")), (0.35, BRASS), (0.7, hx("#A87530")), (1, hx("#E7B866"))]


def face_base(c, r=240, ring=12):
    """Dark glass face with a quiet brass bezel. Units = 512 px, centre (256,256)."""
    face = c.circle(256, 256, r)
    c.shadow(c.circle(256, 256, r + ring / 2), dy=3 * c.k / c.ss, blur=4, alpha=0.30)
    c.fill(c.circle(256, 256, r + ring / 2), Gradient(BRASS_RING, p0=(60, 40), p1=(450, 470)))
    c.fill(c.circle(256, 256, r - ring / 2 + 1), hx("#2B2214"))
    c.fill(face - c.circle(256, 256, r - ring / 2), (0, 0, 0, 0))
    inner = c.circle(256, 256, r - ring / 2 - 2)
    c.fill(inner, Gradient([(0, hx("#1B221D")), (1, hx("#0C100E"))], center=(230, 220), radius=r * 1.1), 0.96)
    c.fill(c.ring(256, 256, r - ring / 2 - 2, 2), (255, 240, 205, 255), 0.10)
    return inner


def glass(c, inner):
    c._vfade(inner & c.ellipse(256, 150, 190, 120), 30, 270, 0.09, 0.0, (255, 250, 235, 255))


def dial_wind_face():
    c = Canvas(512).unit(0, 0, 1)
    inner = face_base(c)
    # faint compass rose
    for ang, ln, w in ((0, 150, 30), (90, 150, 30), (180, 150, 30), (270, 150, 30), (45, 105, 20), (135, 105, 20), (225, 105, 20), (315, 105, 20)):
        a = math.radians(ang - 90)
        p = (256 + math.cos(a) * ln, 256 + math.sin(a) * ln)
        q = (256 + math.cos(a + math.pi / 2) * w / 2, 256 + math.sin(a + math.pi / 2) * w / 2)
        q2 = (256 - math.cos(a + math.pi / 2) * w / 2, 256 - math.sin(a + math.pi / 2) * w / 2)
        c.fill(c.poly([p, q, (256, 256)], 0), BRASS, 0.20)
        c.fill(c.poly([p, q2, (256, 256)], 0), BRASS, 0.10)
    c.fill(c.ring(256, 256, 150, 2), BRASS, 0.30)
    c.fill(c.ring(256, 256, 206, 2), CREAM, 0.20)
    # ticks every 5 degrees
    for i in range(72):
        deg = i * 5
        major = deg % 30 == 0
        a = math.radians(deg - 90)
        r1, r2 = (176, 205) if major else (188, 204)
        c.fill(c.line([(256 + math.cos(a) * r1, 256 + math.sin(a) * r1), (256 + math.cos(a) * r2, 256 + math.sin(a) * r2)],
                      4.0 if major else 2.0), CREAM, 0.80 if major else 0.38)
    # cardinal letters
    for lab, deg, col in (("N", 0, hx("#E87D5E")), ("E", 90, CREAM), ("S", 180, CREAM), ("W", 270, CREAM)):
        a = math.radians(deg - 90)
        x, y = 256 + math.cos(a) * 148, 256 + math.sin(a) * 148
        c.fill(c.text(lab, x, y, 44, "mm", "Bold"), col, 1.0 if lab == "N" else 0.82)
    # north pointer notch on the bezel side
    c.fill(c.poly([(256, 46), (244, 70), (268, 70)], 2), hx("#E87D5E"))
    for deg in (45, 135, 225, 315):
        a = math.radians(deg - 90)
        c.fill(c.circle(256 + math.cos(a) * 148, 256 + math.sin(a) * 148, 4.5), BRASS, 0.8)
    glass(c, inner)
    return c.render()


def needle_wind():
    c = Canvas(512).unit(0, 0, 1)
    pts_head = [(256, 66), (276, 256), (236, 256)]
    pts_tail = [(256, 330), (270, 256), (242, 256)]
    c.shadow(c.poly(pts_head, 3) | c.poly([(256, 340), (276, 256), (236, 256)], 3), dy=3, blur=3, alpha=0.35)
    c.fill(c.poly(pts_head, 3), vgrad(hx("#F6D590"), hx("#C68A38"), 66, 256))
    c.fill(c.poly([(256, 66), (256, 256), (236, 256)], 3), hx("#7A4F18"), 0.30)
    c.fill(c.poly([(256, 330), (276, 256), (236, 256)], 3), vgrad(hx("#E7DEC0"), hx("#9C9580"), 256, 330))
    c.fill(c.circle(256, 256, 26), Gradient([(0, hx("#FFF3CF")), (0.6, CREAM), (1, hx("#A89F85"))], center=(248, 246), radius=36))
    c.fill(c.circle(256, 256, 12), Gradient([(0, BRASS_HI), (1, BRASS_LO)], center=(252, 252), radius=14))
    c.fill(c.circle(256, 256, 4), hx("#4A3410"))
    return c.render()


BAT_START, BAT_SPAN = 150.0, 240.0   # same sweep the code-drawn dial used (degrees clockwise from +x, y down)


def dial_battery_face():
    c = Canvas(512).unit(0, 0, 1)
    inner = face_base(c)
    R = 176
    c.fill(c.arc(256, 256, R, BAT_START, BAT_START + BAT_SPAN, 38), hx("#000000"), 0.45)
    c.fill(c.arc(256, 256, R, BAT_START, BAT_START + BAT_SPAN, 32), hx("#2B332D"))
    c.fill(c.arc(256, 256, R - 12, BAT_START + 2, BAT_START + BAT_SPAN - 2, 3), (0, 0, 0, 255), 0.35)
    for i in range(0, 5):
        a = math.radians(BAT_START + BAT_SPAN * i / 4)
        r1, r2 = R + 26, R + 40
        if i in (0, 4):
            r1, r2 = R + 22, R + 40
        c.fill(c.line([(256 + math.cos(a) * r1, 256 + math.sin(a) * r1), (256 + math.cos(a) * r2, 256 + math.sin(a) * r2)], 4), CREAM, 0.7)
    for lab, deg in (("E", BAT_START), ("F", BAT_START + BAT_SPAN)):
        a = math.radians(deg)
        c.fill(c.text(lab, 256 + math.cos(a) * (R - 2), 256 + math.sin(a) * (R - 2) + 78, 30, "mm", "Bold"), CREAM, 0.6)
    c.fill(c.ring(256, 256, 118, 2), BRASS, 0.25)
    # small bolt glyph, brass
    draw_bolt(c, 256, 380, 70)
    glass(c, inner)
    return c.render()


def battery_fill(col_hi, col_lo):
    c = Canvas(512).unit(0, 0, 1)
    R = 176
    c.fill(c.arc(256, 256, R, BAT_START, BAT_START + BAT_SPAN, 32), Gradient([(0, col_hi), (1, col_lo)], p0=(80, 100), p1=(430, 430)))
    c.fill(c.arc(256, 256, R + 9, BAT_START + 1, BAT_START + BAT_SPAN - 1, 6), (255, 255, 255, 255), 0.18)
    return c.render()


def needle_battery():
    c = Canvas(512).unit(0, 0, 1)
    pts = [(256, 96), (264, 256), (248, 256)]
    c.shadow(c.poly(pts, 2), dy=3, blur=3, alpha=0.35)
    c.fill(c.poly(pts, 2.5), vgrad(hx("#F6D590"), hx("#C68A38"), 96, 256))
    c.fill(c.circle(256, 256, 22), Gradient([(0, hx("#FFF3CF")), (0.6, CREAM), (1, hx("#A89F85"))], center=(249, 248), radius=30))
    c.fill(c.circle(256, 256, 10), Gradient([(0, BRASS_HI), (1, BRASS_LO)], center=(252, 252), radius=12))
    return c.render()


# ---------------------------------------------------------------- weather
def weather_glyph(kind, S=512):
    c = Canvas(S).unit(S / 2, S / 2, S / 100.0)
    if kind == "sun":
        draw_sun(c, 0, 0, 20)
    elif kind == "moon":
        draw_moon(c, 0, 0, 26)
        draw_flake(c, 22, -22, 5, 1.4, BRASS_HI) if False else None
    elif kind == "cloud":
        draw_cloud(c, 0, 0, 44)
    elif kind == "rain":
        draw_cloud(c, 0, -10, 40, CREAM_HI, hx("#C9CFC3"))
        draw_rain(c, 0, 18, 30)
    elif kind == "storm":
        draw_cloud(c, 0, -14, 40, hx("#D8D8CC"), hx("#8C9488"))
        draw_bolt(c, -2, 18, 52)
        draw_rain(c, 24, 20, 20, 1)
    elif kind == "fog":
        draw_cloud(c, 0, -14, 36, hx("#E6E2CF"), hx("#B7B6A4"))
        draw_fog(c, 0, 22, 40)
    elif kind == "snow":
        draw_cloud(c, 0, -14, 40)
        for dx in (-22, 0, 22):
            draw_flake(c, dx, 26, 8, 2.2, LAKE_HI)
    elif kind == "wind":
        draw_wind(c, 0, 0, 62)
    return c.render()


WEATHER = ["sun", "cloud", "rain", "storm", "fog", "snow", "wind", "moon"]


# ---------------------------------------------------------------- status glyphs (64 and 128, cream or brass)
def status_glyph(kind, S, col):
    c = Canvas(S).unit(S / 2, S / 2, S / 100.0)
    if kind == "wifi":
        for r in (42, 28, 14):
            c.fill(c.arc(0, 28, r, -135, -45, 7.5, True), col)
        c.fill(c.circle(0, 28, 6), col)
    elif kind == "signal":
        for i in range(4):
            h = 16 + i * 17
            x = -33 + i * 22
            c.fill(c.rrect(x, 40 - h, x + 15, 40, 4), col, 1.0 if i < 3 else 0.35)
    elif kind == "battery":
        c.fill(c.rrect(-44, -22, 36, 22, 9) - c.rrect(-38, -16, 30, 16, 4), col)
        c.fill(c.rrect(-33, -11, 14, 11, 3), col)
        c.fill(c.rrect(40, -9, 46, 9, 3), col, 0.9)
    elif kind == "notification":
        bell = c.poly([(-30, 22), (-24, 8), (-22, -16), (-8, -32), (8, -32), (22, -16), (24, 8), (30, 22)], 6)
        bell = bell | c.rrect(-32, 18, 32, 26, 4)
        c.fill(bell, col)
        c.fill(c.circle(0, -37, 5), col)
        c.fill(c.circle(0, 36, 8) & c.rrect(-10, 31, 10, 46, 0), col)
    elif kind == "search":
        c.fill(c.ring(-8, -8, 26, 9), col)
        c.fill(c.line([(12, 12), (38, 38)], 10), col)
    elif kind == "mic":
        c.fill(c.rrect(-14, -42, 14, 8, 14), col)
        c.fill(c.arc(0, -4, 28, 10, 170, 7.5), col)
        c.fill(c.line([(0, 24), (0, 40)], 7.5), col)
        c.fill(c.line([(-14, 42), (14, 42)], 7.5), col)
    return c.render()


def badge_dot(S=64):
    c = Canvas(S).unit(S / 2, S / 2, S / 64.0)
    c.shadow(c.circle(0, 0, 24), dy=1, blur=2, alpha=0.35)
    c.fill(c.circle(0, 0, 24), CREAM, 1.0)
    c.fill(c.circle(0, 0, 19.5), Gradient([(0, hx("#F07A66")), (1, hx("#C0443A"))], p0=(-14, -16), p1=(14, 16)))
    c._vfade(c.circle(0, 0, 19.5) & c.ellipse(0, -9, 14, 8), -20, 0, 0.30, 0, (255, 255, 255, 255))
    return c.render()


def badge_unread(w=96, h=64):
    c = Canvas(w, h).unit(w / 2, h / 2, 1.0)
    c.shadow(c.rrect(-44, -26, 44, 26, 26), dy=1, blur=2, alpha=0.35)
    c.fill(c.rrect(-46, -28, 46, 28, 28), CREAM)
    c.fill(c.rrect(-41, -23, 41, 23, 23), Gradient([(0, hx("#F07A66")), (1, hx("#C0443A"))], p0=(-30, -23), p1=(30, 23)))
    c._vfade(c.rrect(-41, -23, 41, 23, 23) & c.rrect(-36, -21, 36, -2, 12), -23, 0, 0.30, 0, (255, 255, 255, 255))
    return c.render()


def build():
    save(dial_wind_face(), "dials/dial_wind_face.png")
    save(needle_wind(), "dials/dial_needle_wind.png")
    save(dial_battery_face(), "dials/dial_battery_face.png")
    save(battery_fill(hx("#9CCB9F"), hx("#5E9768")), "dials/dial_battery_fill.png")
    save(battery_fill(hx("#F6D590"), hx("#C98F3C")), "dials/dial_battery_fill_amber.png")
    save(battery_fill(hx("#E88A70"), hx("#B0452F")), "dials/dial_battery_fill_rust.png")
    save(needle_battery(), "dials/dial_needle_battery.png")
    atlas = Image.new("RGBA", (256 * 4, 256 * 2))
    for i, k in enumerate(WEATHER):
        g = weather_glyph(k, 512)
        save(g, f"weather/weather_{k}.png")
        for S in (128, 64, 44):
            save(weather_glyph(k, S), f"weather/{S}/weather_{k}.png")
        atlas.alpha_composite(g.resize((256, 256), Image.LANCZOS), ((i % 4) * 256, (i // 4) * 256))
    save(atlas, "weather/widget_weather_face.png")
    for k in ("wifi", "signal", "battery", "notification", "search", "mic"):
        name = "search_mic" if k == "mic" else f"status_{k}"
        for S in (128, 64):
            save(status_glyph(k, S, CREAM), f"status/{S}/{name}.png")
            save(status_glyph(k, S, BRASS), f"status/{S}/{name}_brass.png")
    save(badge_dot(64), "status/badge_dot.png")
    save(badge_dot(32), "status/32/badge_dot.png")
    save(badge_unread(), "status/badge_unread.png")


if __name__ == "__main__":
    build()
