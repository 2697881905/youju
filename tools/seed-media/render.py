#!/usr/bin/env python3
"""冷启动素材渲染：把内容库里的帖子渲染成 3:4 文字海报，给作者渲染头像。

为什么在本机渲染：生产镜像里没有字体也没有 Pillow，而海报只需要渲染一次、
之后就是静态对象。渲染结果走 COS，不进 git（见 .gitignore 的 /seed-assets/）。

版式对齐 App 内置的四款文字海报（entry/src/main/ets/utils/poster/posterTokens.ets）：
素纸、胶片、牛皮纸、便利贴。底色与墨色逐值复制，文字区按 1080 画布等比缩放到 810。

用法
    /opt/anaconda3/bin/python3 tools/seed-media/render.py --out seed-assets
    /opt/anaconda3/bin/python3 tools/seed-media/render.py --out seed-assets --only shuma
"""

import argparse
import json
import math
import os
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

WIDTH = 810
HEIGHT = 1080
SCALE = WIDTH / 1080.0

CONTENT_DIR = Path(__file__).resolve().parents[2] / "backend" / "prisma" / "seed-data" / "coldstart"

STYLES = {
    "paper": {
        "background": "#EFE9DC",
        "ink": "#241D12",
        "accent": "#8A6548",
        "box": (200, 300, 880, 1120),
        "foot_opacity": 0.55,
    },
    "film": {
        "background": "#111214",
        "ink": "#F2EDE3",
        "accent": "#C8A96A",
        "box": (200, 320, 896, 1140),
        "foot_opacity": 0.50,
    },
    "kraft": {
        "background": "#C7A379",
        "ink": "#2A1C0C",
        "accent": "#5A3C1C",
        "box": (184, 316, 896, 1120),
        "foot_opacity": 0.55,
    },
    "sticky": {
        "background": "#F2E2A8",
        "ink": "#2A2410",
        "accent": "#C9A94E",
        "box": (216, 316, 896, 1108),
        "foot_opacity": 0.55,
    },
}

FONT_CANDIDATES = [
    ("/System/Library/Fonts/Supplemental/Songti.ttc", 1),
    ("/System/Library/Fonts/Supplemental/Songti.ttc", 6),
    ("/System/Library/Fonts/STHeiti Medium.ttc", 0),
    ("/System/Library/Fonts/Supplemental/Arial Unicode.ttf", 0),
]
SANS_CANDIDATES = [
    ("/System/Library/Fonts/Hiragino Sans GB.ttc", 0),
    ("/System/Library/Fonts/STHeiti Light.ttc", 0),
    ("/System/Library/Fonts/Supplemental/Arial Unicode.ttf", 0),
]

NO_LINE_START = "，。！？、；）」』”’,.!?;:%)]"
NO_LINE_END = "（「『“‘([{"


def load_font(candidates, size):
    for path, index in candidates:
        if not os.path.exists(path):
            continue
        for idx in (index, 0, 1, 2, 3):
            try:
                return ImageFont.truetype(path, size, index=idx)
            except Exception:
                continue
    raise RuntimeError("找不到可用中文字体")


def text_width(font, text):
    if not text:
        return 0
    return font.getbbox(text)[2] - font.getbbox(text)[0]


def wrap(text, font, max_width, max_lines):
    """按像素宽度折行，带最基本的避头尾处理。"""
    lines = []
    current = ""
    for ch in text:
        if ch == "\n":
            lines.append(current)
            current = ""
            if len(lines) >= max_lines:
                break
            continue
        trial = current + ch
        if text_width(font, trial) <= max_width:
            current = trial
            continue
        # 行首不能是标点：把上一个字一起挪下来
        if ch in NO_LINE_START and current:
            lines.append(current[:-1])
            current = current[-1] + ch
        elif current and current[-1] in NO_LINE_END:
            lines.append(current[:-1])
            current = current[-1] + ch
        else:
            lines.append(current)
            current = ch
        if len(lines) >= max_lines:
            break
    if current and len(lines) < max_lines:
        lines.append(current)
    # 孤字控制：末行只剩一个字时，从上一行挪一个字下来，避免「值」单独占一行
    if len(lines) >= 2 and len(lines[-1]) == 1 and len(lines[-2]) >= 3:
        lines[-1] = lines[-2][-1] + lines[-1]
        lines[-2] = lines[-2][:-1]
    if len(lines) == max_lines and current and text_width(font, lines[-1] + current) > max_width:
        last = lines[-1]
        while last and text_width(font, last + "…") > max_width:
            last = last[:-1]
        lines[-1] = last + "…"
    return lines


def hex_to_rgb(value):
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def draw_texture(img, style_key, seed):
    """极轻的纹理。目的是让大片纯色不至于像占位图，不是做拟物。"""
    rnd = random.Random(seed)
    draw = ImageDraw.Draw(img, "RGBA")
    if style_key == "paper":
        for _ in range(1400):
            x = rnd.randrange(WIDTH)
            y = rnd.randrange(HEIGHT)
            alpha = rnd.randrange(4, 12)
            draw.point((x, y), fill=(90, 70, 45, alpha))
        for offset in (56, 68):
            draw.line([(90, HEIGHT - offset), (WIDTH - 90, HEIGHT - offset)], fill=(138, 101, 72, 60), width=1)
    elif style_key == "film":
        for _ in range(3200):
            x = rnd.randrange(WIDTH)
            y = rnd.randrange(HEIGHT)
            alpha = rnd.randrange(6, 20)
            draw.point((x, y), fill=(255, 255, 255, alpha))
        draw.line([(72, 90), (72, HEIGHT - 90)], fill=(200, 169, 106, 120), width=1)
    elif style_key == "kraft":
        for _ in range(900):
            x = rnd.randrange(WIDTH)
            y = rnd.randrange(HEIGHT)
            alpha = rnd.randrange(5, 14)
            draw.point((x, y), fill=(60, 40, 18, alpha))
        draw.line([(80, 150), (WIDTH - 80, 150)], fill=(90, 60, 28, 90), width=1)
        draw.line([(80, HEIGHT - 150), (WIDTH - 80, HEIGHT - 150)], fill=(90, 60, 28, 90), width=1)
    else:
        draw.rectangle([0, 0, 10, HEIGHT], fill=(201, 169, 78, 255))


