"""用本机 ComfyUI 生成 recomp_app 的动漫风图标候选。

管线：Krea2 Turbo (fp8) + Qwen3-VL 4B 编码 + qwen_image VAE + 动漫风 LoRA
参数对齐用户已跑通的工作流：8 步 / CFG 1 / euler / simple。
"""
import json
import sys
import time
import urllib.request
import urllib.error
import uuid
import os

BASE = 'http://127.0.0.1:8188'
opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))


def post(path, payload):
    data = json.dumps(payload).encode('utf-8')
    req = urllib.request.Request(BASE + path, data=data,
                                 headers={'Content-Type': 'application/json'})
    with opener.open(req, timeout=60) as r:
        return json.loads(r.read().decode('utf-8'))


def get(path):
    with opener.open(BASE + path, timeout=60) as r:
        return json.loads(r.read().decode('utf-8'))


def build(prompt, seed, lora, lora_strength, width, height, steps=8, cfg=1.0):
    return {
        "unet": {"class_type": "UNETLoader",
                 "inputs": {"unet_name": "krea2_turbo_fp8.safetensors",
                            "weight_dtype": "default"}},
        "clip": {"class_type": "CLIPLoader",
                 "inputs": {"clip_name": "qwen3vl_4b_bf16.safetensors",
                            "type": "krea2", "device": "default"}},
        "vae": {"class_type": "VAELoader",
                "inputs": {"vae_name": "qwen_image_vae.safetensors"}},
        "lora": {"class_type": "LoraLoader",
                 "inputs": {"model": ["unet", 0], "clip": ["clip", 0],
                            "lora_name": lora,
                            "strength_model": lora_strength,
                            "strength_clip": lora_strength}},
        "pos": {"class_type": "CLIPTextEncode",
                "inputs": {"text": prompt, "clip": ["lora", 1]}},
        "neg": {"class_type": "CLIPTextEncode",
                "inputs": {"text": "", "clip": ["lora", 1]}},
        "latent": {"class_type": "EmptyLatentImage",
                   "inputs": {"width": width, "height": height, "batch_size": 1}},
        "sampler": {"class_type": "KSampler",
                    "inputs": {"model": ["lora", 0], "seed": seed,
                               "steps": steps, "cfg": cfg,
                               "sampler_name": "euler", "scheduler": "simple",
                               "positive": ["pos", 0], "negative": ["neg", 0],
                               "latent_image": ["latent", 0], "denoise": 1.0}},
        "decode": {"class_type": "VAEDecode",
                   "inputs": {"samples": ["sampler", 0], "vae": ["vae", 0]}},
        "save": {"class_type": "SaveImage",
                 "inputs": {"images": ["decode", 0], "filename_prefix": "recomp_icon"}},
    }


def run(name, prompt, seed, lora, strength, width=1024, height=1024):
    wf = build(prompt, seed, lora, strength, width, height)
    t0 = time.time()
    try:
        res = post('/prompt', {"prompt": wf, "client_id": str(uuid.uuid4())})
    except urllib.error.HTTPError as e:
        body = e.read().decode('utf-8', 'replace')
        print('[FAIL] {} 提交被拒: {} {}'.format(name, e.code, body[:800]))
        return None
    pid = res.get('prompt_id')
    print('[OK] {} 已提交 prompt_id={}'.format(name, pid[:8]))

    # 轮询历史
    for _ in range(240):
        time.sleep(2)
        try:
            hist = get('/history/' + pid)
        except Exception:
            continue
        if pid in hist:
            entry = hist[pid]
            status = entry.get('status', {})
            if status.get('status_str') == 'error' or not status.get('completed', True):
                print('[FAIL] {} 执行出错: {}'.format(name, json.dumps(status, ensure_ascii=False)[:900]))
                return None
            outputs = entry.get('outputs', {})
            for node_out in outputs.values():
                for img in node_out.get('images', []):
                    print('[DONE] {} 用时 {:.1f}s -> {}'.format(name, time.time() - t0, img['filename']))
                    return img['filename']
    print('[TIMEOUT]', name)
    return None


if __name__ == '__main__':
    tasks = json.load(open(sys.argv[1], encoding='utf-8'))
    results = []
    for t in tasks:
        fn = run(t['name'], t['prompt'], t['seed'], t['lora'],
                 t.get('strength', 0.8), t.get('width', 1024), t.get('height', 1024))
        results.append((t['name'], fn))
    print()
    print('=== 汇总 ===')
    for n, f in results:
        print('  {}: {}'.format(n, f or 'FAILED'))
