"""导出图标候选：拷到可访问目录 + 生成对比预览页（含多种裁切/尺寸）。"""
import os
import shutil
from PIL import Image, ImageDraw, ImageFont

SRC = r'D:\claude\comfyui\ComfyUI_windows_portable\ComfyUI\output'
DST = r'D:\claude\recomp_app\docs\icon_candidates'

CANDS = [
    ('recomp_icon_00008_.png', 'A', '三色环 + 角色', '橙/绿/蓝三弧对应碳蛋脂配比，构图最贴应用语义；角色偏小'),
    ('recomp_icon_00002_.png', 'B', '营养师 + 饭团', '营养主题最直白，但缩小后细节糊成一团'),
    ('recomp_icon_00001_.png', 'C', '哑铃 + 点赞', '轮廓最干净，森绿背景呼应应用主题；偏「健身」少「吃」'),
    ('recomp_icon_00007_.png', 'D', '屈臂 + 绿系', '与 C 同类，构图略平淡'),
    ('recomp_icon_00005_.png', 'E', '大头贴纸 + 三点', '脸颊三点呼应三宏量；牙齿有 AI 瑕疵，需重出'),
    ('recomp_icon_00004_.png', 'F', '胜利姿态 + 餐盘', '元素最丰富，缩小后偏乱'),
]

os.makedirs(DST, exist_ok=True)

# 1) 拷贝原图 + 生成各尺寸与裁切形态
SIZES = [512, 192, 144, 96, 72, 48]
rows_html = []

for fn, key, name, note in CANDS:
    src_path = os.path.join(SRC, fn)
    im = Image.open(src_path).convert('RGB')
    base = os.path.join(DST, '{}_1024.png'.format(key))
    im.save(base)

    # 圆角方形（Android 常见观感）
    rounded = os.path.join(DST, '{}_rounded.png'.format(key))
    mask = Image.new('L', (512, 512), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, 511, 511), radius=112, fill=255)
    r = Image.new('RGB', (512, 512), (255, 255, 255))
    r.paste(im.resize((512, 512), Image.LANCZOS), (0, 0), mask)
    r.save(rounded)

    # 圆形
    circle = os.path.join(DST, '{}_circle.png'.format(key))
    cmask = Image.new('L', (512, 512), 0)
    ImageDraw.Draw(cmask).ellipse((0, 0, 511, 511), fill=255)
    c = Image.new('RGB', (512, 512), (255, 255, 255))
    c.paste(im.resize((512, 512), Image.LANCZOS), (0, 0), cmask)
    c.save(circle)

    # 各尺寸（PNG）
    thumbs = []
    for s in SIZES:
        tp = os.path.join(DST, '{}_48.png'.format(key)) if s == 48 else os.path.join(DST, '{}_s{}.png'.format(key, s))
        t = im.resize((s, s), Image.LANCZOS)
        if s >= 96:
            tm = Image.new('L', (s, s), 0)
            ImageDraw.Draw(tm).rounded_rectangle((0, 0, s - 1, s - 1), radius=max(2, s // 5), fill=255)
            t2 = Image.new('RGB', (s, s), (255, 255, 255))
            t2.paste(t, (0, 0), tm)
            t2.save(tp)
        else:
            t.save(tp)
        thumbs.append((s, tp))

    thumbs_html = ''.join(
        '<span class="thumb"><img src="{}" width="{}" height="{}"><em>{}px</em></span>'.format(
            os.path.basename(tp), s, s, s) for s, tp in thumbs)

    rows_html.append('''
    <section class="card">
      <h2><span class="key">{key}</span> {name}</h2>
      <div class="variants">
        <figure><img src="{key}_1024.png" alt=""><figcaption>原图 1024</figcaption></figure>
        <figure><img class="rounded" src="{key}_rounded.png" alt=""><figcaption>圆角方形</figcaption></figure>
        <figure><img class="circle" src="{key}_circle.png" alt=""><figcaption>圆形</figcaption></figure>
      </div>
      <p class="note">{note}</p>
      <div class="thumbs">{thumbs}</div>
    </section>'''.format(key=key, name=name, note=note, thumbs=thumbs_html))

html = '''<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<title>recomp_app 图标候选</title>
<style>
  body {{ margin:0; padding:28px; background:#f4f5f7; color:#1c1d21;
         font-family:"Microsoft YaHei","Segoe UI",sans-serif; }}
  h1 {{ font-size:20px; margin:0 0 6px; }}
  .sub {{ color:#6b6d76; font-size:13px; margin-bottom:24px; }}
  .card {{ background:#fff; border-radius:16px; padding:18px 20px 22px;
           margin-bottom:18px; box-shadow:0 1px 3px rgba(0,0,0,.07); }}
  .card h2 {{ font-size:16px; margin:0 0 14px; display:flex; align-items:center; gap:10px; }}
  .key {{ display:inline-flex; width:26px; height:26px; border-radius:8px;
          background:#1b5e20; color:#fff; font-size:14px; align-items:center;
          justify-content:center; }}
  .variants {{ display:flex; gap:16px; flex-wrap:wrap; }}
  figure {{ margin:0; text-align:center; }}
  figure img {{ display:block; width:150px; height:150px; border-radius:8px; }}
  figcaption {{ font-size:11px; color:#8a8c95; margin-top:5px; }}
  .note {{ font-size:13px; color:#4a4c55; margin:14px 0 8px; }}
  .thumbs {{ display:flex; align-items:flex-end; gap:14px; padding-top:10px;
             border-top:1px dashed #e2e3e8; }}
  .thumb {{ display:inline-flex; flex-direction:column; align-items:center; gap:3px; }}
  .thumb em {{ font-size:10px; color:#9a9ca5; font-style:normal; }}
</style>
</head>
<body>
<h1>recomp_app 图标候选</h1>
<div class="sub">六套方案 · 每套给出原图 / 圆角方形 / 圆形三种形态，以及 512→48px 逐级缩小效果。<br>
判断要点：<strong>缩到 48px 还认不认得出</strong>。图片文件同目录，可直接取用。</div>
{rows}
</body>
</html>'''.format(rows='\n'.join(rows_html))

out = os.path.join(DST, 'compare.html')
with open(out, 'w', encoding='utf-8') as f:
    f.write(html)

print('目录:', DST)
print('页面:', out)
print('文件数:', len(os.listdir(DST)))
