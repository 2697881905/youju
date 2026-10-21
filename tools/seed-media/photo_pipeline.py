#!/usr/bin/env python3
"""图文帖照片流水线：manifest 生成对账清单，process 把 ImageGen 原图裁成封面规格。

流程分两段，中间隔着逐帖调 ImageGen（每帖一张，竖构图）：
    manifest  →  seed-assets/photo-manifest.json（30 条：id / circle / prompt / 期望文件名）
    （逐帖生成，原图放 seed-assets/raw-photos/<id>.png）
    process   →  seed-assets/posts/seed/<id>-1.jpg（810×1080 JPEG q80，中心裁剪）

process 做对账：manifest 里有而 raw 目录里没有的，列出并退出非 0，
不允许「少一张就静默跳过」——seed 的 --media-report 会把缺图拦下来，
但在这里先拦一次，报错信息更直接。

用法
    /opt/anaconda3/bin/python3 tools/seed-media/photo_pipeline.py manifest
    /opt/anaconda3/bin/python3 tools/seed-media/photo_pipeline.py process
"""

import argparse
import json
import sys
from pathlib import Path

from PIL import Image

CONTENT_DIR = Path(__file__).resolve().parents[2] / "backend" / "prisma" / "seed-data" / "coldstart"
OUT_DIR = Path(__file__).resolve().parents[2] / "seed-assets"

WIDTH = 810
HEIGHT = 1080

# 统一风格后缀：所有照片同一套拍摄语言，避免 30 张图风格散掉。
STYLE_SUFFIX = (
    "手机随手拍风格，自然光，轻微手持视角，真实生活场景，构图自然不摆拍，"
    "照片质感，竖构图，画面中没有任何文字、水印、品牌标志"
)

# 每帖的拍摄场景。按 _topic 手写，不与生成模型共享措辞，
# 改这里就能换场景，不用动内容库。
SCENES = {
    "shuma-0001": "桌面上并排放着的两个手机壳，一个是透明硅胶一个是深色硬壳，旁边散落着包装盒和纸巾",
    "shuma-0002": "木桌上平放的一台二手智能手机，屏幕亮着显示设置页面，旁边放着充电线和便签纸",
    "shuma-0006": "手机维修工作台的局部，螺丝刀、撬棒和一块拆下来的手机电池摆在垫子上",
    "jiadian-0001": "室内墙上刚装好的一台白色挂壁空调，下方地面放着工具箱和一段铜管",
    "jiadian-0002": "家电卖场角落里贴着促销标签的滚筒洗衣机，侧面有轻微划痕，灯光偏冷",
    "jiadian-0003": "厨房里半敞开的嵌入式洗碗机，拉出的碗篮里摆着洗净的玻璃杯和盘子",
    "jiadian-0008": "打开的滚筒洗衣机门口，一只手戴着橡胶手套用旧牙刷刷洗黑色橡胶密封圈",
    "caipu-0001": "白色瓷盘里刚炒好的一盘番茄炒蛋，旁边放着木铲和两个生鸡蛋，灶台有点使用痕迹",
    "caipu-0002": "铁锅里正煎着一条完整的鱼，鱼皮金黄微焦，锅边有油光和姜丝",
    "caipu-0005": "锅中浮着的一锅白胖水饺，旁边的小碟里是醋和蒜瓣，热气腾腾",
    "caipu-0016": "深色砂锅里炖着的一锅红烧肉，酱色浓亮，上面撒着葱段，锅沿有多年使用的包浆",
    "zhuangxiu-0001": "毛坯房墙面上整齐排布的红蓝两色电线线管，未封槽，地面有切割粉尘",
    "zhuangxiu-0005": "贴好瓷砖的卫生间墙面局部，一只手拿着橡胶锤柄敲击瓷砖听空鼓",
    "zhuangxiu-0006": "卫生间地面做了闭水试验，积着两厘米高的浅水，门口用沙袋挡住，墙角放着记号笔",
    "zhuangxiu-0011": "刚装修完的空房间里，吸尘器、超细纤维抹布和玻璃刮摆在一起，窗上有保护膜",
    "chongwu-0001": "客厅角落里放着的一个敞开式猫砂盆，旁边有猫抓板和小铲子，木地板",
    "chongwu-0004": "书桌抽屉半开，里面散着几卷彩色缝纫线团，一只橘猫的爪子伸向线团",
    "chongwu-0007": "纸箱里蜷着一只刚到家的幼猫，警惕地抬头看镜头，箱边放着食盆和水碗",
    "chongwu-0012": "笔记本电脑键盘上趴着一只睡着的虎斑猫，屏幕上是一份未写完的文档",
    "meishi-0001": "小面馆灶台前，老板正把一碗手擀面盛进白瓷碗，汤面飘着葱花，雾气蒸腾",
    "meishi-0005": "一家网红小店门口排着长队，队伍拐过街角，人们低头看手机，傍晚光线",
    "meishi-0009": "小面馆木质吧台上的敞开账本，密密麻麻写着名字和备注，旁边一副老花镜",
    "lvxing-0001": "山间徒步小路蜿蜒向上，路边有杂草和石头，远处山脊被薄雾笼罩，晨光斜照",
    "lvxing-0006": "山间公路的弯道，一辆车停在观景处，远山层叠，仪表盘上放着地图",
    "lvxing-0011": "清晨的露天菜市场，摊主把蔬菜码成小山，地上有水渍，行人提着购物袋",
    "yundong-0001": "地板上并排摆着三双跑鞋，一双鞋底磨损明显，旁边放着袜子和运动水壶",
    "yundong-0002": "室内羽毛球场地边，一双穿着专业羽毛球鞋的脚正做侧向移动，木地板反光",
    "yundong-0006": "清晨公园塑胶跑道上，一双跑步者的腿正在向前迈步，路边有露水和长椅",
    "yongche-0001": "汽车维修车间里一辆车打开引擎盖，师傅的手拿着手电筒检查发动机舱",
    "yongche-0007": "蹲在汽车旁的一双手正把胎压计抵在轮胎气门嘴上，旁边车门敞开",
}


