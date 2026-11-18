#!/usr/bin/env python3
"""
Công cụ kiểm tra & dựng animation cho nhân vật (chạy bằng Python 3 + Pillow + numpy).

  python tools/sprite_tools.py check            # kiểm tra tất cả nhân vật
  python tools/sprite_tools.py check zoro       # kiểm tra 1 nhân vật
  python tools/sprite_tools.py build zoro       # tạo animations/zoro/spriteframes.tres từ các PNG

Cấu trúc thư mục bắt buộc:
  animations/<id>/battle_loop/f01..f06.png
  animations/<id>/s1/f01..f06.png
  animations/<id>/s2/f01..f06.png
  animations/<id>/ult/f01..f12.png
Mỗi PNG: 768x576, RGBA, nền trong suốt, chân nhân vật đứng tại (312, 500).
Clip hiệu ứng lớn (hóa rồng, phượng hoàng, cầu lửa khổng lồ, hóa Phật...): xuất với canvas =
768x576 nhân k (1.5 / 2 / 2.5 / 3 / 4), chân nhân vật ở cùng vị trí TƯƠNG ĐỐI (40.6% từ trái,
86.8% từ trên). Không cần khai báo gì; game và công cụ tự nhận ra. (battle_loop luôn 768x576.)
Muốn pivot khác quy tắc đó mới cần khai báo CLIP_LAYOUT trong scripts/character_animations.gd.

`check` ghi ảnh tổng hợp vào tools/reports/<id>.png (viền đỏ = frame có cảnh báo,
dấu + xanh = điểm chân chuẩn) để bạn lướt mắt 1 lần thay vì mở 30 file.
Mã thoát: 0 = không lỗi, 1 = có LỖI (cảnh báo thì vẫn 0).
"""
import sys, re
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
ANIM = ROOT / "animations"
REPORTS = Path(__file__).resolve().parent / "reports"

CANVAS = (768, 576)
PIVOT = (312, 500)
CLIPS = {"battle_loop": 6, "s1": 6, "s2": 6, "ult": 12}
CLIP_SPEED = {"battle_loop": 7.0, "s1": 10.0, "s2": 10.0, "ult": 14.0}
CLIP_LOOP = {"battle_loop": True, "s1": False, "s2": False, "ult": False}
ALPHA_T = 16            # alpha > ngưỡng này mới tính là "có hình"
FEET_TOL = 14           # sai số cho phép của chân so với PIVOT.y (idle)
HEIGHT_TOL = 0.15       # frame đầu của skill lệch chiều cao > 15% so với idle -> cảnh báo
JUMP_PX = 140           # tâm nhân vật nhảy ngang > số này giữa 2 frame -> cảnh báo


def read_layout():
    """Đọc CLIP_LAYOUT trong scripts/character_animations.gd (mỗi clip một dòng, không comment)."""
    out = {}
    gd = ROOT / "scripts" / "character_animations.gd"
    if not gd.exists():
        return out
    pat = re.compile(
        r'^\s*"(\w+)"\s*:\s*\{\s*"(\w+)"\s*:\s*\{[^}]*?"canvas"\s*:\s*Vector2\(\s*(\d+)\s*,\s*(\d+)\s*\)'
        r'[^}]*?"pivot"\s*:\s*Vector2\(\s*(\d+)\s*,\s*(\d+)\s*\)', re.M)
    for line in gd.read_text(encoding="utf-8").splitlines():
        if line.strip().startswith("#"):
            continue
        m = pat.match(line)
        if m:
            cid, clip, cw, ch, px, py = m.groups()
            out.setdefault(cid, {})[clip] = {"canvas": (int(cw), int(ch)), "pivot": (int(px), int(py))}
    return out


LAYOUT = read_layout()


def auto_pivot(size):
    return (round(PIVOT[0] * size[0] / CANVAS[0]), round(PIVOT[1] * size[1] / CANVAS[1]))


def auto_scale_ok(size):
    """Canvas hợp lệ = 768x576 nhân k (bước 0.5, tối đa 4)."""
    k = size[0] / CANVAS[0]
    return abs(size[1] - CANVAS[1] * k) < 0.5 and k >= 1 and k <= 4 and abs(k * 2 - round(k * 2)) < 1e-6


def clip_layout(cid, clip, size=None):
    """-> (canvas, pivot, la_khai_bao_rieng). Có size thì tính pivot tự động theo quy tắc tương đối."""
    l = LAYOUT.get(cid, {}).get(clip)
    if l:
        return l["canvas"], l["pivot"], True
    if size is not None and tuple(size) != CANVAS:
        return tuple(size), auto_pivot(size), False
    return CANVAS, PIVOT, False


def list_ids():
    return sorted(p.name for p in ANIM.iterdir() if p.is_dir())


