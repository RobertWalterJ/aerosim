# AeroSim UI fonts (lane appui2)

All three families are under the SIL Open Font License 1.1 (OFL), which allows bundling and embedding in a game, including a sold one. The fonts are unmodified; only the file names were changed to the paths the code expects. The full licence texts are next to the files.

| File | Font | Weight | Copyright | Licence |
|---|---|---|---|---|
| `ui_sans.ttf` | Work Sans 2.012 | Regular (400) | 2019 The Work Sans Project Authors, https://github.com/weiweihuanghuang/Work-Sans | OFL 1.1, `OFL-WorkSans.txt` |
| `ui_sans_bold.ttf` | Work Sans 2.012 | Bold (700) | as above | OFL 1.1 |
| `ui_sans_italic.ttf` | Work Sans 2.012 | Italic (400) | as above | OFL 1.1 |
| `ui_serif.ttf` | IBM Plex Serif 2.6 | Regular (400) | 2020 IBM Corp., Reserved Font Name "Plex" | OFL 1.1, `OFL-IBMPlex.txt` |
| `ui_serif_bold.ttf` | IBM Plex Serif 2.6 | Bold (700) | as above | OFL 1.1 |
| `ui_serif_italic.ttf` | IBM Plex Serif 2.6 | Italic (400) | as above | OFL 1.1 |
| `ui_mono.ttf` | IBM Plex Mono 2.3 | Regular (400) | 2017 IBM Corp., Reserved Font Name "Plex" | OFL 1.1, `OFL-IBMPlex.txt` |
| `ui_mono_bold.ttf` | IBM Plex Mono 2.3 | Bold (700) | as above | OFL 1.1 |

Source of the files: the static TTF builds bundled with Anthropic's canvas-design skill (Google Fonts releases with their OFL texts), already on this machine; nothing was downloaded for this lane.

## Why these

- **Work Sans** for the UI: open, wide-aperture letters with a large x-height, so 9 to 11 px small caps and 14 to 16 px body stay legible on the dark pine panels. Tabular figures are built in.
- **IBM Plex Serif** for the Casebook: a sturdy book serif with a slightly typewritten, engineered feel; reads like an official file without pretending to be a typewriter.
- **IBM Plex Mono** for times, distances and counts: clear 0/O and 1/l, same family as the serif.

## Shortfall: medium and semibold

The brief asked for four sans weights. Only Regular and Bold exist as real cuts here (no internet download was made). `ui_sans_medium.tres` and `ui_sans_semibold.tres` are Godot `FontVariation` resources that embolden Regular by 0.35 and 0.7; they are usable today but are synthetic. If true Work Sans Medium (500) and SemiBold (600) TTFs are added later from Google Fonts (same OFL), point the two `.tres` files at them and set `variation_embolden = 0`.

## Not in the fonts

Nothing in the art (icons, stamps, portraits, tiles) contains text; the only lettering is in the contact sheets, which are documentation.
