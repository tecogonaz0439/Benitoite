"""群 G の局所検査と最後の work の時刻・終了・出力の識別を保存する。"""
from pathlib import Path
from datetime import datetime, timezone
import argparse
import json
import subprocess
import time
from reconcile import HERE, ROOT, digest, save


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('kind',choices=['signatures','build','selection','work'])
    parser.add_argument('--tmp',type=Path,required=True)
    args=parser.parse_args();args.tmp.mkdir(parents=True,exist_ok=True)
    commands={'signatures':['lake','env','lean','-M','12288','../'+str((HERE/'signatures.lean').relative_to(ROOT))],
              'build':['lake','build'],
              'selection':['scripts/check.sh','--level','work','--base','fcde6fe216d35c3c74fcaa8d28164df063b6aa8b','--dry-run'],
              'work':['scripts/check.sh','--level','work','--base','fcde6fe216d35c3c74fcaa8d28164df063b6aa8b']}
    dest=HERE/(args.kind+'-check.json')
    assert not dest.exists(), '同じ検査の実行記録が既にある'
    command=commands[args.kind];raw=args.tmp/(args.kind+'.log')
    cwd=ROOT/'formal' if args.kind in {'signatures','build'} else ROOT
    start=datetime.now(timezone.utc);tick=time.monotonic()
    with raw.open('wb') as stream:
        result=subprocess.run(command,cwd=cwd,stdout=stream,stderr=subprocess.STDOUT)
    data={'command':command,'cwd':'formal' if cwd!=ROOT else '.',
          'start_utc':start.isoformat(),'end_utc':datetime.now(timezone.utc).isoformat(),
          'seconds':time.monotonic()-tick,'exit':result.returncode,'raw':digest(raw)}
    save(dest.name,data)
    if args.kind=='signatures' and result.returncode==0:
        (HERE/'signatures-definitions.md').write_text('# 入口と定義の実型\n\n```lean\n'+raw.read_text()+'```\n')
    print(json.dumps(data,ensure_ascii=False))
    raise SystemExit(result.returncode)


if __name__=='__main__':main()
