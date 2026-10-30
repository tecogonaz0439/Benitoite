#!/usr/bin/env python3
import datetime, hashlib, json, pathlib, re
base=pathlib.Path(__file__).resolve().parent
repo=base.parents[3]
records=[]
for log in sorted((base/'checks').glob('*.log')):
    name=log.stem;txt=log.read_text();jp=log.with_suffix('.json');j=json.loads(jp.read_text())if jp.exists()else{}
    if (base/'checks'/f'{name}.status').exists():
        lean_exit=int((base/'checks'/f'{name}.status').read_text());status=f'Lean {lean_exit}'
    elif 'error:' in txt or 'no such file or directory' in txt:
        lean_exit=None;status='失敗（Lean終了値は未分離）'
    else:lean_exit=None;status='ログにLeanエラーなし（終了値未分離）'
    sec=j.get('seconds')
    if sec is None:
        m=re.search(r'([0-9.]+) real',txt);sec=float(m[1])if m else None
    records.append(dict(id=name,status=status,lean_exit=lean_exit,seconds=sec,maxrss_bytes=j.get('maxrss_bytes'),time_exit=j.get('time_exit',1),source=j.get('source','Skeleton.lean'),log=str(log.relative_to(base))))
md=['# 検査の記録','','全て `lake env lean -M 12288` で検査した。time -l 自体は sandbox の kern.clockrate 拒否で終了1になる。status ファイルに記録した Lean 子プロセスの終了を優先する。03・04は代替のメモリ計測を開始したが、まだ終了値の分離前である。01・02の最大常駐量は未取得である。','','RSS は macOS の getrusage(RUSAGE_CHILDREN) のバイト値を MiB に換算した、実行コマンドの子プロセスの最大値である。初回以外の時間は monotonic clock による。途中の失敗も保存する。','','| 検査 | Leanの状態 | 経過（秒） | 最大常駐量（MiB） | ログ |','|---|---|---:|---:|---|']
for j in records:
    mem=f'{j["maxrss_bytes"]/1024**2:.2f}'if j['maxrss_bytes']is not None else '未取得'
    md.append(f'| {j["id"]} | {j["status"]} | {j["seconds"]} | {mem} | [{j["id"]}]({j["log"]}) |')
md+=['','最終成果物は final-skeleton-2 と final-constants-2。いずれも Lean 終了0、警告なしである。途中の10は再帰の停止性の診断用に一時的な穴を使った試行であり、最終のソースにその穴は残していない。07・09は停止性の証明でsimpの探索を広げすぎてheartbeat上限に達した失敗で、約55秒で終了した。10分の上限に達した検査はない。']
(base/'checks.md').write_text('\n'.join(md)+'\n')
(base/'checks/index.json').write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n')
# 最終のソースの穴と独自公理、代表定理の出力を確認する。
proofs={}
for name in ['Skeleton.lean','Constants.lean']:
    text=(base/name).read_text()
    # 今回のファイルには文字列内のこれらの語はない。コメントは区間を除く。
    source=re.sub(r'/\-.*?\-/','',text,flags=re.S)
    source=re.sub(r'--[^\n]*','',source)
    holes=re.findall(r'\b(?:sorry|admit|axiom)\b',source)
    assert not holes,(name,holes)
    proofs[name]=dict(theorems=len(re.findall(r'^\s*theorem\s',text,re.M)),sha256=hashlib.sha256((base/name).read_bytes()).hexdigest(),holes=0,custom_axioms=0)
for name in ['final-skeleton-2','final-constants-2']:
    j=json.loads((base/'checks'/f'{name}.json').read_text());assert j['exit']==0,j
    txt=(base/'checks'/f'{name}.log').read_text();assert 'sorryAx'not in txt and 'error:'not in txt and 'warning:'not in txt
src=json.loads((base/'source-sha256.json').read_text());changed=[p for p,h in src.items()if hashlib.sha256((repo/p).read_bytes()).hexdigest()!=h]
assert not changed,changed
# ソースへのリンクだけでなく成果物の相互リンクも確認する。
broken=[]
for name in ['findings.md','main-theorems.md','inventory.md','checks.md']:
    txt=(base/name).read_text()
    for link in re.findall(r'\]\(([^)]+)\)',txt):
        if '://'not in link and not (base/link.split('#')[0]).exists():broken.append((name,link))
assert not broken,broken
now=datetime.datetime.now().astimezone()
started=datetime.datetime.fromisoformat((base/'started-at.txt').read_text().strip())
audit=dict(finished_at=now.isoformat(),recorded_start=started.isoformat(),recorded_elapsed_seconds=round((now-started).total_seconds(),1),initial_reading='計時ファイル作成より前の共通条件・現行定義の読解は含まない',proofs=proofs,production_source_hashes=len(src),production_sources_changed=changed,broken_links=broken,review='自己点検。独立した担当によるレビューは未実施。')
(base/'finish.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2)+'\n')
print(json.dumps(audit,ensure_ascii=False,indent=2))
