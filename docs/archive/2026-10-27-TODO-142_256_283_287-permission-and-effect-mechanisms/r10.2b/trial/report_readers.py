"""B_WORKの全読者を、ファイル・宣言・出現位置で一意に数える。"""
import collections, json, os, re, subprocess
from pathlib import Path
root=Path(__file__).parent
semantic={
 'types/mod.rs':{'subst','show_ty','scoped_effects_survive_rows_and_types_inside_failures'},
 'typeck/context.rs':{'substitute'},
 'typeck/solve.rs':{'zonk_checked','finalize_zonked','finalize_failure_type_normalized','equal_with_outer','diagnostic_type'},
 'typeck/solve/provenance.rs':{'build_value','known_mismatch','record_provenance','recovered_type','provenance_failure'},
 'typeck/solve/effect_key.rs':{'new'},
 'typeck/traits/solve.rs':{'resolve_normalized','finalize_normalized'},
 'ir/check.rs':{'valid_contracts'},'ir/decision/arena.rs':{'ty_bytes'},
 'runtime/assert.rs':{'substitute'},'external/types.rs':{'validate'},
 'desugar_export/builtins.rs':{'remap_ty'},'desugar_export/exchange.rs':{'ty'},
 'coverage_export.rs':{'ty_json','named_ty_json'},'derive_inventory/schema.rs':{'ty'},
}
ds=json.loads((root/'diagnostics.json').read_text())
for d in ds:d[0]=os.path.normpath(d[0])
rows=[]
for group in ['src','tests','examples']:
 for p in sorted(Path('crates/benitoite',group).rglob('*.rs')):
  s=subprocess.check_output(['git','show','HEAD:'+str(p)]).decode()
  for m in re.finditer(r'I?Ty::Con',s):
   start=m.start();line=s.count('\n',0,start)+1;column=start-s.rfind('\n',0,start)
   prev=list(re.finditer(r'(?m)^\s*(?:pub(?:\([^)]*\))?\s+)?(?:async\s+)?fn\s+(\w+)',s[:start]))
   decl=prev[-1][1] if prev else '<module>'
   decl_line=s.count('\n',0,prev[-1].start())+1 if prev else 1
   comment=s[s.rfind('\n',0,start)+1:start].lstrip().startswith('//')
   key=str(p.relative_to(Path('crates/benitoite',group)))
   category='注記' if comment else ('意味' if decl in semantic.get(key,set()) else '機械')
   diagnostics=sorted(set(d[3] for d in ds if d[0]==str(p) and d[1]==line))
   rows.append(dict(group=group,file=str(p),line=line,column=column,declaration=f'{decl}:{decl_line}',category=category,diagnostics=diagnostics))
(root/'reader-inventory.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2)+'\n')
lines=['# 試行 T の読者の分類','',
 '基準は `a26ed29afaeb444325da1daf362d9fe7ad12b18b` である。計画の検索語 `Ty::Con` は `ITy::Con` も含む。同じファイル・行・桁を一出現、同じファイル・関数名・定義開始行を一宣言として数える。宣言の行はその宣言の開始位置である。', '',
 '「機械」は既存の構築の明示の Top と、分類・子だけの走査のパターンの引数追加である。「意味」は添字を保持・比較・表示する処理と、旧版への書き出しの拒否を要する処理である。コメントは別に数える。意味の分類は対象宣言全体に付ける。','',
 '初回の診断の位置は 正規化した相対パスで照合する。列挙した診断がない読者は検査済みとはしない。lib/lib test の失敗のため、独立した全統合ターゲットと examples の検査はまだ閉じていない。`tests/desugar_export` の3ファイル13出現はlib testにも含まれ、初回診断がある。残る5ファイル20出現と examples 3ファイル4出現は初回の下流で未検査である。','',
 '| 対象 | ファイル | 出現 | 宣言 | 機械 | 意味 | 注記 | 初回診断ありの出現 |','|---|---:|---:|---:|---:|---:|---:|---:|']
for group in ['src','tests','examples']:
 rs=[r for r in rows if r['group']==group];c=collections.Counter(r['category'] for r in rs)
 lines.append(f"| {group} | {len(set(r['file'] for r in rs))} | {len(rs)} | {len(set((r['file'],r['declaration']) for r in rs))} | {c['機械']} | {c['意味']} | {c['注記']} | {sum(bool(r['diagnostics']) for r in rs)} |")
lines+=['','src は51ファイル288箇所、tests は8ファイル33箇所であり計画と一致する。examples の3ファイル4箇所を追加して数えた。src のうち1箇所は代入の説明コメントである。','',
 '初回の一意の診断は281件・54ファイルである。E0023が153件、E0061が126件、二次的なE0614が2件である。libは196件、lib testは281件で失敗した。二重に表示されたlibの診断を足さない。','',
 '## ファイルごとの分類','', '| ファイル（crates/benitoite/ 起点） | 出現 | 宣言 | 機械 | 意味 | 注記 | 診断のない出現 |','|---|---:|---:|---:|---:|---:|---:|']
for fn in sorted(set(r['file'] for r in rows)):
 rs=[r for r in rows if r['file']==fn];c=collections.Counter(r['category'] for r in rs)
 lines.append(f"| `{fn.removeprefix('crates/benitoite/')}` | {len(rs)} | {len(set(r['declaration'] for r in rs))} | {c['機械']} | {c['意味']} | {c['注記']} | {sum(not r['diagnostics'] for r in rs)} |")
lines+=['','## 宣言ごとの分類','', '| ファイル・宣言 | 出現 | 分類 | 診断のない位置 |','|---|---:|---|---|']
for fn,decl in sorted(set((r['file'],r['declaration']) for r in rows)):
 rs=[r for r in rows if (r['file'],r['declaration'])==(fn,decl)]
 lines.append(f"| `{fn.removeprefix('crates/benitoite/')}::{decl}` | {len(rs)} | {', '.join(sorted(set(r['category'] for r in rs)))} | {', '.join(str(r['line'])+':'+str(r['column']) for r in rs if not r['diagnostics']) or '—'} |")
(root/'reader-tables.md').write_text('\n'.join(lines)+'\n')
print('\n'.join(lines[8:15]))
