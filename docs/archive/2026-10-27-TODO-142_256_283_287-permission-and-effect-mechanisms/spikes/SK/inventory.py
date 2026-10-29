#!/usr/bin/env python3
"""SK: pinned, direct lexical inventory; no production writes."""
import hashlib
import json
from pathlib import Path
import re
import subprocess

OUT = Path(__file__).resolve().parent
BASE = 'ec1c26afbe4253d38fc24c2d63d0ca367fa08b2c'
AREAS = ['formal/Benitoite/Release', 'formal/Benitoite/Surface', 'formal/Benitoite/Exchange', 'formal/SurfaceCheck']

def git(*args):
    r = subprocess.run(['git', *args], text=True, capture_output=True)
    if r.returncode not in (0, 1):
        raise RuntimeError(r.stderr)
    return r.stdout

# Comment/string erasure copied from SA/inventory.py.
def erase_comments_strings(source):
    # Preserve newlines, including those in nested block comments.
    out = []
    i = 0
    depth = 0
    string = False
    while i < len(source):
        if depth:
            if source.startswith('/-', i):
                depth += 1; out.extend('  '); i += 2
            elif source.startswith('-/', i):
                depth -= 1; out.extend('  '); i += 2
            else:
                out.append('\n' if source[i] == '\n' else ' '); i += 1
        elif string:
            if source[i] == '\\':
                out.extend('  '); i += 2
            elif source[i] == '"':
                string = False; out.append(' '); i += 1
            else:
                out.append('\n' if source[i] == '\n' else ' '); i += 1
        elif source.startswith('/-', i):
            depth = 1; out.extend('  '); i += 2
        elif source.startswith('--', i):
            end = source.find('\n', i)
            if end == -1:
                end = len(source)
            out.extend(' ' * (end - i)); i = end
        elif source[i] == '"':
            string = True; out.append(' '); i += 1
        else:
            out.append(source[i]); i += 1
    return ''.join(out)


SYMBOLS = ['io_op', 'io_typed', 'io_exists', 'effect_ops', 'io_kind', 'opEff_io',
           'ioResponse', 'Event', 'NoHandler', 'name_end', 'end_of_noHandler',
           'opSig', 'handled', 'HasTypeClausesQ', 'C_Handle', 'K_Handle', 'BuiltinOnly']
GROUPS = {
    'contracts': SYMBOLS[:6],
    'events': ['ioResponse', 'Event', 'E_IO', 'E_IOErr', 'E_Exit'],
    'propagation': ['NoHandler', 'name_end', 'end_of_noHandler', 'handled', 'HasTypeClausesQ', 'C_Handle', 'K_Handle', 'BuiltinOnly'],
}
patterns = {s: r'\b'+re.escape(s)+r'\b' for s in SYMBOLS}
patterns.update({k:r'\b(?:'+'|'.join(map(re.escape,v))+r')\b' for k,v in GROUPS.items()})
raw={}
for s in SYMBOLS:
    result=git('grep','-n','-w',s,BASE,'--',*AREAS)
    (OUT/(s+'.grep.txt')).write_text(result)
    raw[s]={'lines':len(result.splitlines()), 'files':len({l.split(':',2)[1] for l in result.splitlines()})}
