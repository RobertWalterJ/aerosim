"""Per-app art for every tablet app (lane osui): splash icon, header banner, empty-state illustration.

  apps/<app>/splash_icon.png   Android 12 splash: the foreground on its circle, 288 x 288 (192 dp at 1.5x); the
                               splash background colour is in APP_COLOURS / the spec
  apps/<app>/header.png        1600 x 200 app-bar banner (tonal gradient + watermark), 2x for a 800 x 100 dp slot
  apps/<app>/empty.png         empty-state illustration 480 x 480 (240 dp at 2x): tonal disc + mono glyph + accents
The per-app glyph lists (Material Symbols names) are in APP_GLYPHS and in the spec.
"""
import os
import osui_lib as L
import gen_icons as GI

OUT = os.path.join(L.OUT, "apps")

APP_GLYPHS = {
    "dronebudz": ["forum", "send", "attach_file", "mic", "mood", "reply", "group", "notifications", "search", "more_vert"],
    "vidtube": ["play_arrow", "pause", "videocam", "file_download_off", "share", "edit", "visibility", "payments", "sort", "add"],
    "photos": ["photo_library", "image", "share", "delete", "edit", "star", "add_photo_alternate", "grid_view", "filter_list"],
    "jobs": ["work", "route", "payments", "schedule", "check_circle", "flag", "filter_list", "map", "verified"],
    "casebook": ["badge", "local_police", "gavel", "folder", "photo_camera", "history", "group", "label", "lock"],
    "facade": ["storefront", "shopping_cart", "sell", "payments", "inventory_2", "local_parking", "verified", "star"],
    "store": ["install_mobile", "download", "download_done", "update", "delete", "star", "shield", "privacy_tip", "apps"],
    "map": ["search", "my_location", "navigation", "layers", "explore", "directions", "directions_car", "route", "pin_drop", "zoom_in", "zoom_out"],
    "settings": ["wifi", "bluetooth", "apps", "notifications", "battery_full", "storage", "volume_up", "display_settings", "palette", "security", "location_on", "system_update"],
    "weather": ["sunny", "partly_cloudy_day", "cloud", "rainy", "thunderstorm", "foggy", "ac_unit", "air", "thermostat"],
    "camera": ["photo_camera", "videocam", "flashlight_on", "timer", "hdr_auto", "center_focus_strong", "exposure", "wb_auto"],
    "phone": ["call", "history", "person", "group", "volume_up", "mic"],
    "clock": ["schedule", "alarm", "timer", "bedtime"],
    "files": ["folder", "image", "videocam", "download", "storage", "delete", "share"],
    "notes": ["edit", "bookmark", "label", "search", "add"],
    "recents": ["history", "close"],
    "installer": ["install_mobile", "download", "shield", "check_circle", "cancel"],
}
EMPTY_TEXT = {
    "dronebudz": ("No messages yet", "The crew will post here when there is news."),
    "vidtube": ("No uploads yet", "Upload a clip from the camera roll."),
    "photos": ("No photographs yet", "Press the shutter while flying."),
    "jobs": ("No jobs right now", "New work appears after the next story beat."),
    "casebook": ("No open case", "Rennick will send the file."),
    "facade": ("Nothing listed", "Check back after the next delivery."),
    "store": ("No apps to update", "Everything is up to date."),
    "map": ("No saved places", "Long-press the map to drop a pin."),
    "settings": ("No results", "Try another word."),
    "weather": ("No forecast", "The valley station is offline."),
    "camera": ("Camera unavailable", "Fit a camera add-on from Facade."),
    "phone": ("No recent calls", ""), "clock": ("No alarms", ""), "files": ("This folder is empty", ""),
    "notes": ("No notes", "Tap + to start a note."), "recents": ("No recent items", ""), "installer": ("Nothing to install", ""),
}


def build():
    A = GI.apps()
    for key, (name, top, bot, parts, game) in A.items():
        fg = GI.fg_markup(parts)
        # splash: Android 12 crops the foreground to a 2/3 circle; ship it on its own background disc
        sp = (f'<svg xmlns="http://www.w3.org/2000/svg" width="288" height="288" viewBox="18 18 72 72">'
              f'<defs><clipPath id="c"><circle cx="54" cy="54" r="36"/></clipPath></defs>'
              f'<g clip-path="url(#c)">{GI.bg_markup(top, bot)}{fg}</g></svg>')
        L.render(sp, 288, 288, os.path.join(OUT, key, "splash_icon.png"))
        # header banner: tonal gradient from the app colour to surface, watermark glyph on the right
        mono = GI.mono_markup(parts, "#FFFFFF", "wm")
        hd = (f'<svg xmlns="http://www.w3.org/2000/svg" width="1600" height="200" viewBox="0 0 800 100">'
              f'<defs><linearGradient id="h" x1="0" y1="0" x2="1" y2="0.4"><stop offset="0" stop-color="{bot}"/>'
              f'<stop offset="0.75" stop-color="{L.DARK["surface-container-high"]}"/></linearGradient></defs>'
              f'<rect width="800" height="100" fill="url(#h)"/>'
              f'<g transform="translate(600 -40) scale(1.7)" opacity="0.10">{mono}</g>'
              f'<g transform="translate(690 10) scale(0.75)" opacity="0.16">{mono}</g></svg>')
        L.render(hd, 1600, 200, os.path.join(OUT, key, "header.png"))
        # empty state
        em = (f'<svg xmlns="http://www.w3.org/2000/svg" width="480" height="480" viewBox="0 0 240 240">'
              f'<circle cx="120" cy="120" r="96" fill="{L.DARK["surface-container-high"]}"/>'
              f'<circle cx="120" cy="120" r="96" fill="{top}" fill-opacity="0.18"/>'
              f'<circle cx="198" cy="58" r="9" fill="{top}" fill-opacity="0.45"/><circle cx="44" cy="186" r="6" fill="{top}" fill-opacity="0.35"/>'
              f'<circle cx="210" cy="170" r="4" fill="{L.DARK["primary"]}" fill-opacity="0.6"/>'
              f'<g transform="translate(-9.6 -9.6) scale(2.4)">{GI.mono_markup(parts, L.DARK["on-surface-variant"], "em")}</g></svg>')
        L.render(em, 480, 480, os.path.join(OUT, key, "empty.png"))
    L.note(os.path.join(OUT, "<app>", "splash_icon.png"), 288, 288, None, "Android 12 splash icon (bg colour = icon bg bottom colour)")
    L.note(os.path.join(OUT, "<app>", "header.png"), 1600, 200, None, "app header banner, 800 x 100 dp slot (2x)")
    L.note(os.path.join(OUT, "<app>", "empty.png"), 480, 480, None, "empty-state illustration, 240 dp (2x)")
    return A


if __name__ == "__main__":
    print(len(build()), "apps")
