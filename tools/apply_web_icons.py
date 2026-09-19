"""用选定的 B 方案图标替换 Web 端图标与 favicon。"""
import os
from PIL import Image

SRC = r'D:\claude\recomp_app\docs\icon_candidates\B_1024.png'
WEB = r'D:\claude\recomp_app\web'

src = Image.open(SRC).convert('RGB')


def rounded(size, radius_ratio=0.22):
    im = src.resize((size, size), Image.LANCZOS)
    mask = Image.new('L', (size, size), 0)
    from PIL import ImageDraw
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, size - 1, size - 1), radius=int(size * radius_ratio), fill=255)
    out = Image.new('RGB', (size, size), (255, 255, 255))
    out.paste(im, (0, 0), mask)
    return out


# PWA 图标（圆角观感）
rounded(192).save(os.path.join(WEB, 'icons', 'Icon-192.png'))
rounded(512).save(os.path.join(WEB, 'icons', 'Icon-512.png'))
# maskable：主体要留安全区，缩小到 80% 再贴到满幅背景上
for size in (192, 512):
    inner = int(size * 0.78)
    canvas = Image.new('RGB', (size, size), (255, 255, 255))
    im = src.resize((inner, inner), Image.LANCZOS)
    off = (size - inner) // 2
    canvas.paste(im, (off, off))
    canvas.save(os.path.join(WEB, 'icons', 'Icon-maskable-{}.png'.format(size)))
# favicon
rounded(32, radius_ratio=0.2).save(os.path.join(WEB, 'favicon.png'))
print('web 图标已替换')