files=git('ls-tree','-r','--name-only',BASE,*AREAS).splitlines()
entries=[]; hashes={}; main=[]
main_paths={
 'formal/Benitoite/Release/Theorems.lean': {'progress','preservation','effect_soundness'},
 'formal/Benitoite/Surface/Theorems.lean': {'desugar_typed'},
}
for path in files:
    if not path.endswith('.lean'): continue
    source=git('show',BASE+':'+path)
    hashes[path]=hashlib.sha256(source.encode()).hexdigest()
    lines=erase_comments_strings(source).splitlines(keepends=True)
    heads=[]; bounds=[]
    for i,line in enumerate(lines):
        if re.match(r'^(?:namespace|end|section|noncomputable\s+section|mutual|example|(?:noncomputable\s+)?instance|variable|open|attribute|import)\b|^#',line):
            bounds.append(i)
        d=re.match(r'^\s*(?:@\[[^\]]*\]\s*)*(?:(?:private|protected|noncomputable|partial|unsafe)\s+)*(theorem|lemma|def|abbrev|inductive|structure)\s+([^\s({:]+)',line)
        if d: heads.append((i,d))
    for pos,(i,d) in enumerate(heads):
        stop=heads[pos+1][0] if pos+1<len(heads) else len(lines)
        stop=min([stop]+[b for b in bounds if i<b<stop])
        body=''.join(lines[i:stop])
        if d[2] in main_paths.get(path,set()):
            main.append({'path':path,'line':i+1,'name':d[2], 'statement':body.split(':=',1)[0].strip()})
        body=body[:d.start(2)]+' '*(d.end(2)-d.start(2))+body[d.end(2):]
        cats=[k for k,p in patterns.items() if re.search(p,body)]
        if cats:
            entries.append({'path':path,'line':i+1,'kind':d[1],'name':d[2],'categories':cats,
               'statement_categories':[k for k,p in patterns.items() if re.search(p,body.split(':=',1)[0])]})
summary={}
for k in patterns:
    es=[e for e in entries if k in e['categories']]
    ts=[e for e in es if e['kind'] in ('theorem','lemma')]
    nonexamples=[e for e in ts if not re.search(r'(?:Examples|Counterexamples|/Model\.lean|/tests/)',e['path'])]
    summary[k]={'declarations':len(es),'files':len({e['path'] for e in es}),
      'theorems':len(ts),'theorem_files':len({e['path'] for e in ts}),
      'theorems_without_examples':len(nonexamples),'nonexample_files':len({e['path'] for e in nonexamples})}
union=[e for e in entries if any(k in e['categories'] for k in GROUPS)]
summary['groups_union']={'declarations':len(union),'files':len({e['path'] for e in union}),
 'theorems':len([e for e in union if e['kind'] in ('theorem','lemma')]),
 'theorem_files':len({e['path'] for e in union if e['kind'] in ('theorem','lemma')})}
result={'base':BASE,'areas':AREAS,'method':'git grep -n -w; comment/string-erased declaration blocks; own name excluded; direct lexical references only',
 'raw_grep':raw,'summary':summary,'main_theorems':main,'entries':entries,'source_sha256':hashes}
(OUT/'inventory.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
report=['# SK: 本番の直接参照の集計','',f'基準版: `{BASE}`。対象: Release・Surface・Exchange・SurfaceCheck。',
 '', 'コメント・文字列・宣言自身の名前を除く字句上の直接参照である。推移的な依存数でも、書き換える定理の確定数でもない。',
 '', '| 対象 | grep 一致行／ファイル | 直接参照する定理／ファイル | 例・Model を除く定理／ファイル |', '|---|---:|---:|---:|']
for k in SYMBOLS:
    r=raw[k];s=summary[k]
    report.append(f"| `{k}` | {r['lines']}／{r['files']} | {s['theorems']}／{s['theorem_files']} | {s['theorems_without_examples']}／{s['nonexample_files']} |")
report+=['','## 群の和集合','']
for k in [*GROUPS,'groups_union']:
    s=summary[k];report.append(f"- `{k}`: {s['declarations']}宣言／{s['files']}ファイル、うち定理{s['theorems']}件／{s['theorem_files']}ファイル。")
report+=['','## 主な定理の言明','']
for m in main:
    report+=[f"### {m['path']}:{m['line']} {m['name']}",'','```lean',m['statement'],'```','']
report+=['## 直接参照する宣言の一覧','']
for e in entries:
    report.append(f"- `{e['path']}:{e['line']}` `{e['name']}` ({e['kind']}): {', '.join(e['categories'])}")
(OUT/'inventory.md').write_text('\n'.join(report)+'\n')
print(json.dumps({'base':BASE,'raw':raw,'groups':{k:summary[k] for k in [*GROUPS,'groups_union']}},ensure_ascii=False,indent=2))
