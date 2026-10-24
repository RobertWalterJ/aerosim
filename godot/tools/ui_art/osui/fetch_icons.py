"""Download the permissively licensed SVG icons and fonts the OS UI (lane osui) uses into godot/assets/ui/svg/.

  python fetch_icons.py            (re-runnable; skips files already present)

Sources are the official GitHub repositories (raw) or their npm packages on jsDelivr, pinned by version:
  Material Symbols  github google/material-design-icons (Apache-2.0)
  Lucide            npm lucide-static@0.460.0 (ISC)
  Tabler            npm @tabler/icons@3.19.0 (MIT)
  Phosphor          npm @phosphor-icons/core@2.1.1 (MIT)
  Maki              npm @mapbox/maki@8.0.1 (CC0-1.0)
  Temaki            npm @rapideditor/temaki@5.8.0 (CC0-1.0)
  Roboto, Roboto Mono  github googlefonts (Apache-2.0 / OFL-1.1 as per each LICENSE file)
The GPA corporate proxy re-signs TLS; Windows' certificate store trusts it, so urllib uses the OS store via
`ssl.create_default_context()` + truststore when available. If a download fails it is recorded in FETCH-LOG.md.
"""
import os, sys, ssl, urllib.request, json, time

HERE = os.path.dirname(os.path.abspath(__file__))
GODOT = os.path.normpath(os.path.join(HERE, "..", "..", ".."))
OUT = os.path.join(GODOT, "assets", "ui", "svg")

try:
    import truststore  # pip vendors one; a standalone copy may exist
    truststore.inject_into_ssl()
except Exception:
    try:
        from pip._vendor import truststore  # type: ignore
        truststore.inject_into_ssl()
    except Exception:
        pass

MS = "https://raw.githubusercontent.com/google/material-design-icons/master/symbols/web/{n}/materialsymbolsoutlined/{n}{f}_24px.svg"
SETS = {
    "material": {
        "licence": "Apache-2.0", "url": MS,
        "repo": "https://github.com/google/material-design-icons",
        "names": """wifi wifi_off bluetooth bluetooth_disabled do_not_disturb_on airplanemode_active screen_rotation
        screen_lock_rotation flashlight_on flashlight_off battery_saver screen_record settings power_settings_new mic search
        arrow_back home apps notifications notifications_off notifications_active notifications_paused brightness_low
        brightness_high dark_mode light_mode location_on my_location navigation near_me layers explore add remove close check
        more_vert more_horiz expand_more expand_less chevron_right download install_mobile delete share edit star info warning
        error lock lock_open fingerprint photo_camera videocam image photo_library work folder storefront map cloud
        partly_cloudy_day sunny rainy thunderstorm foggy ac_unit air chat forum call history person group schedule alarm
        calendar_month volume_up volume_off vibration signal_cellular_alt battery_full battery_5_bar battery_3_bar
        battery_1_bar battery_alert battery_charging_full cast data_saver_on accessibility palette wallpaper
        display_settings storage security privacy_tip system_update update restart_alt sync open_in_new reply send attach_file
        mood add_photo_alternate play_arrow pause stop filter_list sort tune timer thermostat nightlight visibility
        center_focus_strong exposure wb_auto hdr_auto flight_takeoff flight_land flight satellite_alt route
        directions directions_car local_parking sailing park forest water landscape zoom_in zoom_out straighten flag
        pin_drop bookmark label verified shield badge local_police inventory_2 shopping_cart sell payments apps_outage
        widgets dashboard screenshot_monitor bedtime keyboard_arrow_up drag_handle radio_button_checked check_circle
        cancel help mark_chat_unread swipe_up swipe_down open_with crop_free grid_view view_list account_circle
        travel_explore download_done file_download_off progress_activity hourglass_empty""".split(),
        "filled": """wifi bluetooth do_not_disturb_on airplanemode_active flashlight_on battery_saver home notifications
        location_on my_location navigation star lock photo_camera videocam image work folder storefront map chat call person
        settings mic play_arrow pause bookmark flag check_circle account_circle""".split(),
    },
    "lucide": {
        "licence": "ISC", "url": "https://cdn.jsdelivr.net/npm/lucide-static@0.460.0/icons/{n}.svg",
        "repo": "https://github.com/lucide-icons/lucide",
        "names": """thermometer-sun scan focus aperture sun-moon moon-star crosshair layers compass locate-fixed navigation-2
        sun-medium scan-eye gauge battery-full battery-medium battery-low battery-warning signal-high radio-tower rotate-ccw
        house undo-2 video circle-dot film image camera zoom-in zoom-out mountain waves tent fuel car-front tractor fish
        anchor sailboat trees church store warehouse""".split(),
    },
    "tabler": {
        "licence": "MIT", "url": "https://cdn.jsdelivr.net/npm/@tabler/icons@3.19.0/icons/outline/{n}.svg",
        "repo": "https://github.com/tabler/tabler-icons",
        "names": """drone drone-off propeller helicopter plane antenna-bars-5 battery-4 battery-2 battery-1 temperature
        flame moon-stars focus-2 focus-auto aperture exposure brightness-half sun-high target arrow-back-up home-2
        current-location compass map-pin route steering-wheel gps satellite world-latitude scan""".split(),
    },
    "phosphor": {
        "licence": "MIT", "url": "https://cdn.jsdelivr.net/npm/@phosphor-icons/core@2.1.1/assets/regular/{n}.svg",
        "repo": "https://github.com/phosphor-icons/core",
        "names": """drone binoculars thermometer crosshair-simple aperture camera-rotate film-strip airplane-takeoff
        airplane-landing house-line compass map-trifold storefront chat-circle-dots briefcase folder-simple-star""".split(),
    },
    "maki": {
        "licence": "CC0-1.0", "url": "https://cdn.jsdelivr.net/npm/@mapbox/maki@8.0.1/icons/{n}.svg",
        "repo": "https://github.com/mapbox/maki",
        "names": """cafe restaurant fuel parking police hospital school place-of-worship religious-christian cemetery park
        picnic-site campsite harbor ferry bus rail farm garden lodging shop grocery post town-hall viewpoint information
        toilet playground water wetland mountain marker triangle-stroked beer bar fire-station library museum monument
        attraction slipway swimming golf airfield heliport car bicycle home warehouse industry dog-park zoo castle
        racetrack stadium suitcase village town city marker-stroked""".split(),
    },
    "temaki": {
        "licence": "CC0-1.0", "url": "https://cdn.jsdelivr.net/npm/@rapideditor/temaki@5.8.0/icons/{n}.svg",
        "repo": "https://github.com/rapideditor/temaki",
        "names": """boat_ramp barn silo windmill bench power_tower cabin boating fishing_pier pier_fixed pier_floating gate\n        rope_fence tree_and_bench storage_tank water_tower bridge railway_track hedge tower_communication tents boat_floating""".split(),
    },
}
FONTS = [
    ("Roboto-Regular.ttf", "https://cdn.jsdelivr.net/gh/googlefonts/roboto@main/src/hinted/Roboto-Regular.ttf"),
    ("Roboto-Medium.ttf", "https://cdn.jsdelivr.net/gh/googlefonts/roboto@main/src/hinted/Roboto-Medium.ttf"),
    ("Roboto-Bold.ttf", "https://cdn.jsdelivr.net/gh/googlefonts/roboto@main/src/hinted/Roboto-Bold.ttf"),
    ("Roboto-LICENSE.txt", "https://cdn.jsdelivr.net/gh/googlefonts/roboto@main/LICENSE"),
    ("RobotoMono-Medium.ttf", "https://cdn.jsdelivr.net/gh/googlefonts/RobotoMono@main/fonts/ttf/RobotoMono-Medium.ttf"),
    ("RobotoMono-Bold.ttf", "https://cdn.jsdelivr.net/gh/googlefonts/RobotoMono@main/fonts/ttf/RobotoMono-Bold.ttf"),
    ("RobotoMono-OFL.txt", "https://cdn.jsdelivr.net/gh/googlefonts/RobotoMono@main/OFL.txt"),
]
LICENCE_FILES = {
    "material": "https://raw.githubusercontent.com/google/material-design-icons/master/LICENSE",
    "lucide": "https://cdn.jsdelivr.net/npm/lucide-static@0.460.0/LICENSE",
    "tabler": "https://cdn.jsdelivr.net/npm/@tabler/icons@3.19.0/LICENSE",
    "phosphor": "https://cdn.jsdelivr.net/npm/@phosphor-icons/core@2.1.1/LICENSE",
    "maki": "https://cdn.jsdelivr.net/npm/@mapbox/maki@8.0.1/LICENSE.txt",
    "temaki": "https://cdn.jsdelivr.net/npm/@rapideditor/temaki@5.8.0/LICENSE.md",
}


