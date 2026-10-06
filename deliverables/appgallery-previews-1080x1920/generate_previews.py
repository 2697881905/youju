#!/usr/bin/env python3
"""Build 1080x1920 AppGallery preview posters from real app screenshots."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Sequence

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "source"
OUT = ROOT
WIDTH, HEIGHT = 1080, 1920

# The refreshed app UI is white, near-black, and blue. Keep the poster chrome
# in the same visual system so the screenshot feels like part of the product.
BG = "#FFFFFF"
INK = "#111214"
BLUE = "#0066CC"
BLUE_DARK = "#0055AA"
MUTED = "#68707A"
LINE = "#E5E6E8"
FRAME = "#FFFFFF"

FONT_SERIF = "/System/Library/Fonts/Supplemental/Songti.ttc"
FONT_SANS = "/System/Library/Fonts/STHeiti Medium.ttc"


def font(path: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(path, size=size, index=0)


def draw_text(draw: ImageDraw.ImageDraw, xy: tuple[int, int], value: str, size: int,
              fill: str = INK, serif: bool = False, anchor: str = "la",
              spacing: int = 0) -> None:
    draw.text(
        xy,
        value,
        font=font(FONT_SERIF if serif else FONT_SANS, size),
        fill=fill,
        anchor=anchor,
        spacing=spacing,
    )


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255
    )
    return mask


def rgb_image(image: Image.Image) -> Image.Image:
    """Composite RGBA source pixels over white before RGB export."""
    if image.mode == "RGBA":
        canvas = Image.new("RGB", image.size, BG)
        canvas.paste(image, mask=image.getchannel("A"))
        return canvas
    return image.convert("RGB")


def paste_rounded(canvas: Image.Image, image: Image.Image,
                  box: tuple[int, int, int, int], radius: int) -> None:
    x, y, width, height = box
    # Scale exactly once from the original 1320x2848 capture. This avoids the
    # soft, jagged result caused by a crop followed by a second fit operation.
    resized = rgb_image(image).resize((width, height), Image.Resampling.LANCZOS)
    canvas.paste(resized, (x, y), rounded_mask((width, height), radius))


def draw_soft_shadow(canvas: Image.Image, box: tuple[int, int, int, int],
                     radius: int) -> None:
    x, y, width, height = box
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    mask = rounded_mask((width, height), radius).filter(ImageFilter.GaussianBlur(24))
    shadow = Image.new("RGBA", (width, height), (25, 51, 89, 30))
    layer.paste(shadow, (x, y + 20), mask)
    canvas.alpha_composite(layer)


def draw_phone(canvas: Image.Image, source: Image.Image, x: int, y: int,
               width: int) -> None:
    inner_width = width - 32
    inner_height = round(inner_width * source.height / source.width)
    height = inner_height + 32
    draw_soft_shadow(canvas, (x, y, width, height), 50)

    frame = Image.new("RGB", (width, height), FRAME)
    paste_rounded(frame, source, (16, 16, inner_width, inner_height), 40)
    frame_draw = ImageDraw.Draw(frame)
    frame_draw.rounded_rectangle(
        (8, 8, width - 9, height - 9), radius=48, outline=LINE, width=3
    )
    canvas.paste(frame, (x, y), rounded_mask((width, height), 50))


def draw_header(canvas: Image.Image, number: str) -> None:
    draw = ImageDraw.Draw(canvas)
    logo = rgb_image(Image.open(SOURCE / "logo.png")).resize(
        (64, 64), Image.Resampling.LANCZOS
    )
    canvas.paste(logo, (72, 68), rounded_mask((64, 64), 18))
    draw_text(draw, (154, 86), "有据", 38, serif=True, anchor="lm")
    draw_text(draw, (154, 123), "SUBSTANTIATE", 14, fill=MUTED, anchor="lm", spacing=3)
    draw_text(draw, (1008, 94), number, 22, fill=BLUE, anchor="rm")


def draw_title(canvas: Image.Image, title: str, subtitle: str) -> None:
    draw = ImageDraw.Draw(canvas)
    title_y = 218
    size = 78
    while size > 54 and draw.textbbox(
        (72, title_y), title, font=font(FONT_SERIF, size)
    )[2] > 1008:
        size -= 2
    draw_text(draw, (72, title_y), title, size, serif=True)
    # A short blue rule ties the poster copy to the app's blue interaction
    # color without adding another decorative object to the screenshot.
    draw.rounded_rectangle((74, 326, 88, 356), radius=7, fill=BLUE)
    draw_text(draw, (104, 323), subtitle, 30, fill=BLUE_DARK)


def draw_footer(canvas: Image.Image) -> None:
    draw = ImageDraw.Draw(canvas)
    draw.line((72, 1854, 1008, 1854), fill=LINE, width=2)
    draw_text(draw, (72, 1882), "真实经验，有据可循", 26, serif=True)
    draw_text(draw, (1008, 1884), "鸿蒙原生应用", 20, fill=MUTED, anchor="ra")


def build_page(number: str, title: str, subtitle: str, source_name: str) -> Image.Image:
    canvas = Image.new("RGBA", (WIDTH, HEIGHT), BG)
    draw_header(canvas, number)
    draw_title(canvas, title, subtitle)
    source = rgb_image(Image.open(SOURCE / source_name))
    # The new source captures are 1320x2848. Keep their exact ratio and make
    # one large viewport so small UI labels survive store thumbnail scaling.
    draw_phone(canvas, source, 200, 400, 680)
    draw_footer(canvas)
    return canvas.convert("RGB")


def save_jpg(image: Image.Image, filename: str) -> None:
    image.save(
        OUT / filename,
        format="JPEG",
        quality=100,
        subsampling=0,
        optimize=True,
        progressive=True,
    )


def main() -> None:
    pages: Sequence[dict[str, str]] = [
        {
            "number": "01 / 06",
            "stem": "preview-01-home",
            "title": "真实经验，一屏浏览",
            "subtitle": "推荐、关注、每日一帖，首页集中查看",
            "source": "home.png",
        },
        {
            "number": "02 / 06",
            "stem": "preview-02-structured",
            "title": "结构化发布，逐步写清",
            "subtitle": "优缺点与推荐指数，按信息块组织",
            "source": "structured.png",
        },
        {
            "number": "03 / 06",
            "stem": "preview-03-search",
            "title": "搜一下，先找到问题答案",
            "subtitle": "搜索你关心的经验和问题",
            "source": "search.png",
        },
        {
            "number": "04 / 06",
            "stem": "preview-04-circles",
            "title": "按问题，找到对应圈子",
            "subtitle": "手机数码、电脑装机、健康习惯等主题",
            "source": "circles.png",
        },
        {
            "number": "05 / 06",
            "stem": "preview-05-daily",
            "title": "每天一帖，读一个经验",
            "subtitle": "今日精选卡片，随手翻完一条内容",
            "source": "daily.png",
        },
        {
            "number": "06 / 06",
            "stem": "preview-06-share-card",
            "title": "一张卡片，分享经验",
            "subtitle": "把有据内容整理成可分享的卡片",
            "source": "share-card.png",
        },
    ]

    manifest = []
    for page in pages:
        image = build_page(
            page["number"], page["title"], page["subtitle"], page["source"]
        )
        jpg_name = page["stem"] + ".jpg"
        png_name = page["stem"] + ".png"
        save_jpg(image, jpg_name)
        image.save(OUT / png_name, format="PNG", optimize=True)
        manifest.append({
            "file": png_name,
            "jpg_fallback": jpg_name,
            "size": [WIDTH, HEIGHT],
            "format": "PNG",
            "color_mode": "RGB",
            "brand_asset": "source/logo.png",
            "source": "source/" + page["source"],
            "status": "draft_pending_content_review",
        })

    (OUT / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n"
    )
    print(f"generated {len(pages)} previews in {OUT}")


if __name__ == "__main__":
    main()
