"""既定ビルド又は全環境の監査を、formal から指定のロックの下で一度実行する。"""
import argparse
import datetime
import json
from pathlib import Path
import subprocess
import time
from evidence import HERE,ROOT,HEAD,digest,fingerprint,snapshot


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action',choices=['build','audit'])
    parser.add_argument('--tmp',type=Path,required=True)
    parser.add_argument('--lock',type=Path,required=True)
    args=parser.parse_args()
    args.tmp.mkdir(parents=True,exist_ok=True)
    label='build' if args.action=='build' else 'axioms'
    raw=args.tmp/(label+'.log')
    assert not raw.exists(),'生出力を上書きしない'
    sources=snapshot()
    before=fingerprint(sources)
    snapshot_file=args.tmp/(label+'-sources.json')
    snapshot_file.write_text(json.dumps(sources,sort_keys=True)+'\n')
    command=['/usr/bin/lockf','-t','3600',str(args.lock)]
    if label=='build':command+=['lake','build']
    else:command+=['lake','env','lean','-M','12288','../'+str(HERE.relative_to(ROOT))+'/axioms.lean']
    start=datetime.datetime.now().astimezone().isoformat(timespec='seconds')
    tick=time.monotonic()
    print(label+' 開始 '+start,flush=True)
    with raw.open('wb') as out:
        result=subprocess.run(command,cwd=ROOT/'formal',stdout=out,stderr=subprocess.STDOUT)
    row={'head':HEAD,'source_before':before,'source_after':fingerprint(),'start':start,
         'end':datetime.datetime.now().astimezone().isoformat(timespec='seconds'),
         'seconds':round(time.monotonic()-tick,3),'exit':result.returncode,'cwd':'formal',
         'command':[s.replace(str(args.lock),'<lock>') for s in command],
         'raw':digest(raw),'maximum_rss':'未取得（計画上の非採取）'}
    if label=='axioms':row['input']=digest(HERE/'axioms.lean')
    (HERE/('resume5-'+label+'.json')).write_text(json.dumps(row,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(row,ensure_ascii=False),flush=True)
    assert row['source_before']==row['source_after'],'検査中のソース変更'
    if result.returncode:print(raw.read_text()[-5000:])
    raise SystemExit(result.returncode)


if __name__=='__main__':main()
