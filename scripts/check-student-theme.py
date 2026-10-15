"""Check text contrast for the native app's light and dark surface palettes."""

import re
from pathlib import Path


def luminance(rgb):
    channels = [value / 255 for value in rgb]
    linear = [
        value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4
        for value in channels
    ]
    return sum(
        value * weight
        for value, weight in zip(linear, (0.2126, 0.7152, 0.0722), strict=True)
    )


def contrast(foreground, background):
    lower, upper = sorted((luminance(foreground), luminance(background)))
    return (upper + 0.05) / (lower + 0.05)


def rgb(hex_value):
    return tuple(int(hex_value[index : index + 2], 16) for index in (0, 2, 4))


def main():
    path = (
        Path(__file__).resolve().parents[1]
        / "mobile/ios/CampusZeitStudents/Sources/CampusZeitStudents/CampusTheme.swift"
    )
    # The native license screen must be revised when an external package is added.
    manifest = path.parents[2] / "Package.swift"
    assert ".package(" not in manifest.read_text(encoding="utf-8"), (
        "An external Swift package was added; update the native license screen."
    )
    colors = {
        name: (rgb(light), rgb(dark))
        for name, light, dark in re.findall(
            r"let (campus\w+) = campusColor\(0x([A-F0-9]{6}), 0x([A-F0-9]{6})\)",
            path.read_text(encoding="utf-8"),
        )
    }
    checked = 0
    for mode in (0, 1):
        canvas = colors["campusCanvas"][mode]
        surface = colors["campusSurface"][mode]
        translucent = tuple(
            0.82 * a + 0.18 * b for a, b in zip(surface, canvas, strict=True)
        )
        for name in (
            "campusInk",
            "campusMuted",
            "campusBlue",
            "campusMint",
            "campusViolet",
            "campusRed",
        ):
            for background in (canvas, surface, translucent):
                ratio = contrast(colors[name][mode], background)
                assert ratio >= 4.5, f"{name}, mode {mode}: {ratio:.2f}:1 < 4.5:1"
                checked += 1
    assert contrast(rgb("FFFFFF"), colors["campusBlue"][0]) >= 4.5
    print(
        f"{checked} text/surface combinations and the filled login button meet 4.5:1."
    )


if __name__ == "__main__":
    main()
