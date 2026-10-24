"""Regenerate the whole tablet UI kit:  python build_all.py   (needs Pillow + numpy; Inter font bundled)."""
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_icons, gen_dials, gen_controls, gen_sheets

if __name__ == "__main__":
    print("icons", len(gen_icons.build()))
    gen_dials.build()
    print("dials, weather, status done")
    gen_controls.build()
    print("controls, frame, polish done")
    gen_sheets.build()
    print("sheets done")