def load(path):
    im = Image.open(path)
    return im, np.array(im.convert("RGBA"))


def bbox(a):
    m = a[..., 3] > ALPHA_T
    if not m.any():
        return None
    ys, xs = np.where(m)
    return xs.min(), ys.min(), xs.max(), ys.max()


def check_character(cid):
    errors, warns = [], []
    frames = {}   # clip -> list of (path, img, arr, bb, flags)
    base = ANIM / cid
    for clip, n in CLIPS.items():
        folder = base / clip
        files = sorted(folder.glob("f*.png")) if folder.exists() else []
        names = [f.name for f in files]
        expect = ["f%02d.png" % (i + 1) for i in range(n)]
        if names != expect:
            errors.append(f"[{clip}] cần đúng {n} file {expect[0]}..{expect[-1]}, hiện có {len(names)}: {names[:3]}...")
        items = []
        if files:
            sizes = {Image.open(f).size for f in files}
            if len(sizes) > 1:
                errors.append(f"[{clip}] các frame khác kích thước nhau: {sorted(sizes)} (mọi frame trong 1 clip phải cùng kích thước)")
        for f in files:
            im, arr = load(f)
            flags = []
            where = f"{clip}/{f.name}"
            want, _pv, custom = clip_layout(cid, clip)
            if custom:
                size_ok = im.size == want
                msg = f"cần {want} (theo CLIP_LAYOUT)"
            elif clip == "battle_loop":
                size_ok = im.size == CANVAS
                msg = f"cần {CANVAS} (battle_loop luôn cố định)"
            else:
                size_ok = auto_scale_ok(im.size)
                msg = f"cần 768x576 hoặc bội số k (1.5/2/2.5/3/4) giữ tỉ lệ 4:3, ví dụ 1536x1152"
            if not size_ok:
                errors.append(f"{where}: kích thước {im.size}, {msg}")
                flags.append("size")
            if im.mode != "RGBA":
                errors.append(f"{where}: mode {im.mode}, cần RGBA (nền trong suốt)")
                flags.append("mode")
            bb = bbox(arr)
            if bb is None:
                errors.append(f"{where}: frame TRỐNG (không có pixel nào)")
                flags.append("empty")
            else:
                x0, y0, x1, y1 = bb
                h, w = arr.shape[:2]
                sides = []
                if x0 <= 0: sides.append("trái")
                if y0 <= 0: sides.append("trên")
                if x1 >= w - 1: sides.append("phải")
                if y1 >= h - 1: sides.append("dưới")
                if sides:
                    warns.append(f"{where}: hiệu ứng/nhân vật chạm mép {', '.join(sides)} -> có thể bị CẮT")
                    flags.append("clip")
            items.append((f, im, arr, bb, flags))
        frames[clip] = items

    # idle: chân + chiều cao
    idle = [it for it in frames.get("battle_loop", []) if it[3]]
    idle_h = None
    if idle:
        feet = [it[3][3] for it in idle]
        idle_h = float(np.median([it[3][3] - it[3][1] for it in idle]))
        # Hiệu ứng aura/lửa làm bbox sai lệch so với chân thật, nên chỉ kiểm tra độ ỔN ĐỊNH
        # của đường chân giữa các frame idle (không so với số tuyệt đối).
        if max(feet) - min(feet) > FEET_TOL:
            warns.append(f"battle_loop: chân dao động y={min(feet)}..{max(feet)} giữa các frame idle (nhân vật bị 'trôi' lên xuống)")
            for it in idle:
                it[4].append("feet")

    for clip, items in frames.items():
        prev = None
        for i, it in enumerate(items):
            f, im, arr, bb, flags = it
            if bb is None:
                prev = None
                continue
            where = f"{clip}/{f.name}"
            # frame đầu của skill phải cùng "kích cỡ cơ thể" với idle
            if clip != "battle_loop" and i == 0 and idle_h and not clip_layout(cid, clip)[2] and im.size == CANVAS:
                h = bb[3] - bb[1]
                if abs(h - idle_h) > HEIGHT_TOL * idle_h * 2.2:   # skill có thể kèm hiệu ứng nên nới rộng
                    warns.append(f"{where}: cao {h}px so với idle {idle_h:.0f}px -> nhân vật có thể bị to/nhỏ khi vào chiêu")
                    flags.append("scale")
            if prev is not None:
                if np.array_equal(prev[2], arr):
                    warns.append(f"{where}: GIỐNG HỆT frame trước -> giật/đứng hình")
                    flags.append("dup")
                cx_p = (prev[3][0] + prev[3][2]) / 2
                cx_c = (bb[0] + bb[2]) / 2
                if abs(cx_p - cx_c) > JUMP_PX:
                    warns.append(f"{where}: tâm nhảy ngang {abs(cx_p-cx_c):.0f}px so với frame trước")
                    flags.append("jump")
            prev = it

    # file .tres
    tres = base / "spriteframes.tres"
    if tres.exists():
        for rel in re.findall(r'path="res://([^"]+)"', tres.read_text(encoding="utf-8")):
            if not (ROOT / rel).exists():
                errors.append(f"spriteframes.tres trỏ tới file không tồn tại: {rel}")
    else:
        warns.append("chưa có spriteframes.tres (chạy: build %s)" % cid)

    make_sheet(cid, frames)
    return errors, warns, idle_h


