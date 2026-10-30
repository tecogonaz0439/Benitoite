"""保存した検査記録から一覧と最終点検の JSON を作る。P4 外には書かない。"""
import pathlib,json,hashlib,re,ast,datetime
root=pathlib.Path(__file__).resolve().parent
repo=root.parents[3]
records=[json.loads(p.read_text()) for p in (root/'checks').glob('*.json')]
records.sort(key=lambda r:r['started'])
final=[r for r in records if r['name'].startswith('final-')]
assert len(final)==7 and all(r.get('command_exit_code')==0 for r in final)
for p in root.glob('*.py'): ast.parse(p.read_text(),filename=str(p))
forbidden={}
pattern=re.compile(r'\b(sorry|admit|axiom|native_decide|implemented_by|unsafe)\b')
for p in root.glob('*.lean'):
    matches=[(i,line) for i,line in enumerate(p.read_text().splitlines(),1) if pattern.search(line)]
    if matches: forbidden[p.name]=matches
assert not forbidden,forbidden
axioms=set(); axiom_reports=[]
for r in final:
    log=(root/r['log']).read_text()
    assert 'error:' not in log and 'sorryAx' not in log
    for m in re.finditer(r"'([^']+)' depends on axioms: \[([^\]]*)\]",log):
        names=[s.strip() for s in m[2].split(',') if s.strip()]
        axioms.update(names); axiom_reports.append({'declaration':m[1],'axioms':names})
assert axioms<={'propext','Classical.choice','Quot.sound'},axioms
p2same=(root/'P2.lean').read_bytes()==(repo/'spikes/P2/lean/P2.lean').read_bytes()
assert p2same
source_hashes={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in root.glob('*.lean')}
artifacts={p.name:{'source_mtime_ns':p.stat().st_mtime_ns,'olean_mtime_ns':p.with_suffix('.olean').stat().st_mtime_ns} for p in root.glob('*.lean')}
assert all(r['source_mtime_ns']<=r['olean_mtime_ns'] for r in artifacts.values())
initial=json.loads((root/'protected-before-final.json').read_text())
changed=[p for p,h in initial['sha256'].items() if not (repo/p).is_file() or hashlib.sha256((repo/p).read_bytes()).hexdigest()!=h]
now=datetime.datetime.now(datetime.timezone.utc)
verification={'checked_at':now.isoformat(),'final_checks':[(r['name'],r['command_exit_code']) for r in final],
 'forbidden_lean_tokens':forbidden,'standard_axioms_only':sorted(axioms),'axiom_reports':axiom_reports,
 'p2_copy_matches':p2same,'source_sha256':source_hashes,'artifacts':artifacts,
 'protected_snapshot_started_at':initial['at'],'protected_files_compared':len(initial['sha256']),
 'protected_files_changed':changed,'protected_snapshot_note':'作業途中から最終点検までの比較。全期間の開始前の比較ではない。',
 'independent_review':False,'max_rss_available':False}
(root/'verification.json').write_text(json.dumps(verification,ensure_ascii=False,indent=2)+'\n')
lines=['# P4 の検査記録','',
 'コマンド本体の終了状態と `/usr/bin/time -l` の終了状態を分ける。全件で計測器は sandbox の `sysctl kern.clockrate` 制限により終了1、最大常駐量は取得できなかった。秒数は実行器が記録した壁時計の経過である。', '',
 '最初の `build-head` だけは本体の終了状態を直接保存していない。ログに573 jobsの成功があり、終了コードを別に保存する方式に変更後の増分ビルドも本体の終了0だった。初期形式の `exit_code` は計測器の値を持つ場合があるので、`command_exit_code` を判定に使う。最初の記録ではそれを不明とする。','',
 '## 最終の Lean 検査','',
 '| 対象 | 本体の終了 | 経過（秒） | 最大常駐量 | ログ |','|---|---:|---:|---|---|']
for r in final: lines.append(f"| {r['name'][6:]} | {r['command_exit_code']} | {r['elapsed_seconds']:.3f} | 取得不可 | [{r['name']}]({r['log']}) |")
lines+=['',f"最終7件の実行器の経過の合計は {sum(r['elapsed_seconds'] for r in final):.3f} 秒。依存順は P2 → Logic → Context → Derivations → M6 → Production → Cases。全件に `-M 12288` を指定し、600秒を上限とした。",'',
 '## 全試行','',
 '失敗は途中のLeanの構文・型推論・証明の未完を含む。生のログを残し、最終の成功だけで途中の失敗を上書きしない。`p2-build` の最初の失敗はパッケージのroot指定不足であり、`-R` にP4のパスを指定して解消した。','',
 '| 試行 | 本体の終了 | 計測器の終了 | 経過（秒） | 最大常駐量 | ログ |','|---|---:|---:|---:|---|---|']
for r in records:
    actual=r.get('command_exit_code'); timer=r.get('time_exit_code',r.get('exit_code'))
    lines.append(f"| {r['name']} | {actual if actual is not None else '不明'} | {timer} | {r['elapsed_seconds']:.3f} | 取得不可 | [log]({r['log']}) |")
lines+=['','## 再実行と点検','',
 'リポジトリの根から `python3 spikes/P4/check-all.py <記録の接頭辞>` を実行する。実行器がformalへ移動し、P4のLEAN_PATHとパッケージrootを指定して、各ファイルを依存順に再コンパイルする。本番のlake buildを再実行する台本ではない。','',
 f"最終のLean7ファイルで独自のaxiom宣言・sorry・admit・native_decide・implemented_by・unsafeは0件。#print axioms の{len(axiom_reports)}件の出力は propext・Classical.choice・Quot.sound の範囲だけだった。P2の写しは元とバイト単位で一致した。Pythonの3台本も構文を点検した。",'',
 f"本番ソース等{len(initial['sha256'])}件について、途中の{initial['at']}から最終点検までのハッシュ比較で変更は{len(changed)}件。このハッシュ比較を作業開始前からの比較とはしない。本番formalとHEADの差分0の確認は formal-head-source-match のログを参照。",'']
(root/'checks.md').write_text('\n'.join(lines))
print(json.dumps({'final_lean_checks':len(final),'final_elapsed_seconds':sum(r['elapsed_seconds'] for r in final),'axiom_reports':len(axiom_reports),'forbidden':forbidden,'protected_changed':changed},ensure_ascii=False))
