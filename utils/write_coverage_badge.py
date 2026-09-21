#!/usr/bin/env python3
"""Read gcovr's coverage-summary.json and write a coverage badge.

Usage: write_coverage_badge.py <coverage-summary.json> <out-badge.json> [<out-badge.svg>]

The JSON is a shields.io endpoint badge (usable once the repository is public);
the SVG is a self-contained flat badge the README can embed by relative path,
which is what a PRIVATE repository needs (shields.io cannot fetch its raw files).
"""
import json
import os
import sys

COLORS = {"brightgreen": "#4c1", "green": "#97ca00", "yellow": "#dfb317", "red": "#e05d44"}


def color_for(pct: float) -> str:
    if pct >= 90:
        return "brightgreen"
    if pct >= 75:
        return "green"
    if pct >= 50:
        return "yellow"
    return "red"


def svg_badge(label: str, message: str, color: str) -> str:
    # Flat shields-style badge; widths approximated from character counts (Verdana 11px ≈ 6.5px/char).
    lw = int(len(label) * 6.5) + 10
    mw = int(len(message) * 6.5) + 10
    w = lw + mw
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="20" role="img" aria-label="{label}: {message}">'
        f'<title>{label}: {message}</title>'
        f'<linearGradient id="s" x2="0" y2="100%"><stop offset="0" stop-color="#bbb" stop-opacity=".1"/><stop offset="1" stop-opacity=".1"/></linearGradient>'
        f'<clipPath id="r"><rect width="{w}" height="20" rx="3" fill="#fff"/></clipPath>'
        f'<g clip-path="url(#r)"><rect width="{lw}" height="20" fill="#555"/><rect x="{lw}" width="{mw}" height="20" fill="{COLORS[color]}"/>'
        f'<rect width="{w}" height="20" fill="url(#s)"/></g>'
        f'<g fill="#fff" text-anchor="middle" font-family="Verdana,Geneva,DejaVu Sans,sans-serif" font-size="11">'
        f'<text x="{lw / 2:.1f}" y="15" fill="#010101" fill-opacity=".3">{label}</text><text x="{lw / 2:.1f}" y="14">{label}</text>'
        f'<text x="{lw + mw / 2:.1f}" y="15" fill="#010101" fill-opacity=".3">{message}</text><text x="{lw + mw / 2:.1f}" y="14">{message}</text>'
        f'</g></svg>\n'
    )


def main() -> int:
    if len(sys.argv) not in (3, 4):
        print(f"usage: {sys.argv[0]} <coverage-summary.json> <out-badge.json> [<out-badge.svg>]", file=sys.stderr)
        return 2

    summary_path, out_json = sys.argv[1], sys.argv[2]
    out_svg = sys.argv[3] if len(sys.argv) == 4 else None
    with open(summary_path) as fh:
        pct = json.load(fh)["line_percent"]

    color = color_for(pct)
    message = f"{pct:.1f}%"
    os.makedirs(os.path.dirname(out_json) or ".", exist_ok=True)
    with open(out_json, "w") as fh:
        json.dump({"schemaVersion": 1, "label": "coverage", "message": message, "color": color}, fh)
    if out_svg:
        os.makedirs(os.path.dirname(out_svg) or ".", exist_ok=True)
        with open(out_svg, "w") as fh:
            fh.write(svg_badge("coverage", message, color))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
