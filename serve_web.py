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


class IsolatedHandler(http.server.SimpleHTTPRequestHandler):
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
