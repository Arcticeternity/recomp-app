"""把选定候选做成 Android / iOS 完整图标集。

原图是 1024×1024 满图。Android 用 traditional 方形图标（启动器自行加圆角/圆形遮罩）。
小尺寸加锐化补偿：B 方案细节偏多，直接缩会糊。
"""
import os
import shutil
from PIL import Image, ImageFilter, ImageEnhance

SRC = r'D:\claude\recomp_app\docs\icon_candidates\B_1024.png'
RES = r'D:\claude\recomp_app\android\app\src\main\res'
IOS = r'D:\claude\recomp_app\ios\Runner\Assets.xcassets\AppIcon.appiconset'

src = Image.open(SRC).convert('RGB')
assert src.size == (1024, 1024), src.size

# 备份原图标
backup = r'D:\claude\recomp_app\docs\icon_candidates\_backup_original_icons'
if not os.path.exists(backup):
    os.makedirs(backup)


def render(size):
    """缩放 + 小尺寸锐化补偿。"""
    im = src.resize((size, size), Image.LANCZOS)
    if size <= 192:
        # 缩小时细节会糊：轻微提锐 + 提饱和，保住轮廓与色彩
        im = im.filter(ImageFilter.UnsharpMask(radius=1.6, percent=110, threshold=3))
        im = ImageEnhance.Color(im).enhance(1.06)
        im = ImageEnhance.Contrast(im).enhance(1.04)
    return im


# ---- Android ----
ANDROID = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
}
for folder, size in ANDROID.items():
    d = os.path.join(RES, folder)
    os.makedirs(d, exist_ok=True)
    tgt = os.path.join(d, 'ic_launcher.png')
    if os.path.exists(tgt) and not os.path.exists(os.path.join(backup, 'android_' + folder + '_ic_launcher.png')):
        shutil.copy2(tgt, os.path.join(backup, 'android_' + folder + '_ic_launcher.png'))
    render(size).save(tgt, 'PNG')
    print('android {:<16} {}px'.format(folder, size))

# ---- iOS ----
IOS_FILES = {
    'Icon-App-20x20@1x.png': 20,
    'Icon-App-20x20@2x.png': 40,
    'Icon-App-20x20@3x.png': 60,
    'Icon-App-29x29@1x.png': 29,
    'Icon-App-29x29@2x.png': 58,
    'Icon-App-29x29@3x.png': 87,
    'Icon-App-40x40@1x.png': 40,
    'Icon-App-40x40@2x.png': 80,
    'Icon-App-40x40@3x.png': 120,
    'Icon-App-60x60@2x.png': 120,
    'Icon-App-60x60@3x.png': 180,
    'Icon-App-76x76@1x.png': 76,
    'Icon-App-76x76@2x.png': 152,
    'Icon-App-83.5x83.5@2x.png': 167,
    'Icon-App-1024x1024@1x.png': 1024,
}
for fn, size in IOS_FILES.items():
    tgt = os.path.join(IOS, fn)
    if os.path.exists(tgt) and not os.path.exists(os.path.join(backup, 'ios_' + fn)):
        shutil.copy2(tgt, os.path.join(backup, 'ios_' + fn))
    render(size).save(tgt, 'PNG')
print('ios: {} 个尺寸'.format(len(IOS_FILES)))

print('备份原图标 ->', backup)
