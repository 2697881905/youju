#!/usr/bin/env python3
"""Build the 1080x1920 AppGallery preview drafts from real app screenshots.

The source screenshots are intentionally kept as the only UI content. This
script adds presentation chrome around them, but never invents in-app fields,
badges, votes, or privacy controls.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Iterable, Sequence

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "source"
OUT = ROOT
WIDTH, HEIGHT = 1080, 1920
BG = "#F6F1E3"
CARD = "#FFFCF3"
INK = "#1C1912"
WARM = "#8A6548"
BLUE = "#1A5FB4"
BLUE_LIGHT = "#DDEBFA"
MUTED = "#746E63"
FRAME = "#151820"

FONT_SERIF = "/System/Library/Fonts/Supplemental/Songti.ttc"
FONT_SANS = "/System/Library/Fonts/STHeiti Medium.ttc"
FONT_SANS_LIGHT = "/System/Library/Fonts/STHeiti Light.ttc"


def font(path: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(path, size=size, index=0)


def text(draw: ImageDraw.ImageDraw, xy: tuple[int, int], value: str, size: int,
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


def fit_text(draw: ImageDraw.ImageDraw, value: str, max_width: int,
             start_size: int, serif: bool = False) -> tuple[str, int]:
    """Return a two-line split only when the complete line would overflow."""
    current = start_size
    family = FONT_SERIF if serif else FONT_SANS
    while current >= 30 and draw.textbbox((0, 0), value, font=font(family, current))[2] > max_width:
        current -= 2
    if current >= 30:
        return value, current
    midpoint = max(1, len(value) // 2)
    return value[:midpoint] + "\n" + value[midpoint:], start_size


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=radius, fill=255)
    return mask


def paste_rounded(canvas: Image.Image, image: Image.Image, box: tuple[int, int, int, int],
                  radius: int) -> None:
    x, y, w, h = box
    # The phone viewport is calculated from the source aspect ratio, so a
    # direct resize avoids ImageOps.fit introducing a second crop or stretch.
    resized = image.convert("RGB").resize((w, h), Image.Resampling.LANCZOS)
    canvas.paste(resized, (x, y), rounded_mask((w, h), radius))


def draw_soft_shadow(canvas: Image.Image, box: tuple[int, int, int, int], radius: int,
                     offset: tuple[int, int] = (0, 18), alpha: int = 48) -> None:
    x, y, w, h = box
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    mask = rounded_mask((w, h), radius).filter(ImageFilter.GaussianBlur(20))
    shadow = Image.new("RGBA", (w, h), (28, 25, 18, alpha))
    layer.paste(shadow, (x + offset[0], y + offset[1]), mask)
    canvas.alpha_composite(layer)


def crop_source(name: str, crop: tuple[int, int, int, int]) -> Image.Image:
    image = Image.open(SOURCE / name).convert("RGB")
    return image.crop(crop)


def phone(canvas: Image.Image, source: Image.Image, x: int, y: int, w: int,
          h: int | None = None) -> None:
    inner_w = w - 28
    inner_h = round(inner_w * source.height / source.width)
    h = inner_h + 28 if h is None else h
    draw_soft_shadow(canvas, (x, y, w, h), 46)
    frame = Image.new("RGB", (w, h), FRAME)
    paste_rounded(frame, source, (14, 14, w - 28, h - 28), 36)
    frame_draw = ImageDraw.Draw(frame)
    frame_draw.rounded_rectangle((8, 8, w - 9, h - 9), radius=44, outline="#FFFFFF", width=3)
    canvas.paste(frame, (x, y), rounded_mask((w, h), 46))


def inset(canvas: Image.Image, source: Image.Image, crop: tuple[int, int, int, int],
          box: tuple[int, int, int, int], caption: str) -> None:
    x, y, w, h = box
    draw_soft_shadow(canvas, (x, y, w, h), 24, offset=(0, 8), alpha=36)
    card = Image.new("RGB", (w, h), CARD)
    crop_image = source.crop(crop)
    paste_rounded(card, crop_image, (10, 10, w - 20, h - 44), 18)
    card_draw = ImageDraw.Draw(card)
    card_draw.rounded_rectangle((10, 10, w - 11, h - 45), radius=18, outline=BLUE, width=4)
    text(card_draw, (w // 2, h - 21), caption, 20, fill=WARM, anchor="mm")
    canvas.paste(card, (x, y), rounded_mask((w, h), 24))


def arrow(draw: ImageDraw.ImageDraw, start: tuple[int, int], end: tuple[int, int]) -> None:
    draw.line((start[0], start[1], end[0], end[1]), fill=BLUE, width=4)
    ex, ey = end
    draw.polygon([(ex, ey), (ex - 18, ey - 8), (ex - 15, ey + 10)], fill=BLUE)


def header(canvas: Image.Image, number: str) -> None:
    draw = ImageDraw.Draw(canvas)
    logo = Image.open(SOURCE / "logo.png").convert("RGB").resize((64, 64), Image.Resampling.LANCZOS)
    canvas.paste(logo, (72, 68), rounded_mask((64, 64), 16))
    text(draw, (154, 86), "有据", 38, fill=INK, serif=True, anchor="lm")
    text(draw, (154, 123), "SUBSTANTIATE", 14, fill=MUTED, anchor="lm", spacing=3)
    text(draw, (1008, 94), number, 22, fill=WARM, anchor="rm")


def title_block(canvas: Image.Image, title_lines: Sequence[str], subtitle: str) -> None:
    draw = ImageDraw.Draw(canvas)
    y = 230
    for line in title_lines:
        text(draw, (72, y), line, 82, fill=INK, serif=True)
        y += 96
    text(draw, (74, y + 16), subtitle, 30, fill=WARM)


def footer(canvas: Image.Image, status: str | None = None) -> None:
    draw = ImageDraw.Draw(canvas)
    draw.line((72, 1854, 1008, 1854), fill="#D8CEBD", width=2)
    text(draw, (72, 1882), "真实经验，有据可循", 26, fill=WARM, serif=True)
    text(draw, (1008, 1884), "鸿蒙原生应用", 20, fill=MUTED, anchor="ra")
    # Capture readiness belongs in manifest.json, not in the store artwork.


def build_page(number: str, title_lines: Sequence[str], subtitle: str, source_name: str,
              crop: tuple[int, int, int, int] | None, status: str | None,
              inset_crop: tuple[int, int, int, int] | None = None,
              inset_caption: str | None = None,
              title_color: str = INK) -> Image.Image:
    canvas = Image.new("RGBA", (WIDTH, HEIGHT), BG)
    header(canvas, number)
    title_block(canvas, title_lines, subtitle)
    source = Image.open(SOURCE / source_name).convert("RGB")
    visible = source if crop is None else source.crop(crop)
    # Keep the source screenshot's 1136:2690 ratio and give it enough area
    # to remain legible in the AppGallery thumbnail.
    phone(canvas, visible, 230, 410, 620)
    draw = ImageDraw.Draw(canvas)
    if inset_crop and inset_caption:
        inset(canvas, source, inset_crop, (758, 1182, 250, 230), inset_caption)
        arrow(draw, (754, 1288), (704, 1328))
    footer(canvas, status)
    return canvas.convert("RGB")


def save(image: Image.Image, filename: str) -> None:
    # PNG is the master export; keep the JPG fallback at maximum quality for
    # stores that reject larger lossless files.
    image.save(
        OUT / filename,
        format="JPEG",
        quality=100,
        subsampling=0,
        optimize=True,
        progressive=True,
    )


def main() -> None:
    pages = [
        {
            "number": "01 / 06",
            "stem": "preview-01-home",
            "title": ["推荐、关注、每日一帖"],
            "subtitle": "首页把想看的内容放在一起",
            "source": "home.jpg",
            "crop": None,
            "status": "首页需替换测试内容",
        },
        {
            "number": "02 / 06",
            "stem": "preview-02-structured",
            "title": ["结构化发布，逐步写清"],
            "subtitle": "从体裁、圈子到信息流，按步骤组织内容",
            "source": "composer.jpg",
            "crop": None,
            "status": "编辑页为未填写状态",
        },
        {
            "number": "03 / 06",
            "stem": "preview-03-detail",
            "title": ["帖子详情，边看边互动"],
            "subtitle": "正文、作者、点赞与评论，都在一页",
            "source": "detail.jpg",
            "crop": None,
            "status": "详情页需替换测试内容",
        },
        {
            "number": "04 / 06",
            "stem": "preview-04-circles",
            "title": ["圈子地图，按问题查"],
            "subtitle": "手机数码、健康习惯等主题，就近找到同题的人",
            "source": "circles.jpg",
            "crop": None,
            "status": "圈子需替换测试数据",
        },
        {
            "number": "05 / 06",
            "stem": "preview-05-daily",
            "title": ["每日一帖，读一个经验"],
            "subtitle": "今日精选卡片，几分钟看完一条内容",
            "source": "daily.jpg",
            "crop": None,
            "status": "每日内容需替换测试数据",
        },
        {
            "number": "06 / 06",
            "stem": "preview-06-messages",
            "title": ["消息中心，一处查看"],
            "subtitle": "点赞、关注、评论与系统通知，集中处理",
            "source": "messages.jpg",
            "crop": None,
            "status": "消息页需替换测试数据",
        },
    ]

    manifest = []
    for page in pages:
        image = build_page(
            page["number"], page["title"], page["subtitle"], page["source"],
            page["crop"], page["status"], page.get("inset"), page.get("inset_caption"),
        )
        jpg_name = page["stem"] + ".jpg"
        png_name = page["stem"] + ".png"
        save(image, jpg_name)
        image.save(OUT / png_name, format="PNG", optimize=True)
        manifest.append({
            "file": png_name,
            "jpg_fallback": jpg_name,
            "size": [WIDTH, HEIGHT],
            "format": "PNG",
            "color_mode": "RGB",
            "brand_asset": "source/logo.png",
            "source": "source/" + page["source"],
            "status": "draft_pending_capture",
            "missing_capture": page["status"],
        })
    (OUT / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    print(f"generated {len(pages)} previews in {OUT}")


if __name__ == "__main__":
    main()
