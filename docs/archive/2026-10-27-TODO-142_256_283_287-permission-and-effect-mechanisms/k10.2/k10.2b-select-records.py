"""比較の反復出力と200 KiB超のファイルを同じ相対位置へ移し、内容の一覧のハッシュを残す。"""
import hashlib
import json
from pathlib import Path
import re
import shutil

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
RAW = ROOT/'target/k10.2-raw'
RAW.mkdir(parents=True, exist_ok=True)
INDEX = RAW/'.inventories'
INDEX.mkdir(exist_ok=True)
REPORT = HERE/'k10.2b-moved-records.json'


def require(ok, message):
    if not ok:
        raise AssertionError(message)


def digest(data):
    return hashlib.sha256(data).hexdigest()


moved = json.loads(REPORT.read_text()) if REPORT.exists() else []

def move(path):
    relative = path.relative_to(HERE).as_posix()
    target = RAW/relative
    require(not target.exists(), relative+': destination already exists')
    files = sorted(p for p in path.rglob('*') if p.is_file()) if path.is_dir() else [path]
    rows = [dict(path=p.relative_to(HERE).as_posix(), bytes=p.stat().st_size,
                 sha256=digest(p.read_bytes())) for p in files]
    encoded = (json.dumps(rows,ensure_ascii=False,sort_keys=True,separators=(',',':'))+'\n').encode()
    name = relative.replace('/','__')+'.json'
    (INDEX/name).write_bytes(encoded)
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.move(str(path), str(target))
    for row in rows:
        data = (RAW/row['path']).read_bytes()
        require(len(data) == row['bytes'] and digest(data) == row['sha256'], row['path']+': moved file differs')
    moved.append(dict(path=relative,files=len(rows),bytes=sum(r['bytes'] for r in rows),
                      inventory='.inventories/'+name,inventorySha256=digest(encoded),
                      sha256=rows[0]['sha256'] if len(rows)==1 else None))

# 大きい交換の本文・反復した各呼び出しの生出力を要約と分ける。
for name in ('f-interval-vm','f-range','f-range-final','k10.2b-f-range-output'):
    directory = HERE/name
    if directory.exists():
        for path in sorted(directory.iterdir()):
            if path.is_dir():
                move(path)
for name in ('rejection-comparison','k10.2b-rejections-first','k10.2b-rejections-second','k10.2b-rejections-final'):
    directory = HERE/name
    if directory.exists():
        # 独立の入力と最終の判定は正式な比較結果側に同じものがある。
        move(directory)
# 同じ交換入力を各呼び出しごとに写したものを移す。正式な手書きの入力は残す。
for directory in (HERE/'range-source-comparison/rejections/inputs',
                  HERE/'k10.2b-source-comparison/rejections/inputs'):
    if directory.exists():
        move(directory)
for path in sorted(HERE.rglob('*')):
    if path.is_file() and 'rv-probes' not in path.relative_to(HERE).parts and path.stat().st_size > 200*1024:
        move(path)
REPORT.write_text(json.dumps(moved,ensure_ascii=False,indent=2)+'\n')
# 本文のリンクが移したファイルそのものか、その配下を指す場合は恒久の一覧へ向ける。
for path in HERE.rglob('*.md'):
    if 'rv-probes' in path.relative_to(HERE).parts or path.name == 'LARGE-FILES.md':
        continue
    text = path.read_text()
    def replace(match):
        target = match[2]
        if '://' in target or target.startswith('#'):
            return match[0]
        resolved = (path.parent/target.split('#')[0]).resolve()
        for row in moved:
            former = HERE/row['path']
            if resolved == former or former in resolved.parents:
                from os.path import relpath
                return '['+match[1]+']('+relpath(HERE/'LARGE-FILES.md',path.parent)+')'
        return match[0]
    text = re.sub(r'\[([^\]]+)\]\(([^)]+)\)', replace, text)
    path.write_text(text)
# 短い要約・入力・手書き期待・台本・判定JSONと短いログは残す。
lines=['# 大きい記録と比較の生の出力\n',
       '2026-10-29、K10.2b担当。元の `k10.2/` に対する相対位置を保ち、リポジトリ内の `target/k10.2-raw/` へ移した。削除していない。`target/` の保持を恒久の根拠とせず、結論・件数・入力・期待値・台本・短い判定とログは本ディレクトリに残す。\n',
       'ファイルは内容の SHA-256 を、ディレクトリは全ファイルの path・bytes・sha256 を相対path順に並べた一覧の SHA-256 を示す。一覧はUTF-8のJSON（キーをソート、区切りはカンマとコロン、末尾改行1個）である。個別ファイルの一覧は移動先の `.inventories/` にあり、その一覧自体もハッシュで同定する。移動時に全内容のハッシュを再照合した。\n',
       f"合計 **{sum(r['files'] for r in moved):,}ファイル、{sum(r['bytes'] for r in moved):,} bytes（{sum(r['bytes'] for r in moved)/2**20:.2f} MiB）**。移動の台本は [k10.2b-select-records.py](k10.2b-select-records.py)、機械可読の一覧は [k10.2b-moved-records.json](k10.2b-moved-records.json) である。\n",
       '| 元の相対位置（移動先も同じ） | ファイル数 | bytes | ファイルのSHA-256 / ディレクトリ一覧のSHA-256 |\n|---|---:|---:|---|']
for row in moved:
    lines.append(f"| `{row['path']}` | {row['files']} | {row['bytes']} | `{row['sha256'] or row['inventorySha256']}` |")
(HERE/'LARGE-FILES.md').write_text('\n'.join(lines)+'\n')
print(json.dumps(dict(movedFiles=sum(r['files'] for r in moved),movedBytes=sum(r['bytes'] for r in moved),groups=len(moved))))
