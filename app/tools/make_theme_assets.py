#!/usr/bin/env python3
"""Writes the walnut-and-felt page colours (light and dark) into the asset catalog. Run from app/.
Table materials (felt, walnut, tiles) are fixed colours in Theme.swift and do not change with dark mode."""
import json, pathlib

CATALOG = pathlib.Path("MajiangApp/Resources/Assets.xcassets")
COLORS = {
    "TablePaper": ("F4F3EF", "121513"),
    "TableCard": ("FFFFFF", "1C201E"),
    "TableInk": ("1B1F1D", "ECEDEB"),
    "TableFill": ("1B1F1D", "2E7353"),
    "TableRed": ("D2402F", "E5574A"),
    "TablePositive": ("215A40", "6FC39A"),
    "TableGray": ("6E7370", "A4A8A5"),
    "TableFaint": ("A3A6A2", "6A6E6B"),
    "TableLine": ("DDDBD4", "2B2F2C"),
    "TableLineSoft": ("E8E6E0", "232725"),
    "TableSegment": ("EAE8E2", "232725"),
}

def component(hex_color):
    r, g, b = (hex_color[i:i + 2] for i in (0, 2, 4))
    return {"color-space": "srgb",
            "components": {"red": f"0x{r}", "green": f"0x{g}", "blue": f"0x{b}", "alpha": "1.000"}}

for name, (light, dark) in COLORS.items():
    folder = CATALOG / f"{name}.colorset"
    folder.mkdir(parents=True, exist_ok=True)
    (folder / "Contents.json").write_text(json.dumps({
        "colors": [
            {"idiom": "universal", "color": component(light)},
            {"idiom": "universal", "color": component(dark),
             "appearances": [{"appearance": "luminosity", "value": "dark"}]},
        ],
        "info": {"author": "xcode", "version": 1},
    }, indent=2) + "\n")