# 关键词 → 帖子 id。ImageGen 并行生成时输出文件名以场景句开头（截断到约 40 字），
# collect 阶段按这个关键词把文件归位成 raw-photos/<id>.png。
# 关键词取场景句前 30 字以内、且全库唯一的词，避免截断后匹配不到。
KEYWORDS = {
    "caipu-0001": "番茄炒蛋",
    "caipu-0002": "金黄微焦",
    "caipu-0005": "白胖水饺",
    "caipu-0016": "砂锅",
    "chongwu-0001": "猫砂盆",
    "chongwu-0004": "缝纫线团",
    "chongwu-0007": "幼猫",
    "chongwu-0012": "键盘上趴着",
    "jiadian-0001": "挂壁空调",
    "jiadian-0002": "促销标签",
    "jiadian-0003": "洗碗机",
    "jiadian-0008": "橡胶手套",
    "lvxing-0001": "徒步小路",
    "lvxing-0006": "山间公路",
    "lvxing-0011": "菜市场",
    "meishi-0001": "手擀面",
    "meishi-0005": "排着长队",
    "meishi-0009": "敞开账本",
    "shuma-0001": "手机壳",
    "shuma-0002": "二手智能手机",
    "shuma-0006": "螺丝刀",
    "yongche-0001": "引擎盖",
    "yongche-0007": "胎压计",
    "yundong-0001": "三双跑鞋",
    "yundong-0002": "羽毛球",
    "yundong-0006": "塑胶跑道",
    "zhuangxiu-0001": "线管",
    "zhuangxiu-0005": "瓷砖",
    "zhuangxiu-0006": "闭水试验",
    "zhuangxiu-0011": "吸尘器",
}

IMG_EXTS = {".png", ".jpg", ".jpeg", ".webp"}


