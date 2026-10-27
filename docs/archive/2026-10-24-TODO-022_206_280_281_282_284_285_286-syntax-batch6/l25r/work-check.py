"""最終検査本体と外側の計測器の終了を分けて記録する。"""
import json,subprocess,time
import run
command=['scripts/check.sh','--level','work','--base',run.BASE,'--only','formal_build,spec_examples,spec_tally']
start=time.monotonic()
result=subprocess.run(command,cwd=run.ROOT)
(run.OUT/'work-check.json').write_text(json.dumps(dict(command=command,check_exit=result.returncode,
    seconds=round(time.monotonic()-start,3)),indent=2)+'\n')
raise SystemExit(result.returncode)