def make_sheet(cid, frames):
    REPORTS.mkdir(exist_ok=True)
    cw, ch = int(CANVAS[0] * 0.32), int(CANVAS[1] * 0.32)   # ô cố định, frame lớn hơn sẽ thu nhỏ vừa ô
    cols = 6
    rows = sum((len(v) + cols - 1) // cols for v in frames.values() if v) or 1
    sheet = Image.new("RGBA", (cols * cw, rows * ch), (40, 44, 56, 255))
    d = ImageDraw.Draw(sheet)
    r = 0
    for clip, items in frames.items():
        for i, (f, im, arr, bb, flags) in enumerate(items):
            _want, pv, custom = clip_layout(cid, clip, im.size)
            big = custom or im.size != CANVAS
            col, rr = i % cols, r + i // cols
            ox, oy = col * cw, rr * ch
            k = min(cw / im.size[0], ch / im.size[1])
            nw, nh = max(1, int(im.size[0] * k)), max(1, int(im.size[1] * k))
            try:
                small = im.convert("RGBA").resize((nw, nh), Image.NEAREST)
                sheet.alpha_composite(small, (ox, oy))
            except Exception:
                pass
            px, py = ox + int(pv[0] * k), oy + int(pv[1] * k)
            d.line([(px - 5, py), (px + 5, py)], fill=(60, 255, 120, 255))
            d.line([(px, py - 5), (px, py + 5)], fill=(60, 255, 120, 255))
            if flags:
                d.rectangle([ox, oy, ox + cw - 1, oy + ch - 1], outline=(255, 50, 50, 255), width=3)
            d.text((ox + 4, oy + 3), f"{clip} {f.stem}" + (f" [canvas x{im.size[0]/CANVAS[0]:g}]" if big else ""), fill=(255, 255, 255, 255))
        r += (len(items) + cols - 1) // cols
    sheet.convert("RGB").save(REPORTS / f"{cid}.png")


def build_tres(cid):
    base = ANIM / cid
    ext, anims, idx = [], [], 0
    for clip, n in CLIPS.items():
        fr = []
        for i in range(n):
            idx += 1
            ext.append(f'[ext_resource type="Texture2D" path="res://animations/{cid}/{clip}/f{i+1:02d}.png" id="{idx}_tex"]')
            fr.append('{"duration": 1.0, "texture": ExtResource("%d_tex")}' % idx)
        anims.append('{\n"frames": [\n%s\n],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}'
                     % (",\n".join(fr), "true" if CLIP_LOOP[clip] else "false", clip, CLIP_SPEED[clip]))
    text = ('[gd_resource type="SpriteFrames" load_steps=%d format=3]\n\n' % (idx + 1)
            + "\n".join(ext) + "\n\n[resource]\nanimations = [\n" + ",\n".join(anims) + "\n]\n")
    (base / "spriteframes.tres").write_text(text, encoding="utf-8")


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in ("check", "build"):
        print(__doc__); return 2
    cmd = sys.argv[1]
    ids = sys.argv[2:] or list_ids()
    bad = False
    for cid in ids:
        if not (ANIM / cid).exists():
            print(f"✗ không thấy animations/{cid}"); bad = True; continue
        if cmd == "build":
            build_tres(cid)
            errors, warns, idle_h = check_character(cid)
            print(f"✓ đã tạo animations/{cid}/spriteframes.tres")
            if idle_h:
                print(f'   Thêm vào BODY_REFERENCE_PX trong character_animations.gd:  "{cid}": <chiều cao THÂN người, không tính aura/lửa>,')
                print(f'   (tham khảo thô: bbox idle cao {idle_h:.0f}px, đã gồm cả hiệu ứng; thân thật thường nhỏ hơn)')
        else:
            errors, warns, idle_h = check_character(cid)
        status = "LỖI" if errors else ("CẢNH BÁO" if warns else "OK")
        print(f"\n== {cid}: {status}  (ảnh tổng hợp: tools/reports/{cid}.png)")
        for e in errors: print("  ✗", e)
        for w in warns: print("  !", w)
        bad = bad or bool(errors)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
