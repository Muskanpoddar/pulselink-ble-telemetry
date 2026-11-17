#!/usr/bin/env python3
"""Generates the PulseLink launcher icons.

    pip install pillow
    python tools/generate_app_icon.py

Android gets a rounded square with transparent corners, iOS gets a full bleed
square because the system applies its own mask.
"""

import pathlib

from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parent.parent

BLUE_TOP = (42, 120, 214)
BLUE_BOTTOM = (21, 74, 150)
WHITE = (255, 255, 255)

# A single ECG pulse, in fractions of the icon size.
PULSE = [
    (0.10, 0.56),
    (0.30, 0.56),
    (0.39, 0.24),
    (0.50, 0.80),
    (0.61, 0.38),
    (0.70, 0.56),
    (0.90, 0.56),
]


def draw_icon(size: int, rounded: bool) -> Image.Image:
    scale = 4
    canvas = Image.new("RGBA", (size * scale, size * scale), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)

    # Background with a vertical gradient.
    background = Image.new("RGB", (1, size * scale))
    for y in range(size * scale):
        ratio = y / (size * scale - 1)
        background.putpixel(
            (0, y),
            tuple(
                int(BLUE_TOP[i] + (BLUE_BOTTOM[i] - BLUE_TOP[i]) * ratio)
                for i in range(3)
            ),
        )
    background = background.resize((size * scale, size * scale))

    if rounded:
        mask = Image.new("L", (size * scale, size * scale), 0)
        ImageDraw.Draw(mask).rounded_rectangle(
            (0, 0, size * scale - 1, size * scale - 1),
            radius=int(size * scale * 0.22),
            fill=255,
        )
        canvas.paste(background, (0, 0), mask)
    else:
        canvas.paste(background, (0, 0))

    # The pulse line.
    line = ImageDraw.Draw(canvas)
    points = [
        (int(x * size * scale), int(y * size * scale)) for x, y in PULSE
    ]
    line.line(
        points,
        fill=WHITE,
        width=max(2, int(size * scale * 0.075)),
        joint="curve",
    )
    # Round the ends.
    radius = max(2, int(size * scale * 0.037))
    for x, y in (points[0], points[-1]):
        line.ellipse((x - radius, y - radius, x + radius, y + radius), fill=WHITE)

    return canvas.resize((size, size), Image.LANCZOS)


ANDROID = {
    "android/app/src/main/res/mipmap-mdpi/ic_launcher.png": 48,
    "android/app/src/main/res/mipmap-hdpi/ic_launcher.png": 72,
    "android/app/src/main/res/mipmap-xhdpi/ic_launcher.png": 96,
    "android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png": 144,
    "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png": 192,
}

IOS = {
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png": 20,
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png": 40,
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png": 60,
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png": 29,
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png": 58,
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png": 87,
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png": 40,
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png": 80,
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png": 120,
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png": 120,
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png": 180,
    "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png": 1024,
}


def main():
    for path, size in ANDROID.items():
        target = ROOT / path
        target.parent.mkdir(parents=True, exist_ok=True)
        draw_icon(size, rounded=True).save(target)
        print(f"{path} ({size}x{size})")

    for path, size in IOS.items():
        target = ROOT / path
        target.parent.mkdir(parents=True, exist_ok=True)
        draw_icon(size, rounded=False).save(target)
        print(f"{path} ({size}x{size})")


if __name__ == "__main__":
    main()
