"""Priority 1 controls + tablet frame, Priority 2 polish (page dots, dock tray, vignette)."""
from lib import *
from glyphs import *

FIELD_D = hx("#232823")


def switch(on):
    c = Canvas(104, 64).unit(0, 0, 1)
    tr = c.rrect(2, 6, 102, 58, 26)
    if on:
        c.fill(tr, Gradient([(0, hx("#86B88C")), (1, hx("#4F8359"))], p0=(0, 6), p1=(0, 58)))
        c._vfade(tr, 6, 22, 0.22, 0, (255, 255, 255, 255))
        c.fill(tr.edge(8), hx("#2C4A36"), 0.35)
    else:
        c.fill(tr, vgrad(hx("#1B201C"), hx("#2A2F29"), 6, 58))
        c.fill(tr.edge(10), CREAM, 0.30)
    return c.render()


def knob(S=64, on=False):
    c = Canvas(S).unit(S / 2, S / 2, S / 64.0)
    d = c.circle(0, 0, 25)
    c.shadow(d, dy=2, blur=3, alpha=0.38)
    if on:
        c.fill(d, Gradient([(0, BRASS_HI), (1, hx("#C58A3A"))], p0=(-18, -22), p1=(18, 24)))
    else:
        c.fill(d, Gradient([(0, CREAM_HI), (1, hx("#CFC5A5"))], p0=(-18, -22), p1=(18, 24)))
    c.fill(d.edge(4), (255, 255, 255, 255), 0.25)
    return c.render()


def slider(kind):
    c = Canvas(256, 64).unit(0, 0, 1)
    cap = c.rrect(8, 26, 248, 38, 6)
    if kind == "track":
        c.fill(cap, vgrad(hx("#12160F"), hx("#2A2F29"), 26, 38))
        c.fill(cap.edge(2), CREAM, 0.20)
    else:
        c.fill(cap, Gradient([(0, hx("#F2CB86")), (1, hx("#C58A3A"))], p0=(0, 26), p1=(0, 38)))
        c._vfade(cap, 26, 32, 0.35, 0, (255, 255, 255, 255))
    return c.render()


def slider_knob():
    c = Canvas(64).unit(32, 32, 1)
    d = c.circle(0, 0, 25)
    c.shadow(d, dy=2, blur=3, alpha=0.38)
    c.fill(d, Gradient([(0, CREAM_HI), (1, hx("#CFC5A5"))], p0=(-18, -22), p1=(18, 24)))
    c.fill(c.circle(0, 0, 10), Gradient([(0, BRASS_HI), (1, hx("#C58A3A"))], p0=(-8, -8), p1=(8, 10)))
    c.fill(c.ring(0, 0, 25, 2), (255, 255, 255, 255), 0.3)
    return c.render()


def button(kind, pressed=False):
    W, H = 192, 96
    c = Canvas(W, H).unit(0, 0, 1)
    body = c.rrect(4, 4, W - 4, H - 6, 28)
    if kind == "primary":
        top, bot = (hx("#F2CB86"), hx("#C58A3A")) if not pressed else (hx("#D7A95A"), hx("#A8742E"))
        c.shadow(body, dy=2, blur=3, alpha=0.35)
        c.fill(body, vgrad(top, bot, 4, H - 6))
        c._vfade(body, 4, 40, 0.28, 0, (255, 255, 255, 255))
        c.fill(body.edge(3), hx("#7A5420"), 0.45)
    elif kind == "ghost":
        c.fill(body.edge(4), CREAM, 0.42 if not pressed else 0.70)
        if pressed:
            c.fill(body, CREAM, 0.08)
    else:
        c.shadow(body, dy=2, blur=3, alpha=0.30)
        c.fill(body, vgrad(hx("#242A24") if not pressed else hx("#2A2F29"), hx("#1B201B"), 4, H - 6))
        c._vfade(body, 4, 30, 0.07, 0, (255, 245, 215, 255))
        c.fill(body.edge(3), CREAM, 0.14)
    return c.render()


def mark(kind, on):
    c = Canvas(64).unit(32, 32, 1)
    if kind == "radio":
        o = c.circle(0, 0, 22)
        if on:
            c.fill(o, Gradient([(0, hx("#86B88C")), (1, hx("#4F8359"))], p0=(-16, -18), p1=(16, 20)))
            c.fill(c.circle(0, 0, 9), CREAM_HI)
        else:
            c.fill(o, hx("#1B201C"))
            c.fill(o.edge(8), CREAM, 0.50)
    else:
        b = c.rrect(-21, -21, 21, 21, 8)
        if on:
            c.fill(b, Gradient([(0, hx("#86B88C")), (1, hx("#4F8359"))], p0=(-16, -18), p1=(16, 20)))
            c.fill(c.line([(-11, 1), (-3, 9), (12, -8)], 5.6), CREAM_HI)
        elif kind == "mixed":
            c.fill(b, hx("#1B201C"))
            c.fill(b.edge(8), BRASS, 0.8)
            c.fill(c.line([(-10, 0), (10, 0)], 5.6), BRASS)
        else:
            c.fill(b, hx("#1B201C"))
            c.fill(b.edge(8), CREAM, 0.50)
    return c.render()


def search_pill():
    W, H = 640, 96
    c = Canvas(W, H).unit(0, 0, 1)
    p = c.rrect(4, 4, W - 4, H - 8, 44)
    c.shadow(p, dy=2, blur=4, alpha=0.30)
    c.fill(p, vgrad(hx("#2A302A"), hx("#181C18"), 4, H - 8), 0.84)
    c._vfade(p, 4, 36, 0.10, 0, (255, 245, 215, 255))
    c.fill(p.edge(3), CREAM, 0.22)
    return c.render()


