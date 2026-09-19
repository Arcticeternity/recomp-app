"""把静态 SQLite 库导出成 SQL dump（Web 端内存库执行用）。

为什么不用二进制反序列化：sqlite3 3.6 未暴露 deserialize，
而 sqflite_common_ffi_web 的 VFS 目录名属于实现细节，不适合硬编码。
SQL dump 走公开 API，跨平台稳定。
"""
import sqlite3
import os

ASSETS = r'D:\claude\recomp_app\assets'

JOBS = [
    ('food_composition.db', 'food_composition.sql'),
    ('fitness.db', 'fitness.sql'),
]


def esc(v):
    if v is None:
        return 'NULL'
    if isinstance(v, bool):
        return '1' if v else '0'
    if isinstance(v, (int, float)):
        return repr(v)
    if isinstance(v, bytes):
        return "X'" + v.hex() + "'"
    return "'" + str(v).replace("'", "''") + "'"


for db_name, sql_name in JOBS:
    src = os.path.join(ASSETS, db_name)
    dst = os.path.join(ASSETS, sql_name)
    con = sqlite3.connect(src)
    cur = con.cursor()

    lines = []
    lines.append('-- generated from {} by tools/dump_static_db.py'.format(db_name))

    # 表结构
    tables = [r[0] for r in cur.execute(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name")]
    for t in tables:
        ddl = cur.execute(
            "SELECT sql FROM sqlite_master WHERE type='table' AND name=?", (t,)).fetchone()[0]
        lines.append('DROP TABLE IF EXISTS "{}";'.format(t))
        lines.append(ddl + ';')

    # 索引
    for (idx_sql,) in cur.execute(
            "SELECT sql FROM sqlite_master WHERE type='index' AND sql IS NOT NULL"):
        lines.append(idx_sql + ';')

    # 数据：每条 INSERT 单独一行、单行完整语句 ——
    # 数据里含 JSON（带分号/换行符），按分号切语句会切坏，按行切才安全。
    total = 0
    for t in tables:
        cols = [c[1] for c in cur.execute('PRAGMA table_info("{}")'.format(t)).fetchall()]
        collist = ', '.join('"{}"'.format(c) for c in cols)
        rows = cur.execute('SELECT * FROM "{}"'.format(t)).fetchall()
        total += len(rows)
        for row in rows:
            values = '(' + ', '.join(esc(v) for v in row) + ')'
            lines.append('INSERT INTO "{}" ({}) VALUES {};'.format(t, collist, values))

    con.close()
    content = '\n'.join(lines) + '\n'
    with open(dst, 'w', encoding='utf-8') as f:
        f.write(content)
    print('{} -> {} ({} 行数据, {:.0f} KB, {} 条语句)'.format(
        db_name, sql_name, total, len(content.encode('utf-8')) / 1024, len(lines)))

print('完成')
