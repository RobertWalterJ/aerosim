"""Contact sheets: tablet_ui_final_views.jpg and tablet_ui_final_textures.jpg into docs/realism/models/."""
import os
from lib import *
import gen_icons

DOCS = os.path.normpath(os.path.join(HERE, "..", "..", "docs", "realism", "models"))
WALL = os.path.normpath(os.path.join(OUT, "..", "tablet_red_barn.jpg"))
if not os.path.exists(WALL):   # the wallpaper lives on lane/notify until it merges
    WALL = os.path.normpath(os.path.join(HERE, "..", "..", "..", "..", "AeroSim-notify", "godot", "assets", "ui", "tablet_red_barn.jpg"))
LIGHT = hx("#EDE6D3")
DARK = hx("#161A17")


def font(sz, w="Regular"):
    f = ImageFont.truetype(FONT_PATH, sz)
    try:
        f.set_variation_by_name(w)
    except Exception:
        pass
    return f


def ld(rel):
    return Image.open(os.path.join(OUT, rel)).convert("RGBA")


def views():
    names = [n for n, *_ in gen_icons.ICONS]
    colw = 190
    W = 40 + colw * 12
    H = 2900
    im = Image.new("RGBA", (W, H), LIGHT)
    d = ImageDraw.Draw(im)
    d.text((20, 14), "AeroSim tablet UI kit - final views", font=font(30, "Bold"), fill=INK)
    y0 = 64
    for band, bg, fg in (("LIGHT", LIGHT, INK), ("DARK", DARK, CREAM)):
        d.rectangle([0, y0, W, y0 + 560], fill=bg)
        d.text((20, y0 + 6), f"icons on {band.lower()} background: 512 (scaled to 160), 128, 64, 44 px", font=font(15), fill=fg)
        for i, n in enumerate(names):
            x = 24 + i * colw
            big = ld(f"icons/{n}.png").resize((160, 160), Image.LANCZOS)
            im.alpha_composite(big, (x, y0 + 36))
            yy = y0 + 210
            for S in (128, 64, 44):
                ic = ld(f"icons/{S}/{n}.png")
                im.alpha_composite(ic, (x, yy))
                yy += S + 10
            d.text((x, y0 + 210 + 128 + 64 + 44 + 30), n.replace("icon_", ""), font=font(14, "SemiBold"), fill=fg)
        y0 += 560
    # monochrome strip
    d.rectangle([0, y0, W, y0 + 120], fill=hx("#2A2F29"))
    d.text((20, y0 + 6), "monochrome (notification shade) 64 / 44 px", font=font(15), fill=CREAM)
    for i, n in enumerate(names):
        im.alpha_composite(ld(f"icons/mono/64/{n}_mono.png"), (24 + i * colw, y0 + 36))
        im.alpha_composite(ld(f"icons/mono/44/{n}_mono.png"), (24 + i * colw + 80, y0 + 46))
    y0 += 120
    # dials + weather + status on the dark band
    d.rectangle([0, y0, W, y0 + 440], fill=DARK)
    x = 24
    for f in ("dials/dial_wind_face.png", "dials/dial_battery_face.png"):
        im.alpha_composite(ld(f).resize((300, 300), Image.LANCZOS), (x, y0 + 30)); x += 320
    wn = ld("dials/dial_needle_wind.png").resize((300, 300), Image.LANCZOS)
    im.alpha_composite(wn, (24, y0 + 30))
    bf = ld("dials/dial_battery_fill.png").resize((300, 300), Image.LANCZOS)
    im.alpha_composite(bf, (344, y0 + 30))
    im.alpha_composite(ld("dials/dial_needle_battery.png").resize((300, 300), Image.LANCZOS).rotate(-60, center=(150, 150), resample=Image.BICUBIC), (344, y0 + 30))
    d.text((24, y0 + 6), "wind face + needle (north); battery face + 100% fill + needle at +60 degrees", font=font(15), fill=CREAM)
    x = 700
    for i, k in enumerate(["sun", "cloud", "rain", "storm", "fog", "snow", "wind", "moon"]):
        im.alpha_composite(ld(f"weather/128/weather_{k}.png"), (x + (i % 4) * 140, y0 + 30 + (i // 4) * 140))
    x = 700
    for i, k in enumerate(["wifi", "signal", "battery", "notification", "search"]):
        im.alpha_composite(ld(f"status/64/status_{k}.png"), (x + i * 66, y0 + 340))
        im.alpha_composite(ld(f"status/64/status_{k}_brass.png"), (x + 380 + i * 66, y0 + 340))
    im.alpha_composite(ld("status/badge_dot.png"), (1500, y0 + 340))
    im.alpha_composite(ld("status/badge_unread.png"), (1600, y0 + 340))
    y0 += 440
    # controls
    d.rectangle([0, y0, W, y0 + 330], fill=hx("#1F241F"))
    d.text((20, y0 + 6), "controls", font=font(15), fill=CREAM)
    x = 24
    for f in ["switch_on", "switch_off", "switch_knob", "switch_knob_on", "slider_knob", "radio_on", "radio_off", "check_on", "check_off", "check_mixed"]:
        c = ld(f"controls/{f}.png"); im.alpha_composite(c, (x, y0 + 36)); x += c.width + 14
    im.alpha_composite(ld("controls/slider_track.png"), (24, y0 + 120))
    im.alpha_composite(ld("controls/slider_fill.png").crop((0, 0, 150, 64)), (24, y0 + 120))
    im.alpha_composite(ld("controls/slider_knob.png"), (24 + 150 - 32, y0 + 120))
    x = 330
    for f in ["button_primary", "button_ghost", "button_card"]:
        c = ld(f"controls/{f}.png"); im.alpha_composite(c, (x, y0 + 110)); x += 206
    im.alpha_composite(ld("controls/search_pill.png"), (24, y0 + 210))
    im.alpha_composite(ld("status/64/search_mic.png").resize((48, 48), Image.LANCZOS), (58, y0 + 234))
    im.alpha_composite(ld("polish/dock_tray.png"), (700, y0 + 200))
    for i, f in enumerate(["page_dot_on", "page_dot_off", "page_dot_off"]):
        im.alpha_composite(ld(f"polish/{f}.png"), (1250 + i * 36, y0 + 250))
    y0 += 330
    # frame on wallpaper
    if os.path.exists(WALL):
        wp = Image.open(WALL).convert("RGBA").resize((960, 540), Image.LANCZOS)
    else:
        wp = Image.new("RGBA", (960, 540), hx("#3B4D3F"))
    wp.alpha_composite(ld("polish/wallpaper_vignette.png").resize((960, 540), Image.LANCZOS))
    wp.alpha_composite(ld("frame/tablet_frame_1280x720.png").resize((960, 540), Image.LANCZOS))
    im.alpha_composite(wp, (24, y0 + 20))
    d.text((1010, y0 + 30), "tablet frame + vignette over the wallpaper\n(frame is transparent inside the screen;\nshown here at 960 x 540 from the 1280 x 720 export)", font=font(16), fill=INK)
    out = im.crop((0, 0, W, y0 + 580)).convert("RGB")
    os.makedirs(DOCS, exist_ok=True)
    out.save(os.path.join(DOCS, "tablet_ui_final_views.jpg"), quality=92)


def textures():
    W, H = 2000, 1500
    im = Image.new("RGBA", (W, H), hx("#F3EEDD"))
    d = ImageDraw.Draw(im)
    d.text((40, 28), "AeroSim tablet UI kit - palette, materials and type", font=font(40, "Bold"), fill=INK)
    sw = [("PINE BLACK", PINE_BLACK), ("PINE", PINE), ("PANEL", PANEL), ("CARD", CARD), ("FIELD", FIELD), ("CREAM", CREAM),
          ("CREAM DIM", CREAM_DIM), ("MUTED", MUTED), ("BRASS", BRASS), ("MOSS", MOSS), ("LAKE", LAKE), ("RUST", RUST),
          ("DANGER", DANGER), ("SLATE", SLATE)]
    for i, (n, c) in enumerate(sw):
        x, y = 40 + (i % 7) * 270, 100 + (i // 7) * 170
        d.rounded_rectangle([x, y, x + 250, y + 110], 14, fill=c)
        d.rounded_rectangle([x, y, x + 250, y + 110], 14, outline=(0, 0, 0, 40), width=2)
        d.text((x, y + 118), f"{n}  #{c[0]:02X}{c[1]:02X}{c[2]:02X}", font=font(17, "SemiBold"), fill=INK)
    # tile gradients
    d.text((40, 450), "App tile gradients (top-left light to bottom-right deep)", font=font(22, "SemiBold"), fill=INK)
    for i, (n, t, b, _) in enumerate(gen_icons.ICONS):
        x, y = 40 + (i % 6) * 320, 490 + (i // 6) * 130
        g = Image.new("RGBA", (300, 100))
        gd = ImageDraw.Draw(g)
        for k in range(300):
            gd.line([(k, 0), (k, 100)], fill=mix(hx(t), hx(b), k / 299.0))
        mk = Image.new("L", (300, 100), 0)
        ImageDraw.Draw(mk).rounded_rectangle([0, 0, 299, 99], 22, fill=255)
        im.paste(g, (x, y), mk)
        d.text((x + 14, y + 66), f"{n.replace('icon_', '')} {t} / {b}", font=font(14, "SemiBold"), fill=CREAM)
    # brass ring + materials
    d.text((40, 770), "Materials", font=font(22, "SemiBold"), fill=INK)
    ring = ld("dials/dial_wind_face.png").resize((300, 300), Image.LANCZOS)
    bgp = Image.new("RGBA", (340, 320), hx("#161A17")); bgp.alpha_composite(ring, (20, 10)); im.paste(bgp, (40, 810))
    ic = ld("icons/icon_facade.png").resize((300, 300), Image.LANCZOS)
    bgp = Image.new("RGBA", (340, 320), hx("#EDE6D3")); bgp.alpha_composite(ic, (20, 10)); im.paste(bgp, (400, 810))
    d.text((760, 820), "Surface recipe (every tile)", font=font(20, "Bold"), fill=INK)
    notes = ["diagonal gradient, light top-left to deep bottom-right", "warm radial glow at the top-left, soft edge vignette",
             "four faint topographic contour arcs, 7% cream", "top rim light fading down, dark rim fading up from the base",
             "1.6 px warm hairline, 3 px contact shadow (never over 8 px)", "art sits in the 66% adaptive safe zone, 100 units = 338 px"]
    for i, t in enumerate(notes):
        d.text((760, 860 + i * 30), "- " + t, font=font(17), fill=INK)
    # type specimen
    d.text((40, 1160), "Typography: Inter (SIL Open Font License 1.1, The Inter Project Authors) - the only font used in the art", font=font(20, "SemiBold"), fill=INK)
    d.text((40, 1200), "N E S W  042°  78%", font=font(70, "Bold"), fill=INK)
    d.text((40, 1290), "Bold - compass letters and gauge numerals", font=font(18), fill=hx("#5A5A4A"))
    d.text((760, 1200), "SemiBold: wind 14 km/h · drone battery", font=font(34, "SemiBold"), fill=INK)
    d.text((760, 1255), "Regular: a warm field kit for the valley, drawn once and kept crisp at 44, 64, 128 and 512 px.", font=font(22), fill=INK)
    d.text((760, 1295), "Labels are in the dial PNGs only; the game keeps its own UI font for live text.", font=font(18), fill=hx("#5A5A4A"))
    d.text((40, 1440), "Generated by godot/tools/ui_art/build_all.py", font=font(15), fill=hx("#5A5A4A"))
    im.convert("RGB").save(os.path.join(DOCS, "tablet_ui_final_textures.jpg"), quality=92)


def build():
    views()
    textures()


if __name__ == "__main__":
    build()
