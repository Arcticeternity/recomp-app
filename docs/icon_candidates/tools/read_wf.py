import json
import sys

path = r'D:\claude\comfyui\ComfyUI_windows_portable\ComfyUI\user\default\workflows\Krea2-二次元-B站-是古手梨花sama.json'
wf = json.load(open(path, encoding='utf-8'))
nodes = wf.get('nodes', [])
print('nodes:', len(nodes))
for n in nodes:
    t = n.get('type')
    title = n.get('title') or ''
    wv = n.get('widgets_values')
    line = '  [{}] {} {} :: {}'.format(n.get('id'), t, title, str(wv)[:200])
    print(line)
print()
print('=== links 概览 ===')
for l in wf.get('links', [])[:40]:
    print('  ', l)
