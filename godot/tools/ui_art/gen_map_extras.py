"""Map app art, app banners and video thumbnail overlays (CLAUDE-PHONE-APP-UI-PASS.md P1, CLAUDE-APP-ASSETS.md P2)."""
import math
from appui_lib import *
from gen_casebook import paper


def map_pin(S, kind):
    c = Canvas(S).unit(S / 2, S / 2, S / 24.0)
    if kind == "current":
        c.fill(c.circle(0, 0, 11), LAKE, 0.22)
        c.fill(c.circle(0, 0, 6.8), CREAM_HI)
        c.fill(c.circle(0, 0, 5.0), Gradient([(0, hx("#8FC6CF")), (1, hx("#2F6E79"))], p0=(-4, -4), p1=(4, 4)))
        return c.render()
    body = c.circle(0, -4, 7.4) | c.poly([(-6.2, -0.4), (6.2, -0.4), (0, 11)], 0.8)
    cols = {"suggested": (BRASS_HI, BRASS_LO), "locked": (hx("#A3A79A"), hx("#5E6258")), "open": (hx("#96C49B"), hx("#4C7C55"))}[kind]
    c.shadow(body, dy=0.8 if S < 48 else 1.4, blur=1.0 if S < 48 else 2.0, alpha=0.35)
    c.fill(body, vgrad(cols[0], cols[1], -11, 11))
    c.fill(body.edge(max(1, int(S / 40 * c.ss))), (255, 246, 220, 255), 0.35)
    if kind == "locked":
        c.fill(c.rrect(-3.3, -4.2, 3.3, 0.8, 0.8), CREAM_HI)
        c.fill(c.arc(0, -4.4, 2.2, 180, 360, 1.3), CREAM_HI)
    elif kind == "open":
        c.fill(c.ring(0, -4, 3.0, 1.8), CREAM_HI)
    else:
        c.fill(c.circle(0, -4, 2.8), hx("#6E4A1C"))
    return c.render()


def route_line(W=128, H=12, period=32, dash=20):
    c = Canvas(W, H).unit(0, H / 2, 1.0)
    for x in range(0, W, period):
        c.fill(c.line([(x + 3, 0), (x + 3 + dash - 6, 0)], 6), BRASS)
    return c.render()


def compass(S=256):
    c = Canvas(S).unit(S / 2, S / 2, S / 100.0)
    c.fill(c.circle(0, 0, 47), hx("#1F241F"), 0.55)
    c.fill(c.ring(0, 0, 45, 2.2), BRASS)
    c.fill(c.ring(0, 0, 39, 0.8), BRASS, 0.6)
    for i in range(72):
        a = math.radians(i * 5)
        r0 = 39 if i % 18 == 0 else (41.5 if i % 2 == 0 else 42.8)
        c.fill(c.line([(r0 * math.cos(a), r0 * math.sin(a)), (44 * math.cos(a), 44 * math.sin(a))], 0.9 if i % 18 else 1.6), BRASS, 0.85)
    for k in range(8):
        a = math.radians(-90 + k * 45)
        ln = 34 if k % 2 == 0 else 20
        w = 6.5 if k % 2 == 0 else 4.5
        tip = (ln * math.cos(a), ln * math.sin(a))
        l = (w * math.cos(a + math.pi / 2), w * math.sin(a + math.pi / 2))
        half1 = c.poly([(0, 0), tip, l], 0.2)
        half2 = c.poly([(0, 0), tip, (-l[0], -l[1])], 0.2)
        if k == 0:
            c.fill(half1, hx("#D9714E")); c.fill(half2, hx("#9A4430"))
        else:
            c.fill(half1, BRASS_HI if k % 2 == 0 else CREAM_LO); c.fill(half2, BRASS_LO if k % 2 == 0 else MUTED)
    c.fill(c.circle(0, 0, 3.4), BRASS_HI)
    c.fill(c.circle(0, 0, 1.4), hx("#6E4A1C"))
    # N marker without a letter: a small brass triangle outside the ring
    c.fill(c.poly([(-4, -47.5), (4, -47.5), (0, -42)], 0.3), hx("#D9714E"))
    return c.render()


def beacon(S=128):
    c = Canvas(S).unit(S / 2, S / 2, S / 24.0)
    for r, a in ((10.5, 0.35), (7.5, 0.6), (4.5, 0.9)):
        c.fill(c.arc(0, 2, r, -150, -30, 1.6), BRASS, a)
    c.fill(c.circle(0, 2, 2.4), hx("#E36A4E"))
    c.fill(c.line([(0, 4), (0, 11)], 1.5), BRASS)
    c.fill(c.line([(-3, 11), (3, 11)], 1.5), BRASS)
    return c.render()


