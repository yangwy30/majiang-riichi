#!/usr/bin/env python3
"""Writes the washi + indigo colour sets (light and dark) into the asset catalog. Run from app/."""
import json, pathlib

CATALOG = pathlib.Path("MajiangApp/Resources/Assets.xcassets")
COLORS = {
    "WashiPaper": ("F6F1E7", "10151F"),
    "WashiCard": ("FFFCF5", "1A2130"),
    "WashiInk": ("1C2A40", "ECE6D9"),
    "WashiIndigo": ("23395B", "3B5B8F"),
    "WashiVermilion": ("C8402A", "D9543C"),
    "WashiGray": ("6B6358", "A79F92"),
    "WashiFaint": ("A69D8E", "6F6A62"),
    "WashiLine": ("E0D8C8", "2B3446"),
    "WashiLineSoft": ("ECE5D7", "232B3B"),
    "WashiSegment": ("EAE3D4", "232B3B"),
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
