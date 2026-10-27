"""固定TSVを保ち、二つの保存入力を各一度だけ評価して差分を記録する。"""
from pathlib import Path
import collections, hashlib, json, subprocess, time
OUT = Path(__file__).resolve().parent
ROOT = OUT.parents[2]
DIRECTORY = ROOT / 'crates/benitoite/testdata/interval-budget'
BASELINE = OUT.parent / 'l16b2/reference-raw'
fixed = {name: (DIRECTORY/(name+'.tsv')).read_bytes() for name in ('body','whole','summary')}
summary = {}
raw = OUT/'reference-raw'
raw.mkdir(exist_ok=True)
for name, widths in [('budget-reference.lean',(11,14)),('summary-reference.lean',(9,))]:
    destination = raw/(name+'.log')
    assert not destination.exists(), '保存済みの計算を重ねて実行しない: '+name
    command = ['lake','env','lean','-M','12288',str(DIRECTORY/name)]
    started = time.monotonic()
    result = subprocess.run(command,cwd=ROOT/'formal',capture_output=True,text=True)
    seconds = time.monotonic()-started
    output = result.stdout+result.stderr
    destination.write_text(output.replace(str(ROOT),'<repo>').replace(str(Path.home()),'<home>'))
    assert result.returncode == 0, (name,result.returncode)
    def rows(text):
        return {tuple(row[:3]): row for line in text.splitlines()
                if len(row := line.split('\t')) in widths and row[1].isdigit()}
    before,after=rows((BASELINE/(name+'.log')).read_text()),rows(output)
    assert before and after and before.keys() == after.keys(),name
    changes=collections.Counter(key[0] for key in before if before[key]!=after[key])
    summary[name]={'exit':0,'seconds':seconds,'baseline_rows':len(before),'current_rows':len(after),
                   'changed_rows_by_shape':dict(changes),
                   'changed_shapes_cap200':{shape:{'before':before[(shape,'0','200')],
                                                  'after':after[(shape,'0','200')]}
                                            for shape in changes}}
    print(name,json.dumps(summary[name],ensure_ascii=False),flush=True)
for name,data in fixed.items():
    assert data==(DIRECTORY/(name+'.tsv')).read_bytes(),name
summary['saved_sha256']={name:hashlib.sha256(data).hexdigest() for name,data in fixed.items()}
(OUT/'reference-impact.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n')