def render_poster(post, circle_name, out_path):
    style_key = post.get("posterStyle") or pick_style(post["id"])
    style = STYLES[style_key]
    seed = sum(ord(c) for c in post["id"])
    img = Image.new("RGB", (WIDTH, HEIGHT), hex_to_rgb(style["background"]))
    draw_texture(img, style_key, seed)
    draw = ImageDraw.Draw(img)

    left, top, right, bottom = [int(v * SCALE) for v in style["box"]]
    box_width = right - left

    title = post["title"].strip()
    excerpt = (post.get("posterLine") or first_sentence(post.get("content", ""))).strip()

    title_length = len(title)
    if title_length <= 12:
        hero_size = 84
    elif title_length <= 20:
        hero_size = 72
    elif title_length <= 28:
        hero_size = 60
    else:
        hero_size = 50

    title_font = load_font(FONT_CANDIDATES, hero_size)
    body_font = load_font(SANS_CANDIDATES, 25)
    foot_font = load_font(SANS_CANDIDATES, 20)

    title_lines = wrap(title, title_font, box_width, 4)
    line_height = int(hero_size * 1.46)
    title_block = line_height * len(title_lines)

    body_lines = wrap(excerpt, body_font, box_width, 3) if excerpt else []
    body_block = int(25 * 1.75) * len(body_lines)

    total = title_block + (30 if body_lines else 0) + body_block
    cursor = top + max(0, int(((bottom - top) - total) * 0.38))

    # 标题上方的短横线（强调色）
    draw.line([(left, cursor - 34), (left + 56, cursor - 34)], fill=hex_to_rgb(style["accent"]), width=3)

    ink = hex_to_rgb(style["ink"])
    for line in title_lines:
        draw.text((left, cursor), line, font=title_font, fill=ink)
        cursor += line_height

    if body_lines:
        cursor += 14
        faded = tuple(int(c + (255 - c) * 0.45) if sum(ink) > 380 else int(c * 0.75) for c in ink)
        for line in body_lines:
            draw.text((left, cursor), line, font=body_font, fill=faded)
            cursor += int(25 * 1.75)

    footer = f"有据 · {circle_name}"
    foot_width = text_width(foot_font, footer)
    foot_color = tuple(int(c * (style["foot_opacity"] + 0.25)) for c in ink)
    draw.text((right - foot_width, bottom - 6), footer, font=foot_font, fill=foot_color)

    out_path.parent.mkdir(parents=True, exist_ok=True)
    img.save(out_path, "JPEG", quality=80, optimize=True, progressive=True)


def render_avatar(author, out_path):
    color = hex_to_rgb(author.get("avatarColor", "#3A4652"))
    size = 512
    img = Image.new("RGB", (size, size), color)
    draw = ImageDraw.Draw(img, "RGBA")
    # 极淡的对角线，让纯色头像有一点层次
    draw.line([(0, size), (size, 0)], fill=(255, 255, 255, 18), width=3)
    draw.line([(0, size // 2), (size // 2, 0)], fill=(255, 255, 255, 12), width=2)

    initial = author["nickname"][:1]
    font = load_font(FONT_CANDIDATES, 240)
    bbox = draw.textbbox((0, 0), initial, font=font)
    x = (size - (bbox[2] - bbox[0])) // 2 - bbox[0]
    y = (size - (bbox[3] - bbox[1])) // 2 - bbox[1]
    draw.text((x, y), initial, font=font, fill=(245, 242, 235))

    out_path.parent.mkdir(parents=True, exist_ok=True)
    img.save(out_path, "PNG", optimize=True)


def pick_style(post_id):
    keys = list(STYLES.keys())
    return keys[sum(ord(c) for c in post_id) % len(keys)]


def first_sentence(text):
    for sep in ("。", "！", "？", "\n"):
        index = text.find(sep)
        if index > 0:
            return text[:index][:60]
    return text[:60]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default="seed-assets")
    parser.add_argument("--content", default=str(CONTENT_DIR))
    parser.add_argument("--only", default="", help="只渲染某个圈子的 slug")
    parser.add_argument("--skip-avatars", action="store_true")
    args = parser.parse_args()

    content_dir = Path(args.content)
    out_dir = Path(args.out)
    authors_path = content_dir / "authors.json"
    if not authors_path.exists():
        print(f"缺少 {authors_path}", file=sys.stderr)
        return 1
    authors = json.loads(authors_path.read_text(encoding="utf-8"))["authors"]

    if not args.skip_avatars:
        for author in authors:
            render_avatar(author, out_dir / "avatars" / "seed" / f"{author['slug']}.png")
        print(f"头像 {len(authors)} 张")

    total = 0
    for file in sorted((content_dir / "circles").glob("*.json")):
        if args.only and file.stem != args.only:
            continue
        payload = json.loads(file.read_text(encoding="utf-8"))
        circle = payload["circle"]
        for post in payload["posts"]:
            render_poster(post, circle, out_dir / "posts" / "seed" / f"{post['id']}.jpg")
            total += 1
        print(f"{circle} {len(payload['posts'])} 张")
    print(f"海报合计 {total} 张，输出目录 {out_dir}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