def collect():
    """把 raw-photos 下（含子目录）的生成图按关键词归位成 <id>.png。"""
    raw_dir = OUT_DIR / "raw-photos"
    if not raw_dir.exists():
        print(f"目录不存在 {raw_dir}", file=sys.stderr)
        return 1
    moved, unmatched = [], []
    for path in sorted(raw_dir.rglob("*")):
        if not path.is_file() or path.suffix.lower() not in IMG_EXTS:
            continue
        if path.parent == raw_dir and path.stem in KEYWORDS:
            continue  # 已归位
        matched = None
        for pid, keyword in KEYWORDS.items():
            if keyword in path.name:
                matched = pid
                break
        if matched is None:
            unmatched.append(str(path.relative_to(raw_dir)))
            continue
        target = raw_dir / f"{matched}{path.suffix.lower()}"
        if target.exists():
            target.unlink()
        path.rename(target)
        moved.append(f"{path.name} → {target.name}")
    for line in moved:
        print(f"  {line}")
    print(f"归位 {len(moved)} 张")
    if unmatched:
        print(f"未匹配 {len(unmatched)} 张（关键词表需补）：{'、'.join(unmatched)}", file=sys.stderr)
        return 1
    return 0


def build_manifest():
    if not SCENES:
        print("SCENES 为空", file=sys.stderr)
        return 1
    items = []
    for file in sorted((CONTENT_DIR / "circles").glob("*.json")):
        payload = json.loads(file.read_text(encoding="utf-8"))
        for post in payload["posts"]:
            if not post.get("photoCount"):
                continue
            pid = post["id"]
            scene = SCENES.get(pid)
            if not scene:
                print(f"缺少 {pid} 的拍摄场景，请在 SCENES 里补一句", file=sys.stderr)
                return 1
            items.append({
                "id": pid,
                "circle": payload["circle"],
                "topic": post.get("_topic", ""),
                "title": post["title"],
                "raw": f"raw-photos/{pid}.png",
                "out": f"posts/seed/{pid}-1.jpg",
                "prompt": f"{scene}。{STYLE_SUFFIX}",
            })
    manifest_path = OUT_DIR / "photo-manifest.json"
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(
        json.dumps({"count": len(items), "items": items}, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"manifest {len(items)} 条 → {manifest_path}")
    for item in items:
        print(f"  {item['id']}  {item['topic']}")
    return 0


def find_raw(raw_dir: Path, stem: str):
    for ext in (".png", ".jpg", ".jpeg", ".webp"):
        candidate = raw_dir / f"{stem}{ext}"
        if candidate.exists():
            return candidate
    return None


def process():
    manifest_path = OUT_DIR / "photo-manifest.json"
    if not manifest_path.exists():
        print(f"缺少 {manifest_path}，先跑 manifest", file=sys.stderr)
        return 1
    items = json.loads(manifest_path.read_text(encoding="utf-8"))["items"]
    raw_dir = OUT_DIR / "raw-photos"

    missing = []
    done = 0
    for item in items:
        raw = find_raw(raw_dir, item["id"])
        if raw is None:
            missing.append(item["id"])
            continue
        img = Image.open(raw)
        img = img.convert("RGB")
        # 中心裁剪到 3:4，再缩放到 810×1080，与文字海报同一规格。
        # 裁剪窗口整体上移：生成图右下角带「AI生成」角标，裁掉底部 15% 才能去掉。
        target_ratio = WIDTH / HEIGHT
        w, h = img.size
        if w / h > target_ratio:
            new_w = int(h * target_ratio)
            left = (w - new_w) // 2
            img = img.crop((left, 0, left + new_w, h))
        else:
            new_h = int(w / target_ratio)
            top = int((h - new_h) * 0.15)
            img = img.crop((0, top, w, top + new_h))
        img = img.resize((WIDTH, HEIGHT), Image.LANCZOS)
        out_path = OUT_DIR / item["out"]
        out_path.parent.mkdir(parents=True, exist_ok=True)
        img.save(out_path, "JPEG", quality=80, optimize=True, progressive=True)
        done += 1

    print(f"处理 {done} 张 → {OUT_DIR / 'posts' / 'seed'}")
    if missing:
        print(f"缺 {len(missing)} 张原图：{' '.join(missing)}", file=sys.stderr)
        return 1
    return 0


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("step", choices=["manifest", "collect", "process"])
    args = parser.parse_args()
    if args.step == "manifest":
        return build_manifest()
    if args.step == "collect":
        return collect()
    return process()


if __name__ == "__main__":
    sys.exit(main())
