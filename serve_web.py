"""recomp_app Web 版本地预览服务器（仅标准库）。

为什么不能随手用 `python -m http.server`：
sqflite_common_ffi_web 走 sqlite3 WASM + SharedArrayBuffer，浏览器要求
页面处于「跨域隔离」状态才允许 SharedArrayBuffer，因此必须带上

    Cross-Origin-Opener-Policy: same-origin
    Cross-Origin-Embedder-Policy: require-corp

缺这两个头，Web 版会卡在数据库初始化。

用法：
    python serve_web.py            # 默认 8080
    python serve_web.py 9000       # 指定端口
"""
import http.server
import os
import socketserver
import sys


# Python 的 SimpleHTTPRequestHandler 不认识这些扩展名，会给错 Content-Type：
# - .wasm 需要 application/wasm，否则 WebAssembly.instantiateStreaming 被拒
# - .mjs  需要 text/javascript，否则浏览器拒绝当作 ES 模块加载
# 缺了它们，Flutter Web（尤其 --wasm 构建）在本地预览时会直接起不来。
EXTRA_TYPES = {
    '.wasm': 'application/wasm',
    '.mjs': 'text/javascript',
    '.js': 'text/javascript',
    '.otf': 'font/otf',
    '.ttf': 'font/ttf',
    '.woff2': 'font/woff2',
}


class IsolatedHandler(http.server.SimpleHTTPRequestHandler):
    def guess_type(self, path):
        ext = os.path.splitext(path)[1].lower()
        if ext in EXTRA_TYPES:
            return EXTRA_TYPES[ext]
        return super().guess_type(path)

    def end_headers(self):
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
        self.send_header('Cross-Origin-Resource-Policy', 'cross-origin')
        # 便于反复调试：不缓存
        self.send_header('Cache-Control', 'no-store')
        super().end_headers()

    def log_message(self, fmt, *args):
        # 只报错误，避免刷屏
        status = args[1] if len(args) > 1 else ''
        if str(status).startswith(('4', '5')):
            sys.stderr.write('%s - %s\n' % (self.address_string(), fmt % args))


def main():
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
    if len(sys.argv) > 2:
        # 第二个参数可指定根目录（本地用 base-href 构建测试时有用）
        root = os.path.abspath(sys.argv[2])
    else:
        root = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'build', 'web')
    if not os.path.isdir(root):
        sys.exit('未找到 %s，请先执行：flutter build web --release' % root)

    os.chdir(root)
    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(('127.0.0.1', port), IsolatedHandler) as httpd:
        print('recomp_app Web 预览： http://127.0.0.1:%d/' % port)
        print('根目录： %s' % root)
        print('按 Ctrl+C 停止')
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print('\n已停止')


if __name__ == '__main__':
    main()
