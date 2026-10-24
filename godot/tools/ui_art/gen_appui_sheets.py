"""Contact sheets for lane appui2: one sheet per group with file names (docs/realism/appui2/), plus the two lane sheets
docs/realism/models/appui2_final_views.jpg and appui2_final_textures.jpg."""
import os, glob
from PIL import Image, ImageDraw, ImageFont
from appui_lib import UI, HERE, hx

DOCS = os.path.normpath(os.path.join(HERE, "..", "..", "docs", "realism"))
FONTS = os.path.normpath(os.path.join(HERE, "..", "..", "assets", "fonts"))
LIGHT = (237, 230, 211)
DARK = (22, 26, 23)
INK = (27, 42, 34)
CREAMC = (240, 233, 209)


def font(sz, bold=False):
    return ImageFont.truetype(os.path.join(FONTS, "ui_sans_bold.ttf" if bold else "ui_sans.ttf"), sz)


def ld(rel):
    return Image.open(os.path.join(UI, rel)).convert("RGBA")


def grid_sheet(title, items, cell=180, cols=8, bg=DARK, fg=CREAMC, show=None, small=None, paper=None, note=None):
    """items: list of rel paths. show: box size for the main preview; small: list of extra px sizes shown beside it."""
    show = show or cell - 50
    rows = (len(items) + cols - 1) // cols
    extra = 0
    W, H = cols * cell + 20, rows * (cell + 26) + 70 + extra
    im = Image.new("RGBA", (W, H), bg + (255,))
    if paper:
        p = Image.open(os.path.join(UI, paper)).convert("RGBA").resize((W, H))
        im.alpha_composite(p)
    d = ImageDraw.Draw(im)
    d.text((14, 12), title, font=font(24, True), fill=fg)
    if note:
        d.text((14, 42), note, font=font(13), fill=fg)
    for i, rel in enumerate(items):
        x = 10 + (i % cols) * cell
        y = 66 + (i // cols) * (cell + 26)
        try:
            t = ld(rel)
        except FileNotFoundError:
            d.text((x + 6, y + 40), "MISSING\n" + rel, font=font(12), fill=(219, 92, 82))
            continue
        w, h = t.size
        k = min(show / w, show / h, 1.0 if max(w, h) <= show else 99)
        k = min(show / w, show / h)
        tt = t.resize((max(1, int(w * k)), max(1, int(h * k))), Image.LANCZOS)
        im.alpha_composite(tt, (x + 4, y + 4))
        if small:
            sx = x + 4 + tt.size[0] + 6
            sy = y + 4
            for s in small:
                if sx + s > x + cell:
                    break
                im.alpha_composite(t.resize((s, max(1, int(h * s / w))), Image.LANCZOS), (sx, sy))
                sy += s + 4
        name = os.path.basename(rel)
        d.text((x + 4, y + cell - 18), name, font=font(11 if len(name) * 6.2 < cell - 8 else 9), fill=fg)
        d.text((x + 4, y + cell - 4), f"{w} x {h}", font=font(10), fill=tuple(int(c * 0.7) for c in fg))
    return im.convert("RGB")


def nine_preview(rel, margins, W=360, H=200, bg=DARK):
    """Stretch a 9-patch to W x H to show it behaves."""
    t = ld(rel)
    l, tp, r, b = margins
    w, h = t.size
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    xs = [(0, l, 0, l), (l, w - r, l, W - r), (w - r, w, W - r, W)]
    ys = [(0, tp, 0, tp), (tp, h - b, tp, H - b), (h - b, h, H - b, H)]
    for sx0, sx1, dx0, dx1 in xs:
        for sy0, sy1, dy0, dy1 in ys:
            piece = t.crop((sx0, sy0, sx1, sy1)).resize((max(1, dx1 - dx0), max(1, dy1 - dy0)), Image.LANCZOS)
            out.alpha_composite(piece, (dx0, dy0))
    return out


GROUPS = {}


def groups():
    g = {}
    g["01_app_icons"] = ([f"icon_{k}.png" for k in ("chat", "studio", "photos", "jobs", "casebook", "market", "map", "settings", "recents", "home", "search", "weather", "camera", "phone")],
                         dict(cols=7, cell=200, small=[48, 40]), "Phone app icons at assets/ui/icon_<key>.png (256 root, shown with 48 and 40 px)")
    sysn = ["status_signal", "status_wifi", "status_battery", "status_battery_low", "status_notification", "status_search",
            "nav_home", "nav_back", "nav_recents", "nav_close", "nav_more", "badge_dot", "badge_unread", "badge_work", "badge_guide", "page_dot_on", "page_dot_off"]
    g["02_system_glyphs"] = ([n + ".png" for n in sysn], dict(cols=9, cell=150, show=72, small=[18, 24]), "Status, navigation and badges: root 2x (36 px) shown at 72, then at 18 and 24 px")
    g["03_portraits"] = ([f"avatar_{k}.png" for k in ("maya", "jo", "riley", "tom", "alex", "sam", "rennick", "unknown", "you", "wren", "kit")],
                         dict(cols=6, cell=270, show=200, small=[48, 36]), "Portraits at assets/ui/avatar_<key>.png (512), with 48 and 36 px")
    g["04_product_tiles"] = ([f"item_{k}.png" for k in ("raptor", "nightowl", "thermal_camera", "night_vision", "battery", "motors", "props", "controller", "repair_kit")],
                             dict(cols=5, cell=320, show=200, small=[96, 48]), "Facade product tiles (512, transparent outside the accent plate), with 96 and 48 px")
    g["05_casebook_kit"] = (["casebook_folder.png", "casebook_photo_frame.png", "casebook_stamp_open.png", "casebook_stamp_closed.png",
                             "casebook_stamp_evidence.png", "stamp_evidence.png", "stamp_case_closed.png", "casebook_empty_folder.png",
                             "casebook_tab_overview.png", "casebook_tab_evidence.png", "casebook_tab_chapters.png", "casebook_tab_contacts.png",
                             "casebook_timeline_node_open.png", "casebook_timeline_node_done.png", "casebook_timeline_node_waiting.png", "casebook_pin_red.png"],
                            dict(cols=8, cell=180, paper="casebook_paper.jpg", bg=LIGHT, fg=INK, small=[32, 24]), "Casebook kit on casebook_paper.jpg (tab glyphs are cream: shown on paper they read faint, they sit on the dark rail)")
    g["06_stamps"] = (["act_1_waiting.png", "act_2_lake_car.png", "act_3_last_flight.png", "act_4_cabin.png", "act_5_end.png",
                       "job_stamp_pulled.png", "job_stamp_excellent.png", "facade_sold.png"],
                      dict(cols=8, cell=200, paper="casebook_paper.jpg", bg=LIGHT, fg=INK, small=[64]), "Act, job and Facade stamps: worn ink, no readable text (shown with 64 px)")
    bad = ["badge_rush", "badge_dm", "badge_job", "badge_story", "badge_edited", "notify_clip", "notify_video", "notify_photo", "notify_job",
           "channel_clips", "channel_town", "channel_weather", "channel_jobs"]
    jb = ["job_badge_distance", "job_badge_range", "job_badge_frame", "job_badge_retake", "job_badge_pulled", "job_badge_excellent"]
    g["07_badges"] = ([n + ".png" for n in bad + jb], dict(cols=10, cell=150, show=96, small=[32, 24]), "Badges, notification glyphs, channel marks and job badges")
    gl = ["chat_compose", "chat_attach", "chat_mic", "chat_send", "chat_channel_hash", "chat_channel_voice", "chat_channel_jobs", "chat_reply_arrow",
          "chat_pinned", "chat_edited", "studio_metric_followers", "studio_metric_money", "studio_metric_videos", "studio_metric_views", "studio_play",
          "studio_upload", "studio_cut", "photos_album", "photos_grid", "photos_detail", "photos_delete", "photos_share", "job_category_photo",
          "job_category_farm", "job_category_lake", "job_category_civic", "facade_drones", "facade_cameras", "facade_power", "facade_parts"]
    g["08_app_glyphs"] = ([n + ".png" for n in gl], dict(cols=10, cell=140, show=64, small=[24]), "App glyphs (cream on transparent), root 2x, with 24 px")
    g["09_map"] = (["map_paper.jpg", "map_pin_current.png", "map_pin_suggested.png", "map_pin_locked.png", "map_pin_open.png", "map_route_line.png",
                    "map_compass.png", "map_beacon.png"], dict(cols=8, cell=200, small=[32]), "Map: survey paper, pins, dashed route tile, compass and beacon")
    g["10_banners_overlays"] = (["studio_banner.jpg", "chat_server_banner.png", "photos_empty.png", "photos_frame_clean.png", "facade_seller_strip.png",
                                 "thumb_frame_clean.png", "thumb_frame_rust.png", "thumb_duration_mask.png", "thumb_play_plate.png", "paper_grain.png"],
                                dict(cols=5, cell=300, bg=(90, 96, 88), fg=CREAMC), "Banners, empty states, 9-patches, thumbnail overlays (on mid grey) and the paper grain overlay")
    return g


def fonts_sheet():
    W, H = 1600, 520
    im = Image.new("RGB", (W, H), DARK)
    d = ImageDraw.Draw(im)
    d.text((14, 12), "Fonts at assets/fonts (OFL 1.1)", font=font(24, True), fill=CREAMC)
    y = 60
    for f, label in (("ui_sans.ttf", "ui_sans.ttf  Work Sans Regular"), ("ui_sans_bold.ttf", "ui_sans_bold.ttf  Work Sans Bold"),
                     ("ui_serif.ttf", "ui_serif.ttf  IBM Plex Serif Regular"), ("ui_serif_bold.ttf", "ui_serif_bold.ttf  IBM Plex Serif Bold"),
                     ("ui_mono.ttf", "ui_mono.ttf  IBM Plex Mono Regular")):
        d.text((14, y), label, font=font(13), fill=(153, 159, 141))
        fo = ImageFont.truetype(os.path.join(FONTS, f), 30)
        d.text((14, y + 18), "Halloway Valley · Maya cut the ridge clip · 1,248 views · 07:42 · 3.6 km", font=fo, fill=CREAMC)
        y += 88
    return im


def build():
    out = os.path.join(DOCS, "appui2")
    os.makedirs(out, exist_ok=True)
    sheets = []
    for name, (items, kw, title) in groups().items():
        sh = grid_sheet(title, items, **kw)
        if name == "10_banners_overlays":
            # add a stretched 9-patch demo row
            demo = Image.new("RGB", (sh.size[0], 240), (90, 96, 88))
            dd = ImageDraw.Draw(demo)
            dd.text((14, 8), "9-patch stretch test: casebook_folder (48,72,48,48), casebook_photo_frame (24), facade_seller_strip (16,12,12,12)", font=font(13), fill=CREAMC)
            x = 14
            for rel, m, w, h in (("casebook_folder.png", (48, 72, 48, 48), 420, 200), ("casebook_photo_frame.png", (24, 24, 24, 24), 320, 200), ("facade_seller_strip.png", (16, 12, 12, 12), 420, 60)):
                p = nine_preview(rel, m, w, h)
                demo.paste(p, (x, 32), p)
                x += w + 20
            big = Image.new("RGB", (sh.size[0], sh.size[1] + 240))
            big.paste(sh, (0, 0)); big.paste(demo, (0, sh.size[1]))
            sh = big
        sh.save(os.path.join(out, name + ".jpg"), quality=90)
        sheets.append(sh)
    fs = fonts_sheet()
    fs.save(os.path.join(out, "11_fonts.jpg"), quality=90)
    sheets.append(fs)
    # combined lane views sheet: every group sheet stacked at a common width
    Wc = 2400
    scaled = [s.resize((Wc, int(s.size[1] * Wc / s.size[0])), Image.LANCZOS) for s in sheets]
    Hc = sum(s.size[1] for s in scaled) + 60
    comb = Image.new("RGB", (Wc, Hc), DARK)
    d = ImageDraw.Draw(comb)
    d.text((14, 14), "Lane appui2 - phone app art: final views (group sheets in docs/realism/appui2/)", font=font(30, True), fill=CREAMC)
    y = 60
    for s in scaled:
        comb.paste(s, (0, y)); y += s.size[1]
    comb.save(os.path.join(DOCS, "models", "appui2_final_views.jpg"), quality=86)
    textures_sheet()


TEXTURES = [
    ("casebook_paper.jpg", "Casebook paper, 2048 tileable", "procedural noise + fibres", "original"),
    ("map_paper.jpg", "Map survey paper, grid and folds", "procedural, original", "generated"),
    ("paper_grain.png", "Paper grain overlay 512, alpha 0-18%", "procedural, original", "generated"),
    ("studio_banner.jpg", "VidTube channel banner", "procedural, original", "generated"),
    ("chat_server_banner.png", "DroneBudz server banner", "procedural, original", "generated"),
]
RENDER_TEX = [
    ("Portrait bodies, faces, skins, eyes, hair, clothes", "MakeHuman CC0 system assets + community assets via MPFB 2 (people lane pipeline)", "CC0 and CC BY: see assets/ui/APPUI-README.md"),
    ("Portrait fabrics (knitted_fleece, cotton_jersey, caban, polar_fleece, stretch_poplin, rough_linen)", "Poly Haven photographs (people lane cache)", "CC0"),
    ("Portrait props (headphones, lanyard, radio, strap, magnifier, tools, goggles, gaiter)", "modelled in appui_portraits.py, flat Principled materials", "original"),
    ("Raptor, Night Owl, night vision pod, thermal pod", "the game's own glTF models (drones lane, models9)", "as their lanes"),
    ("Battery, motors, props, controller, repair kit", "modelled in appui_products.py, Principled + procedural noise bump", "original"),
]
PALETTE = [("#0E110F", "pine black"), ("#1F241F", "card"), ("#F0E9D1", "warm paper"), ("#E0AB59", "brass"), ("#74A87A", "moss"),
           ("#5C959F", "lake"), ("#B36447", "rust"), ("#DB5C52", "danger"), ("#5A7088", "slate"), ("#4E5F73", "ink slate"),
           ("#8E3B2A", "ink rust"), ("#A8742C", "ink brass"), ("#D9C08A", "manila"), ("#C8463A", "pin red")]


def textures_sheet():
    W = 2000
    H = 1500
    im = Image.new("RGB", (W, H), LIGHT)
    d = ImageDraw.Draw(im)
    d.text((14, 12), "Lane appui2 - textures and sources used", font=font(30, True), fill=INK)
    x, y = 14, 64
    for rel, label, src, lic in TEXTURES:
        t = ld(rel)
        k = 360 / max(t.size)
        tt = t.resize((int(t.size[0] * k), int(t.size[1] * k)), Image.LANCZOS)
        bg = Image.new("RGBA", (360, 360), (120, 120, 112, 255))
        bg.alpha_composite(tt, ((360 - tt.size[0]) // 2, (360 - tt.size[1]) // 2))
        im.paste(bg.convert("RGB"), (x, y))
        d.text((x, y + 366), rel, font=font(15, True), fill=INK)
        d.text((x, y + 386), label, font=font(13), fill=INK)
        d.text((x, y + 404), f"{src}; {lic}", font=font(12), fill=(90, 90, 80))
        x += 390
    # crop of the paper at 1:1
    p = ld("casebook_paper.jpg").crop((0, 0, 600, 300))
    im.paste(p.convert("RGB"), (14, 500))
    d.text((14, 805), "casebook_paper.jpg at 1:1 (fibres and tooth)", font=font(13), fill=INK)
    p = ld("map_paper.jpg").crop((560, 900, 1160, 1200))
    im.paste(p.convert("RGB"), (640, 500))
    d.text((640, 805), "map_paper.jpg at 1:1 (grid, a fold line)", font=font(13), fill=INK)
    y = 840
    d.text((14, y), "Palette swatches (UI-STYLE.md plus ink and manila)", font=font(18, True), fill=INK)
    for i, (hxv, nm) in enumerate(PALETTE):
        xx = 14 + i * 138
        d.rectangle([xx, y + 30, xx + 126, y + 110], fill=hx(hxv)[:3])
        d.text((xx, y + 114), f"{nm}\n{hxv}", font=font(12), fill=INK)
    y = 1010
    d.text((14, y), "Materials inside the renders (portraits and product tiles)", font=font(18, True), fill=INK)
    for i, (a, b, c) in enumerate(RENDER_TEX):
        d.text((14, y + 32 + i * 50), a, font=font(14, True), fill=INK)
        d.text((14, y + 52 + i * 50), f"{b}  |  licence: {c}", font=font(13), fill=(70, 70, 62))
    d.text((14, H - 40), "Fonts: Work Sans, IBM Plex Serif, IBM Plex Mono (SIL OFL 1.1), see assets/fonts/LICENSES.md", font=font(14), fill=INK)
    im.save(os.path.join(DOCS, "models", "appui2_final_textures.jpg"), quality=88)


if __name__ == "__main__":
    build()
