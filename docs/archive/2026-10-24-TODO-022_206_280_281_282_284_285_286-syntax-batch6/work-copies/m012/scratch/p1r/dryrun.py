from pathlib import Path
import re, shlex, subprocess,json,time
D=Path('docs/2026-10-24-TODO-022_206_280_281_282-syntax-batch6')
p=(D/'plan.md').read_text()
rows={}
for line in p.splitlines():
    m=re.match(r'\| ([A-Z]\d\d[a-z]?) \| B_WORK',line)
    if not m: continue
    for cmd in re.findall(r'`(scripts/check\.sh --level work --base B_WORK[^`]*)`',line):
        cmd=cmd.strip().replace('B_WORK','706d7ca3')+' --dry-run'
        rows.setdefault(cmd,[]).append(m.group(1))
# R06の条件付き追加の指定、S-R2も実際の形で照合する。
rows['scripts/check.sh --level work --base 706d7ca3 --only reference_examples,skill_docs,skill_generated,tests_related --test skill_examples --test stdlib_doc_examples --dry-run']=['R06（Log.bntのdocを変える場合）']
rows['scripts/check.sh --level stage --base 706d7ca3 --only tests_related --test property_library --test reference_examples --test skill_docs --test skill_examples --test spec_examples --dry-run']=['S-R2']
results=[]
for i,(cmd,ids) in enumerate(rows.items(),1):
    t=time.monotonic()
    r=subprocess.run(shlex.split(cmd),capture_output=True,text=True)
    output=(r.stdout+r.stderr).replace(str(Path.cwd()),'<repo>').replace(str(Path.home()),'<home>')
    results.append(dict(number=i,rows=ids,command=cmd,exit=r.returncode,seconds=round(time.monotonic()-t,3),output=output))
    print(i,','.join(ids),'exit',r.returncode,'seconds',results[-1]['seconds'])
Path('work/m012/scratch/p1r/dryrun.json').write_text(json.dumps(results,ensure_ascii=False,indent=2))
print('command_forms',len(rows),'covered_work_rows',len({i for r in results for i in r['rows'] if re.fullmatch(r'[A-Z]\d\d[a-z]?',i)}))