def page_dot(on):
    c = Canvas(32).unit(16, 16, 1)
    if on:
        c.fill(c.circle(0, 0, 9), Gradient([(0, CREAM_HI), (1, hx("#CFC5A5"))], p0=(-6, -8), p1=(6, 8)))
    else:
        c.fill(c.circle(0, 0, 6.5), CREAM, 0.38)
    return c.render()


def dock_tray():
    W, H = 512, 128
    c = Canvas(W, H).unit(0, 0, 1)
    t = c.rrect(4, 6, W - 4, H - 8, 44)
    c.fill(t, vgrad(hx("#2A312B"), hx("#101410"), 6, H - 8), 0.58)
    c._vfade(t, 6, 50, 0.16, 0, (255, 245, 215, 255))
    c.fill(t.edge(3), CREAM, 0.20)
    return c.render()


def vignette(W=1920, H=1080):
    import numpy as np
    y, x = np.mgrid[0:H, 0:W].astype(np.float32)
    nx, ny = (x / W - 0.5) * 2, (y / H - 0.5) * 2
    d = np.sqrt((nx * 0.92) ** 2 + (ny * 1.05) ** 2)
    a = np.clip((d - 0.62) / 0.55, 0, 1) ** 1.8 * 0.46
    arr = np.zeros((H, W, 4), np.float32)
    arr[..., 0], arr[..., 1], arr[..., 2] = 34, 22, 12      # warm umber, never pure black
    arr[..., 3] = a * 255
    return Image.fromarray(arr.astype(np.uint8), "RGBA")


def tablet_frame(W, H):
    f = H / 720.0
    ss = 2
    big = Image.new("RGBA", (W * ss, H * ss), hx("#0A0C0B"))
    d = ImageDraw.Draw(big)
    b = 17 * f * ss
    rad = 22 * f * ss
    hole = Image.new("L", big.size, 0)
    ImageDraw.Draw(hole).rounded_rectangle([b, b, W * ss - b - 1, H * ss - b - 1], radius=rad, fill=255)
    # chassis rim: very thin lighter line at the outermost edge
    rim = Image.new("L", big.size, 0)
    ImageDraw.Draw(rim).rounded_rectangle([0, 0, W * ss - 1, H * ss - 1], radius=rad + b, outline=255, width=max(2, int(1.5 * f * ss)))
    big.paste(Image.new("RGBA", big.size, hx("#4A4F47")), (0, 0), rim)
    # soft inner lip (inside the screen area, a few px, keeps the photo visible)
    lip_o = hole
    lip_i = Image.new("L", big.size, 0)
    ImageDraw.Draw(lip_i).rounded_rectangle([b + 2.2 * f * ss, b + 2.2 * f * ss, W * ss - b - 2.2 * f * ss - 1, H * ss - b - 2.2 * f * ss - 1],
                                              radius=rad - 2.2 * f * ss, fill=255)
    lip = ImageChops.subtract(lip_o, lip_i).point(lambda v: int(v * 0.30))
    big.paste(Image.new("RGBA", big.size, hx("#05070A")), (0, 0), lip)
    # camera + speaker slot in the top bezel
    cx, cy = W * ss / 2, b / 2
    r = 3.4 * f * ss
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=hx("#050607"))
    d.ellipse([cx - r * 0.62, cy - r * 0.62, cx + r * 0.62, cy + r * 0.62], fill=hx("#1E3A44"))
    d.ellipse([cx - r * 0.30 - r * 0.15, cy - r * 0.30 - r * 0.2, cx + r * 0.05, cy + r * 0.0], fill=hx("#6FA0A8"))
    sx = cx + 40 * f * ss
    d.rounded_rectangle([sx - 15 * f * ss, cy - 1.5 * f * ss, sx + 15 * f * ss, cy + 1.5 * f * ss], radius=1.5 * f * ss, fill=hx("#1A1D1B"))
    # cut the screen opening transparent (premultiplied-safe resize)
    a = big.getchannel("A")
    inv = hole.point(lambda v: 255 - v)
    big.putalpha(ImageChops.multiply(a, inv))
    return big.convert("RGBa").resize((W, H), Image.LANCZOS).convert("RGBA")


def build():
    save(switch(True), "controls/switch_on.png")
    save(switch(False), "controls/switch_off.png")
    save(knob(64), "controls/switch_knob.png")
    save(knob(64, True), "controls/switch_knob_on.png")
    save(slider("track"), "controls/slider_track.png")
    save(slider("fill"), "controls/slider_fill.png")
    save(slider_knob(), "controls/slider_knob.png")
    for k in ("primary", "ghost", "card"):
        save(button(k), f"controls/button_{k}.png")
        save(button(k, True), f"controls/button_{k}_pressed.png")
    for k in ("radio", "check"):
        save(mark(k, True), f"controls/{k}_on.png")
        save(mark(k, False), f"controls/{k}_off.png")
    save(mark("mixed", False), "controls/check_mixed.png")
    save(search_pill(), "controls/search_pill.png")
    for (W, H) in ((1280, 720), (1920, 1080), (2560, 1440)):
        save(tablet_frame(W, H), f"frame/tablet_frame_{W}x{H}.png")
    save(page_dot(True), "polish/page_dot_on.png")
    save(page_dot(False), "polish/page_dot_off.png")
    save(dock_tray(), "polish/dock_tray.png")
    save(vignette(), "polish/wallpaper_vignette.png")


if __name__ == "__main__":
    build()
