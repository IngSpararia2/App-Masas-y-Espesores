from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
BRANDING = ROOT / "assets" / "branding"
GENERATED = BRANDING / "generated"

DENSITIES = {
    "mdpi": 1,
    "hdpi": 1.5,
    "xhdpi": 2,
    "xxhdpi": 3,
    "xxxhdpi": 4,
}


def resized(source: Image.Image, size: int) -> Image.Image:
    return source.resize((size, size), Image.Resampling.LANCZOS)


def centered(source: Image.Image, canvas_size: int, content_ratio: float) -> Image.Image:
    canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    content_size = round(canvas_size * content_ratio)
    content = resized(source, content_size)
    offset = (canvas_size - content_size) // 2
    canvas.alpha_composite(content, (offset, offset))
    return canvas


def save_png(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, optimize=True)


def main() -> None:
    icon = Image.open(BRANDING / "app_icon_source.png").convert("RGBA")
    splash = Image.open(BRANDING / "splash_logo.png").convert("RGBA")
    android = GENERATED / "android" / "res"

    for density, scale in DENSITIES.items():
        save_png(
            resized(icon, round(48 * scale)),
            android / f"mipmap-{density}" / "ic_launcher.png",
        )
        save_png(
            resized(icon, round(108 * scale)),
            android / f"drawable-{density}" / "ic_launcher_foreground.png",
        )
        save_png(
            centered(splash, round(256 * scale), 0.82),
            android / f"drawable-{density}" / "splash_icon.png",
        )
        save_png(
            centered(splash, round(288 * scale), 0.62),
            android / f"drawable-{density}" / "splash_icon_android12.png",
        )

    windows_icon = GENERATED / "windows" / "app_icon.ico"
    windows_icon.parent.mkdir(parents=True, exist_ok=True)
    icon.save(
        windows_icon,
        format="ICO",
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
    )


if __name__ == "__main__":
    main()