def banner(W, H, base, accent, seed, film=False):
    """A textless channel banner: graded field, valley contour lines and a low brass sun."""
    yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
    t = xx / W * 0.6 + yy / H * 0.4
    img = np.zeros((H, W, 3), np.float32)
    lo, hi = np.array(darken(base, 0.35)[:3], np.float32), np.array(lighten(base, 0.12)[:3], np.float32)
    img[:] = hi * (1 - t[..., None]) + lo * t[..., None]
    nz = tile_noise(max(W, H), seed, ((6, 1.0), (16, 0.5), (60, 0.25)))[:H, :W]
    img *= (0.92 + 0.12 * nz)[..., None]
    im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB").convert("RGBA")
    d = ImageDraw.Draw(im, "RGBA")
    sx, sy, sr = W * 0.74, H * 0.64, H * 0.28
    for k in range(6, 0, -1):
        d.ellipse([sx - sr * (1 + k * 0.25), sy - sr * (1 + k * 0.25), sx + sr * (1 + k * 0.25), sy + sr * (1 + k * 0.25)], fill=(accent[0], accent[1], accent[2], 10))
    d.ellipse([sx - sr, sy - sr, sx + sr, sy + sr], fill=(accent[0], accent[1], accent[2], 235))
    rng = np.random.default_rng(seed)
    for k in range(7):
        base_y = H * (0.55 + k * 0.08)
        ph = rng.random() * 6
        pts = [(x, base_y + H * 0.07 * math.sin(x / W * 5 + ph) + H * 0.03 * math.sin(x / W * 13 + ph * 2)) for x in np.linspace(-10, W + 10, 120)]
        poly = pts + [(W + 10, H + 10), (-10, H + 10)]
        shade = darken(base, 0.25 + k * 0.08)
        d.polygon(poly, fill=(shade[0], shade[1], shade[2], 255))
        d.line(pts, fill=(240, 233, 209, 40), width=max(1, H // 200))
    if film:
        for x in range(12, W, 36):
            d.rounded_rectangle([x, 8, x + 18, 20], 3, fill=(14, 17, 15, 150))
            d.rounded_rectangle([x, H - 20, x + 18, H - 8], 3, fill=(14, 17, 15, 150))
    return im


def thumb_overlay(W, H, kind):
    c = Canvas(W, H, ss=2).unit(0, 0, W / 1280.0)
    if kind == "clean":
        c.fill(c.rrect(0, 0, 1280, 720, 0) - c.rrect(10, 10, 1270, 710, 4), CREAM, 0.92)
        for cx, cy in ((0, 0), (1280, 0), (0, 720), (1280, 720)):
            c.fill(c.circle(cx, cy, 260), Gradient([(0, (0, 0, 0, 90)), (1, (0, 0, 0, 0))], center=(cx, cy), radius=260))
    elif kind == "rust":
        c.fill(c.rrect(0, 0, 1280, 720, 0) - c.rrect(14, 14, 1266, 706, 4), RUST, 0.95)
        c.fill(c.circle(1280, 0, 340), Gradient([(0, (179, 100, 71, 190)), (1, (179, 100, 71, 0))], center=(1280, 0), radius=340))
        c.fill(c.circle(0, 720, 300), Gradient([(0, (0, 0, 0, 110)), (1, (0, 0, 0, 0))], center=(0, 720), radius=300))
        c.fill(c.rrect(1150, 34, 1240, 124, 22), RUST)
        c.fill(c.poly([(1182, 58), (1182, 100), (1218, 79)], 3), CREAM_HI)
    elif kind == "duration":
        c.fill(c.rrect(1080, 640, 1256, 700, 14), (14, 17, 15, 255), 0.72)
    elif kind == "play":
        c.fill(c.circle(640, 360, 78), (14, 17, 15, 255), 0.55)
        c.fill(c.ring(640, 360, 78, 4), CREAM, 0.7)
        c.fill(c.poly([(615, 318), (615, 402), (684, 360)], 6), CREAM, 0.95)
    return c.render()


def build():
    save_ui(paper(2048, seed=23, base=(236, 228, 204), fib=500, grid=(64, (120, 140, 120), 0.10), folds=((1 / 3, 2 / 3), (0.5,))),
            "map_paper.jpg", note="2048 survey paper, faint grid and fold lines, no labels")
    for k in ("current", "suggested", "locked", "open"):
        save_ui(map_pin(64, k), f"map_pin_{k}.png", note="32 px nominal; pin tip at bottom centre (current: centre)")
        save_ui(map_pin(32, k), f"sizes/32/map_pin_{k}.png")
    save_ui(route_line(), "map_route_line.png", note="tile horizontally; 3 px dashed brass line at 1x (6 px here), 32 px period")
    save_ui(compass(256), "map_compass.png", note="128 px nominal; north is up, marked by the rust needle")
    save_ui(compass(128), "sizes/128/map_compass.png")
    save_ui(beacon(128), "map_beacon.png", note="64 px nominal")
    save_ui(banner(1600, 500, RUST, BRASS, 61, film=True), "studio_banner.jpg", note="VidTube channel banner, no text")
    save_ui(banner(1200, 200, MOSS, CREAM, 62), "chat_server_banner.png", note="DroneBudz server banner, no text")
    for kind in ("clean", "rust", "duration", "play"):
        name = {"clean": "thumb_frame_clean", "rust": "thumb_frame_rust", "duration": "thumb_duration_mask", "play": "thumb_play_plate"}[kind]
        save_ui(thumb_overlay(1280, 720, kind), f"{name}.png", note="1280 x 720 overlay")
        save_ui(thumb_overlay(480, 270, kind), f"thumbs/480/{name}.png", note="480 x 270 overlay")


if __name__ == "__main__":
    build()