def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "AeroSim-osui-fetch/1.0"})
    with urllib.request.urlopen(req, timeout=40) as r:
        return r.read()


def save(path, url, log):
    if os.path.exists(path) and os.path.getsize(path) > 0:
        return True
    try:
        data = get(url)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "wb") as f:
            f.write(data)
        return True
    except Exception as e:  # noqa
        log.append(f"| `{os.path.relpath(path, OUT)}` | {url} | {type(e).__name__}: {e} |")
        return False


def main():
    log, counts = [], {}
    for key, s in SETS.items():
        n_ok = 0
        for n in s["names"]:
            url = s["url"].format(n=n, f="")
            n_ok += save(os.path.join(OUT, key, n + ".svg"), url, log)
        for n in s.get("filled", []):
            n_ok += save(os.path.join(OUT, key, "filled", n + ".svg"), MS.format(n=n, f="_fill1"), log)
        save(os.path.join(OUT, key, "LICENSE.txt"), LICENCE_FILES[key], log)
        counts[key] = n_ok
    for name, url in FONTS:
        save(os.path.join(OUT, "..", "fonts_osui", name), url, log)
    with open(os.path.join(OUT, "FETCH-LOG.md"), "w", encoding="utf-8") as f:
        f.write("# Icon fetch log\n\nRun: %s\n\n" % time.strftime("%Y-%m-%d %H:%M"))
        f.write("Counts: " + json.dumps(counts) + "\n\n")
        if log:
            f.write("Files that could not be downloaded (name not in that set's version, or the network refused):\n\n| File | URL | Error |\n|---|---|---|\n")
            f.write("\n".join(log) + "\n")
        else:
            f.write("Every requested file downloaded. The corporate proxy did not block jsDelivr or raw.githubusercontent.com.\n")
    print(counts, "failures", len(log))


if __name__ == "__main__":
    main()
